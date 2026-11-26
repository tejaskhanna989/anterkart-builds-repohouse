#!/usr/bin/env python3
"""Validate a release APK before it is published.

A broken package reaches a phone as "There was an error while parsing the
package", which is impossible to debug after the fact. This gate rejects an
APK before publication unless it is demonstrably installable:

  * the ZIP container is intact (no bad CRC, no duplicate entries)
  * AndroidManifest.xml is a valid binary-XML document
  * the package name, the launcher activity and the version code are the ones
    that were asked for
  * resources.arsc and classes.dex are present and have a valid header

Usage:
    python3 tools/verify_apk.py <apk> --package com.otamzo.vendor \
        --min-version-code 2002 [--label "Otamzo Vendor"]
"""
import argparse
import struct
import sys
import zipfile

ANDROID_NS = "http://schemas.android.com/apk/res/android"
RES_STRING_POOL = 0x0001
RES_XML_START_ELEMENT = 0x0102
RES_XML_END_ELEMENT = 0x0103
RES_XML_TYPE = 0x0003


class ValidationError(Exception):
    pass


# --------------------------------------------------------------------------
# Binary XML (AXML) reader
# --------------------------------------------------------------------------
def read_string_pool(data, off):
    header_size, chunk_size = struct.unpack_from("<HH", data, off + 2)
    string_count, _style_count, flags, strings_start, _styles_start = struct.unpack_from(
        "<IIIII", data, off + 8
    )
    is_utf8 = bool(flags & (1 << 8))
    offsets = []
    for i in range(string_count):
        (o,) = struct.unpack_from("<I", data, off + header_size + 4 * i)
        offsets.append(o)
    base = off + strings_start
    strings = []
    for o in offsets:
        p = base + o
        if is_utf8:
            (char_len,) = struct.unpack_from("<B", data, p)
            p += 1
            if char_len & 0x80:
                p += 1
            (byte_len,) = struct.unpack_from("<B", data, p)
            p += 1
            if byte_len & 0x80:
                (byte_len,) = struct.unpack_from("<H", data, p)
                p += 2
            strings.append(data[p:p + byte_len].decode("utf-8", "replace"))
        else:
            (char_len,) = struct.unpack_from("<H", data, p)
            p += 2
            if char_len & 0x8000:
                p += 4
            strings.append(data[p:p + char_len * 2].decode("utf-16-le", "replace"))
    return strings, off + chunk_size


def parse_axml(data):
    strings = []
    events = []
    off = 0
    while off < len(data):
        chunk_type, header_size, chunk_size = struct.unpack_from("<HHI", data, off)
        if chunk_type == RES_XML_TYPE:
            off += header_size
            continue
        if chunk_type == RES_STRING_POOL:
            strings, _ = read_string_pool(data, off)
        elif chunk_type == RES_XML_START_ELEMENT:
            ns_idx, name_i, attr_start, attr_size, attr_count = struct.unpack_from(
                "<IIHHH", data, off + header_size
            )
            attrs = {}
            p = off + header_size + attr_start
            for _ in range(attr_count):
                (a_ns, a_name, _raw, _size, _res0, a_type, a_data) = struct.unpack_from(
                    "<IIIHBBI", data, p
                )
                ns = strings[a_ns] if a_ns != 0xFFFFFFFF else ""
                value = strings[a_data] if a_type == 0x03 else a_data
                attrs[(ns, strings[a_name])] = value
                p += attr_size
            events.append(("start", strings[name_i], attrs))
        elif chunk_type == RES_XML_END_ELEMENT:
            _ns, name_i = struct.unpack_from("<II", data, off + header_size)
            events.append(("end", strings[name_i], {}))
        off += chunk_size
    return events


def manifest_facts(zf):
    raw = zf.read("AndroidManifest.xml")
    events = parse_axml(raw)
    facts = {
        "package": None,
        "version_code": None,
        "version_name": None,
        "min_sdk": None,
        "target_sdk": None,
        "label": None,
        "launchers": [],
        "activities": [],
    }
    current = None
    for kind, name, attrs in events:
        if kind != "start":
            continue

        def a(key, default=None):
            return attrs.get((ANDROID_NS, key), default)

        if name == "manifest":
            # The package attribute carries no namespace prefix.
            facts["package"] = attrs.get(("", "package"))
            facts["version_code"] = a("versionCode")
            facts["version_name"] = a("versionName")
        elif name == "uses-sdk":
            facts["min_sdk"] = a("minSdkVersion")
            facts["target_sdk"] = a("targetSdkVersion")
        elif name == "application":
            facts["label"] = a("label")
        elif name in ("activity", "activity-alias"):
            current = {
                "name": a("name"),
                "actions": [],
                "categories": [],
            }
            facts["activities"].append(current)
        elif name == "action" and current is not None:
            current["actions"].append(a("name"))
        elif name == "category" and current is not None:
            current["categories"].append(a("name"))

    for act in facts["activities"]:
        if "android.intent.action.MAIN" in act["actions"] and \
           "android.intent.category.LAUNCHER" in act["categories"]:
            facts["launchers"].append(act["name"])
    return facts


# --------------------------------------------------------------------------
# Container checks
# --------------------------------------------------------------------------
def check_zip(path):
    zf = zipfile.ZipFile(path)
    bad = zf.testzip()
    if bad is not None:
        raise ValidationError(f"corrupt ZIP entry (bad CRC): {bad}")
    names = zf.namelist()
    seen = set()
    for n in names:
        if n in seen:
            raise ValidationError(f"duplicate ZIP entry: {n}")
        seen.add(n)
    for required in ("AndroidManifest.xml", "resources.arsc", "classes.dex"):
        if required not in names:
            raise ValidationError(f"missing {required}")
    return zf


def check_resources(zf):
    raw = zf.read("resources.arsc")
    if len(raw) < 12:
        raise ValidationError("resources.arsc is too small")
    res_type, header_size, size = struct.unpack_from("<HHI", raw, 0)
    if res_type != 0x0002:
        raise ValidationError(f"resources.arsc has an unexpected type 0x{res_type:04x}")
    if header_size != 12 or size != len(raw):
        raise ValidationError("resources.arsc header does not match the file size")
    (package_count,) = struct.unpack_from("<I", raw, 12)
    if package_count < 1:
        raise ValidationError("resources.arsc contains no resource package")


def check_dex(zf):
    raw = zf.read("classes.dex")
    if len(raw) < 112:
        raise ValidationError("classes.dex is too small")
    if not raw.startswith(b"dex\n"):
        raise ValidationError("classes.dex has no dex magic")
    (file_size,) = struct.unpack_from("<I", raw, 32)
    if file_size != len(raw):
        raise ValidationError("classes.dex header size does not match the file size")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("apk")
    parser.add_argument("--package", required=True)
    parser.add_argument("--min-version-code", type=int, default=0)
    parser.add_argument("--label", default=None)
    args = parser.parse_args()

    try:
        zf = check_zip(args.apk)
        check_resources(zf)
        check_dex(zf)
        facts = manifest_facts(zf)
    except (ValidationError, KeyError, struct.error, IndexError) as exc:
        print(f"INVALID  {args.apk}: {exc}")
        return 1

    problems = []
    if facts["package"] != args.package:
        problems.append(f"package is {facts['package']!r}, expected {args.package!r}")
    if not facts["launchers"]:
        problems.append("no MAIN/LAUNCHER activity")
    if facts["version_code"] is None:
        problems.append("no versionCode")
    elif facts["version_code"] < args.min_version_code:
        problems.append(
            f"versionCode {facts['version_code']} is below {args.min_version_code}"
        )
    if args.label and facts["label"] != args.label:
        problems.append(f"label is {facts['label']!r}, expected {args.label!r}")

    if problems:
        print(f"INVALID  {args.apk}: " + "; ".join(problems))
        return 1

    print(
        f"OK       {args.apk}: package={facts['package']} "
        f"versionCode={facts['version_code']} versionName={facts['version_name']} "
        f"minSdk={facts['min_sdk']} targetSdk={facts['target_sdk']} "
        f"label={facts['label']!r} launcher={facts['launchers'][0]} "
        f"activities={len(facts['activities'])}"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
