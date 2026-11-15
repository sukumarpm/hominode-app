const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const {getSecurityVisitorSummaryCore} = require("../src/security_visitor_summary");

const now = Date.parse("2026-11-14T00:00:00+08:00");
const auth = {uid: "officer", token: {
  phone_number: "+639170000000", firebase: {sign_in_provider: "phone"},
}};
function fixture(visitors = {}) {
  const store = {
    securityStaff: {officer: {uid: "officer", role: "security", isActive: true,
      communityId: "a", phoneNumber: auth.token.phone_number}},
    communities: {a: {isActive: true, timeZone: "Asia/Manila"}}, visitors,
  };
  const reads = [];
  const db = {
    store, reads,
    collection: (name) => ({
      doc: (id) => ({kind: "doc", name, id}),
      where: (field, op, value) => ({select: (...fields) => ({kind: "query", name, field, op, value, fields})}),
    }),
    runTransaction: async (callback, options) => {
      assert.deepEqual(options, {readOnly: true});
      return callback({get: async (ref) => {
        reads.push(ref);
        if (ref.kind === "doc") {
          const value = store[ref.name]?.[ref.id];
          return {exists: !!value, data: () => value};
        }
        assert.equal(ref.name, "visitors");
        assert.equal(ref.field, "communityId");
        assert.equal(ref.op, "==");
        assert.equal(ref.value, "a");
        assert.deepEqual(ref.fields, ["status", "isApproved", "actualArrival", "departure"]);
        if (db.queryError) throw db.queryError;
        return {docs: Object.values(store.visitors).filter((v) => v.communityId === ref.value)
          .map((v) => ({data: () => Object.fromEntries(ref.fields.filter((k) => k in v).map((k) => [k, v[k]]))}))};
      }});
    },
  };
  return db;
}
const summarize = (db, extra = {}) => getSecurityVisitorSummaryCore({db, auth, now: () => now, ...extra});

test("summary is community scoped, uncapped and preserves dashboard metric definitions", async () => {
  const rows = {};
  for (let i = 0; i < 301; i++) rows[i] = {
    communityId: "a", status: "inside", actualArrival: new Date(now), departure: null,
    visitorName: "Private name", qrToken: "secret",
  };
  Object.assign(rows, {
    expected: {communityId: "a", status: "expected", isApproved: false},
    approved: {communityId: "a", status: "expected", isApproved: true},
    rejected: {communityId: "a", status: "rejected", isApproved: false},
    completed: {communityId: "a", status: "completed", actualArrival: new Date(now - 1), departure: new Date(now)},
    oldInside: {communityId: "a", status: "inside", actualArrival: new Date(now - 1)},
    oldExit: {communityId: "a", status: "completed", departure: new Date(now - 1)},
    foreign: {communityId: "b", status: "inside", actualArrival: new Date(now)},
  });
  const result = await summarize(fixture(rows), {data: {communityId: "b"}});
  assert.deepEqual(result, {communityId: "a", timeZone: "Asia/Manila", localDate: "2026-11-14",
    refreshedAt: now, totalToday: 301, activeInside: 302, pendingRequests: 1, exitsToday: 1});
  assert.equal(JSON.stringify(result).includes("secret"), false);
  assert.equal(JSON.stringify(result).includes("Private name"), false);
});

test("authorized empty community returns genuine zero counts", async () => {
  const result = await summarize(fixture());
  for (const key of ["totalToday", "activeInside", "pendingRequests", "exitsToday"]) assert.equal(result[key], 0);
});

for (const [label, date, hours] of [
  ["spring DST", "2026-03-08", 23], ["autumn DST", "2026-11-01", 25],
]) {
  test(`Today uses canonical community day including ${label}`, async () => {
    const start = Date.parse(`${date}T00:00:00${hours === 23 ? "-05:00" : "-04:00"}`);
    const end = start + hours * 3600000;
    const rows = {};
    for (const [i, time] of [start - 1, start, end - 1, end].entries()) rows[i] = {
      communityId: "a", status: "completed", actualArrival: new Date(time), departure: new Date(time),
    };
    const db = fixture(rows); db.store.communities.a.timeZone = "America/New_York";
    const result = await summarize(db, {now: () => start + 3600000});
    assert.equal(result.localDate, date);
    assert.equal(result.totalToday, 2);
    assert.equal(result.exitsToday, 2);
  });
}

for (const [label, mutate, code] of [
  ["no authentication", (db, args) => { args.auth = null; }, "unauthenticated"],
  ["non-phone provider", (db, args) => { args.auth = {...auth, token: {...auth.token, firebase: {sign_in_provider: "password"}}}; }, "unauthenticated"],
  ["missing staff", (db) => { delete db.store.securityStaff.officer; }, "permission-denied"],
  ["wrong role", (db) => { db.store.securityStaff.officer.role = "admin"; }, "permission-denied"],
  ["inactive staff", (db) => { db.store.securityStaff.officer.isActive = false; }, "permission-denied"],
  ["mismatched uid", (db) => { db.store.securityStaff.officer.uid = "another"; }, "permission-denied"],
  ["mismatched phone", (db) => { db.store.securityStaff.officer.phoneNumber = "+639170000001"; }, "permission-denied"],
  ["no community assignment", (db) => { db.store.securityStaff.officer.communityId = ""; }, "permission-denied"],
  ["missing community", (db) => { delete db.store.communities.a; }, "permission-denied"],
  ["inactive community", (db) => { db.store.communities.a.isActive = false; }, "permission-denied"],
  ["missing timezone", (db) => { delete db.store.communities.a.timeZone; }, "failed-precondition"],
  ["invalid timezone", (db) => { db.store.communities.a.timeZone = "invalid/timezone"; }, "failed-precondition"],
]) {
  test(`summary denies ${label} without querying visitor rows`, async () => {
    const db = fixture(), args = {}; mutate(db, args);
    await assert.rejects(summarize(db, args), (error) => error.code === code);
    assert.equal(db.reads.some((read) => read.kind === "query"), false);
  });
}

test("query failures propagate rather than reporting zero", async () => {
  const db = fixture(); db.queryError = new Error("unavailable");
  await assert.rejects(summarize(db), /unavailable/);
});

test("callable uses the existing App Check and verified-phone Security wrapper", () => {
  const source = fs.readFileSync(`${__dirname}/../src/index.js`, "utf8");
  assert.match(source, /exports\.getSecurityVisitorSummary = securityWorkflowCallable\(\s*getSecurityVisitorSummaryCore,/);
  assert.match(source, /function securityWorkflowCallable[\s\S]*?enforceAppCheck: true[\s\S]*?requirePhoneAuth\(request.auth\)/);
});
