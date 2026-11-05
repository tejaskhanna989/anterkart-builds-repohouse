<?php
// Re-offer endpoint: re-sends offer to nearby riders (within 1km)
// Called every 2 seconds by the rider app until the offer is accepted or declined.
require_once __DIR__ . '/../../bootstrap.php';

$rid = verifyToken('rider');
$input = getInput();
$orderId = (int)($input['order_id'] ?? 0);
if (!$orderId) jsonError('order_id required');

$tid = storeTenantId();
$stmt = $pdo->prepare("SELECT id, status, delivery_boy_id FROM orders WHERE id=? AND tenant_id=?");
$stmt->execute([$orderId, $tid]);
$order = $stmt->fetch();
if (!$order) jsonError('Order not found', 404);
if ($order['status'] !== 'ready' && $order['status'] !== 'confirmed') jsonError('Order not available for pickup');
if ($order['delivery_boy_id'] !== null) jsonError('Order already assigned');

require_once __DIR__ . '/../../../../admin/php/onesignal.php';
$offered = offer_drivers_nearby($tid, $orderId, 10);
if ($offered === 0) {
    jsonError('No nearby riders available');
}
jsonOk(['offered' => $offered], 'Offer re-sent to nearby riders');