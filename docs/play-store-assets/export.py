"""Export and verify the Play pack. Requires Pillow; never alters app UI pixels."""

import argparse
import hashlib
import json
import struct
import zipfile
from pathlib import Path

from PIL import Image, ImageCms, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent
REPO = ROOT.parent.parent
PACK = ROOT / "it-IT"
# LittleCMS stamps new profiles with the current time. Normalize only that header
# field so exports and independent verification use identical valid sRGB bytes.
_profile = bytearray(ImageCms.ImageCmsProfile(ImageCms.createProfile("sRGB")).tobytes())
_profile[24:36] = struct.pack(">6H", 2000, 1, 1, 0, 0, 0)
SRGB = bytes(_profile)
PHONES = {
    "01-iniziative.png": "Esplora le iniziative di Trento, con copertine, date e attività da realizzare insieme.",
    "02-dettagli-attivita.png": "Dettaglio di un'attività: obiettivo, luogo pubblico e normale percorso di partecipazione.",
    "03-scambio-dona.png": "Scambio e Dona: due tavoli pieghevoli da scambiare con un aiuto per sistemare una mensola, a Trento.",
    "04-chat.png": "Chat di progetto: Giulia e Sara si organizzano per materiali e incontro, con messaggi sintetici in italiano.",
    "05-dona.png": "Un annuncio di dono: attrezzi da giardinaggio in buono stato, disponibili a Trento.",
}
ART = {
    "app-icon.png": ((512, 512), "RGBA", 1_024_000, "Logo originale PLANETS su fondo chiaro, con la cornice multicolore e i simboli di cura e collaborazione."),
    "feature-graphic.png": ((1024, 500), "RGB", 15_000_000, "Iniziative, eventi e scambi nella tua città: persone al lavoro insieme e oggetti da scambiare o donare."),
}
SPECS = {**ART, **{f"phone/{name}": ((1080, 1920), "RGB", 8_000_000, alt) for name, alt in PHONES.items()}}


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def inspect(path, spec):
    size, mode, limit, alt = spec
    with Image.open(path) as image:
        image.load()
        if image.format != "PNG" or image.size != size or image.mode != mode:
            raise ValueError(f"{path}: expected PNG {size} {mode}, got {image.format} {image.size} {image.mode}")
        if image.info.get("icc_profile") != SRGB:
            raise ValueError(f"{path}: expected embedded sRGB profile")
        if mode == "RGBA" and image.getchannel("A").getextrema() != (255, 255):
            raise ValueError(f"{path}: full-square icon must be opaque")
    if path.stat().st_size > limit:
        raise ValueError(f"{path}: exceeds {limit} bytes")
    bit_depth, color_type = struct.unpack("BB", path.read_bytes()[24:26])
    expected_type = 6 if mode == "RGBA" else 2
    if bit_depth != 8 or color_type != expected_type:
        raise ValueError(f"{path}: expected 8-bit PNG color type {expected_type}")
    if len(alt) > 140:
        raise ValueError(f"{path}: alt text exceeds 140 characters")
    return {"file": path.relative_to(PACK).as_posix(), "width": size[0], "height": size[1],
            "bytes": path.stat().st_size, "format": "PNG", "mode": mode,
            "bitDepth": bit_depth, "pngColorType": color_type, "colorSpace": "sRGB",
            "alphaChannel": mode == "RGBA", "aspectRatio": f"{size[0]}:{size[1]}",
            "sha256": sha(path), "altTextIt": alt}


def font(size, bold=False):
    # Match the website's installed Windows fallback, never silently substitute.
    return ImageFont.truetype("C:/Windows/Fonts/segoeuib.ttf" if bold else "C:/Windows/Fonts/segoeui.ttf", size)


def preview(available):
    canvas = Image.new("RGB", (1800, 1450), "#fbfaf6")
    draw = ImageDraw.Draw(canvas)
    draw.text((64, 42), "PLANETS · Google Play · Italiano", font=font(38, True), fill="#18302e")
    draw.text((66, 101), "Asset di presentazione · anteprima, non destinata al caricamento", font=font(23), fill="#536563")
    with Image.open(PACK / "app-icon.png") as icon:
        canvas.paste(icon.convert("RGB").resize((300, 300), Image.Resampling.LANCZOS), (142, 240))
    draw.text((142, 570), "Icona · 512 × 512", font=font(24, True), fill="#18302e")
    with Image.open(PACK / "feature-graphic.png") as feature:
        canvas.paste(feature, (682, 169))
    draw.text((682, 685), "Immagine in evidenza · 1024 × 500", font=font(24, True), fill="#18302e")
    labels = ["01 · Iniziative", "02 · Attività", "03 · Scambio", "04 · Chat", "05 · Dona"]
    for index, (name, label) in enumerate(zip(PHONES, labels)):
        x = 64 + index * 340
        draw.text((x, 768), label, font=font(26, True), fill="#18302e")
        if name in available:
            with Image.open(PACK / "phone" / name) as screen:
                canvas.paste(screen.resize((312, 555), Image.Resampling.LANCZOS), (x, 820))
        else:
            draw.rectangle((x, 820, x + 312, 1375), fill="#f4f2eb", outline="#cbd1c9")
            draw.text((x + 32, 1060), "Cattura Android\nmancante", font=font(28, True), fill="#536563", spacing=12)
    canvas.save(PACK / "preview.jpg", quality=94, subsampling=0, icc_profile=SRGB)


def export(partial):
    provenance_path = ROOT / "captures" / "it-IT" / "provenance.json"
    provenance = json.loads(provenance_path.read_text(encoding="utf-8"))
    available = [name for name in PHONES if (ROOT / "captures" / "it-IT" / name).is_file()]
    missing = [name for name in PHONES if name not in available]
    if missing and not partial:
        raise ValueError(f"Missing actual Android captures: {', '.join(missing)}. --partial explicitly exports an incomplete pack.")
    PACK.mkdir(exist_ok=True)
    for name, (size, mode, _, _) in ART.items():
        with Image.open(ROOT / ".rendered" / name) as image:
            image.convert(mode).resize(size, Image.Resampling.LANCZOS).save(PACK / name, optimize=True, icc_profile=SRGB)
    (PACK / "phone").mkdir(exist_ok=True)
    for name in available:
        raw = ROOT / "captures" / "it-IT" / name
        record = provenance["captures"][name]
        if sha(raw) != record["sha256"]:
            raise ValueError(f"{raw}: differs from its recorded capture hash")
        if record["sourceCommit"] != provenance["sourceCommit"]:
            raise ValueError(f"{raw}: unexpected source commit")
        with Image.open(raw) as image:
            if image.size != (1080, 1920):
                raise ValueError(f"{raw}: capture must be native 1080 x 1920; refusing to stretch or crop UI")
            image.convert("RGB").save(PACK / "phone" / name, optimize=True, icc_profile=SRGB)
    assets = []
    for name, spec in SPECS.items():
        if name.startswith("phone/") and name.split("/")[1] in missing:
            continue
        record = inspect(PACK / name, spec)
        if name.startswith("phone/"):
            record["provenance"] = provenance["captures"][name.split("/")[1]]
        else:
            record["provenance"] = {"artwork": f"../artwork/{name.replace('.png', '.svg')}",
                                    "sourceCommit": provenance["sourceCommit"],
                                    "method": "Editable SVG rendered with installed Segoe UI and existing repository images"}
        assets.append(record)
    manifest = {"schemaVersion": 1, "locale": "it-IT", "status": "incomplete" if missing else "draft-complete",
                "createdOn": provenance["createdOn"], "sourceCommit": provenance["sourceCommit"],
                "missingCaptures": missing, "releaseCompatibility": provenance["releaseCompatibility"],
                "artworkSources": [{"file": p, "sha256": sha(REPO / p)} for p in [
                    "apps/mobile/assets/brand/planets-logo.png", "scripts/demo-assets/covers/mural.webp",
                    "scripts/demo-assets/covers/garden-tools.webp", "scripts/demo-assets/assets.json"]],
                "assets": assets}
    (PACK / "asset-manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    preview(available)
    verify()
    archive_path = ROOT / ("PLANETS-play-store-assets-it-IT-INCOMPLETE.zip" if missing else "PLANETS-play-store-assets-it-IT.zip")
    members = [a["file"] for a in assets] + ["asset-manifest.json", "README.md"]
    with zipfile.ZipFile(archive_path, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
        for name in sorted(members):
            info = zipfile.ZipInfo(f"it-IT/{name}", (2026, 10, 8, 0, 0, 0))
            info.compress_type = zipfile.ZIP_DEFLATED
            info.external_attr = 0o644 << 16
            archive.writestr(info, (PACK / name).read_bytes())
    with zipfile.ZipFile(archive_path) as archive:
        if archive.testzip() is not None:
            raise ValueError(f"{archive_path}: ZIP integrity failed")
    print(f"Exported {len(assets)} verified assets; missing captures: {len(missing)}; ZIP: {archive_path.name}")


def verify():
    manifest = json.loads((PACK / "asset-manifest.json").read_text(encoding="utf-8"))
    expected = set(SPECS) - {f"phone/{name}" for name in manifest["missingCaptures"]}
    actual = [a["file"] for a in manifest["assets"]]
    if set(actual) != expected or len(actual) != len(expected):
        raise ValueError("Manifest inventory does not match the declared complete/partial pack")
    disk_inventory = {p.relative_to(PACK).as_posix() for p in PACK.rglob("*.png")}
    if disk_inventory != expected:
        raise ValueError("Upload directory contains missing or unlisted PNGs; reconcile old exports explicitly")
    if (manifest["status"] == "draft-complete") != (not manifest["missingCaptures"]):
        raise ValueError("Manifest status contradicts the capture inventory")
    for record in manifest["artworkSources"]:
        if sha(REPO / record["file"]) != record["sha256"]:
            raise ValueError(f"{record['file']}: artwork source changed; export again")
    for record in manifest["assets"]:
        current = inspect(PACK / record["file"], SPECS[record["file"]])
        if any(record[key] != value for key, value in current.items()):
            raise ValueError(f"{record['file']}: export differs from its manifest")
        if record["file"].startswith("phone/"):
            raw = ROOT / "captures" / "it-IT" / Path(record["file"]).name
            if sha(raw) != record["provenance"]["sha256"]:
                raise ValueError(f"{raw}: raw provenance mismatch")
            with Image.open(raw) as source, Image.open(PACK / record["file"]) as final:
                if source.convert("RGB").tobytes() != final.tobytes():
                    raise ValueError(f"{record['file']}: actual app pixels changed")
    with Image.open(PACK / "preview.jpg") as image:
        image.load()
        if image.format != "JPEG" or image.mode != "RGB":
            raise ValueError("Invalid contact sheet")
    print(f"Verified dimensions, decoding, PNG bit depth/color type, opacity, sRGB, limits, alt text and hashes for {len(actual)} assets.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--verify", action="store_true", help="Verify saved pack without exporting")
    parser.add_argument("--partial", action="store_true", help="Explicitly export incomplete pack with missing-capture markers")
    args = parser.parse_args()
    verify() if args.verify else export(args.partial)
