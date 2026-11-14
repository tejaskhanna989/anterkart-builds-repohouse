<?php
/**
 * Otamzo real-time helper: riders that are close to a point.
 *
 * Additive endpoint - it does not change any existing file.
 *
 * GET api/mobile/realtime/nearby_riders.php?store=<slug>&lat=24.85&lng=74.62&radius_km=1
 *   -> { success, data: { riders: [ {id, name, phone, lat, lng, distance_km} ], count } }
 */
require_once __DIR__ . '/../../bootstrap.php';

$input = getInput();
$lat = (float)($input['lat'] ?? 0);
$lng = (float)($input['lng'] ?? 0);
$radius = (float)($input['radius_km'] ?? 1);

if (!$lat || !$lng) jsonError('lat and lng are required');
if ($radius <= 0 || $radius > 25) $radius = 1.0;

function otamzo_haversine_km($lat1, $lng1, $lat2, $lng2) {
    $R = 6371.0;
    $dLat = deg2rad($lat2 - $lat1);
    $dLng = deg2rad($lng2 - $lng1);
    $a = sin($dLat / 2) * sin($dLat / 2)
        + cos(deg2rad($lat1)) * cos(deg2rad($lat2))
        * sin($dLng / 2) * sin($dLng / 2);
    return $R * 2 * atan2(sqrt($a), sqrt(1 - $a));
}

$sql = "SELECT id, name, phone, lat, lng FROM delivery_boys
        WHERE status='active' AND lat IS NOT NULL AND lng IS NOT NULL
          AND lat != 0 AND lng != 0";
$rows = $pdo->query($sql)->fetchAll();

$near = [];
foreach ($rows as $r) {
    $d = otamzo_haversine_km($lat, $lng, (float)$r['lat'], (float)$r['lng']);
    if ($d <= $radius) {
        $r['distance_km'] = round($d, 3);
        $near[] = $r;
    }
}
usort($near, function ($a, $b) { return $a['distance_km'] <=> $b['distance_km']; });

jsonOk(['riders' => $near, 'count' => count($near)], 'Nearby riders');
