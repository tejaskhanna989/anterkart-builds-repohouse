<?php
/**
 * Otamzo real-time helper: push a notification to the riders that are near
 * a store (and therefore able to take the delivery quickly).
 *
 * This file is ADDITIVE: it does not replace or modify any existing
 * endpoint. The vendor app calls it right after it marks an order as
 * ready / preparing. When the file is not deployed yet the app simply
 * skips the call — nothing breaks.
 *
 * Requires ONESIGNAL_APP_ID + ONESIGNAL_REST_KEY in admin/php/config.php.
 *
 * POST api/mobile/realtime/notify.php?store=<slug>
 *   order_id       (int)    order the rider can pick up
 *   lat, lng       (float)  store coordinates
 *   radius_km      (float)  search radius, default 1 km
 *   title          (string) optional
 *   message        (string) optional
 *
 * GET api/mobile/realtime/nearby_riders.php?store=<slug>&lat=..&lng=..&radius_km=1
 *   -> list of riders within the radius (used for diagnostics)
 */
require_once __DIR__ . '/../bootstrap.php';

$input = getInput();
$isPost = $_SERVER['REQUEST_METHOD'] === 'POST';

function otamzo_haversine_km($lat1, $lng1, $lat2, $lng2) {
    $R = 6371.0;
    $dLat = deg2rad($lat2 - $lat1);
    $dLng = deg2rad($lng2 - $lng1);
    $a = sin($dLat / 2) * sin($dLat / 2)
        + cos(deg2rad($lat1)) * cos(deg2rad($lat2))
        * sin($dLng / 2) * sin($dLng / 2);
    return $R * 2 * atan2(sqrt($a), sqrt(1 - $a));
}

/**
 * Riders with a known position that are within $radiusKm of the point.
 * Riders without GPS data are skipped - they cannot be "nearby".
 */
function otamzo_nearby_riders($pdo, $lat, $lng, $radiusKm, $tenantId = null) {
    $sql = "SELECT id, name, phone, lat, lng FROM delivery_boys
            WHERE status='active' AND lat IS NOT NULL AND lng IS NOT NULL
              AND lat != 0 AND lng != 0";
    $args = [];
    if ($tenantId) {
        $sql .= " AND tenant_id = ?";
        $args[] = (int)$tenantId;
    }
    $rows = $pdo->query($sql)->fetchAll();

    $near = [];
    foreach ($rows as $r) {
        $d = otamzo_haversine_km($lat, $lng, (float)$r['lat'], (float)$r['lng']);
        if ($d <= $radiusKm) {
            $r['distance_km'] = round($d, 3);
            $near[] = $r;
        }
    }
    usort($near, function ($a, $b) { return $a['distance_km'] <=> $b['distance_km']; });
    return $near;
}

if (!$isPost) {
    // Diagnostic mode: list nearby riders.
    $lat = (float)($input['lat'] ?? 0);
    $lng = (float)($input['lng'] ?? 0);
    $radius = (float)($input['radius_km'] ?? 1);
    if (!$lat || !$lng) jsonError('lat and lng are required');
    $near = otamzo_nearby_riders($pdo, $lat, $lng, $radius);
    jsonOk(['riders' => $near, 'count' => count($near)], 'Nearby riders');
}

$orderId   = (int)($input['order_id'] ?? 0);
$lat       = (float)($input['lat'] ?? 0);
$lng       = (float)($input['lng'] ?? 0);
$radius    = (float)($input['radius_km'] ?? 1);
$title     = trim($input['title'] ?? 'New delivery nearby');
$message   = trim($input['message'] ?? 'A delivery is ready near you — tap to accept.');
$orderNo   = trim($input['order_number'] ?? '');

if ($radius <= 0 || $radius > 25) $radius = 1.0;

$near = [];
if ($lat && $lng) {
    // Scope the search to the store that owns the order so riders of another
    // store are never woken up for it.
    $tenantId = null;
    if ($orderId) {
        try {
            $ostmt = $pdo->prepare("SELECT tenant_id FROM orders WHERE id=?");
            $ostmt->execute([$orderId]);
            $tenantId = $ostmt->fetchColumn();
            $tenantId = $tenantId ? (int)$tenantId : null;
        } catch (Throwable $e) { $tenantId = null; }
    }
    $near = otamzo_nearby_riders($pdo, $lat, $lng, $radius, $tenantId);
}

// Also notify every rider that has a live OneSignal subscription for this
// tenant, so a rider without GPS is still told about the delivery.
require_once __DIR__ . '/../../../admin/php/onesignal.php';

$notified = 0;
if (!empty($near)) {
    $ids = [];
    foreach ($near as $r) $ids[] = onesignal_rider_id((int)$r['id']);
    if (onesignal_notify_users($ids, $title, $message, [
        'type' => 'nearby_order',
        'order_id' => $orderId,
        'order_number' => $orderNo,
        'radius_km' => $radius,
        'distance_km' => $near[0]['distance_km'],
    ])) {
        $notified = count($ids);
    }
}

jsonOk([
    'order_id' => $orderId,
    'nearby_count' => count($near),
    'notified' => $notified,
    'riders' => array_map(function ($r) {
        return ['id' => (int)$r['id'], 'name' => $r['name'], 'distance_km' => $r['distance_km']];
    }, $near),
    'onesignal_enabled' => function_exists('onesignal_enabled') ? onesignal_enabled() : false,
], 'Riders notified');
