"""Inspect a signed AAB with pinned bundletool and the installed JDK. No secrets."""
import base64
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import struct
import sys
import urllib.request
import xml.etree.ElementTree as ET
import zipfile

TOOL_URL = "https://github.com/google/bundletool/releases/download/1.18.3/bundletool-all-1.18.3.jar"
TOOL_SHA = "a099cfa1543f55593bc2ed16a70a7c67fe54b1747bb7301f37fdfd6d91028e29"
ANDROID = "{http://schemas.android.com/apk/res/android}"


def run(args):
    result = subprocess.run(args, capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=180)
    if result.returncode:
        raise ValueError("Artifact tool failed: " + args[0] + "; output withheld")
    return result.stdout


def validate_manifest(xml, code):
    root = ET.fromstring(xml)
    app = root.find("application")
    sdk = root.find("uses-sdk")
    if (root.get("package") != "community.planets.app"
            or root.get(ANDROID + "versionCode") != str(code)
            or app is None or app.get(ANDROID + "debuggable", "false") != "false"
            or sdk is None or int(sdk.get(ANDROID + "targetSdkVersion", "0")) < 36):
        raise ValueError("AAB package/version/target/debug contract failed")
    return {"package": root.get("package"), "version_code": code,
            "version_name": root.get(ANDROID + "versionName"),
            "target_sdk": int(sdk.get(ANDROID + "targetSdkVersion")),
            "min_sdk": int(sdk.get(ANDROID + "minSdkVersion", "0")), "debuggable": False}


def validate_jarsigner(output):
    # Upload certificates are intentionally self-signed. Trust comes from the
    # separately pinned Play upload certificate, not the JDK's CA trust store.
    # Keep integrity/expiry/algorithm failures fatal and verify every ZIP payload.
    lines = output.splitlines()
    self_signed = "This jar contains entries whose signer certificate is self-signed." in lines
    remaining = "\n".join(line for line in lines if not (
        self_signed and line.startswith("This jar contains entries whose certificate chain is invalid. Reason:")
    ))
    if "jar verified." not in output or re.search(r"unsigned|expired|disabled|invalid", remaining, re.I):
        raise ValueError("AAB signature verification failed")


def verify_payloads(bundle):
    # Jarsigner checks signatures; independently reject *any* unsigned payload.
    with zipfile.ZipFile(bundle) as archive:
        manifest = archive.read("META-INF/MANIFEST.MF").decode("utf-8").replace("\r\n", "\n").replace("\n ", "")
        signed = {}
        for section in manifest.split("\n\n"):
            fields = dict(line.split(": ", 1) for line in section.splitlines() if ": " in line)
            if "Name" in fields:
                signed[fields["Name"]] = fields.get("SHA-256-Digest")
        payloads = [n for n in archive.namelist() if not n.endswith("/") and not n.upper().startswith("META-INF/")]
        if not payloads:
            raise ValueError("Empty AAB")
        for name in payloads:
            digest = base64.b64encode(hashlib.sha256(archive.read(name)).digest()).decode("ascii")
            if signed.get(name) != digest:
                raise ValueError("Unsigned/changed AAB payload")
        return len(payloads)


def mock_target(variant):
    if variant == "staging":
        return {"capability": False}
    if variant == "closed-test-mock":
        return {"capability": True, "origin": "https://pnolarmzxmmjtguligfc.supabase.co",
                "broker": "https://pnolarmzxmmjtguligfc.supabase.co/functions/v1/mock-personas",
                "generation": "mock-world-2026-10-21-v1", "hosted_readiness_verified": False}
    raise ValueError("Unknown release variant")


def compiled_capability(data, enabled):
    marker = b"PLANETS_COMPILED_MOCK_V1=" + (b"true" if enabled else b"false")
    opposite = b"PLANETS_COMPILED_MOCK_V1=" + (b"false" if enabled else b"true")
    if marker not in data or opposite in data:
        raise ValueError("Compiled Mock capability is absent, conflicting or incorrect")
    if enabled and b"https://pnolarmzxmmjtguligfc.supabase.co/functions/v1/mock-personas" not in data:
        raise ValueError("Compiled mock broker is missing")
    return marker.decode("ascii")


def compiled_map(data, budget):
    marker = b"PLANETS_COMPILED_MAP_V1=11111" + (b"1" if budget else b"0")
    if set(re.findall(rb"PLANETS_COMPILED_MAP_V1=[01]{6}", data)) != {marker}:
        raise ValueError("Compiled map defines are absent, conflicting or incorrect")
    return marker.decode("ascii")


def scan_payload(data):
    if re.search(rb"sb_secret_[A-Za-z0-9_-]+|eyJ[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+", data):
        raise ValueError("Privileged key or JWT found in AAB")


def validate_build(code, policy, build_manifest, source_sha, variant="staging"):
    expected = {"LOCATION_MAP_TILES_ENABLED": "true", "LOCATION_MAP_CENTERS_ENABLED": "true",
                "LOCATION_DETAIL_TILES_ENABLED": "true", "LOCATION_MAP_CACHE_SECONDS": "60",
                "LOCATION_EDITOR_SEARCH_ENABLED": "true"}
    if policy["budget_basemap"]:
        expected["LOCATION_BASEMAP_BUDGET_ENABLED"] = "true"
    if (build_manifest.get("source_commit") != source_sha or build_manifest.get("source_dirty") is not False
            or build_manifest.get("mock") != mock_target(variant)
            or build_manifest.get("backend") != "https://cllpvruvrrvxczjitlqd.supabase.co"
            or build_manifest.get("defines") != expected or build_manifest.get("mode") != "release"
            or build_manifest.get("target") != "appbundle" or build_manifest.get("version_code") != code):
        raise ValueError("Build provenance/config/map flags failed")
    return expected


def native_alignment(data):
    if data[:6] != b"\x7fELF\x02\x01":
        raise ValueError("Expected 64-bit little-endian ELF")
    offset = struct.unpack_from("<Q", data, 32)[0]
    size, count = struct.unpack_from("<HH", data, 54)
    loads = 0
    for index in range(count):
        header = offset + index * size
        if struct.unpack_from("<I", data, header)[0] == 1:
            loads += 1
            if struct.unpack_from("<Q", data, header + 48)[0] < 16384:
                raise ValueError("Native load segment lacks 16 KiB alignment")
    if not loads:
        raise ValueError("Missing ELF load segments")


def inspect(bundle, code, policy, build_manifest, source_sha, variant="staging"):
    if not re.fullmatch(r"[0-9a-f]{64}", policy.get("upload_certificate_sha256") or ""):
        raise ValueError("Missing verified original upload certificate SHA-256")
    expected = validate_build(code, policy, build_manifest, source_sha, variant)
    tool = Path("build/release01/bundletool.jar")
    tool.parent.mkdir(parents=True, exist_ok=True)
    if not tool.exists():
        with urllib.request.urlopen(TOOL_URL, timeout=120) as response:
            tool.write_bytes(response.read())
    if hashlib.sha256(tool.read_bytes()).hexdigest() != TOOL_SHA:
        raise ValueError("Bundletool checksum mismatch")
    run(["java", "-jar", str(tool), "validate", "--bundle=" + str(bundle)])
    xml = run(["java", "-jar", str(tool), "dump", "manifest", "--bundle=" + str(bundle), "--module=base"])
    evidence = validate_manifest(xml, code)
    verification = run(["jarsigner", "-J-Duser.language=en", "-verify", str(bundle)])
    validate_jarsigner(verification)
    certificate = run(["keytool", "-J-Duser.language=en", "-printcert", "-jarfile", str(bundle)])
    fingerprints = re.findall(r"SHA256:\s*([A-Fa-f0-9:]+)", certificate)
    if len(fingerprints) != 1 or fingerprints[0].replace(":", "").lower() != policy["upload_certificate_sha256"]:
        raise ValueError("AAB does not match the original upload certificate")
    evidence.update({"sha256": hashlib.sha256(bundle.read_bytes()).hexdigest(), "source_sha": source_sha,
                     "upload_certificate_sha256": policy["upload_certificate_sha256"], "signed_payloads": verify_payloads(bundle),
                     "backend": build_manifest["backend"], "map_defines": expected, "demos_enabled": False, "release_variant": variant,
                     "mock_capability": mock_target(variant)["capability"], "mock": mock_target(variant)})
    with zipfile.ZipFile(bundle) as archive:
        libraries = [n for n in archive.namelist() if n.endswith("/libapp.so")]
        if not libraries or not all(build_manifest["backend"].encode() in archive.read(n) for n in libraries):
            raise ValueError("Staging origin absent from compiled app libraries")
        evidence["compiled_map_defines"] = {
            n: compiled_map(archive.read(n), policy["budget_basemap"]) for n in libraries}
        evidence["compiled_capabilities"] = {
            n: compiled_capability(archive.read(n), evidence["mock_capability"]) for n in libraries}
        for name in archive.namelist():
            if not name.endswith("/"):
                scan_payload(archive.read(name))
        evidence["all_payloads_scanned"] = True
        native = [n for n in archive.namelist() if n.startswith("base/lib/") and n.endswith(".so")]
        if set(n.split("/")[2] for n in native) != {"armeabi-v7a", "arm64-v8a", "x86_64"}:
            raise ValueError("Unexpected AAB ABI set")
        # Android's 16 KiB requirement concerns 64-bit native libraries.
        checked = [n for n in native if "/arm64-v8a/" in n or "/x86_64/" in n]
        for name in checked:
            native_alignment(archive.read(name))
        evidence["native_16k_checks"] = len(checked)
    return evidence


if __name__ == "__main__":
    try:
        policy = json.loads(Path("scripts/release/policy.json").read_text(encoding="utf-8"))
        build = json.loads(Path("apps/mobile/build/map-live-staging/manifest.json").read_text(encoding="utf-8"))
        result = inspect(Path(sys.argv[1]), int(sys.argv[2]), policy, build, os.environ["GITHUB_SHA"], os.environ.get("RELEASE_VARIANT", "staging"))
        Path("build/release01/artifact.json").write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
        print("Verified signed AAB; nonsecret evidence in build/release01/artifact.json")
    except (ValueError, OSError, KeyError, ET.ParseError, zipfile.BadZipFile, subprocess.SubprocessError):
        print("RELEASE01 artifact verification failed; no upload allowed. Check signing, manifest, map config and provenance.", file=sys.stderr)
        sys.exit(1)
