<?php
require_once __DIR__ . '/../../bootstrap.php';
require_once __DIR__ . '/../../../../admin/php/onesignal.php';

$vid = verifyToken('vendor');

$vstmt = $pdo->prepare("SELECT tenant_id FROM users WHERE id=? AND role='vendor'");
$vstmt->execute([$vid]);
$vendor = $vstmt->fetch();
if (!$vendor) jsonError('Unauthorized', 401);
$tid = (int)$vendor['tenant_id'];

$input = getInput();
$orderId = (int)($input['order_id'] ?? 0);
$status = trim($input['status'] ?? '');
$allowed = ['confirmed', 'preparing', 'ready', 'cancelled'];
if (!$orderId || !in_array($status, $allowed, true)) jsonError('order_id and valid status (confirmed, preparing, ready, cancelled) required');

$stmt = $pdo->prepare("SELECT * FROM orders WHERE id=? AND tenant_id=?");
$stmt->execute([$orderId, $tid]);
$order = $stmt->fetch();
if (!$order) jsonError('Order not found', 404);
if (in_array($order['status'], ['delivered', 'cancelled'], true)) jsonError('Order already ' . $order['status']);
// Forward-only flow: pending->confirmed/cancelled, confirmed->preparing/cancelled,
// preparing->ready/cancelled, ready->delivered (rider).
$okNext = ['pending' => ['confirmed', 'cancelled'], 'confirmed' => ['preparing', 'cancelled'], 'preparing' => ['ready', 'cancelled'], 'ready' => []];
if (!in_array($status, $okNext[$order['status']] ?? [], true)) jsonError("Cannot move order from {$order['status']} to $status");

$pdo->prepare("UPDATE orders SET status=? WHERE id=?")->execute([$status, $orderId]);
    if ($status === 'confirmed') {
        answer_ping_session($orderId, 'vendor', 0, 'answered');
    }

require_once __DIR__ . '/../../../../admin/php/onesignal.php';
$pickupCode = (string)($order['pickup_code'] ?? '');
if ($status === 'ready' && $pickupCode === '') {
    $pickupCode = new_pickup_code();
    $pdo->prepare("UPDATE orders SET pickup_code=? WHERE id=?")->execute([$pickupCode, $orderId]);
}
    if ($status === 'ready') {
        offer_drivers_nearby($tid, $orderId);
    }
order_history($orderId, $status, $status === 'confirmed' ? 'Accepted & confirmed by vendor' : ($status === 'cancelled' ? 'Rejected by vendor' : 'Marked ' . $status . ' by vendor'));
if ($status === 'confirmed') {
    // Dispatch step: driver-first stores lock a rider via offers, store-first
    // stores broadcast to the rider pool.
    if (fulfillment_model($tid) === 'driver_first') {
        offer_drivers_nearby($tid, $orderId);
    } else {
        // Store-first still needs rider awareness without blocking kitchen prep.
        offer_drivers_nearby($tid, $orderId);
    }
}
if ($status === 'cancelled') {
    // Free the locked driver and kill live offers so nobody rides out.
    $pdo->prepare("UPDATE rider_offers SET status='expired' WHERE order_id=? AND status='offered'")->execute([$orderId]);
    if (!empty($order['delivery_boy_id'])) {
        onesignal_notify_users([onesignal_rider_id((int)$order['delivery_boy_id'])], 'Order cancelled #' . ($order['order_number'] ?? $orderId), 'The kitchen cancelled this order. You are released.', ['type' => 'order_cancelled', 'order_id' => $orderId]);
        $pdo->prepare("UPDATE orders SET delivery_boy_id=NULL WHERE id=?")->execute([$orderId]);
    }
}
notify_order_stage($orderId, $status);

jsonOk(['order_id' => $orderId, 'status' => $status, 'pickup_code' => $pickupCode], 'Order status updated');
