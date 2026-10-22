"""Scan the private release fixture; export hashes/counts, never APK contents."""
import hashlib
import json
import re
import sys
import zipfile
from pathlib import Path

apk, secret_file, report_file = map(Path, sys.argv[1:])
secrets = json.loads(secret_file.read_text(encoding="utf-8"))
assert len(secrets) == 2 and all(isinstance(value, str) and len(value) > 30 for value in secrets)
scanned = 0
with zipfile.ZipFile(apk) as bundle:
    for entry in bundle.infolist():
        if entry.is_dir():
            continue
        data = bundle.read(entry)
        assert not any(value.encode() in data for value in secrets), "Privileged backend credential in APK"
        assert re.search(rb"sb_secret_[A-Za-z0-9_-]{20,}", data) is None, "Privileged key pattern in APK"
        assert re.search(rb"eyJ[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}", data) is None, "Embedded session JWT in APK"
        scanned += 1
report_file.parent.mkdir(parents=True, exist_ok=True)
report_file.write_text(json.dumps({"success": True, "entriesScanned": scanned,
    "sha256": hashlib.sha256(apk.read_bytes()).hexdigest(),
    "artifact": "private signed release-mode CI fixture; not upload-ready",
    "privilegedCredentialsFound": 0, "embeddedSessionJwtsFound": 0}, indent=2) + "\n", encoding="utf-8")
