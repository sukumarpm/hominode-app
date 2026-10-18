const assert = require("node:assert/strict");
const path = require("node:path");

function storageRulesDirectory() {
  const variant = process.env.HOMINODE_STORAGE_RULES_VARIANT || "release";
  assert.ok(["release", "minimal"].includes(variant), "Unknown storage rules variant");
  return path.resolve(
    __dirname,
    "../../..",
    variant === "minimal" ? "deployment/storage-minimal" : ".",
  );
}

module.exports = { storageRulesDirectory };
