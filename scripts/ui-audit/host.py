"""UIAUDIT01 loopback command bridge and original Android PNG provenance.

Use only with the task-owned emulator-5580 and ui_audit_test.dart. No screenshot
is marked visually reviewed here: that requires opening the actual image.
"""
import argparse
import hashlib
import json
import queue
import subprocess
import threading
import time
from datetime import datetime, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.request import Request, urlopen


def stamp():
    return datetime.now(timezone.utc).isoformat()


def letter(number):
    result = ""
    while number:
        number, rem = divmod(number - 1, 26)
        result = chr(65 + rem) + result
    return result


def serve(root, resume=False):
    root.mkdir(parents=True, exist_ok=resume)
    (root / "captures").mkdir(exist_ok=resume)
    commands, pending = queue.Queue(), {}
    state = {"latest": None, "captures": [], "operations": []}
    if resume:
        for key, file in [("captures", "capture-metadata.json"), ("operations", "operations.json")]:
            if (root / file).exists():
                state[key] = json.loads((root / file).read_text(encoding="utf-8"))
    lock = threading.Lock()

    class Handler(BaseHTTPRequestHandler):
        def log_message(self, *_):
            pass

        def reply(self, status, value):
            data = json.dumps(value, ensure_ascii=False).encode()
            self.send_response(status)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self.send_header("Content-Length", str(len(data)))
            self.end_headers()
            self.wfile.write(data)

        def do_GET(self):
            if self.path == "/next":
                try:
                    self.reply(200, commands.get_nowait())
                except queue.Empty:
                    self.reply(200, {"action": "idle"})
            elif self.path == "/status":
                self.reply(200, state["latest"])
            else:
                self.reply(404, {"error": "Unknown audit endpoint"})

        def do_POST(self):
            try:
                if self.headers.get("Transfer-Encoding", "").lower() == "chunked":
                    body = bytearray()
                    while True:
                        size = int(self.rfile.readline().split(b";", 1)[0], 16)
                        if size == 0:
                            while self.rfile.readline().strip():
                                pass
                            break
                        if size < 0 or len(body) + size >= 1_000_000:
                            raise ValueError("Invalid audit chunk size")
                        body.extend(self.rfile.read(size))
                        if self.rfile.read(2) != b"\r\n":
                            raise ValueError("Invalid audit chunk boundary")
                else:
                    length = int(self.headers.get("Content-Length", "0"))
                    body = self.rfile.read(length) if 0 < length < 1_000_000 else b""
                if not body:
                    raise ValueError("Invalid audit body size")
                value = json.loads(body)
                if self.path == "/command":
                    value["id"] = str(time.time_ns())
                    event, result = threading.Event(), {}
                    pending[value["id"]] = (event, result)
                    commands.put(value)
                    if not event.wait(45):
                        self.reply(504, {"error": "Native audit command timed out", "id": value["id"]})
                    else:
                        self.reply(200, result)
                elif self.path == "/result":
                    with lock:
                        state["latest"] = value
                        state["operations"].append({"at": stamp(), **value})
                        (root / "operations.json").write_text(json.dumps(state["operations"], ensure_ascii=False, indent=2), encoding="utf-8")
                    item = pending.pop(value["id"], None)
                    if item:
                        item[1].update(value)
                        item[0].set()
                    self.reply(200, {"saved": True})
                elif self.path == "/capture":
                    if not state["latest"] or not state["latest"]["ok"]:
                        raise ValueError("Successful native state required before capture")
                    identifier = letter(len(state["captures"]) + 2)  # A reserved for missing private reference
                    data = subprocess.run(["adb", "-s", "emulator-5580", "exec-out", "screencap", "-p"],
                                          check=True, capture_output=True, timeout=30).stdout
                    if not data.startswith(b"\x89PNG\r\n\x1a\n"):
                        raise ValueError("Android did not return a PNG")
                    destination = root / "captures" / f"{identifier}.png"
                    destination.write_bytes(data)
                    item = {"id": identifier, "image": f"captures/{identifier}.png", "sha256": hashlib.sha256(data).hexdigest(),
                            "capturedAt": stamp(), "visuallyReviewed": False, **value, "native": state["latest"]}
                    state["captures"].append(item)
                    (root / "capture-metadata.json").write_text(json.dumps(state["captures"], ensure_ascii=False, indent=2), encoding="utf-8")
                    self.reply(200, {"id": identifier, "path": str(destination), "sha256": item["sha256"]})
                else:
                    self.reply(404, {"error": "Unknown audit endpoint"})
            except Exception as error:
                self.reply(500, {"error": str(error)})

    print(f"UIAUDIT01 host: 127.0.0.1:58420; originals: {root}", flush=True)
    ThreadingHTTPServer(("127.0.0.1", 58420), Handler).serve_forever()


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path)
    parser.add_argument("--command")
    parser.add_argument("--capture")
    parser.add_argument("--resume", action="store_true")
    args = parser.parse_args()
    if args.root:
        serve(args.root, args.resume)
    else:
        endpoint, body = ("/capture", args.capture) if args.capture else ("/command", args.command)
        if body is None:
            parser.error("Specify --root, --command or --capture")
        request = Request("http://127.0.0.1:58420" + endpoint, data=body.encode(), headers={"Content-Type": "application/json"})
        with urlopen(request, timeout=50) as response:
            print(response.read().decode())
