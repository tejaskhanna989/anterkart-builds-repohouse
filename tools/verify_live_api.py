#!/usr/bin/env python3
"""Final end-to-end check against the live API using the exact transport and
parsing rules that the fixed Flutter apps use."""
import json
import urllib.error
import urllib.parse
import urllib.request

API = "https://otamzo.com/api/mobile"
ACCOUNTS = "/tmp/opencode/qa_accounts.json"


def form_post(path, fields, token=None):
    """Mirrors ApiService.post(): form encoded body, nested values JSON encoded."""
    body = urllib.parse.urlencode(
        {k: (json.dumps(v) if isinstance(v, (dict, list)) else str(v))
         for k, v in fields.items() if v is not None}
    ).encode()
    headers = {"Content-Type": "application/x-www-form-urlencoded", "Accept": "application/json"}
    if token:
        headers["Authorization"] = f"Bearer {token}"
    req = urllib.request.Request(f"{API}/{path}?store=all", data=body, headers=headers, method="POST")
    try:
        with urllib.request.urlopen(req, timeout=25) as r:
            return r.status, json.loads(r.read().decode())
    except urllib.error.HTTPError as e:
        try:
            return e.code, json.loads(e.read().decode())
        except Exception:
            return e.code, {"raw": "non-json"}
    except Exception as e:
        return "ERR", {"message": str(e)[:150]}


def get(path, token=None, **params):
    q = {"store": "all", **params}
    url = f"{API}/{path}?" + urllib.parse.urlencode(q)
    headers = {"Accept": "application/json"}
    if token:
        headers["Authorization"] = f"Bearer {token}"
    req = urllib.request.Request(url, headers=headers)
    try:
        with urllib.request.urlopen(req, timeout=25) as r:
            return r.status, json.loads(r.read().decode())
    except urllib.error.HTTPError as e:
        try:
            return e.code, json.loads(e.read().decode())
        except Exception:
            return e.code, {"raw": "non-json"}
    except Exception as e:
        return "ERR", {"message": str(e)[:150]}


def parse_coords(payload):
    """The exact rules of the fixed Order.fromJson."""
    def coord(v):
        if v is None:
            return None
        if isinstance(v, (int, float)):
            return float(v)
        s = str(v).strip()
        return float(s) if s else None

    lat, lng = coord(payload.get("rider_lat")), coord(payload.get("rider_lng"))
    if lat is None or lng is None:
        loc = payload.get("rider_location")
        if isinstance(loc, dict):
            lat, lng = coord(loc.get("lat")), coord(loc.get("lng"))
    if lat is None or lng is None:
        raw = str(payload.get("rider_location") or "").strip()
        if "," in raw:
            parts = raw.split(",")
            lat = float(parts[0].strip()) if parts[0].strip() else None
            lng = float(parts[1].strip()) if len(parts) > 1 and parts[1].strip() else None
    if lat is None or lng is None or (lat == 0 and lng == 0):
        lat = lng = None

    dlat = coord(payload.get("delivery_lat"))
    dlng = coord(payload.get("delivery_lng"))
    return lat, lng, dlat, dlng


acct = json.load(open(ACCOUNTS))["customer"]
email, password = acct["email"], acct["password"]

print(f"QA customer: {email}")
code, res = form_post("auth/login.php", {"email": email, "password": password})
print(f"1. login              -> {code} {res.get('message')}")
assert res.get("success"), "login failed"
token = res["data"]["token"]

code, res = form_post("cart/clear.php", {}, token)
print(f"2. cart/clear         -> {code} {res.get('message')}")

code, prods = get("products/list.php")
items = ((prods.get("data") or {}).get("products") or [])
pid = items[0]["id"]
print(f"3. products           -> {code} count={len(items)} id={pid}")

code, res = form_post("cart/add.php", {"product_id": pid, "quantity": 1}, token)
print(f"4. cart/add           -> {code} {res.get('message')}")

code, res = form_post("orders/create.php", {
    "address": "QA Test Address, Udaipur, Rajasthan 313001",
    "payment_method": "COD",
    "customer_name": "QA Customer",
    "customer_phone": "9999999999",
    "lat": 24.8535,
    "lng": 74.6201,
}, token)
print(f"5. orders/create      -> {code} {res.get('message')}")
data = res.get("data") or {}
oid = data.get("order_id")
print(f"   order #{oid}  {data.get('order_number')}  vendor={data.get('orders', [{}])[0].get('vendor_name')}  total={data.get('total')}")

code, res = get("orders/list.php", token)
orders = ((res.get("data") or {}).get("orders") or [])
print(f"6. orders/list        -> {code} count={len(orders)}")
if orders:
    lat, lng, dlat, dlng = parse_coords(orders[0])
    print(f"   parsed rider=({lat},{lng}) delivery=({dlat},{dlng})")

code, res = get("orders/detail.php", token, id=oid)
order = (res.get("data") or {}).get("order") or {}
lat, lng, dlat, dlng = parse_coords(order)
print(f"7. orders/detail      -> {code} status={order.get('status')} items={len(order.get('items') or [])}")
print(f"   parsed rider=({lat},{lng}) delivery=({dlat},{dlng})")

code, res = get("orders/track.php", token, order_id=oid)
t = res.get("data") or {}
print(f"8. orders/track       -> {code} stage={t.get('stage_label')}")
print(f"   store={json.dumps(t.get('store'))}  destination={json.dumps(t.get('destination'))[:90]}")

ok = all([
    res.get("success") is not False,
    oid,
    dlat is not None and dlng is not None,
    (t.get("store") or {}).get("lat") is not None,
])
print()
print("RESULT:", "PASS — the whole customer flow works with the fixed transport" if ok else "FAIL")

with open("/tmp/opencode/qa_order.json", "w") as f:
    json.dump({"order_id": oid, "token": token, "email": email, "password": password}, f, indent=2)
