const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const { createHash } = require("node:crypto");

const root = path.resolve(__dirname, "../..");
const directory = path.join(root, "deployment/storage-minimal");
const read = (name) => fs.readFileSync(path.join(directory, name), "utf8");

// Extract nested Rules scopes while ignoring braces in strings and comments.
function scopes(text) {
  const result = new Map();
  const occurrences = new Map();
  const headers = /\bfunction\s+(\w+)\s*\([^)]*\)\s*\{|\bmatch\s+(\S+)\s+\{/g;
  for (const header of text.matchAll(headers)) {
    let depth = 1, quote = null, comment = null;
    let end = header.index + header[0].length;
    for (; depth > 0 && end < text.length; end++) {
      const char = text[end], next = text[end + 1];
      if (comment === "line") {
        if (char === "\n") comment = null;
      } else if (comment === "block") {
        if (char === "*" && next === "/") { comment = null; end++; }
      } else if (quote) {
        if (char === "\\") end++;
        else if (char === quote) quote = null;
      } else if (char === "/" && next === "/") { comment = "line"; end++; }
      else if (char === "/" && next === "*") { comment = "block"; end++; }
      else if (char === "'" || char === '"') quote = char;
      else if (char === "{") depth++;
      else if (char === "}") depth--;
    }
    assert.equal(depth, 0, "Unclosed rules scope");
    const name = header[1] ? `function:${header[1]}` : `match:${header[2]}`;
    const count = (occurrences.get(name) || 0) + 1;
    occurrences.set(name, count);
    const key = count === 1 ? name : `${name}#${count}`;
    result.set(key, text.slice(header.index, end));
  }
  return result;
}

for (const kind of ["firestore", "storage"]) {
  test(`${kind}: every existing production function and unrelated match is byte-identical`, () => {
    const baseline = read(`baseline/${kind}.rules`);
    const metadata = JSON.parse(read("baseline/metadata.json"));
    assert.equal(createHash("sha256").update(baseline).digest("hex"), metadata.baselineHashes[kind]);
    const before = scopes(baseline), after = scopes(read(`${kind}.rules`));
    const imageCollections = new Set([
      "match:/users/{userId}", "match:/posts/{postId}",
      "match:/complaints/{complaintId}", "match:/marketplaces/{listingId}",
      "match:/apartmentImages/{imageId}",
    ]);
    const container = kind === "firestore"
      ? "match:/databases/{database}/documents" : "match:/b/{bucket}/o";
    for (const [key, value] of before) {
      if (key === container) continue;
      if (kind === "firestore" && imageCollections.has(key)) {
        const reads = (text) => [...text.matchAll(/allow\s+([^:]+):[^;]+;/g)]
          .filter((match) => /\b(read|get|list)\b/.test(match[1]))
          .map((match) => match[0]);
        const expected = reads(value);
        if (key === "match:/apartmentImages/{imageId}") {
          for (let i = 0; i < expected.length; i++) expected[i] = expected[i].replace(
            "residentSameBuilding(resource.data)",
            "(residentSameCommunity(resource.data) && resource.data.status == 'active')");
        }
        assert.deepEqual(reads(after.get(key)), expected, `${key}: changed reads`);
      } else {
        // The acceptance fix only permits eligible residents to check a missing
        // own notice receipt; existing/foreign receipt protection is unchanged.
        const expected = value.replace(
          "&& currentResidentMayReadParent()\n          && resource.data.userId == request.auth.uid;",
          "&& currentResidentMayReadParent()\n          && (resource == null || resource.data.userId == request.auth.uid);");
        const actual = after.get(key).replace(
          "// An eligible resident may check whether their own receipt exists.\n        ", "");
        assert.equal(actual, expected, `Changed production scope: ${key}`);
      }
    }
    const additions = [...after.keys()].filter((key) => !before.has(key)).sort();
    const allowed = kind === "firestore" ? [
      "function:legacyImageValue", "function:legacyImageList",
      "function:legacyImagesOnly", "function:managedImagesSafeUpdate",
      "function:noAttachedManagedImages", "match:/storageImageUploads/{assetId}",
    ] : [
      "function:imagePhoneMatchesProfile", "function:imageResidentIsOperational",
      "function:imageUploader", "function:imageStagingCreate",
      "match:/apartment_images/{communityId}/{uid}/{fileName}",
      "match:/resident_images/{communityId}/{uid}/{feature}/{fileName}",
      "match:/private_images/{allPaths=**}",
    ];
    assert.deepEqual(additions, allowed.sort());
  });
}

test("minimal deployment selects only image rules/source; seven-callable allowlist excludes schedulers", () => {
  const config = JSON.parse(fs.readFileSync(path.join(root, "firebase.storage-minimal.json")));
  const full = JSON.parse(fs.readFileSync(path.join(root, "firebase.json")));
  assert.deepEqual(Object.keys(config).sort(), ["firestore", "functions", "storage"]);
  assert.equal(config.firestore.rules, "deployment/storage-minimal/firestore.rules");
  assert.equal(config.storage.rules, "deployment/storage-minimal/storage.rules");
  assert.deepEqual(config.functions, full.functions);
  const metadata = JSON.parse(read("baseline/metadata.json"));
  assert.equal(metadata.initialCallables.length, 7);
  assert.ok(metadata.initialCallables.every((name) => !name.startsWith("cleanup")));
  assert.deepEqual(metadata.excludedSchedulers, ["cleanupApartmentImages", "cleanupResidentImages"]);
});
