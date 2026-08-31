const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const {
  CURRENT_LEGAL_VERSIONS,
  acceptCurrentLegalTermsCore,
  legalAcceptanceIsCurrent,
} = require("../src/legal_acceptance");

const APP_IDS = Object.freeze({
  resident: "1:551984029668:android:ef652ea4d8e070ca0db1f1",
  admin: "1:551984029668:android:322fd085a03f0ff70db1f1",
  security: "1:551984029668:android:93f99854319c9f9a0db1f1",
});

function fakeDb(seed) {
  const values = new Map(Object.entries(seed));
  return {
    values,
    collection(collectionName) {
      return {
        doc(id) {
          const path = `${collectionName}/${id}`;
          return {
            get: async () => ({
              exists: values.has(path),
              data: () => values.get(path),
            }),
            update: async (update) => {
              values.set(path, {...values.get(path), ...update});
            },
          };
        },
      };
    },
  };
}

const displayedVersions = {...CURRENT_LEGAL_VERSIONS};

test("Flutter and Functions use the same canonical legal versions", () => {
  const dartSource = fs.readFileSync(
    path.join(
      __dirname,
      "../../packages/hominode_legal/lib/src/legal_acceptance.dart",
    ),
    "utf8",
  );
  assert.match(dartSource, new RegExp(CURRENT_LEGAL_VERSIONS.termsVersion.replaceAll(".", "\\.")));
  assert.match(dartSource, new RegExp(CURRENT_LEGAL_VERSIONS.privacyVersion.replaceAll(".", "\\.")));
});

test("missing, stale, and incomplete acceptance require review", () => {
  assert.equal(legalAcceptanceIsCurrent(undefined), false);
  assert.equal(legalAcceptanceIsCurrent({...displayedVersions}), false);
  assert.equal(legalAcceptanceIsCurrent({
    ...displayedVersions,
    acceptedAt: new Date(),
  }), true);
  assert.equal(legalAcceptanceIsCurrent({
    termsVersion: "older",
    privacyVersion: CURRENT_LEGAL_VERSIONS.privacyVersion,
    acceptedAt: new Date(),
  }), false);
});

test("each trusted app updates only its authenticated canonical profile", async () => {
  const cases = [
    ["resident", "users", {approvalStatus: "approved", status: "active"}],
    ["admin", "admins", {}],
    ["security", "securityStaff", {}],
  ];

  for (const [role, collection, extra] of cases) {
    const uid = `${role}-a`;
    const path = `${collection}/${uid}`;
    const db = fakeDb({
      [path]: {uid, role, isActive: true, protectedValue: "unchanged", ...extra},
    });
    const result = await acceptCurrentLegalTermsCore({
      db,
      auth: {uid},
      app: {appId: APP_IDS[role]},
      data: {...displayedVersions, uid: "forged", role: "forged"},
    });

    assert.equal(result.accepted, true);
    assert.equal(db.values.get(path).protectedValue, "unchanged");
    assert.equal(
      db.values.get(path).legalAcceptance.termsVersion,
      CURRENT_LEGAL_VERSIONS.termsVersion,
    );
    assert.ok(db.values.get(path).legalAcceptance.acceptedAt);
  }
});

test("stale displayed versions cannot accept a newer legal version", async () => {
  const path = "users/resident-a";
  const db = fakeDb({
    [path]: {
      uid: "resident-a",
      role: "resident",
      isActive: true,
      approvalStatus: "approved",
    },
  });

  await assert.rejects(
    acceptCurrentLegalTermsCore({
      db,
      auth: {uid: "resident-a"},
      app: {appId: APP_IDS.resident},
      data: {...displayedVersions, termsVersion: "older"},
    }),
    {code: "failed-precondition"},
  );
  assert.equal(db.values.get(path).legalAcceptance, undefined);
});

test("an app/profile role mismatch is rejected", async () => {
  const db = fakeDb({
    "users/resident-a": {
      uid: "resident-a",
      role: "resident",
      isActive: true,
      approvalStatus: "approved",
    },
  });

  await assert.rejects(
    acceptCurrentLegalTermsCore({
      db,
      auth: {uid: "resident-a"},
      app: {appId: APP_IDS.admin},
      data: displayedVersions,
    }),
    {code: "permission-denied"},
  );
});
