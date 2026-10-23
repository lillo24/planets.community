"""Extract current GoRoute ownership and non-route modal call sites for UIAUDIT01.

This is a starting inventory, not proof of reachability or visual coverage.
Dynamic relationships, feature gates and in-screen states need manual review.
"""
import json
import re
import sys
from pathlib import Path

root = Path(__file__).resolve().parents[2]
router = root / "apps/mobile/lib/app/router/app_router.dart"
source = router.read_text(encoding="utf-8")
# Preserve offsets while masking Dart strings/comments for balanced delimiters.
mask = re.sub(r"//[^\n]*|/\*[\s\S]*?\*/|'(?:\\.|[^'\\])*'|\"(?:\\.|[^\"\\])*\"",
              lambda m: re.sub(r"[^\n]", " ", m.group()), source)
constants = {"MockModeRoutes.accounts": "/settings/mock-accounts", "MockModeRoutes.normalLink": "/mock/normal-link",
             "MockModeRoutes.unavailableAction": "/mock/action-unavailable", "policyAcceptancePath": "/policies/accept",
             "accountDeletionPath": "/settings/delete-account", "HelpRoutes.path": "/help", "AuthRoutes.entry": "/auth",
             "AuthRoutes.email": "/auth/email", "DraftRoutes.path": "/drafts"}
routes = []
for match in re.finditer(r"\bGoRoute\s*\(", mask):
    depth, end = 1, match.end()
    while depth and end < len(mask):
        depth += (mask[end] == "(") - (mask[end] == ")")
        end += 1
    body = source[match.end():end]
    found = re.search(r"\bpath:\s*(?:'([^']*)'|([\w.]+))", body)
    if not found:
        raise ValueError(f"Missing GoRoute path at {match.start()}")
    value = found[1] if found[1] is not None else constants.get(found[2], "{" + found[2] + "}")
    parents = [item for item in routes if item["start"] < match.start() < item["end"]]
    parent = max(parents, key=lambda item: item["start"]) if parents else None
    full = value if value.startswith("/") else ((parent["route"] if parent else "") + "/" + value)
    screen = re.search(r"\b(\w+(?:Screen|Intro))\s*\(", body)
    routes.append({"id": f"R{len(routes) + 1:03}", "route": full, "line": source.count("\n", 0, match.start()) + 1,
                   "owner": screen[1] if screen else "See route builder", "start": match.start(), "end": end})
for item in routes:
    item.pop("start")
    item.pop("end")
declarations = len(routes)
expanded = []
for item in routes:
    if "{entry.key}" in item["route"]:
        names = (["managed", "memberships", "requests", "offers"] if item["route"].startswith("/groups/mine/")
                 else ["requests", "memberships", "team", "authority-invitations", "role-history", "link-history"])
        for name in names:
            expanded.append({**item, "id": item["id"] + "-" + name, "route": item["route"].replace("{entry.key}", name)})
    else:
        expanded.append(item)
routes = expanded
modals = []
pushed = []
for file in sorted((root / "apps/mobile/lib").rglob("*.dart")):
    if "presentation" not in file.parts and "widgets" not in file.parts:
        continue
    text = file.read_text(encoding="utf-8")
    for call in re.finditer(r"\b(showDialog|showModalBottomSheet|showMenu|showDatePicker|showTimePicker|showDateRangePicker)(?:<[^>]+>)?\s*\(", text):
        modals.append({"id": f"M{len(modals) + 1:03}", "owner": file.relative_to(root).as_posix(),
                       "line": text.count("\n", 0, call.start()) + 1, "kind": call[1]})
    for call in re.finditer(r"\b(MaterialPageRoute|CupertinoPageRoute|DialogRoute)(?:<[^>]+>)?\s*\(", text):
        pushed.append({"id": f"P{len(pushed) + 1:03}", "owner": file.relative_to(root).as_posix(),
                       "line": text.count("\n", 0, call.start()) + 1, "kind": call[1]})
output = {"routeDeclarations": declarations, "routes": routes, "modals": modals, "pushed": pushed}
Path(sys.argv[1]).write_text(json.dumps(output, indent=2), encoding="utf-8")
print(f"Inventory: {declarations} declarations / {len(routes)} expanded route patterns, {len(modals)} modals, {len(pushed)} pushed pages; reachability needs reconciliation.")
