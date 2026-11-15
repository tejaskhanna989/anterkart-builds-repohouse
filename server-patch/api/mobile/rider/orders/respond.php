<?php
// Rider accepts/declines a driver offer. Accept atomically locks the order.
require_once __DIR__ . '/../../bootstrap.php';
require_once __DIR__ . '/../../../../admin/php/onesignal.php';

$rid = verifyToken('rider');
$input = getInput();
$offerId = (int)($input['offer_id'] ?? 0);
$action = strtolower(trim($input['action'] ?? 'accept'));
if (!$offerId || !in_array($action, ['accept', 'decline'], true)) jsonError('offer_id and action (accept|decline) required');

$tstmt = $pdo->prepare("SELECT tenant_id FROM delivery_boys WHERE id=?");
$tstmt->execute([$rid]);
$tid = (int)$tstmt->fetchColumn();
if (!$tid) jsonError('Unauthorized', 401);

$ostmt = $pdo->prepare("SELECT * FROM rider_offers WHERE id=? AND rider_id=?");
$ostmt->execute([$offerId, $rid]);
$offer = $ostmt->fetch();
if (!$offer || $offer['status'] !== 'offered' || strtotime($offer['expires_at']) <= time()) {
    jsonError('Offer expired or already taken', 410);
}
$orderId = (int)$offer['order_id'];

if ($action === 'decline') {
    $pdo->prepare("UPDATE rider_offers SET status='declined' WHERE id=?")->execute([$offerId]);
    answer_ping_session($orderId, 'rider', $rid, 'rejected');
    $o = $pdo->prepare("SELECT tenant_id FROM orders WHERE id=?");
    $o->execute([$orderId]);
    if ($orow = $o->fetch()) {
        require_once __DIR__ . '/../../../../admin/php/onesignal.php';
        answer_ping_session($orderId, 'rider', $rid, 'rejected');
        // Top up: offer the next-nearest riders so the search keeps moving.
        offer_drivers_nearby((int)$orow['tenant_id'], $orderId, 5);
    }
    jsonOk(['order_id' => $orderId], 'Offer declined');
}

// Accept: claim the offer row, then the order (both conditional — no double-lock).
$claim = $pdo->prepare("UPDATE rider_offers SET status='accepted' WHERE id=? AND rider_id=? AND status='offered' AND expires_at > NOW()");
$claim->execute([$offerId, $rid]);
if (!$claim->rowCount()) jsonError('Offer expired or already taken', 410);

$lock = $pdo->prepare("UPDATE orders SET delivery_boy_id=?, assigned_rider_at=NOW(), dispatch_status='assigned' WHERE id=? AND delivery_boy_id IS NULL AND status IN ('pending','confirmed','preparing','ready')");
$lock->execute([$rid, $orderId]);
if (!$lock->rowCount()) {
    jsonError('Order already taken by another rider', 409);
}

$pdo->prepare("UPDATE rider_offers SET status='expired' WHERE order_id=? AND id!=? AND status='offered'")->execute([$orderId, $offerId]);
require_once __DIR__ . '/../../../../admin/php/onesignal.php';
    answer_ping_session($orderId, 'rider', $rid, 'answered');
$pdo->prepare("INSERT INTO order_status_history (order_id, status, note) VALUES (?, (SELECT status FROM orders WHERE id=?), 'Driver secured (offer accepted)')")->execute([$orderId, $orderId]);
// Notify customer about the rider.
$vo = $pdo->prepare("SELECT tenant_id, customer_id, order_number FROM orders WHERE id=?");
$vo->execute([$orderId]);
if ($v = $vo->fetch()) {
    if (!empty($v['customer_id'])) {
        onesignal_notify_users([onesignal_customer_id((int)$v['customer_id'])], 'Rider secured #' . ($v['order_number'] ?? $orderId), 'Rider accepted your order. Track arrival in the app.', ['type' => 'driver_secured', 'order_id' => $orderId]);
        app_notify((int)$v['customer_id'], 'Rider secured', 'Your rider is on the way.', '/order/' . $orderId);
    }
}
// Notify vendor.
$vo2 = $pdo->prepare("SELECT tenant_id, order_number FROM orders WHERE id=?");
$vo2->execute([$orderId]);
if ($v2 = $vo2->fetch()) {
    onesignal_notify_users([onesignal_vendor_id((int)$v2['tenant_id'])], 'Driver secured #' . ($v2['order_number'] ?? $orderId), 'A rider accepted the order. Start preparation now.', ['type' => 'driver_secured', 'order_id' => $orderId]);
}
// Kitchen trigger for driver-first: tell the store to start cooking now.
$vo = $pdo->prepare("SELECT tenant_id, order_number FROM orders WHERE id=?");
$vo->execute([$orderId]);
if ($v = $vo->fetch()) {
    onesignal_notify_users([onesignal_vendor_id((int)$v['tenant_id'])], 'Driver secured #' . ($v['order_number'] ?? $orderId), 'A rider accepted the order. Start preparation now.', ['type' => 'driver_secured', 'order_id' => $orderId]);
}

// Tell the rider whether the counter handover code is still outstanding so the
// app can ask for it right away instead of hiding it in the order detail.
$pcStmt = $pdo->prepare("SELECT pickup_code FROM orders WHERE id=?");
$pcStmt->execute([$orderId]);
$pcRow = $pcStmt->fetch();
$needsCode = !empty($pcRow['pickup_code']) && (string)$pcRow['pickup_code'] !== '';

jsonOk(['order_id' => $orderId, 'locked' => true, 'needs_code' => $needsCode], 'Order accepted. Head to the store.');
