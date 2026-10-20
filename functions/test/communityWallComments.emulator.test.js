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
  runTransaction,
  arrayUnion,
  arrayRemove,
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
      ["peer", "A"],
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
      likes: 0,
      likedBy: [],
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

// Mirrors the Resident transaction's desired-state contract: retries are no-ops.
async function react(store, uid, liked) {
  for (let attempt = 0; ; attempt++) {
    try {
      return await runTransaction(store, async (tx) => {
        const ref = doc(store, "posts/post");
        const post = (await tx.get(ref)).data();
        const before = post.likedBy || [];
        if (before.includes(uid) === liked) return;
        tx.update(ref, {
          likedBy: liked ? arrayUnion(uid) : arrayRemove(uid),
          likes: increment(liked ? 1 : -1),
          updatedAt: serverTimestamp(),
        });
      });
    } catch (error) {
      if (error.code !== "permission-denied" || attempt >= 1) throw error;
    }
  }
}
function reaction(store, fields) {
  return updateDoc(doc(store, "posts/post"), {
    likes: 1,
    likedBy: ["reader"],
    updatedAt: serverTimestamp(),
    ...fields,
  });
}
run("peer resident can like and unlike an own-community post", async () => {
  const store = db("reader");
  await assertSucceeds(react(store, "reader", true));
  let data = (await getDoc(doc(store, "posts/post"))).data();
  assert.equal(data.likes, 1);
  assert.deepEqual(data.likedBy, ["reader"]);
  await assertSucceeds(react(store, "reader", false));
  data = (await getDoc(doc(store, "posts/post"))).data();
  assert.equal(data.likes, 0);
  assert.deepEqual(data.likedBy, []);
});
run(
  "duplicate likes and unlikes are successful no-ops without timestamp changes",
  async () => {
    const store = db("reader");
    await assertSucceeds(react(store, "reader", false));
    assert.equal(
      (await getDoc(doc(store, "posts/post"))).data().updatedAt,
      undefined,
    );
    await assertSucceeds(react(store, "reader", true));
    const first = (await getDoc(doc(store, "posts/post"))).data();
    await assertSucceeds(react(store, "reader", true));
    assert.deepEqual((await getDoc(doc(store, "posts/post"))).data(), first);
    await assertFails(reaction(store, { likes: 2 }));
    await assertSucceeds(react(store, "reader", false));
    const last = (await getDoc(doc(store, "posts/post"))).data();
    await assertSucceeds(react(store, "reader", false));
    assert.deepEqual((await getDoc(doc(store, "posts/post"))).data(), last);
    await assertFails(reaction(store, { likes: -1, likedBy: [] }));
  },
);
run("concurrent residents retain both independent reactions", async () => {
  await Promise.all([
    react(db("reader"), "reader", true),
    react(db("peer"), "peer", true),
  ]);
  let post = (await getDoc(doc(db("reader"), "posts/post"))).data();
  assert.equal(post.likes, 2);
  assert.deepEqual(new Set(post.likedBy), new Set(["reader", "peer"]));
  await assertSucceeds(react(db("reader"), "reader", false));
  post = (await getDoc(doc(db("peer"), "posts/post"))).data();
  assert.equal(post.likes, 1);
  assert.deepEqual(post.likedBy, ["peer"]);
});
run(
  "cannot impersonate, remove another reaction or manipulate counts and timestamps",
  async () => {
    const store = db("reader");
    for (const fields of [
      { likedBy: ["owner"] },
      { likedBy: ["reader", "peer"], likes: 2 },
      { likedBy: ["reader", "reader"], likes: 2 },
      { likes: 2 },
      { likes: -1 },
      { likes: 1.5 },
      { updatedAt: new Date(0) },
    ]) {
      await assertFails(reaction(store, fields));
    }
    await assertSucceeds(react(db("peer"), "peer", true));
    await assertFails(reaction(store, { likedBy: [], likes: 0 }));
    await assertFails(reaction(store, { likedBy: ["reader"], likes: 1 }));
  },
);
run(
  "reaction cannot edit content, identity, images or comment state",
  async () => {
    for (const fields of [
      { content: "Tampered" },
      { communityId: "B" },
      { authorId: "reader" },
      { images: ["forged"] },
      { comments: 7 },
      { lastCommentId: "forged" },
    ]) {
      await assertFails(reaction(db("reader"), fields));
    }
  },
);
run("foreign-community and unauthenticated reactions are denied", async () => {
  await assertFails(reaction(db("foreign"), { likedBy: ["foreign"] }));
  await assertFails(reaction(db(null), {}));
  await assertSucceeds(react(db("reader"), "reader", true));
  await assertFails(reaction(db("foreign"), { likedBy: [], likes: 0 }));
  await assertFails(reaction(db(null), { likedBy: [], likes: 0 }));
});
run(
  "inactive, pending, wrong-role and unverified tenants cannot react",
  async () => {
    for (const changes of [
      { isActive: false },
      { approvalStatus: "pending" },
      { role: "security" },
      {
        residentType: "tenant",
        ownershipType: "tenant",
        identityVerified: false,
      },
    ]) {
      await env.withSecurityRulesDisabled(async (ctx) => {
        await updateDoc(doc(ctx.firestore(), "users/reader"), {
          isActive: true,
          approvalStatus: "approved",
          role: "resident",
          residentType: "owner",
          ownershipType: "owner",
          ...changes,
        });
      });
      await assertFails(reaction(db("reader"), {}));
    }
  },
);
run(
  "requires canonical phone authentication, active community and active post",
  async () => {
    const password = env
      .authenticatedContext("reader", {
        phone_number: phone,
        firebase: { sign_in_provider: "password" },
      })
      .firestore();
    await assertFails(reaction(password, {}));
    const wrongPhone = env
      .authenticatedContext("reader", {
        phone_number: "+639170000001",
        firebase: { sign_in_provider: "phone" },
      })
      .firestore();
    await assertFails(reaction(wrongPhone, {}));
    await env.withSecurityRulesDisabled((ctx) =>
      updateDoc(doc(ctx.firestore(), "communities/A"), { isActive: false }),
    );
    await assertFails(reaction(db("reader"), {}));
    await env.withSecurityRulesDisabled(async (ctx) => {
      await updateDoc(doc(ctx.firestore(), "communities/A"), {
        isActive: true,
      });
      await updateDoc(doc(ctx.firestore(), "posts/post"), {
        status: "deleted",
      });
    });
    await assertFails(reaction(db("reader"), {}));
  },
);
run(
  "owner may react and edit but cannot bypass the counter contract",
  async () => {
    const store = db("owner");
    await assertSucceeds(react(store, "owner", true));
    await assertFails(reaction(store, { likes: 99, likedBy: ["owner"] }));
    await assertFails(
      reaction(store, {
        likes: 2,
        likedBy: ["owner", "reader"],
        content: "Tampered",
      }),
    );
    await assertSucceeds(
      updateDoc(doc(store, "posts/post"), {
        content: "Edited by owner",
        updatedAt: serverTimestamp(),
      }),
    );
    await assertSucceeds(react(store, "owner", false));
  },
);
run("new posts cannot start with forged reactions", async () => {
  const store = db("owner");
  const base = { communityId: "A", authorId: "owner", content: "New post" };
  await assertSucceeds(
    setDoc(doc(store, "posts/new"), { ...base, likes: 0, likedBy: [] }),
  );
  await assertFails(
    setDoc(doc(store, "posts/forged"), {
      ...base,
      likes: 1,
      likedBy: ["reader"],
    }),
  );
});
run(
  "missing legacy reaction fields initialize safely; corrupt counters fail closed",
  async () => {
    await env.withSecurityRulesDisabled((ctx) =>
      setDoc(doc(ctx.firestore(), "posts/post"), {
        communityId: "A",
        authorId: "owner",
        status: "active",
        comments: 0,
      }),
    );
    await assertSucceeds(react(db("reader"), "reader", true));
    await env.withSecurityRulesDisabled((ctx) =>
      updateDoc(doc(ctx.firestore(), "posts/post"), { likes: 8 }),
    );
    await assertFails(
      reaction(db("peer"), { likes: 2, likedBy: ["reader", "peer"] }),
    );
  },
);
run("comment atomicity is preserved after reacting", async () => {
  await assertSucceeds(react(db("reader"), "reader", true));
  await assertSucceeds(comment(db("reader")));
  const post = (await getDoc(doc(db("reader"), "posts/post"))).data();
  assert.equal(post.likes, 1);
  assert.deepEqual(post.likedBy, ["reader"]);
  assert.equal(post.comments, 1);
});
run("simultaneous duplicate actions retain one reaction", async () => {
  await Promise.all([
    react(db("reader"), "reader", true),
    react(db("reader"), "reader", true),
  ]);
  let post = (await getDoc(doc(db("reader"), "posts/post"))).data();
  assert.equal(post.likes, 1);
  assert.deepEqual(post.likedBy, ["reader"]);
  await Promise.all([
    react(db("reader"), "reader", false),
    react(db("reader"), "reader", false),
  ]);
  post = (await getDoc(doc(db("reader"), "posts/post"))).data();
  assert.equal(post.likes, 0);
  assert.deepEqual(post.likedBy, []);
});
