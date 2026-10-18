const test = require("node:test");
const assert = require("node:assert/strict");
const { sosStore } = require("./helpers/sos_store");
const {
  registerResidentCore,
  claimImportedOnboardingCore,
} = require("../src/register_resident");
const { hasCanonicalPhoneProfile } = require("../src/phone_auth");
const identity = { uid: "schema-resident", phoneNumber: "+639170000000" };
const auth = {
  uid: identity.uid,
  token: {
    phone_number: identity.phoneNumber,
    firebase: { sign_in_provider: "phone" },
  },
};

test("invite registration writes only phoneNumber and preserves idempotency", async () => {
  const db = sosStore();
  db.values.set("communities/A", { isActive: true });
  db.values.set("communityInvites/HOME", {
    communityId: "A",
    isActive: true,
    useCount: 0,
  });
  const request = {
    db,
    auth,
    data: {
      inviteCode: "HOME",
      fullName: "Schema Resident",
      buildingReference: "Tower A",
      unitReference: "A1",
      residentType: "owner",
    },
  };
  await registerResidentCore(request);
  const user = db.values.get(`users/${identity.uid}`);
  assert.equal(user.phoneNumber, identity.phoneNumber);
  assert.equal(Object.hasOwn(user, "phone"), false);
  assert.equal((await registerResidentCore(request)).idempotent, true);
});

test("owned imported onboarding claim writes only canonical phoneNumber", async () => {
  const db = sosStore();
  db.values.set("communities/A", { isActive: true });
  db.values.set("residentOnboarding/owned", {
    communityId: "A",
    phoneNumber: identity.phoneNumber,
    residentName: "Schema Resident",
    residentType: "owner",
    creationSource: "admin_single_onboarding",
    status: "pending_registration",
    claimedByUid: null,
  });
  await claimImportedOnboardingCore({ db, identity });
  const user = db.values.get(`users/${identity.uid}`);
  assert.equal(user.phoneNumber, identity.phoneNumber);
  assert.equal(Object.hasOwn(user, "phone"), false);
  assert.equal(
    (await claimImportedOnboardingCore({ db, identity })).idempotent,
    true,
  );
});

test("legacy phone remains display-only and cannot override canonical identity", async () => {
  const db = sosStore();
  db.values.set(`users/${identity.uid}`, {
    uid: identity.uid,
    role: "resident",
    phoneNumber: identity.phoneNumber,
    phone: "outdated display alias",
  });
  assert.equal(await hasCanonicalPhoneProfile(db, auth), true);
  db.values.get(`users/${identity.uid}`).phoneNumber = "+639170000001";
  db.values.get(`users/${identity.uid}`).phone = identity.phoneNumber;
  assert.equal(await hasCanonicalPhoneProfile(db, auth), false);
  delete db.values.get(`users/${identity.uid}`).phoneNumber;
  assert.equal(await hasCanonicalPhoneProfile(db, auth), false);
});
