const test = require("node:test");
const assert = require("node:assert/strict");
const { cleanupResidentMembershipsAndBookingsCore } = require("../src/account_deletion_requests");

function store({ failTransaction = false, failTransactionAt = failTransaction ? 1 : null, flat = {}, bookings = [], profile = { uid: "resident", role: "resident", communityId: "C1", flatId: "F1" }, queryFailureField = null, mutateBeforeTransactionRead = null } = {}) {
  const docs = new Map(Object.entries({
    "accountDeletionRequests/r1": { uid: "resident" },
    "users/resident": profile,
    "flats/F1": { communityId: "C1", residentUserId: "resident", ...flat },
    ...Object.fromEntries(bookings.map((b) => [`amenity_bookings/${b.id}`, b.data])),
    "payments/p1": { userId: "resident", status: "paid" }, "auditLogs/a1": { actorUid: "resident" },
  }));
  const ref = (c,id) => ({collection:c,id,path:`${c}/${id}`});
  const snap = (r) => ({exists:docs.has(r.path ?? `${r.collection}/${r.id}`),id:r.id,ref:r,data:()=>docs.get(r.path ?? `${r.collection}/${r.id}`)});
  const db = {
    docs,
    writeCount: 0,
    transactionCount: 0,
    collection(c) {
      return {
        doc(id) {
          const documentRef = ref(c, id);
          return { ...documentRef, get: async () => snap(documentRef), collection(child) { return { doc(childId) {
            const childRef = ref(`${c}/${id}/${child}`, childId);
            return { ...childRef, get: async () => snap(childRef), set: async (value) => docs.set(childRef.path, { ...docs.get(childRef.path), ...value }) };
          } }; } };
        },
        where(field, _operator, value) {
          return {
            get: async () => {
              if (queryFailureField === field) throw Error("injected query read failure");
              const rows = [...docs].filter(([key, valueDoc]) =>
                key.startsWith(`${c}/`) && valueDoc[field] === value);
              const matchingDocs = rows.map(([key]) =>
                snap(ref(c, key.slice(c.length + 1))));
              return { docs: matchingDocs };
            },
          };
        },
      };
    },
    async runTransaction(fn) {
      db.transactionCount += 1;
      const transactionNumber = db.transactionCount;
      const writes = [];
      const tx = {
        get: async (documentRef) => {
          if (!documentRef.path && documentRef.get) return documentRef.get();
          if (mutateBeforeTransactionRead?.(transactionNumber, documentRef, docs)) {
            // The hook performs a concurrent external write immediately before transaction read.
          }
          return snap(documentRef);
        },
        update: (documentRef, value) => writes.push([documentRef, value]),
      };
      await fn(tx);
      if (failTransactionAt === transactionNumber) throw Error("injected transaction failure");
      for (const [documentRef, value] of writes) {
        const key = documentRef.path ?? `${documentRef.collection}/${documentRef.id}`;
        docs.set(key, { ...docs.get(key), ...value });
        db.writeCount += 1;
      }
    },
  };
  return db;
}
const future=new Date(Date.now()+86400000), past=new Date(Date.now()-86400000);
const date=(d)=>({toDate:()=>d});
const run=(db,overrides={})=>cleanupResidentMembershipsAndBookingsCore({db,data:{requestId:"r1"},...overrides});

test("clears only the requester's single-resident membership",async()=>{const db=store();await run(db);assert.equal(db.docs.get("flats/F1").residentUserId,null);assert.equal(db.docs.has("users/resident"),true);});
test("unit release: sole occupant cleanup makes the retained unit safely assignable", async () => {
  const { assertSafelyVacant } = require("../src/unit_schema");
  const db = store({ flat: { status: "occupied", residentUid: "resident", residentId: "resident", residentIds: ["resident"], residentName: "Former resident", ownershipType: "owner", ownerId: "historical-owner" } });
  await run(db);
  await run(db);
  const flat = db.docs.get("flats/F1");
  assert.equal(flat.status, "vacant");
  for (const field of ["residentUserId", "residentUid", "residentId", "residentName"]) assert.equal(flat[field], null);
  assert.deepEqual(flat.residentIds, []);
  assert.equal(flat.ownershipType, "owner");
  assert.equal(flat.ownerId, "historical-owner");
  assert.equal(db.docs.get("payments/p1").status, "paid");
  assert.ok(db.docs.has("auditLogs/a1"));
  assert.doesNotThrow(() => assertSafelyVacant(flat));
});
test("unit release: another reverse-assigned profile prevents vacancy, including a concurrent occupant", async () => {
  for (const isActive of [true, false]) {
    const db = store({ flat: { status: "occupied" }, mutateBeforeTransactionRead: (_n, ref, docs) => {
      if (ref.path === "flats/F1") docs.set("users/other", { flatId: "F1", communityId: "C1", isActive });
    } });
    await run(db);
    assert.equal(db.docs.get("flats/F1").residentUserId, null);
    assert.equal(db.docs.get("flats/F1").status, "occupied");
    assert.equal(db.docs.get("users/other").flatId, "F1");
  }
});
test("unit release: reservations and maintenance are preserved", async () => {
  for (const flat of [{ status: "occupied", reservedOnboardingId: "reservation" }, { status: "maintenance" }, { status: "occupied", isActive: false }]) {
    const db = store({ flat });
    await run(db);
    assert.equal(db.docs.get("flats/F1").status, flat.status);
    assert.equal(db.docs.get("flats/F1").reservedOnboardingId, flat.reservedOnboardingId);
  }
});
test("unit release: failed occupant discovery does not release or unlink the unit", async () => {
  const db = store({ flat: { status: "occupied" }, queryFailureField: "flatId" });
  await assert.rejects(run(db));
  assert.equal(db.docs.get("flats/F1").status, "occupied");
  assert.equal(db.docs.get("flats/F1").residentUserId, "resident");
});
test("shared unit cleanup removes only the departing membership and keeps the unit occupied", async () => {
  const db = store({flat: {status: "occupied", residentIds: ["resident", "other"], residentUid: "other", residentName: "Other"}});
  assert.equal((await run(db)).complete, true);
  await run(db);
  const flat = db.docs.get("flats/F1");
  assert.deepEqual(flat.residentIds, ["other"]);
  assert.equal(flat.residentUid, "other");
  assert.equal(flat.residentUserId, null);
  assert.equal(flat.residentName, "Other");
  assert.equal(flat.status, "occupied");
});
test("cancels future booking and preserves historical booking and finance/audit",async()=>{const db=store({bookings:[{id:"future",data:{userId:"resident",communityId:"C1",date:date(future),status:"confirmed"}},{id:"past",data:{userId:"resident",communityId:"C1",date:date(past),status:"confirmed"}}]});await run(db);assert.equal(db.docs.get("amenity_bookings/future").status,"cancelled");assert.equal(db.docs.get("amenity_bookings/past").status,"confirmed");assert.equal(db.docs.get("payments/p1").status,"paid");assert.ok(db.docs.has("auditLogs/a1"));});
test("internal cleanup rejects client UID overrides without changing state",async()=>{const db=store();const before={...db.docs.get("flats/F1")};await assert.rejects(cleanupResidentMembershipsAndBookingsCore({db,data:{requestId:"r1",uid:"other"}}));assert.deepEqual(db.docs.get("flats/F1"),before);});
test("transaction failure leaves state unchanged and retry succeeds",async()=>{const db=store({failTransaction:true});const before={...db.docs.get("flats/F1")};await assert.rejects(run(db));assert.deepEqual(db.docs.get("flats/F1"),before);db.runTransaction=async(fn)=>{const writes=[];await fn({get:async r=>({exists:db.docs.has(r.path??`${r.collection}/${r.id}`),data:()=>db.docs.get(r.path??`${r.collection}/${r.id}`)}),update:(r,v)=>writes.push([r,v])});for(const [r,v] of writes){const key=r.path??`${r.collection}/${r.id}`;db.docs.set(key,{...db.docs.get(key),...v});}};await run(db);await run(db);assert.equal(db.docs.get("flats/F1").residentUserId,null);});

test("community mismatch is discovered before membership or booking changes", async () => {
  const db = store({ bookings: [{ id: "wrong-community", data: { userId: "resident", communityId: "C2", date: date(future), status: "confirmed" } }] });
  const result = await run(db);
  assert.equal(result.complete, false);
  assert.equal(db.writeCount, 0);
  assert.equal(db.docs.get("flats/F1").residentUserId, "resident");
  assert.equal(db.docs.get("amenity_bookings/wrong-community").status, "confirmed");
});

test("missing or unsupported booking date blocks all cleanup and preserves the booking", async () => {
  const db = store({ bookings: [{ id: "legacy", data: { userId: "resident", communityId: "C1", date: "2026-10-26", status: "pending" } }] });
  const result = await run(db);
  assert.equal(result.complete, false);
  assert.match(result.blockers[0].reason, /date is missing or uses an unsupported legacy format/);
  assert.equal(db.docs.get("amenity_bookings/legacy").status, "pending");
  assert.equal(db.writeCount, 0);
  assert.equal(db.docs.get("flats/F1").residentUserId, "resident");
});

test("missing request or Resident profile is rejected without deleting identity records", async () => {
  const db = store();
  await assert.rejects(cleanupResidentMembershipsAndBookingsCore({ db, data: { requestId: "missing" } }));
  db.docs.delete("users/resident");
  await assert.rejects(run(db));
  assert.equal(db.docs.has("accountDeletionRequests/r1"), true);
  assert.equal(db.docs.has("flats/F1"), true);
  assert.equal(db.docs.has("payments/p1"), true);
  assert.equal(db.docs.has("auditLogs/a1"), true);
});

test("querying another UID or community never changes that resident's records", async () => {
  const db = store({ bookings: [
    { id: "target", data: { userId: "resident", communityId: "C1", date: date(future), status: "approved" } },
    { id: "other-user", data: { userId: "other", communityId: "C1", date: date(future), status: "confirmed" } },
  ] });
  await run(db);
  assert.equal(db.docs.get("amenity_bookings/target").status, "cancelled");
  assert.equal(db.docs.get("amenity_bookings/other-user").status, "confirmed");
  assert.equal(db.docs.has("users/resident"), true);
  assert.equal(db.docs.has("accountDeletionRequests/r1"), true);
});

test("ambiguous booking is found before any membership or booking write", async () => {
  const db = store({ bookings: [{ id: "ambiguous", data: { userId: "resident", communityId: "C2", date: date(future), status: "confirmed" } }] });
  const beforeFlat = { ...db.docs.get("flats/F1") };
  const result = await run(db);
  assert.equal(result.complete, false);
  assert.equal(db.writeCount, 0);
  assert.deepEqual(db.docs.get("flats/F1"), beforeFlat);
  assert.equal(db.docs.get("amenity_bookings/ambiguous").status, "confirmed");
});

test("malformed membership is found before a valid future booking is changed", async () => {
  const db = store({ flat: { residentIds: "legacy-malformed" }, bookings: [{ id: "future", data: { userId: "resident", communityId: "C1", date: date(future), status: "pending" } }] });
  const result = await run(db);
  assert.equal(result.complete, false);
  assert.equal(db.writeCount, 0);
  assert.equal(db.docs.get("flats/F1").residentUserId, "resident");
  assert.equal(db.docs.get("amenity_bookings/future").status, "pending");
});

test("booking read failure returns a blocker and performs zero cleanup writes", async () => {
  const db = store({ queryFailureField: "residentId", bookings: [{ id: "future", data: { userId: "resident", communityId: "C1", date: date(future), status: "pending" } }] });
  const result = await run(db);
  assert.equal(result.complete, false);
  assert.ok(result.blockers.some((blocker) => blocker.type === "bookings" && blocker.field === "residentId"));
  assert.equal(db.writeCount, 0);
  assert.equal(db.docs.get("flats/F1").residentUserId, "resident");
  assert.equal(db.docs.get("amenity_bookings/future").status, "pending");
});

test("successful read-only preflight allows planned membership and booking cleanup", async () => {
  const db = store({ bookings: [{ id: "future", data: { userId: "resident", communityId: "C1", date: date(future), status: "confirmed" } }] });
  const result = await run(db);
  assert.equal(result.complete, true);
  assert.equal(db.writeCount, 2);
  assert.equal(db.docs.get("flats/F1").residentUserId, null);
  assert.equal(db.docs.get("amenity_bookings/future").status, "cancelled");
});

test("concurrent membership change after preflight is rejected without overwriting it", async () => {
  const db = store({ mutateBeforeTransactionRead: (_transactionNumber, ref, docs) => {
    if (ref.path?.startsWith("flats/") && ref.id === "F1") {
      docs.set("flats/F1", { ...docs.get("flats/F1"), residentId: "new-owner" });
      return true;
    }
    return false;
  } });
  await assert.rejects(run(db), /changed after cleanup preflight/);
  assert.equal(db.writeCount, 0);
  assert.equal(db.docs.get("flats/F1").residentUserId, "resident");
  assert.equal(db.docs.get("flats/F1").residentId, "new-owner");
});

test("deletion request identity change after preflight is rejected before writes", async () => {
  const db = store({ mutateBeforeTransactionRead: (_transactionNumber, ref, docs) => {
    if (ref.path?.startsWith("accountDeletionRequests/") && ref.id === "r1") {
      docs.set("accountDeletionRequests/r1", { uid: "different-user" });
      return true;
    }
    return false;
  } });
  await assert.rejects(run(db), /Deletion request or Resident profile changed after cleanup preflight/);
  assert.equal(db.writeCount, 0);
  assert.equal(db.docs.get("flats/F1").residentUserId, "resident");
});

test("a later transaction failure leaves prior progress intact and retry completes safely", async () => {
  const db = store({ failTransactionAt: 2, bookings: [{ id: "future", data: { userId: "resident", communityId: "C1", date: date(future), status: "approved" } }] });
  await assert.rejects(run(db));
  assert.equal(db.docs.get("flats/F1").residentUserId, null);
  assert.equal(db.docs.get("amenity_bookings/future").status, "approved");
  db.transactionCount = 0;
  db.writeCount = 0;
  // Disable the injected failure while retaining the same data for a safe retry.
  db.runTransaction = async (fn) => {
    db.transactionCount += 1;
    const writes = [];
    await fn({ get: async (ref) => ({ exists: db.docs.has(ref.path ?? `${ref.collection}/${ref.id}`), data: () => db.docs.get(ref.path ?? `${ref.collection}/${ref.id}`) }), update: (ref, value) => writes.push([ref, value]) });
    for (const [ref, value] of writes) {
      const key = ref.path ?? `${ref.collection}/${ref.id}`;
      db.docs.set(key, { ...db.docs.get(key), ...value });
      db.writeCount += 1;
    }
  };
  const retried = await run(db);
  assert.equal(retried.complete, true);
  assert.equal(db.docs.get("amenity_bookings/future").status, "cancelled");
  assert.equal(db.docs.has("users/resident"), true);
  assert.equal(db.docs.get("payments/p1").status, "paid");
});


test("legacy residentId alias releases only the profile's own assignment", async () => {
  const db = store({profile: {uid: "resident", role: "resident", communityId: "C1", flatId: "F1", residentId: "legacy-1"}, flat: {status: "occupied", residentUserId: null, residentId: "legacy-1"}});
  await run(db);
  assert.equal(db.docs.get("flats/F1").residentId, null);
  assert.equal(db.docs.get("flats/F1").status, "vacant");
});

test("unit reassigned before processing is untouched", async () => {
  const db = store({flat: {status: "occupied", residentUserId: "other", residentId: "other", residentIds: ["other"]}});
  const before = {...db.docs.get("flats/F1")};
  await run(db);
  assert.deepEqual(db.docs.get("flats/F1"), before);
});

test("vacancy release updates building counters without changing master metadata", async () => {
  const db = store({flat: {status: "occupied", buildingId: "B1"}});
  db.docs.set("buildings/B1", {communityId: "C1", name: "Retained", occupied: 1, vacant: 0});
  await run(db);
  assert.equal(db.docs.get("buildings/B1").occupied, 0);
  assert.equal(db.docs.get("buildings/B1").vacant, 1);
  assert.equal(db.docs.get("buildings/B1").name, "Retained");
});


test("release preserves original unit links on historical billing, payment and transaction records", async () => {
  const db = store({flat: {status: "occupied"}});
  const history = {communityId: "C1", userId: "resident", flatId: "F1", unitId: "original-label", status: "paid"};
  for (const path of ["bills/b1", "payments/p1", "transactions/t1", "paymentRecords/p1"]) db.docs.set(path, {...history});
  await run(db);
  for (const path of ["bills/b1", "payments/p1", "transactions/t1", "paymentRecords/p1"]) assert.deepEqual(db.docs.get(path), history);
  assert.equal(db.docs.has("flats/F1"), true);
});
