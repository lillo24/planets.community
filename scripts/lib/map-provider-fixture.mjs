import { crc32, deflateSync } from "node:zlib";

// Valid, neutral 256px PNG for offline adapter and REST tests; no map geometry.
export function mapTileFixture() {
  const chunk = (type, data) => {
    const tag = Buffer.from(type);
    const head = Buffer.alloc(4);
    head.writeUInt32BE(data.length);
    const tail = Buffer.alloc(4);
    tail.writeUInt32BE(crc32(Buffer.concat([tag, data])));
    return Buffer.concat([head, tag, data, tail]);
  };
  const header = Buffer.alloc(13);
  header.writeUInt32BE(256, 0);
  header.writeUInt32BE(256, 4);
  header[8] = 8;
  header[9] = 2;
  const pixels = Buffer.alloc(256 * (1 + 256 * 3), 210);
  for (let row = 0; row < 256; row++) pixels[row * 769] = 0;
  return Buffer.concat([
    Buffer.from("89504e470d0a1a0a", "hex"),
    chunk("IHDR", header),
    chunk("IDAT", deflateSync(pixels)),
    chunk("IEND", Buffer.alloc(0)),
  ]);
}

export const mapCenterFixture = {
  results: [
    {
      country_code: "it",
      city: "Bolzano",
      state: "Trentino-Alto Adige",
      result_type: "city",
      lat: 46.4983,
      lon: 11.3548,
      datasource: {
        sourcename: "openstreetmap",
        raw: { id: "MUST_NOT_SURVIVE" },
      },
      place_id: "MUST_NOT_SURVIVE",
      formatted: "Ignored broad provider label",
    },
  ],
};
