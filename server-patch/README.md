# Server patch — "ring nearby riders when an order is ready"

These files are **additive**. Nothing existing is replaced or deleted, and the
apps keep working if they are never uploaded (the app call is best effort).

## What it does

| File | Purpose |
|------|---------|
| `api/mobile/realtime/notify.php` | Finds every active rider with GPS data within `radius_km` (default **1 km**) of the store and sends them a OneSignal push. Called by the vendor app right after it marks an order `ready` / `preparing`. |
| `api/mobile/realtime/nearby_riders.php` | Read-only helper that lists the riders within a radius. Useful for checking the flow from a browser. |

The rider app already polls `rider/orders/offers.php` every 2 seconds, so as
soon as the server creates an offer the rider's phone starts ringing
(`OrderAlarm` now really plays the alarm loop).

## Install (Hostinger hPanel)

1. Open **hPanel → File Manager**.
2. Go to the folder that contains `api/mobile/` (the site root).
3. Create the folder `api/mobile/realtime/`.
4. Upload `notify.php` and `nearby_riders.php` into it.
5. Make sure the file permissions are `644` and the owner is your hPanel user.

FTP alternative:

```bash
cd server-patch
ftp -inv otamzo.com <<'EOF'
user <hpanel-username> <hpanel-password>
binary
cd /public_html
mkdir api/mobile/realtime
cd api/mobile/realtime
put api/mobile/realtime/notify.php
put api/mobile/realtime/nearby_riders.php
bye
EOF
```

## Enable the server side OneSignal push

Open `admin/php/config.php` and set the two constants (they are empty today,
which disables every server side push):

```php
define('ONESIGNAL_APP_ID', '99648958-99e9-4e1e-a015-96e4b512af7d');
define('ONESIGNAL_REST_KEY', '<REST API KEY from OneSignal → Settings → Keys & IDs>');
```

The **REST API Key** is not the App ID and it is not visible in the apps — it
has to be copied from the OneSignal dashboard. Without it the app still rings
(via polling) but a closed app cannot be woken up.

## Verify

```bash
# Riders within 1 km of the store (browser or curl)
curl "https://otamzo.com/api/mobile/realtime/nearby_riders.php?store=all&lat=24.853545&lng=74.620191&radius_km=1"
```

```bash
# Push the notification to those riders
curl -X POST "https://otamzo.com/api/mobile/realtime/notify.php?store=all" \
  -d "order_id=38&lat=24.853545&lng=74.620191&radius_km=1&order_number=AK20261114A2A31E"
```

The response contains `nearby_count`, `notified` and `onesignal_enabled`.
`onesignal_enabled: false` means the REST key is still missing.

## Notes

* Riders are matched on `delivery_boys.lat/lng`, which the rider app updates
  every 5 seconds (`rider/location/update.php`). A rider who has never opened
  the app has no position and is therefore not "nearby".
* The push targets the OneSignal external id `rider:<id>`, which is what the
  rider app logs in with (`OneSignalService.loginAsRider`).
* The server already creates the delivery offers; this patch only adds the
  *notification* to the nearby riders and the diagnostic helper.
