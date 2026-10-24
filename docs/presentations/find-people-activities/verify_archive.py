"""Verify archived presentation bytes. Never renders, changes or downloads files."""
from __future__ import annotations

import hashlib
import json
from pathlib import Path
import sys


def verify(root: Path) -> int:
    manifest = json.loads((root / "manifest.json").read_text(encoding="utf-8"))
    records = manifest["versions"] + manifest["videos"] + manifest.get("additional_files", [])
    errors: list[str] = []
    seen: set[str] = set()
    for item in records:
        relative = item["path"]
        if relative in seen:
            errors.append(f"Duplicate manifest entry: {relative}")
            continue
        seen.add(relative)
        path = (root / relative).resolve()
        if not path.is_relative_to(root.resolve()):
            errors.append(f"Path outside archive: {relative}")
            continue
        if not path.is_file():
            errors.append(f"MISSING: {relative}")
            continue
        content = path.read_bytes()
        if len(content) != item["bytes"]:
            errors.append(f"Size changed: {relative}")
        if hashlib.sha256(content).hexdigest() != item["sha256"]:
            errors.append(f"Checksum changed: {relative}")
    versions = {item["version"] for item in manifest["versions"]}
    video_versions = {item["version"] for item in manifest["videos"]}
    if manifest["current_version"] not in versions:
        errors.append("Current HTML version is missing from the manifest")
    if manifest["current_video_version"] not in video_versions:
        errors.append("Current video version is missing from the manifest")
    if not manifest.get("videos_require_explicit_user_request"):
        errors.append("Explicit-request-only video policy is missing")
    listed_videos = {item["path"] for item in manifest["videos"]}
    actual_videos = {str(path.relative_to(root)).replace("\\", "/") for path in root.rglob("*.mp4")}
    for unlisted in sorted(actual_videos - listed_videos):
        errors.append(f"Unlisted video; verify explicit user authorization: {unlisted}")
    if errors:
        print("Archive verification FAILED:\n" + "\n".join(errors), file=sys.stderr)
        return 1
    print(f"Verified {len(manifest['versions'])} HTML versions, {len(manifest['videos'])} existing videos and {len(manifest.get('additional_files', []))} source files.")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(verify(Path(__file__).resolve().parent))
    except (OSError, KeyError, ValueError, TypeError) as exc:
        print(f"Archive verification FAILED: {exc}", file=sys.stderr)
        raise SystemExit(1)
