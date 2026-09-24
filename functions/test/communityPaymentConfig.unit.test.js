const test = require("node:test");
const assert = require("node:assert/strict");
const {sosStore} = require("./helpers/sos_store");
const {updateCommunityPaymentConfigCore: update} = require("../src/community_payment_config");

const auth = {uid: "admin-a", token: {phone_number: "+15550000001", firebase: {sign_in_provider: "phone"}}};

function fixture({admin = {}, community = {isActive: true}, config} = {}) {
  const db = sosStore();
  db.values.set("admins/admin-a", {
    uid: "admin-a", role: "admin", isActive: true, authorizedCommunityIds: ["COMMUNITY_A"], ...admin,
  });
  db.values.set("communities/COMMUNITY_A", community);
  if (config) db.values.set("communityPaymentConfigs/COMMUNITY_A", config);
  return {db, call: (data) => update({db, auth, data})};
}

test("authorized active community Admin stores the normalized Direct UPI V1 config and audit", async () => {
  const f = fixture();
  await f.call({communityId: "COMMUNITY_A", directUpi: {enabled: true, vpa: "  finance.team+1@upi-bank  ", payeeName: "  Community Association  "}});

  const config = f.db.values.get("communityPaymentConfigs/COMMUNITY_A");
  assert.deepEqual(Object.keys(config).sort(), ["communityId", "directUpi", "updatedAt", "updatedBy", "version"]);
  assert.equal(config.communityId, "COMMUNITY_A");
  assert.equal(config.version, 1);
  assert.deepEqual(config.directUpi, {enabled: true, vpa: "finance.team+1@upi-bank", payeeName: "Community Association"});
  assert.equal(config.updatedBy, "admin-a");
  assert(config.updatedAt.toMillis());

  const audit = [...f.db.values.entries()].find(([path]) => path.startsWith("auditLogs/"))?.[1];
  assert.equal(audit.actorUid, "admin-a");
  assert.equal(audit.actorRole, "admin");
  assert.equal(audit.communityId, "COMMUNITY_A");
  assert.equal(audit.action, "community.payment_config_update");
  assert.equal(audit.targetType, "community_payment_config");
  assert.equal(audit.targetId, "COMMUNITY_A");
  assert.deepEqual(audit.metadata, {directUpiEnabled: true});
  assert.doesNotMatch(JSON.stringify(audit), /finance\.team|Community Association/);
});

test("disabling Direct UPI replaces destination details with enabled false only", async () => {
  const f = fixture({config: {
    communityId: "COMMUNITY_A", version: 1,
    directUpi: {enabled: true, vpa: "old@upi", payeeName: "Old Name"},
  }});
  await f.call({communityId: "COMMUNITY_A", directUpi: {enabled: false}});
  assert.deepEqual(f.db.values.get("communityPaymentConfigs/COMMUNITY_A").directUpi, {enabled: false});
  const audit = [...f.db.values.entries()].find(([path]) => path.startsWith("auditLogs/"))?.[1];
  assert.deepEqual(audit.metadata, {directUpiEnabled: false});
});

test("unauthorized, inactive, Super Admin, or inactive-community actors cannot update config", async () => {
  const cases = [
    {admin: {authorizedCommunityIds: ["COMMUNITY_B"]}, community: {isActive: true}, code: "permission-denied"},
    {admin: {isActive: false}, community: {isActive: true}, code: "permission-denied"},
    {admin: {role: "superAdmin"}, community: {isActive: true}, code: "permission-denied"},
    {admin: {}, community: {isActive: false}, code: "failed-precondition"},
  ];
  for (const options of cases) {
    const f = fixture(options);
    await assert.rejects(f.call({communityId: "COMMUNITY_A", directUpi: {enabled: false}}), {code: options.code});
    assert.equal(f.db.values.has("communityPaymentConfigs/COMMUNITY_A"), false);
    assert.equal([...f.db.values.keys()].some((path) => path.startsWith("auditLogs/")), false);
  }
});

test("invalid VPA and payee name inputs are rejected", async () => {
  const invalidConfigs = [
    {enabled: true, vpa: "", payeeName: "Association"},
    {enabled: true, vpa: "user@one@two", payeeName: "Association"},
    {enabled: true, vpa: "user name@upi", payeeName: "Association"},
    {enabled: true, vpa: "@upi", payeeName: "Association"},
    {enabled: true, vpa: "user@", payeeName: "Association"},
    {enabled: true, vpa: "user@upi", payeeName: "   "},
    {enabled: true, vpa: "user@upi", payeeName: "x".repeat(121)},
    {enabled: true, vpa: "user@upi"},
  ];
  for (const directUpi of invalidConfigs) {
    const f = fixture();
    await assert.rejects(f.call({communityId: "COMMUNITY_A", directUpi}), {code: "invalid-argument"});
  }
});

test("unexpected top-level/nested fields and destination details while disabled are rejected", async () => {
  const invalidRequests = [
    {communityId: "COMMUNITY_A", directUpi: {enabled: false}, bankAccount: "123"},
    {communityId: "COMMUNITY_A", directUpi: {enabled: true, vpa: "user@upi", payeeName: "Association", apiKey: "secret"}},
    {communityId: "COMMUNITY_A", directUpi: {enabled: false, vpa: "user@upi", payeeName: "Association"}},
  ];
  for (const data of invalidRequests) {
    const f = fixture();
    await assert.rejects(f.call(data), {code: "invalid-argument"});
  }
});
