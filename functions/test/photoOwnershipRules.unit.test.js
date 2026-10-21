const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const { createHash } = require("node:crypto");
const checks = {
  "firestore.rules":
    "fc3fe65b02a2e7101926685f185438e444ef198f109d178cf2c37e872c7104fd",
  "deployment/storage-minimal/firestore.rules":
    "dfe4e0cebf1495c9a0d071934f3e7398fac60017f2fb5be87cac59052cbf812c",
};
for (const [file, expected] of Object.entries(checks))
  test(`${file}: legacy image match remains byte-identical`, () => {
    const text = fs.readFileSync(
      path.resolve(__dirname, "../..", file),
      "utf8",
    );
    const start = text.indexOf("    match /apartmentImages/{imageId} {"),
      end = text.indexOf("\n    match /staffAttendance", start);
    assert.equal(
      createHash("sha256").update(text.slice(start, end)).digest("hex"),
      expected,
    );
  });
test("release and minimal V2 Rules use the same ownership policy", () => {
  const extract = (file) => {
    const text = fs.readFileSync(
      path.resolve(__dirname, "../..", file),
      "utf8",
    );
    return text.slice(
      text.indexOf("    // V2 is opt-in."),
      text.indexOf("    match /apartmentImages/{imageId} {"),
    );
  };
  assert.equal(
    extract("firestore.rules"),
    extract("deployment/storage-minimal/firestore.rules"),
  );
});
