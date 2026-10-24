// Standalone three-page phone PDF from original native Android PNGs. No package
// or raster editing dependency: decode screenshot scanlines and embed RGB bytes.
import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { execFileSync } from "node:child_process";
import { readFile, readdir, writeFile } from "node:fs/promises";
import path from "node:path";
import { inflateSync, deflateSync } from "node:zlib";

const [directory, world, before] = process.argv.slice(2);
assert.match(before, /^[0-9a-f]{40}$/);
const pages = [
  [
    "before-it-dark-private",
    "BEFORE - separate source conversations",
    "Fictional Alice and Marco. Original predecessor app.",
  ],
  [
    "after-it-dark-private",
    "AFTER - one personal conversation",
    "The same authorized source histories share one row.",
  ],
  [
    "after-it-dark-thread",
    "AFTER - one chronological history",
    "One composer. Original messages and source actions.",
  ],
];
const images = [];
for (const [name] of pages)
  images.push(png(await readFile(path.join(directory, name + ".png"))));
const objects = [
  null,
  null,
  null,
  Buffer.from("<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>"),
];
const kids = [];
for (let i = 0; i < pages.length; i++) {
  const image = images[i],
    imageId = objects.length;
  const compressed = deflateSync(image.rgb, { level: 9 });
  objects.push(
    Buffer.concat([
      Buffer.from(
        `<< /Type /XObject /Subtype /Image /Width ${image.width} /Height ${image.height} /ColorSpace /DeviceRGB /BitsPerComponent 8 /Filter /FlateDecode /Length ${compressed.length} >>\nstream\n`,
      ),
      compressed,
      Buffer.from("\nendstream"),
    ]),
  );
  const width = 320,
    height = Math.min(740, (width * image.height) / image.width),
    x = (360 - width) / 2,
    y = 770 - height;
  const text = (s) =>
    s.replaceAll("\\", "\\\\").replaceAll("(", "\\(").replaceAll(")", "\\)");
  const content = Buffer.from(
    `BT /F1 15 Tf 20 820 Td (${text(pages[i][1])}) Tj /F1 8 Tf 0 -20 Td (${text(pages[i][2])}) Tj 0 -13 Td (Native Android emulator. Synthetic local data. No hosted rollout.) Tj ET\nq ${width} 0 0 ${height} ${x} ${y} cm /Im${i} Do Q`,
  );
  const contentId = objects.length;
  objects.push(
    Buffer.concat([
      Buffer.from(`<< /Length ${content.length} >>\nstream\n`),
      content,
      Buffer.from("\nendstream"),
    ]),
  );
  const pageId = objects.length;
  kids.push(pageId);
  objects.push(
    Buffer.from(
      `<< /Type /Page /Parent 2 0 R /MediaBox [0 0 360 850] /Resources << /Font << /F1 3 0 R >> /XObject << /Im${i} ${imageId} 0 R >> >> /Contents ${contentId} 0 R >>`,
    ),
  );
}
objects[1] = Buffer.from("<< /Type /Catalog /Pages 2 0 R >>");
objects[2] = Buffer.from(
  `<< /Type /Pages /Count ${kids.length} /Kids [${kids.map((n) => `${n} 0 R`).join(" ")}] >>`,
);
const pieces = [Buffer.from("%PDF-1.4\n")],
  offsets = [0];
let size = pieces[0].length;
for (let n = 1; n < objects.length; n++) {
  offsets[n] = size;
  const piece = Buffer.concat([
    Buffer.from(`${n} 0 obj\n`),
    objects[n],
    Buffer.from("\nendobj\n"),
  ]);
  pieces.push(piece);
  size += piece.length;
}
pieces.push(
  Buffer.from(
    `xref\n0 ${objects.length}\n0000000000 65535 f \n${offsets
      .slice(1)
      .map((n) => String(n).padStart(10, "0") + " 00000 n \n")
      .join(
        "",
      )}trailer\n<< /Size ${objects.length} /Root 1 0 R >>\nstartxref\n${size}\n%%EOF\n`,
  ),
);
await writeFile(
  path.join(directory, "A1-before-after.pdf"),
  Buffer.concat(pieces),
);
const captures = [];
for (const filename of (await readdir(directory))
  .filter((n) => n.endsWith(".png"))
  .sort()) {
  const bytes = await readFile(path.join(directory, filename)),
    decoded = png(bytes);
  captures.push({
    filename,
    sha256: createHash("sha256").update(bytes).digest("hex"),
    width: decoded.width,
    height: decoded.height,
  });
}
assert.equal(
  captures.length,
  7,
  "Every required native checkpoint must be captured.",
);
const migration = (await readdir("supabase/migrations")).find((n) =>
  n.endsWith("_a1_unified_private_conversations.sql"),
);
const proof = {
  before_sha: before,
  after_sha: execFileSync("git", ["rev-parse", "HEAD"], {
    encoding: "utf8",
  }).trim(),
  fictional: true,
  native_android: true,
  real_otp_auth: true,
  original_compositor_pngs: true,
  migration_sha256: createHash("sha256")
    .update(await readFile(path.join("supabase/migrations", migration)))
    .digest("hex"),
  http: JSON.parse(await readFile(path.join(world, "http-proof.json"), "utf8")),
  populated_upgrade: JSON.parse(
    await readFile(path.join(world, "upgrade-proof.json"), "utf8"),
  ),
  captures,
  hosted_operations: false,
  store_upload: false,
};
await writeFile(
  path.join(directory, "review.json"),
  JSON.stringify(proof, null, 2) + "\n",
);
console.log(
  "A1 native PDF and seven original fictional Android PNGs are ready for visual inspection.",
);

function png(buffer) {
  assert.equal(buffer.subarray(0, 8).toString("hex"), "89504e470d0a1a0a");
  let width, height, type;
  const chunks = [];
  for (let offset = 8; offset < buffer.length;) {
    const length = buffer.readUInt32BE(offset),
      name = buffer.toString("ascii", offset + 4, offset + 8),
      data = buffer.subarray(offset + 8, offset + 8 + length);
    if (name === "IHDR") {
      width = data.readUInt32BE(0);
      height = data.readUInt32BE(4);
      assert.equal(data[8], 8);
      type = data[9];
      assert.equal(data[12], 0);
    }
    if (name === "IDAT") chunks.push(data);
    offset += length + 12;
  }
  assert.ok(
    type === 2 || type === 6,
    "Expected original RGB/RGBA Android PNG.",
  );
  const channels = type === 6 ? 4 : 3,
    stride = width * channels,
    raw = inflateSync(Buffer.concat(chunks)),
    pixels = Buffer.alloc(stride * height);
  assert.equal(raw.length, (stride + 1) * height);
  const paeth = (a, b, c) => {
    const p = a + b - c,
      da = Math.abs(p - a),
      db = Math.abs(p - b),
      dc = Math.abs(p - c);
    return da <= db && da <= dc ? a : db <= dc ? b : c;
  };
  for (let y = 0; y < height; y++) {
    const filter = raw[y * (stride + 1)];
    assert.ok(filter <= 4);
    for (let x = 0; x < stride; x++) {
      const index = y * stride + x,
        a = x >= channels ? pixels[index - channels] : 0,
        b = y ? pixels[index - stride] : 0,
        c = y && x >= channels ? pixels[index - stride - channels] : 0;
      pixels[index] =
        (raw[y * (stride + 1) + 1 + x] +
          [0, a, b, Math.floor((a + b) / 2), paeth(a, b, c)][filter]) &
        255;
    }
  }
  const rgb = Buffer.alloc(width * height * 3);
  for (let n = 0; n < width * height; n++)
    for (let c = 0; c < 3; c++) rgb[n * 3 + c] = pixels[n * channels + c];
  return { width, height, rgb };
}
