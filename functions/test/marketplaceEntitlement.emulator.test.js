const test = require("node:test");
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
  query,
  where,
  updateDoc,
  deleteDoc,
  serverTimestamp,
  Timestamp,
} = require("firebase/firestore");
const { storageRulesDirectory } = require("./helpers/storage_rules_variant");
const enabled = !!process.env.FIRESTORE_EMULATOR_HOST;
const phone = "+639170000000";
let env;
const db = (uid = "owner", claims = {}) =>
  uid
    ? env
        .authenticatedContext(uid, {
          phone_number: phone,
          firebase: { sign_in_provider: "phone" },
          ...claims,
        })
        .firestore()
    : env.unauthenticatedContext().firestore();
const run = (name, fn) => test(name, { skip: !enabled }, fn);
const listing = (patch = {}) => ({
  communityId: "A",
  buildingId: "building",
  sellerId: "owner",
  title: "Chair",
  status: "active",
  images: [],
  ...patch,
});
async function subscription(data) {
  await env.withSecurityRulesDisabled(async (ctx) => {
    const ref = doc(ctx.firestore(), "subscriptions/A");
    if (data) await setDoc(ref, data);
    else await deleteDoc(ref);
  });
}
test.before(async () => {
  if (!enabled) return;
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
    for (const id of ["A", "B"])
      await setDoc(doc(store, "communities", id), { isActive: true });
    await setDoc(doc(store, "buildings/building"), { communityId: "A" });
    await setDoc(doc(store, "buildings/foreign"), { communityId: "B" });
    for (const [uid, communityId, buildingId] of [
      ["owner", "A", "building"],
      ["peer", "A", "building"],
      ["foreign", "B", "foreign"],
    ]) {
      await setDoc(doc(store, "users", uid), {
        uid,
        phoneNumber: phone,
        role: "resident",
        isActive: true,
        approvalStatus: "approved",
        status: "active",
        residentType: "owner",
        ownershipType: "owner",
        identityVerificationStatus: "not_required",
        communityId,
        buildingId,
      });
    }
    await setDoc(doc(store, "admins/admin"), {
      uid: "admin",
      phoneNumber: phone,
      role: "admin",
      isActive: true,
      authorizedCommunityIds: ["A"],
    });
    await setDoc(doc(store, "subscriptions/A"), {
      planId: "plus",
      status: "active",
      endsAt: null,
    });
    await setDoc(doc(store, "subscriptions/B"), {
      planId: "pro",
      status: "active",
    });
    for (const name of ["marketplaces", "listings", "marketplace"])
      await setDoc(doc(store, name, "listing"), listing());
    await setDoc(doc(store, "marketplaces/listing/requests/request"), {
      requesterId: "peer",
      status: "pending",
    });
  });
});
for (const plan of ["essential", "plus", "pro"]) {
  run(
    `${plan}: canonical browse/create/edit/sold/delete follow plan`,
    async () => {
      await subscription({
        planId: plan,
        status: "active",
        endsAt: null,
        features: { marketplace: true },
      });
      const check = plan === "essential" ? assertFails : assertSucceeds;
      const store = db();
      await check(getDoc(doc(store, "marketplaces/listing")));
      await check(
        getDocs(
          query(
            collection(store, "marketplaces"),
            where("buildingId", "==", "building"),
            where("status", "==", "active"),
          ),
        ),
      );
      await check(setDoc(doc(store, "marketplaces/new"), listing()));
      await check(
        updateDoc(doc(store, "marketplaces/listing"), { title: "Updated" }),
      );
      await check(
        updateDoc(doc(store, "marketplaces/listing"), {
          status: "sold",
          updatedAt: serverTimestamp(),
        }),
      );
      await check(deleteDoc(doc(store, "marketplaces/listing")));
    },
  );
}
run(
  "stale authenticated Pro session loses access immediately after Essential downgrade",
  async () => {
    const store = db();
    await assertSucceeds(getDoc(doc(store, "marketplaces/listing")));
    await subscription({ planId: "essential", status: "active" });
    await assertFails(getDoc(doc(store, "marketplaces/listing")));
    await assertFails(
      updateDoc(doc(store, "marketplaces/listing"), { status: "sold" }),
    );
  },
);
for (const [name, value] of [
  ["missing", null],
  ["expired", { planId: "pro", status: "expired" }],
  ["inactive", { planId: "pro", status: "suspended" }],
  [
    "past end",
    { planId: "pro", status: "active", endsAt: Timestamp.fromMillis(1) },
  ],
  [
    "future start",
    {
      planId: "pro",
      status: "active",
      startsAt: Timestamp.fromMillis(4102444800000),
    },
  ],
  [
    "malformed start",
    { planId: "pro", status: "active", startsAt: "yesterday" },
  ],
  ["malformed end", { planId: "pro", status: "active", endsAt: "tomorrow" }],
  ["unbounded trial", { planId: "pro", status: "trial" }],
  ["unbounded grace", { planId: "plus", status: "grace" }],
  ["unknown plan", { planId: "custom", status: "active" }],
])
  run(`${name} subscription denies reads and sold writes`, async () => {
    await subscription(value);
    await assertFails(getDoc(doc(db(), "marketplaces/listing")));
    await assertFails(
      updateDoc(doc(db(), "marketplaces/listing"), { status: "sold" }),
    );
  });
for (const status of ["trial", "grace"])
  run(`bounded ${status} Plus access remains available`, async () => {
    await subscription({
      planId: "plus",
      status,
      endsAt: Timestamp.fromMillis(4102444800000),
    });
    await assertSucceeds(getDoc(doc(db(), "marketplaces/listing")));
  });
run(
  "foreign community, unauthenticated and phone mismatch cannot read or write",
  async () => {
    for (const store of [
      db("foreign"),
      db(null),
      db("owner", { phone_number: "+639170000001" }),
    ]) {
      await assertFails(getDoc(doc(store, "marketplaces/listing")));
      await assertFails(setDoc(doc(store, "marketplaces/new"), listing()));
      await assertFails(
        updateDoc(doc(store, "marketplaces/listing"), { status: "sold" }),
      );
      await assertFails(deleteDoc(doc(store, "marketplaces/listing")));
    }
  },
);
run(
  "Plus cannot impersonate a seller or modify another seller listing",
  async () => {
    await assertFails(setDoc(doc(db("peer"), "marketplaces/new"), listing()));
    await assertFails(
      updateDoc(doc(db("peer"), "marketplaces/listing"), { status: "sold" }),
    );
    await assertFails(deleteDoc(doc(db("peer"), "marketplaces/listing")));
    await assertFails(
      updateDoc(doc(db(), "marketplaces/listing"), { communityId: "B" }),
    );
  },
);
for (const collectionName of ["listings", "marketplace"])
  run(`Essential cannot bypass via legacy ${collectionName}`, async () => {
    await subscription({ planId: "essential", status: "active" });
    const ref = doc(db(), collectionName, "listing");
    await assertFails(getDoc(ref));
    await assertFails(setDoc(doc(db(), collectionName, "new"), listing()));
    await assertFails(updateDoc(ref, { status: "sold" }));
    await assertFails(deleteDoc(ref));
  });
run(
  "Essential cannot request or access Marketplace contact details",
  async () => {
    await subscription({ planId: "essential", status: "active" });
    await assertFails(
      getDoc(doc(db("peer"), "marketplaces/listing/requests/request")),
    );
    await assertFails(
      setDoc(doc(db("peer"), "marketplaces/listing/requests/new"), {
        requesterId: "peer",
        status: "pending",
      }),
    );
    await assertFails(
      updateDoc(doc(db(), "marketplaces/listing/requests/request"), {
        status: "accepted",
      }),
    );
    await assertFails(
      setDoc(doc(db("peer"), "marketplaceRequests/new"), {
        communityId: "A",
        productId: "listing",
        productOwnerId: "owner",
        requestUserId: "peer",
        status: "pending",
      }),
    );
  },
);
run("Plus contact requests and seller responses still work", async () => {
  await assertSucceeds(
    setDoc(doc(db("peer"), "marketplaces/listing/requests/new"), {
      requesterId: "peer",
      status: "pending",
    }),
  );
  await assertSucceeds(
    getDoc(doc(db("peer"), "marketplaces/listing/requests/new")),
  );
  await assertSucceeds(
    updateDoc(doc(db(), "marketplaces/listing/requests/new"), {
      status: "accepted",
    }),
  );
});

run(
  "Essential restriction preserves scoped Admin Marketplace reads",
  async () => {
    await subscription({ planId: "essential", status: "active" });
    for (const name of ["marketplaces", "listings", "marketplace"]) {
      await assertSucceeds(getDoc(doc(db("admin"), name, "listing")));
    }
  },
);
run(
  "Plus top-level phone requests retain participant access and tenant checks",
  async () => {
    const data = {
      communityId: "A",
      productId: "listing",
      productOwnerId: "owner",
      requestUserId: "peer",
      status: "pending",
    };
    await assertSucceeds(
      setDoc(doc(db("peer"), "marketplaceRequests/new"), data),
    );
    await assertSucceeds(getDoc(doc(db(), "marketplaceRequests/new")));
    await assertSucceeds(
      updateDoc(doc(db(), "marketplaceRequests/new"), { status: "accepted" }),
    );
    await assertFails(getDoc(doc(db("foreign"), "marketplaceRequests/new")));
    await subscription({ planId: "essential", status: "active" });
    await assertFails(getDoc(doc(db(), "marketplaceRequests/new")));
    await assertFails(
      updateDoc(doc(db(), "marketplaceRequests/new"), { status: "accepted" }),
    );
  },
);
