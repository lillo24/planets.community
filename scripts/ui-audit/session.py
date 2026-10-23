"""Execute a reviewed JSON list of UIAUDIT01 commands and capture checkpoints."""
import json
import sys
from urllib.request import Request, urlopen

sys.stdout.reconfigure(encoding="utf-8")


def send(endpoint, value):
    request = Request("http://127.0.0.1:58420" + endpoint,
                      data=json.dumps(value, ensure_ascii=False).encode("utf-8"),
                      headers={"Content-Type": "application/json"})
    with urlopen(request, timeout=50) as response:
        return json.load(response)


def command(value):
    result = send("/command", value)
    if not result["ok"]:
        raise RuntimeError(f"Native command failed: {value}; {result['error']}")
    return result


def capture(title, state, role, **extra):
    current = command({"action": "status", "wait": 4})
    persona = current["persona"]
    dataset = ("mock-people" if persona in ["luca", "maya", "nora", "teo", "iris"]
               else "mock-activities" if persona else "guest-or-normal")
    result = send("/capture", {"title": title, "state": state, "role": role, "dataset": dataset,
                              "transition": "real Mock selector" if persona else "ordinary guest/normal navigation",
                              **extra})
    print(json.dumps({"capture": result["id"], "title": title, "persona": persona, "route": current["route"]}), flush=True)
    return result


if __name__ == "__main__":
    plan = json.load(open(sys.argv[1], encoding="utf-8"))
    for step in plan:
        if step.get("action") == "capture":
            step.pop("action")
            capture(**step)
        else:
            result = command(step)
            if step.get("inspect"):
                print(json.dumps(result, ensure_ascii=True), flush=True)
