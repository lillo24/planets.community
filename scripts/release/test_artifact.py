import base64
import hashlib
from pathlib import Path
import tempfile
import unittest
import struct
import zipfile
from artifact import validate_manifest, validate_jarsigner, verify_payloads, validate_build, native_alignment


class ArtifactTests(unittest.TestCase):
    xml = '<manifest xmlns:android="http://schemas.android.com/apk/res/android" package="community.planets.app" android:versionCode="13" android:versionName="0.1.9"><uses-sdk android:minSdkVersion="24" android:targetSdkVersion="36"/><application android:debuggable="false"/></manifest>'

    def test_release_manifest(self):
        self.assertEqual(validate_manifest(self.xml, 13)["target_sdk"], 36)

    def test_untrusted_manifests(self):
        for xml in [self.xml.replace('app"', 'other"'), self.xml.replace('debuggable="false"', 'debuggable="true"'), self.xml.replace('targetSdkVersion="36"', 'targetSdkVersion="35"'), self.xml.replace('versionCode="13"', 'versionCode="12"')]:
            with self.assertRaises(ValueError):
                validate_manifest(xml, 13)

    def test_self_signed_upload_certificate_requires_integrity(self):
        warning = "jar verified.\nThis jar contains entries whose certificate chain is invalid. Reason: PKIX path building failed\nThis jar contains entries whose signer certificate is self-signed.\n"
        validate_jarsigner(warning)
        for output in [warning.replace("jar verified.", ""), warning + "unsigned entry", warning + "certificate expired", warning + "algorithm disabled", warning + "invalid signature", warning.replace("This jar contains entries whose signer certificate is self-signed.", "")]:
            with self.assertRaises(ValueError):
                validate_jarsigner(output)

    def test_unsigned_and_changed_payload(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "test.aab"
            digest = base64.b64encode(hashlib.sha256(b"signed").digest()).decode()
            for extra, data in [(False, b"signed"), (True, b"signed"), (False, b"changed")]:
                with zipfile.ZipFile(path, "w") as z:
                    z.writestr("META-INF/MANIFEST.MF", f"Manifest-Version: 1.0\n\nName: base/payload\nSHA-256-Digest: {digest}\n\n")
                    z.writestr("base/payload", data)
                    if extra:
                        z.writestr("base/unsigned", b"injected")
                if extra or data != b"signed":
                    with self.assertRaises(ValueError):
                        verify_payloads(path)
                else:
                    self.assertEqual(verify_payloads(path), 1)

    def test_map_config_and_clean_provenance(self):
        flags = {"LOCATION_MAP_TILES_ENABLED": "true", "LOCATION_MAP_CENTERS_ENABLED": "true", "LOCATION_DETAIL_TILES_ENABLED": "true", "LOCATION_MAP_CACHE_SECONDS": "60", "LOCATION_EDITOR_SEARCH_ENABLED": "true", "LOCATION_BASEMAP_BUDGET_ENABLED": "true"}
        build = {"source_commit": "a" * 40, "source_dirty": False, "backend": "https://cllpvruvrrvxczjitlqd.supabase.co", "defines": flags, "mode": "release", "target": "appbundle", "version_code": 13}
        policy = {"budget_basemap": True}
        self.assertEqual(validate_build(13, policy, build, "a" * 40), flags)
        for changed in [{**build, "source_dirty": True}, {**build, "backend": "http://localhost"}, {**build, "defines": {**flags, "LOCATION_MAP_TILES_ENABLED": "false"}}, {**build, "version_code": 12}]:
            with self.assertRaises(ValueError):
                validate_build(13, policy, changed, "a" * 40)

    def test_native_alignment(self):
        data = bytearray(128)
        data[:6] = b"\x7fELF\x02\x01"
        struct.pack_into("<Q", data, 32, 64)
        struct.pack_into("<HH", data, 54, 56, 1)
        struct.pack_into("<I", data, 64, 1)
        struct.pack_into("<Q", data, 112, 16384)
        native_alignment(data)
        struct.pack_into("<Q", data, 112, 4096)
        with self.assertRaises(ValueError):
            native_alignment(data)
