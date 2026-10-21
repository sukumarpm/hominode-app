const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} = require("@firebase/rules-unit-testing");
const {
  doc,
  setDoc,
  getDoc,
  updateDoc,
  deleteDoc,
  writeBatch,
  serverTimestamp,
  Timestamp,
} = require("firebase/firestore");
const { storageRulesDirectory } = require("./helpers/storage_rules_variant");
let env;
const enabled = !!process.env.FIRESTORE_EMULATOR_HOST;
const run = (name, fn) => test(name, { skip: !enabled }, fn);
const phoneFor = (uid) =>
  ({ r: "+639170000001", peer: "+639170000002", foreign: "+639170000003" })[
    uid
  ];
const residentContext = (uid) =>
  env.authenticatedContext(uid, {
    phone_number: phoneFor(uid),
    firebase: { sign_in_provider: "phone" },
  });
const notification = (uid = "r", cid = "C") => ({
  recipientId: uid,
  communityId: cid,
  audience: "resident",
  role: "resident",
  appId: "resident",
  isRead: false,
  title: "Synthetic notification",
});
test.before(async () => {
  if (!enabled) return;
  env = await initializeTestEnvironment({
    projectId: "demo-hominode-storage-images",
    firestore: {
      rules: fs.readFileSync(
        `${storageRulesDirectory()}/firestore.rules`,
        "utf8",
      ),
    },
  });
  await env.clearFirestore(); // Isolate Rules variants in the shared local emulator.
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    for (const cid of ["C", "D"])
      await setDoc(doc(db, "communities", cid), { isActive: true });
    for (const [uid, cid] of [
      ["r", "C"],
      ["peer", "C"],
      ["foreign", "D"],
    ])
      await setDoc(doc(db, "users", uid), {
        uid,
        phoneNumber: phoneFor(uid),
        role: "resident",
        communityId: cid,
        flatId: "flat",
        residentType: "owner",
        isActive: true,
        approvalStatus: "approved",
        status: "active",
      });
    for (const id of ["a", "b", "c", "d", "e"])
      await setDoc(doc(db, "notifications", id), notification());
    await setDoc(doc(db, "notices/shared"), {
      communityId: "C",
      isActive: true,
      targetFlats: [],
      title: "Shared notice",
    });
    await setDoc(doc(db, "notices/foreign"), {
      communityId: "D",
      isActive: true,
      targetFlats: [],
    });
  });
});
test.after(async () => {
  await env?.cleanup();
});
run(
  "resident can soft-delete one and multiple own canonical notifications",
  async () => {
    const db = residentContext("r").firestore();
    await assertSucceeds(
      updateDoc(doc(db, "notifications/a"), { deletedAt: serverTimestamp() }),
    );
    const batch = writeBatch(db);
    for (const id of ["b", "c"])
      batch.update(doc(db, "notifications", id), {
        deletedAt: serverTimestamp(),
      });
    await assertSucceeds(batch.commit());
    assert.ok((await getDoc(doc(db, "notifications/a"))).data().deletedAt);
    await assertFails(deleteDoc(doc(db, "notifications/a")));
  },
);
run(
  "soft-deleted records cannot be restored or repointed and read updates preserve tombstones",
  async () => {
    const db = residentContext("r").firestore();
    const ref = doc(db, "notifications/a");
    const deletedAt = (await getDoc(ref)).data().deletedAt;
    await assertSucceeds(
      updateDoc(ref, { isRead: true, readAt: serverTimestamp() }),
    );
    await assertFails(setDoc(ref, { ...notification(), deletedAt: null }));
    await assertFails(updateDoc(ref, { recipientId: "peer" }));
    await assertFails(updateDoc(ref, { deletedAt: Timestamp.fromMillis(1) }));
    assert.deepEqual((await getDoc(ref)).data().deletedAt, deletedAt);
  },
);
run(
  "peer, foreign and unauthenticated canonical deletion attempts are denied",
  async () => {
    for (const uid of ["peer", "foreign", null]) {
      const db = uid
        ? residentContext(uid).firestore()
        : env.unauthenticatedContext().firestore();
      await assertFails(
        updateDoc(doc(db, "notifications/d"), { deletedAt: serverTimestamp() }),
      );
      await assertFails(deleteDoc(doc(db, "notifications/d")));
    }
  },
);
run("mixed unauthorized bulk deletion fails atomically", async () => {
  const db = residentContext("peer").firestore();
  const batch = writeBatch(db);
  batch.update(doc(db, "notifications/d"), { deletedAt: serverTimestamp() });
  batch.update(doc(db, "notifications/e"), { deletedAt: serverTimestamp() });
  await assertFails(batch.commit());
  await env.withSecurityRulesDisabled(async (ctx) =>
    assert.equal(
      (await getDoc(doc(ctx.firestore(), "notifications/d"))).data().deletedAt,
      undefined,
    ),
  );
});
run(
  "notice dismissal is per recipient and preserves shared content and read state",
  async () => {
    const db = residentContext("r").firestore();
    const ref = doc(db, "notices/shared/readBy/r");
    await assertSucceeds(
      setDoc(
        ref,
        { userId: "r", deletedAt: serverTimestamp() },
        { merge: true },
      ),
    );
    await assertSucceeds(
      setDoc(ref, { userId: "r", readAt: serverTimestamp() }, { merge: true }),
    );
    assert.ok((await getDoc(ref)).data().deletedAt);
    await assertSucceeds(
      getDoc(doc(residentContext("peer").firestore(), "notices/shared")),
    );
    await assertFails(deleteDoc(doc(db, "notices/shared")));
    await assertFails(deleteDoc(ref));
  },
);
run(
  "notice receipt impersonation, foreign community and unauthenticated dismissal are denied",
  async () => {
    const db = residentContext("r").firestore();
    await assertFails(
      setDoc(doc(db, "notices/shared/readBy/peer"), {
        userId: "peer",
        deletedAt: serverTimestamp(),
      }),
    );
    await assertFails(
      setDoc(doc(db, "notices/foreign/readBy/r"), {
        userId: "r",
        deletedAt: serverTimestamp(),
      }),
    );
    await assertFails(
      setDoc(
        doc(
          env.unauthenticatedContext().firestore(),
          "notices/shared/readBy/r",
        ),
        { userId: "r", deletedAt: serverTimestamp() },
      ),
    );
    await assertFails(
      setDoc(
        doc(db, "notices/shared/readBy/r"),
        { userId: "r", deletedAt: null },
        { merge: true },
      ),
    );
  },
);
