import { readFileSync } from "node:fs";
import { gunzipSync } from "node:zlib";

const read = (phase) =>
  JSON.parse(gunzipSync(readFileSync(new URL(`${phase}.json.gz`, import.meta.url))));
const [beforeName = "before", afterName = "after"] = process.argv.slice(2);
const before = read(beforeName);
const after = read(afterName);
const pair = (a, b) => `${a.toFixed(2)} / ${b.toFixed(2)}`;
const frame = (data, journey, metric) => data[`${journey}-frames`][metric];
const metrics = [
  "90th_percentile_frame_build_time_millis",
  "worst_frame_build_time_millis",
  "90th_percentile_frame_rasterizer_time_millis",
  "worst_frame_rasterizer_time_millis",
];

console.log("All durations in ms; each cell is before / after. Index 0 is first use, 1 and 2 are repeats.\n");
console.log("| Journey | Tap to chrome | UI p90 | UI peak | Raster p90 | Raster peak |");
console.log("| --- | ---: | ---: | ---: | ---: | ---: |");
for (const key of Object.keys(before).filter((key) => key.endsWith("-chrome-ms"))) {
  const journey = key.slice(0, -"-chrome-ms".length);
  const values = [
    pair(before[key], after[key]),
    ...metrics.map((metric) => pair(frame(before, journey, metric), frame(after, journey, metric))),
  ];
  console.log(`| ${journey} | ${values.join(" | ")} |`);
}

console.log("\nIdle trace event counts (separate diagnostic window):\n");
console.log("| Begin event | Before | After |");
console.log("| --- | ---: | ---: |");
for (const name of ["GPURasterizer::Draw", "LayoutBuilder", "RenderStack", "Stack", "AnimatedBuilder"]) {
  const count = (data) => data["home-idle-timeline"].traceEvents.filter(
    (event) => event.ph === "B" && event.name === name,
  ).length;
  console.log(`| ${name} | ${count(before)} | ${count(after)} |`);
}
for (let i = 0; i < 3; i++) {
  console.log(`\nBack ${i}: ${before[`detail-back-${i}-route`]} / ${after[`detail-back-${i}-route`]}`);
}
