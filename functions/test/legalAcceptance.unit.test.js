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

const ADMIN_WEB = "1:551984029668:web:5845083359a375d90db1f1";

test("trusted Admin web ID matches the configured Flutter web app", () => {
  const source = fs.readFileSync(path.join(__dirname,
    "../../hominode-admin/admin_app/lib/firebase_options.dart"), "utf8");
  const webOptions = source.match(/static const FirebaseOptions web = FirebaseOptions\(([\s\S]*?)\);/);
  assert.ok(webOptions);
  assert.equal(webOptions[1].match(/appId: '([^']+)'/)[1], ADMIN_WEB);
});

for (const role of ["admin", "superAdmin"]) {
  test(`${role} can accept and renew legal acceptance using the Admin web app`, async () => {
    const profilePath = "admins/admin-a";
    const db = fakeDb({[profilePath]: {uid: "admin-a", role, isActive: true, protectedValue: "unchanged"}});
    const args = {db, auth: {uid: "admin-a"}, app: {appId: ADMIN_WEB}, data: displayedVersions};
    assert.equal((await acceptCurrentLegalTermsCore(args)).accepted, true);
    assert.equal(legalAcceptanceIsCurrent(db.values.get(profilePath).legalAcceptance), true);
    db.values.get(profilePath).legalAcceptance = {termsVersion: "older", privacyVersion: "older", acceptedAt: new Date(0)};
    assert.equal(legalAcceptanceIsCurrent(db.values.get(profilePath).legalAcceptance), false);
    assert.equal((await acceptCurrentLegalTermsCore(args)).accepted, true);
    assert.equal(legalAcceptanceIsCurrent(db.values.get(profilePath).legalAcceptance), true);
    assert.equal(db.values.get(profilePath).protectedValue, "unchanged");
    assert.equal(db.values.size, 1);
  });
}

test("existing iOS Admin, Resident and Security apps retain legal acceptance access", async () => {
  for (const [appId, role, collection] of [
    ["1:551984029668:ios:c385b8730137f2710db1f1", "admin", "admins"],
    ["1:551984029668:ios:cb57ef578d5066b50db1f1", "resident", "users"],
    ["1:551984029668:ios:7063832b4b5d53fc0db1f1", "security", "securityStaff"],
  ]) {
    const db = fakeDb({[`${collection}/a`]: {uid: "a", role, isActive: true, approvalStatus: "approved"}});
    assert.equal((await acceptCurrentLegalTermsCore({db, auth: {uid: "a"}, app: {appId}, data: displayedVersions})).accepted, true);
  }
});

test("unknown, malformed, missing and inherited-key app IDs fail before profile access", async () => {
  for (const app of [undefined, {}, {appId: null}, {appId: 123}, {appId: {}}, {appId: ""},
    {appId: "1:551984029668:web:unknown"}, {appId: `${ADMIN_WEB}-forged`},
    {appId: "__proto__"}, {appId: "constructor"}, {appId: "toString"}]) {
    await assert.rejects(acceptCurrentLegalTermsCore({db: {}, auth: {uid: "a"}, app, data: displayedVersions}), {
      code: "failed-precondition", message: "This Firebase application is not authorized for legal acceptance.",
    });
  }
});

test("Admin web still requires authentication and current terms AND privacy versions", async () => {
  await assert.rejects(acceptCurrentLegalTermsCore({db: {}, app: {appId: ADMIN_WEB}, data: displayedVersions}), {code: "unauthenticated"});
  for (const data of [undefined, {}, {...displayedVersions, termsVersion: "older"}, {...displayedVersions, privacyVersion: "older"}]) {
    await assert.rejects(acceptCurrentLegalTermsCore({db: {}, auth: {uid: "a"}, app: {appId: ADMIN_WEB}, data}), {
      code: "failed-precondition", message: "The Terms or Privacy Policy changed. Refresh the app and review the current versions.",
    });
  }
});

test("Admin web rejects missing, inactive, mismatched UID and wrong-role canonical profiles", async () => {
  for (const profile of [null, {uid: "a", role: "admin", isActive: false}, {uid: "other", role: "admin", isActive: true},
    {uid: "a", role: "resident", isActive: true}, {uid: "a", role: "security", isActive: true}]) {
    const db = fakeDb(profile ? {"admins/a": profile} : {});
    await assert.rejects(acceptCurrentLegalTermsCore({db, auth: {uid: "a"}, app: {appId: ADMIN_WEB}, data: displayedVersions}), {code: "permission-denied"});
    assert.equal(db.values.get("admins/a")?.legalAcceptance, undefined);
  }
});
