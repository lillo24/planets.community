"""Build the portrait UIAUDIT01 review from inspected canonical review.json.

Requires ReportLab, Pillow and pypdf. Original PNGs are never modified. Detail
crops are derived evidence, with their source and pixel bounds in review.json.
"""
import hashlib
import json
import re
import sys
import zipfile
from pathlib import Path
from xml.sax.saxutils import escape

from PIL import Image
from pypdf import PdfReader
from reportlab.lib.colors import HexColor, black, white
from reportlab.lib.styles import ParagraphStyle
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.pdfgen import canvas
from reportlab.platypus import Paragraph

sys.stdout.reconfigure(encoding="utf-8")
root = Path(sys.argv[1]).resolve()
review = json.loads((root / "review.json").read_text(encoding="utf-8"))
captures, findings = review["captures"], review["findings"]
by_id = {c["id"]: c for c in captures}
assert len(by_id) == len(captures), "Repeated screenshot ID"
assert len({f["id"] for f in findings}) == len(findings), "Repeated finding ID"
assert all(c["visuallyReviewed"] for c in captures), "Open every original before delivery"
for c in captures:
    file = root / c["image"]
    assert file.is_file(), f"Missing original: {c['id']}"
    assert hashlib.sha256(file.read_bytes()).hexdigest() == c["sha256"], f"Changed original: {c['id']}"
    with Image.open(file) as im:
        im.verify()
for f in findings:
    assert f["decision"] == "pending", "This audit never grants UI approval"
    assert f["evidence"] and all(i in by_id for i in f["evidence"]), f"Missing finding evidence: {f['id']}"
    assert f["proposal"].strip(), f"Missing concrete proposal: {f['id']}"

# Use installed Unicode fonts without copying a proprietary font into sources.
font = Path("C:/Windows/Fonts/arial.ttf")
bold = Path("C:/Windows/Fonts/arialbd.ttf")
if not font.exists():
    font = Path("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf")
    bold = Path("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf")
pdfmetrics.registerFont(TTFont("Audit", str(font)))
pdfmetrics.registerFont(TTFont("AuditBold", str(bold)))
style = ParagraphStyle("body", fontName="Audit", fontSize=12, leading=17, textColor=HexColor("#202b33"))
small = ParagraphStyle("small", parent=style, fontSize=9.5, leading=13)
title_style = ParagraphStyle("title", parent=style, fontName="AuditBold", fontSize=19, leading=24)
sub_style = ParagraphStyle("sub", parent=style, fontName="AuditBold", fontSize=14, leading=19)
W, H, margin = 360, 1060, 23
width = W - margin * 2
pdf = root.parent / "PLANETS_UIAUDIT01_Review.pdf"
c = canvas.Canvas(str(pdf), pagesize=(W, H), pageCompression=1)
c.setTitle("PLANETS UIAUDIT01 — native Pixel 9 Pro review")
c.setAuthor("PLANETS UI audit")
page = 0
page_title = ""


def paragraph(text, y, chosen=style, x=margin, available=width):
    p = Paragraph(escape(str(text)).replace("\n", "<br/>"), chosen)
    _, height = p.wrap(available, H)
    if y - height < 42:
        continuation = page_title.removesuffix(" · continued") + " · continued"
        end()
        y = begin(continuation)
    assert y - height >= 42, f"Paragraph exceeds a page: {text[:80]}"
    p.drawOn(c, x, y - height)
    return y - height - 12


def begin(title, bookmark=None):
    global page, page_title
    page += 1
    page_title = title
    c.setFillColor(white)
    c.rect(0, 0, W, H, fill=1, stroke=0)
    if bookmark:
        c.bookmarkPage(bookmark)
    c.setFillColor(HexColor("#247189"))
    c.rect(0, H - 7, W, 7, fill=1, stroke=0)
    return paragraph(title, H - 29, title_style)


def end():
    c.setFillColor(HexColor("#687780"))
    c.setFont("Audit", 8)
    c.drawString(margin, 20, "PLANETS UIAUDIT01 · source " + review["run"]["sourceSha"][:8])
    c.drawRightString(W - margin, 20, str(page))
    if page > 1:
        c.linkRect("Contents", "contents", (W - 82, 10, W - 20, 33), relative=0, thickness=0)
    c.showPage()


y = begin("PLANETS\nMobile UI review", "cover")
y = paragraph(review["statusTitle"], y - 8, sub_style)
y = paragraph(review["summary"], y)
y = paragraph(f"{len(captures)} captures · {len(captures)} originals opened and reviewed\n"
              f"{len(findings)} unique proposals · {review['coverageSummary']['blocked']} blocked inventory entries", y, sub_style)
y = paragraph("Read the proposal, then reply with its permanent ID and yes or no. Missing answers stay pending. "
              "An issue seen in several accounts still has one vote.", y)
y = paragraph("General UI changes are proposals only. No app UI change or duplicate-chat repair was made by this audit.", y)
y = paragraph("The supplied real-account reference A is unavailable. A1 keeps that limitation separate from the current-source, fictional reproduction.", y)
y = paragraph("Main pass: Italian, dark mode, default scaling. Android 16 / API 36, SDK Pixel 9 Pro AVD, "
              "1280 × 2856 px, density 480, 426.7 × 952 logical dp. Profile integration build, app 0.1.10+14.", y)
y = paragraph("Tap Contents for the proposal index and every reviewed screenshot. Complete route/state blockers and the persona matrix are in coverage.md in the source ZIP.", y)
c.linkRect("Contents", "contents", (margin, 55, W - margin, 95), relative=0, thickness=1)
c.setFont("AuditBold", 14)
c.setFillColor(HexColor("#247189"))
c.drawString(margin + 12, 71, "Open contents →")
end()

y = begin("Priority decisions")
for identifier in ["DU1", "GL1", "FO1", "OA1", "A1"]:
    finding = next(f for f in findings if f["id"] == identifier)
    top = y
    y = paragraph(identifier + " · " + finding["title"], y, sub_style)
    y = paragraph("Pending · open the single decision card for evidence and the proposed change.", y, small)
    c.linkRect(identifier, "issue-" + identifier, (margin, y + 6, W - margin, top), relative=0, thickness=0)
y = paragraph("These are review priorities, not approvals. The full proposal index follows.", y)
end()

y = begin("Contents · proposals", "contents")
for f in findings:
    if y < 120:
        end()
        y = begin("Contents · proposals continued")
    top = y
    y = paragraph(f["id"] + " · " + f["title"], y, sub_style)
    y = paragraph(f["type"] + " · impact " + f["impact"] + " · pending", y, small)
    c.linkRect(f["id"], "issue-" + f["id"], (margin, y + 6, W - margin, top), relative=0, thickness=0)
end()
y = begin("Contents · screenshots")
for item in captures:
    label = item["id"] + " · " + item["title"]
    probe = Paragraph(escape(label), small)
    _, needed = probe.wrap(width, H)
    if y - needed < 64:
        end()
        y = begin("Contents · screenshots continued")
    top = y
    y = paragraph(label, y, small) - 2
    c.linkRect(item["id"], "capture-" + item["id"], (margin, y + 7, W - margin, top), relative=0, thickness=0)
end()

(root / "annotated").mkdir(exist_ok=True)
for f in findings:
    y = begin(f["id"] + " · " + f["title"], "issue-" + f["id"])
    c.addOutlineEntry(f["id"] + " " + f["title"], "issue-" + f["id"], level=0)
    y = paragraph(f["type"] + " · impact " + f["impact"] + "\nConfidence: " + f["confidence"], y, small)
    source = by_id[f["evidence"][0]]
    image = Image.open(root / source["image"])
    bounds = f.get("crop")
    if bounds is None:
        center = int(f["anchor"][1] * image.height)
        bounds = [0, max(0, center - 330), image.width, min(image.height, center + 330)]
    crop = image.crop(tuple(bounds))
    target = root / "annotated" / (f["id"] + "_detail.png")
    crop.save(target)
    f["detail"] = {"image": target.relative_to(root).as_posix(), "source": source["id"], "pixelBounds": bounds,
                   "sha256": hashlib.sha256(target.read_bytes()).hexdigest()}
    ratio = min(width / crop.width, 330 / crop.height)
    draw_w, draw_h = crop.width * ratio, crop.height * ratio
    c.drawImage(str(target), margin, y - draw_h, width=draw_w, height=draw_h, preserveAspectRatio=True)
    y -= draw_h + 10
    y = paragraph("Enlarged detail · original " + source["id"], y, small)
    y = paragraph("Visible / why it matters", y, sub_style)
    y = paragraph(f["visible"], y)
    if f.get("diagnosis"):
        y = paragraph("Supporting diagnosis", y, sub_style)
        y = paragraph(f["diagnosis"], y)
    y = paragraph("Proposed change", y, sub_style)
    y = paragraph(f["proposal"], y)
    y = paragraph("Decision: pending · one yes/no vote", y, sub_style)
    related = "; ".join(i + " (" + (by_id[i]["native"]["persona"] or "guest / normal") + ")" for i in f["evidence"])
    y = paragraph("Related evidence: " + related, y, small)
    y -= 8
    for i in f["evidence"]:
        if y < 70:
            end()
            y = begin(f["id"] + " · supporting evidence")
            y = paragraph("Same proposal and pending decision. No additional vote.", y, small)
        c.setFont("Audit", 9.5)
        c.setFillColor(HexColor("#247189"))
        c.drawString(margin, y + 6, "Open screenshot " + i)
        c.linkRect(i, "capture-" + i, (margin, y, W - margin, y + 20), relative=0, thickness=0)
        y -= 24
    end()

(root / "notes").mkdir(exist_ok=True)
for item in captures:
    y = begin(item["id"] + " · " + item["title"], "capture-" + item["id"])
    person = item["native"]["persona"] or "guest / normal"
    y = paragraph(person + " · " + item["role"], y, small)
    im = Image.open(root / item["image"])
    bottom = 230
    # Long state titles must not overlap the screenshot or its account label.
    draw_w = min(width, (y - bottom) * im.width / im.height)
    draw_h = im.height / im.width * draw_w
    c.drawImage(str(root / item["image"]), (W - draw_w) / 2, bottom, width=draw_w, height=draw_h, preserveAspectRatio=True)
    first = [f for f in findings if f["evidence"][0] == item["id"]]
    for f in first:
        marker_y = bottom + draw_h * (1 - f["anchor"][1])
        c.setStrokeColor(HexColor("#247189"))
        c.setFillColor(white)
        c.circle(11, marker_y, 8, fill=1, stroke=1)
        c.setFillColor(black)
        c.setFont("AuditBold", 9)
        c.drawCentredString(11, marker_y - 3, re.search(r"\d+$", f["id"]).group())
        c.line(19, marker_y, margin, marker_y)
    y = 214
    related = [f for f in findings if item["id"] in f["evidence"]]
    if related:
        for f in related:
            top = y
            y = paragraph(("Proposal " if f["evidence"][0] == item["id"] else "Also shows ") + f["id"] + " · see its single decision card.", y, small)
            c.linkRect(f["id"], "issue-" + f["id"], (margin, y + 8, W - margin, top), relative=0, thickness=0)
    else:
        y = paragraph("No new issue recorded for this capture.", y)
    y = paragraph(item["state"], y, small)
    if item.get("observation") and not related:
        y = paragraph(item["observation"], y, small)
    end()
    text = [f"# {item['id']} — {item['title']}", f"Account: {person}; dataset: {item['dataset']}; role: {item['role']}",
            f"State: {item['state']}", f"Image: {item['image']}; SHA-256: {item['sha256']}"]
    if related:
        text.extend("See canonical proposal " + f["id"] + ". No additional vote." for f in related)
    else:
        text.append("No new issue recorded for this capture.")
        if item.get("observation"):
            text.append("Observation: " + item["observation"])
    (root / "notes" / (item["id"] + ".md")).write_text("\n\n".join(text) + "\n", encoding="utf-8")

y = begin("Environment and limits", "appendix")
for label, value in review["appendix"]:
    if y < 160:
        end()
        y = begin("Environment and limits · continued")
    y = paragraph(label, y, sub_style)
    y = paragraph(value, y, small)
end()
c.save()
reader = PdfReader(str(pdf))
assert len(reader.pages) == page
assert all(p.mediabox.height > p.mediabox.width for p in reader.pages)
assert reader.outline, "PDF index missing"
assert any(p.get("/Annots") for p in reader.pages), "PDF links missing"
decisions = "# Decisions\n\nReply with an ID and yes/no. Missing answers stay pending.\n\n" + "\n".join(
    f"- {f['id']}: pending — {f['proposal']}" for f in findings) + "\n"
(root / "decisions.md").write_text(decisions, encoding="utf-8")
(root / "review.json").write_text(json.dumps(review, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
archive = root.parent / "PLANETS_UIAUDIT01_Sources.zip"
allowed = {"captures", "annotated", "notes", "report"}
top = {"review.json", "coverage.md", "coverage.json", "decisions.md", "README.md", "run.json", "inventory.json"}
with zipfile.ZipFile(archive, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=6) as z:
    for file in sorted(root.rglob("*")):
        relative = file.relative_to(root)
        if file.is_file() and (relative.parts[0] in allowed or relative.as_posix() in top) and "rendered" not in relative.parts:
            assert not re.search(r"private|defines|\.log$|operations\.json|\.apk$", relative.as_posix(), re.I), "Private source export refused"
            z.write(file, "PLANETS_UIAUDIT01/" + relative.as_posix())
with zipfile.ZipFile(archive) as z:
    assert z.testzip() is None
    assert all("PLANETS_UIAUDIT01/" + item["image"] in z.namelist() for item in captures)
print(json.dumps({"pdf": str(pdf), "pages": page, "zip": str(archive), "captures": len(captures), "findings": len(findings)}))
