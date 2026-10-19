const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} = require("@firebase/rules-unit-testing");
const {
  doc,
  setDoc,
  getDoc,
  getDocs,
  collection,
  writeBatch,
  increment,
  serverTimestamp,
  updateDoc,
  deleteDoc,
} = require("firebase/firestore");
const { storageRulesDirectory } = require("./helpers/storage_rules_variant");
const enabled = !!process.env.FIRESTORE_EMULATOR_HOST;
const phone = "+639170000000";
let env;
const db = (uid) =>
  uid
    ? env
        .authenticatedContext(uid, {
          phone_number: phone,
          firebase: { sign_in_provider: "phone" },
        })
        .firestore()
    : env.unauthenticatedContext().firestore();
const run = (name, fn) => test(name, { skip: !enabled }, fn);
test.before(async () => {
  if (!enabled) return;
  assert.match(
    process.env.FIRESTORE_EMULATOR_HOST,
    /^(localhost|127\.0\.0\.1):\d+$/,
  );
  env = await initializeTestEnvironment({
    projectId: "demo-hominode-storage-images",
    firestore: {
      rules: fs.readFileSync(
        path.join(storageRulesDirectory(), "firestore.rules"),
        "utf8",
      ),
    },
  });
});
test.after(async () => {
  if (env) await env.cleanup();
});
test.beforeEach(async () => {
  if (!enabled) return;
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const store = ctx.firestore();
    for (const community of ["A", "B"])
      await setDoc(doc(store, "communities", community), { isActive: true });
    for (const [uid, communityId] of [
      ["owner", "A"],
      ["reader", "A"],
      ["foreign", "B"],
    ]) {
      await setDoc(doc(store, "users", uid), {
        uid,
        name: uid,
        phoneNumber: phone,
        communityId,
        role: "resident",
        approvalStatus: "approved",
        isActive: true,
        status: "active",
        residentType: "owner",
        ownershipType: "owner",
        identityVerificationStatus: "not_required",
      });
    }
    await setDoc(doc(store, "posts", "post"), {
      communityId: "A",
      authorId: "owner",
      content: "Original",
      status: "active",
      comments: 0,
    });
  });
});
function comment(store, overrides = {}, counter = {}, id = "comment") {
  const batch = writeBatch(store);
  batch.set(doc(store, "posts/post/comments", id), {
    postId: "post",
    communityId: "A",
    authorId: "reader",
    authorName: "reader",
    profileImage: "",
    comment: "Hello",
    createdAt: serverTimestamp(),
    ...overrides,
  });
  batch.update(doc(store, "posts/post"), {
    comments: increment(1),
    updatedAt: serverTimestamp(),
    lastCommentId: id,
    ...counter,
  });
  return batch.commit();
}
run(
  "same-community non-owner atomically creates and reads a comment and count",
  async () => {
    const store = db("reader");
    await assertSucceeds(comment(store));
    assert.equal((await getDoc(doc(store, "posts/post"))).data().comments, 1);
    assert.equal(
      (await getDocs(collection(store, "posts/post/comments"))).size,
      1,
    );
    await assertSucceeds(comment(store, {}, {}, "second"));
    assert.equal((await getDoc(doc(store, "posts/post"))).data().comments, 2);
  },
);
run("post owner can comment with canonical identity", async () => {
  await assertSucceeds(
    comment(db("owner"), { authorId: "owner", authorName: "owner" }),
  );
});
run("cross-community resident cannot create or read comments", async () => {
  await assertSucceeds(comment(db("reader")));
  await assertFails(
    comment(
      db("foreign"),
      { authorId: "foreign", authorName: "foreign" },
      {},
      "foreign",
    ),
  );
  await assertFails(getDoc(doc(db("foreign"), "posts/post/comments/comment")));
  await assertFails(getDocs(collection(db("foreign"), "posts/post/comments")));
});
run("unauthenticated comment and read are denied", async () => {
  await assertFails(comment(db(null)));
  await assertFails(getDocs(collection(db(null), "posts/post/comments")));
});
run(
  "spoofed community, author, parent, name and timestamp are denied",
  async () => {
    for (const change of [
      { communityId: "B" },
      { authorId: "owner" },
      { authorName: "owner" },
      { postId: "other" },
      { createdAt: new Date(0) },
      { profileImage: "forged" },
      { comment: "" },
    ]) {
      await assertFails(comment(db("reader"), change));
    }
  },
);
run(
  "standalone counter increments and standalone comments are denied",
  async () => {
    const store = db("reader");
    await assertFails(
      updateDoc(doc(store, "posts/post"), {
        comments: 1,
        updatedAt: serverTimestamp(),
        lastCommentId: "missing",
      }),
    );
    await assertFails(
      setDoc(doc(store, "posts/post/comments/comment"), {
        postId: "post",
        communityId: "A",
        authorId: "reader",
        authorName: "reader",
        profileImage: "",
        comment: "Hello",
        createdAt: serverTimestamp(),
      }),
    );
  },
);
run(
  "failed counter or content mutation leaves no partial comment",
  async () => {
    const store = db("reader");
    for (const counter of [
      { comments: 7 },
      { content: "Tampered" },
      { communityId: "B" },
      { images: ["forged"] },
      { lastCommentId: "different" },
    ]) {
      await assertFails(comment(store, {}, counter));
      assert.equal(
        (await getDoc(doc(store, "posts/post/comments/comment"))).exists(),
        false,
      );
      assert.equal((await getDoc(doc(store, "posts/post"))).data().comments, 0);
    }
  },
);
run("comments cannot be overwritten or deleted", async () => {
  const store = db("reader");
  await assertSucceeds(comment(store));
  await assertFails(comment(store));
  await assertFails(
    updateDoc(doc(store, "posts/post/comments/comment"), { comment: "Edited" }),
  );
  await assertFails(deleteDoc(doc(store, "posts/post/comments/comment")));
});
run("inactive residents cannot comment", async () => {
  await env.withSecurityRulesDisabled((ctx) =>
    updateDoc(doc(ctx.firestore(), "users/reader"), { isActive: false }),
  );
  await assertFails(comment(db("reader")));
});

run(
  "existing post-owner edits remain permitted without comment metadata",
  async () => {
    await assertSucceeds(
      updateDoc(doc(db("owner"), "posts/post"), {
        content: "Updated",
        updatedAt: serverTimestamp(),
      }),
    );
  },
);
run("optional null profile fields use existing display fallbacks", async () => {
  await env.withSecurityRulesDisabled((ctx) =>
    updateDoc(doc(ctx.firestore(), "users/reader"), {
      name: null,
      profileImage: null,
    }),
  );
  await assertSucceeds(comment(db("reader"), { authorName: "Unknown User" }));
});
