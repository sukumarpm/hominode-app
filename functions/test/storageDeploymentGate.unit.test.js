const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");

function loadExports() {
  const db = { kind: "isolated-firestore" };
  const bucket = { kind: "isolated-storage" };
  const calls = [];
  const wrap = (options, handler) => ({ options, handler });
  const noop = () => {};
  const core = (name) => async (context) => {
    assert.equal(context.db, db);
    assert.equal(context.bucket, bucket);
    calls.push(name);
  };
  const modules = {
    "firebase-admin/app": { initializeApp: noop },
    "firebase-admin/firestore": { getFirestore: () => db },
    "firebase-admin/storage": { getStorage: () => ({ bucket: () => bucket }) },
    "firebase-admin/auth": { getAuth: noop },
    "firebase-admin/messaging": { getMessaging: noop },
    "firebase-functions/v2/https": { onCall: wrap, HttpsError: class extends Error {} },
    "firebase-functions/v2/firestore": { onDocumentCreated: wrap, onDocumentUpdated: wrap },
    "firebase-functions/v2/storage": { onObjectFinalized: wrap },
    "firebase-functions/v2/scheduler": { onSchedule: wrap },
    "firebase-functions/logger": {},
    "firebase-functions/params": {
      defineSecret: () => ({ value: noop }),
      defineString: () => ({ value: noop }),
    },
    "./apartment_images": { cleanupApartmentImagesCore: core("apartments") },
    "./resident_images": {
      cleanupResidentImagesCore: core("resident-assets"),
      cleanupUnreservedResidentStaging: core("resident-staging"),
    },
  };
  const exports = {};
  vm.runInNewContext(fs.readFileSync(path.join(__dirname, "../src/index.js"), "utf8"), {
    exports,
    require(name) {
      if (Object.hasOwn(modules, name)) return modules[name];
      assert.ok(name.startsWith("./"), `Unexpected dependency: ${name}`);
      return new Proxy({}, { get: () => noop });
    },
  });
  return { exports, calls };
}

test("storage callable export names match client calls, region and App Check", () => {
  const { exports } = loadExports();
  const names = [
    "prepareStorageImageUpload", "completeStorageImageUpload", "readStorageImage",
    "saveApartmentImage", "deleteApartmentImage", "createResidentImageDraft", "commitResidentImages",
  ];
  const sources = [
    "packages/hominode_storage/lib/src/storage_image_upload.dart",
    "hominode-admin/admin_app/lib/services/cloudinary_apartment_images_service.dart",
    "resident_app/lib/src/services/resident_image_operations.dart",
  ].map((file) => fs.readFileSync(path.join(__dirname, "../..", file), "utf8")).join("\n");
  for (const name of names) {
    assert.ok(sources.includes(`'${name}'`), `Missing client call: ${name}`);
    assert.equal(typeof exports[name].handler, "function");
    assert.equal(exports[name].options.region, "asia-southeast1");
    assert.equal(exports[name].options.enforceAppCheck, true);
  }
});

test("actual apartment cleanup export resolves Firestore and Storage at invocation", async () => {
  const { exports, calls } = loadExports();
  const cleanup = exports.cleanupApartmentImages;
  assert.equal(cleanup.options.region, "asia-southeast1");
  assert.equal(cleanup.options.schedule, "every 15 minutes");
  await cleanup.handler();
  assert.deepEqual(calls, ["apartments"]);
});

test("actual Resident cleanup export resolves dependencies for both sequential sweeps", async () => {
  const { exports, calls } = loadExports();
  const cleanup = exports.cleanupResidentImages;
  assert.equal(cleanup.options.region, "asia-southeast1");
  assert.equal(cleanup.options.schedule, "every 15 minutes");
  await cleanup.handler();
  assert.deepEqual(calls, ["resident-assets", "resident-staging"]);
});

test("Firebase upload file selection excludes local seeds, env files and artifacts", async () => {
  const root = path.join(__dirname, "../..");
  const config = JSON.parse(fs.readFileSync(path.join(root, "firebase.json"), "utf8"));
  const functionsRoot = path.join(root, config.functions.source);
  // Use the installed deploy packager's own filesystem traversal. Inspect names
  // only; never open or archive the excluded seed credentials or env files.
  const { readdirRecursive } = require("firebase-tools/lib/fsAsync");
  const files = await readdirRecursive({ path: functionsRoot, ignore: config.functions.ignore });
  const selected = files.map((file) => path.relative(functionsRoot, file.name));
  assert.ok(selected.includes("src/index.js"));
  assert.ok(selected.includes("src/storage_images.js"));
  assert.ok(selected.includes("package-lock.json"));
  assert.ok(!selected.some((file) => /^(scripts\/|test\/|node_modules\/|\.env(?:\.|$))/.test(file)));
  assert.ok(!selected.some((file) => /(?:^|\/)(?:firestore-debug\.log|\.DS_Store)$/.test(file)));
});
