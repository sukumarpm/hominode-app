const test = require("node:test");
const assert = require("node:assert/strict");
const {
  canonicalResidentType,
  identityVerificationRequired,
  operationalAccessFailure,
  resolveFlatOccupant,
  verificationStatus,
  approveResidentRegistrationCore,
  submitResidentIdentityProofCore,
  moveOutResidentCore,
  reviewResidentIdentityProofCore,
} = require("../src/resident_identity");

const community = (overrides = {}) => ({id: "A", isActive: true, ...overrides});
const profile = (overrides = {}) => ({
  role: "resident",
  approvalStatus: "approved",
  isActive: true,
  communityId: "A",
  residentType: "owner",
  ownershipType: "owner",
  identityVerified: false,
  identityVerificationStatus: "not_required",
  ...overrides,
});

test("owner without proof proceeds when owner verification is optional", () => {
  assert.equal(identityVerificationRequired("owner", community()), false);
  assert.equal(operationalAccessFailure(profile(), community()), null);
});

test("owner proof can be explicitly required by community configuration", () => {
  const configured = community({ownerIdentityVerificationRequired: true});
  assert.equal(identityVerificationRequired("owner", configured), true);
  assert.equal(
    operationalAccessFailure(profile({identityVerificationStatus: "verification_required"}), configured),
    "identity-verification-required",
  );
});

test("tenant remains restricted for required, pending, and rejected proof states", () => {
  for (const status of ["verification_required", "pending", "rejected"]) {
    assert.equal(
      operationalAccessFailure(profile({residentType: "tenant", ownershipType: "tenant", identityVerificationStatus: status}), community()),
      "identity-verification-required",
    );
  }
});

test("only a verified tenant can use operational features", () => {
  assert.equal(
    operationalAccessFailure(profile({residentType: "tenant", ownershipType: "tenant", identityVerified: true, identityVerificationStatus: "verified"}), community()),
    null,
  );
  assert.equal(
    operationalAccessFailure(profile({residentType: "tenant", ownershipType: "tenant", identityVerified: true, identityVerificationStatus: "pending"}), community()),
    "identity-verification-required",
  );
});

test("wrong-community, inactive, pending, and ambiguous profiles fail closed", () => {
  assert.equal(operationalAccessFailure(profile(), community({id: "B"})), "wrong-community");
  assert.equal(operationalAccessFailure(profile({isActive: false}), community()), "inactive");
  assert.equal(operationalAccessFailure(profile({status: "inactive"}), community()), "inactive");
  assert.equal(operationalAccessFailure(profile({approvalStatus: "pending"}), community()), "not-approved");
  assert.equal(operationalAccessFailure(profile({residentType: "owner", ownershipType: "tenant"}), community()), "resident-type-ambiguous");
});

test("bulk owner and tenant types remain canonical and imports are not auto-verified", () => {
  assert.equal(canonicalResidentType({residentType: "owner", ownershipType: "owner"}), "owner");
  assert.equal(canonicalResidentType({residentType: "tenant", ownershipType: "tenant"}), "tenant");
  assert.equal(verificationStatus({identityVerified: false}), "verification_required");
});

function phoneAuth(uid) {
  return {uid, token: {phone_number: "+639171100000", firebase: {sign_in_provider: "phone"}}};
}

function fakeDb(seed, {onUpdate} = {}) {
  const values = new Map(Object.entries(seed));
  const applyChanges = (path, changes) => {
    const next = {...values.get(path)};
    for (const [field, value] of Object.entries(changes)) {
      if (value?.constructor?.name === "DeleteTransform") delete next[field];
      else next[field] = value;
    }
    values.set(path, next);
  };
  const snapshot = (path) => ({
    id: path.split("/").pop(),
    exists: values.has(path),
    data: () => values.get(path),
  });
  const ref = (path) => ({
    _path: path,
    id: path.split("/").pop(),
    get: async () => snapshot(path),
    update: async (changes) => {
      if (onUpdate) await onUpdate(path, changes);
      applyChanges(path, changes);
    },
  });
  const query = (collection, clauses = []) => ({
    _query: true,
    collection,
    clauses,
    where(field, _operator, expected) {
      return query(collection, [...clauses, {field, expected}]);
    },
  });
  const querySnapshot = (value) => ({
    docs: [...values.entries()]
      .filter(([path, data]) => path.startsWith(`${value.collection}/`) &&
        !path.slice(value.collection.length + 1).includes("/") &&
        value.clauses.every(({field, expected}) => data[field] === expected))
      .map(([path]) => snapshot(path)),
  });
  return {
    values,
    collection(name) {
      return {...query(name), doc: (id) => ref(`${name}/${id}`)};
    },
    async runTransaction(action) {
      const pendingUpdates = [];
      const result = await action({
        get: async (target) => target._query ? querySnapshot(target) : snapshot(target._path),
        update(target, changes) {
          pendingUpdates.push({target, changes});
        },
      });
      for (const {target, changes} of pendingUpdates) {
        if (onUpdate) await onUpdate(target._path, changes);
        applyChanges(target._path, changes);
      }
      return result;
    },
  };
}

const approvalSeed = (residentOverrides = {}, extras = {}) => ({
  "admins/admin-a": {uid: "admin-a", role: "admin", isActive: true, authorizedCommunityIds: ["A"]},
  "communities/A": {isActive: true},
  "buildings/building-a": {communityId: "A", name: "Ivory"},
  "flats/flat-a": {communityId: "A", buildingId: "building-a", flatId: "I002", status: "vacant"},
  "users/resident-a": {
    role: "resident",
    communityId: "A",
    approvalStatus: "pending",
    isActive: false,
    declaredResidentType: "owner",
    identityVerified: false,
    identityVerificationStatus: "verification_required",
    ...residentOverrides,
  },
  ...extras,
});

const approvalData = (residentType) => ({
  communityId: "A",
  userId: "resident-a",
  buildingId: "building-a",
  flatId: "flat-a",
  residentType,
});

const activeOccupant = (residentType, overrides = {}) => ({
  role: "resident",
  communityId: "A",
  buildingId: "building-a",
  flatId: "flat-a",
  residentType,
  ownershipType: residentType,
  approvalStatus: "approved",
  isActive: true,
  status: "active",
  occupancyStatus: "current",
  identityVerified: residentType === "tenant",
  identityVerificationStatus: residentType === "tenant" ? "verified" : "not_required",
  ...overrides,
});

test("trusted approval activates optional-proof owner and blocks unverified tenant approval", async () => {
  const ownerDb = fakeDb(approvalSeed());
  const owner = await approveResidentRegistrationCore({db: ownerDb, auth: phoneAuth("admin-a"), data: approvalData("owner")});
  assert.equal(owner.isActive, true);
  assert.equal(ownerDb.values.get("users/resident-a").identityVerificationStatus, "not_required");

  const tenantDb = fakeDb(approvalSeed({declaredResidentType: "tenant"}));
  await assert.rejects(
    () => approveResidentRegistrationCore({db: tenantDb, auth: phoneAuth("admin-a"), data: approvalData("tenant")}),
    {code: "failed-precondition"},
  );
});

test("approval cannot change the persisted registered resident type", async () => {
  const db = fakeDb(approvalSeed({
    declaredResidentType: "tenant",
    identityVerified: true,
    identityVerificationStatus: "verified",
  }));
  await assert.rejects(
    () => approveResidentRegistrationCore({
      db,
      auth: phoneAuth("admin-a"),
      data: approvalData("owner"),
    }),
    (error) => error.code === "failed-precondition" &&
      /registered resident type/.test(error.message),
  );
});

test("empty flat allows a verified tenant approval", async () => {
  const db = fakeDb(approvalSeed({
    declaredResidentType: "tenant",
    identityVerified: true,
    identityVerificationStatus: "verified",
  }));
  const result = await approveResidentRegistrationCore({
    db,
    auth: phoneAuth("admin-a"),
    data: approvalData("tenant"),
  });
  assert.equal(result.status, "approved");
  assert.equal(db.values.get("users/resident-a").isActive, true);
  assert.equal(db.values.get("flats/flat-a").residentUserId, "resident-a");
});

test("trusted approval prevents an active duplicate owner and cross-community requests", async () => {
  const duplicateDb = fakeDb(approvalSeed({}, {
    "users/other-owner": activeOccupant("owner"),
  }));
  await assert.rejects(
    () => approveResidentRegistrationCore({db: duplicateDb, auth: phoneAuth("admin-a"), data: approvalData("owner")}),
    {code: "failed-precondition"},
  );
  await assert.rejects(
    () => approveResidentRegistrationCore({db: fakeDb(approvalSeed()), auth: phoneAuth("admin-a"), data: {...approvalData("owner"), communityId: "B"}}),
    {code: "permission-denied"},
  );
});

test("all owner and tenant combinations reject a second active occupant", async () => {
  for (const [existingType, candidateType] of [
    ["owner", "owner"],
    ["owner", "tenant"],
    ["tenant", "owner"],
    ["tenant", "tenant"],
  ]) {
    const candidate = {
      declaredResidentType: candidateType,
      ...(candidateType === "tenant"
        ? {identityVerified: true, identityVerificationStatus: "verified"}
        : {}),
    };
    const db = fakeDb(approvalSeed(candidate, {
      "flats/flat-a": {
        communityId: "A",
        buildingId: "building-a",
        status: "occupied",
        residentUserId: "current-resident",
      },
      "users/current-resident": activeOccupant(existingType),
    }));
    await assert.rejects(
      () => approveResidentRegistrationCore({
        db,
        auth: phoneAuth("admin-a"),
        data: approvalData(candidateType),
      }),
      (error) => error.code === "failed-precondition" &&
        /active resident occupant/.test(error.message),
    );
  }
});

test("legacy occupant aliases reconcile safely and conflicts fail closed", async () => {
  assert.equal(resolveFlatOccupant({residentUid: "resident-a"}).uid, "resident-a");
  assert.equal(resolveFlatOccupant({residentUserId: "resident-a", residentUid: "resident-a"}).uid, "resident-a");
  assert.throws(
    () => resolveFlatOccupant({residentUserId: "resident-a", residentUid: "resident-b"}),
    {code: "failed-precondition"},
  );

  for (const flatAliases of [
    {residentUid: "resident-a"},
    {residentUserId: "resident-a", residentUid: "resident-a"},
    {residentIds: ["resident-a"]},
  ]) {
    const db = fakeDb(approvalSeed({}, {
      "flats/flat-a": {
        communityId: "A",
        buildingId: "building-a",
        status: "occupied",
        ...flatAliases,
      },
    }));
    await approveResidentRegistrationCore({
      db,
      auth: phoneAuth("admin-a"),
      data: approvalData("owner"),
    });
    const flat = db.values.get("flats/flat-a");
    assert.equal(flat.residentUserId, "resident-a");
    assert.equal("residentUid" in flat, false);
    assert.equal("residentIds" in flat, false);
  }

  const conflictDb = fakeDb(approvalSeed({}, {
    "flats/flat-a": {
      communityId: "A",
      buildingId: "building-a",
      status: "occupied",
      residentUserId: "resident-a",
      residentUid: "resident-b",
    },
  }));
  await assert.rejects(
    () => approveResidentRegistrationCore({
      db: conflictDb,
      auth: phoneAuth("admin-a"),
      data: approvalData("owner"),
    }),
    {code: "failed-precondition"},
  );
});

test("inactive stale occupant is reconciled but ambiguous stale data is rejected", async () => {
  const staleDb = fakeDb(approvalSeed({}, {
    "flats/flat-a": {
      communityId: "A",
      buildingId: "building-a",
      status: "occupied",
      residentUid: "old-resident",
    },
    "users/old-resident": activeOccupant("owner", {isActive: false, status: "inactive"}),
  }));
  await approveResidentRegistrationCore({
    db: staleDb,
    auth: phoneAuth("admin-a"),
    data: approvalData("owner"),
  });
  assert.equal(staleDb.values.get("flats/flat-a").residentUserId, "resident-a");

  const ambiguousDb = fakeDb(approvalSeed({}, {
    "flats/flat-a": {
      communityId: "A",
      buildingId: "building-a",
      status: "occupied",
      residentUserId: "old-resident",
    },
    "users/old-resident": activeOccupant("owner", {flatId: "different-flat", isActive: false}),
  }));
  await assert.rejects(
    () => approveResidentRegistrationCore({
      db: ambiguousDb,
      auth: phoneAuth("admin-a"),
      data: approvalData("owner"),
    }),
    {code: "failed-precondition"},
  );
});

test("unauthorized Admin and inactive community are rejected", async () => {
  await assert.rejects(
    () => approveResidentRegistrationCore({
      db: fakeDb(approvalSeed()),
      auth: phoneAuth("unknown-admin"),
      data: approvalData("owner"),
    }),
    {code: "permission-denied"},
  );
  const inactiveDb = fakeDb(approvalSeed({}, {"communities/A": {isActive: false}}));
  await assert.rejects(
    () => approveResidentRegistrationCore({
      db: inactiveDb,
      auth: phoneAuth("admin-a"),
      data: approvalData("owner"),
    }),
    {code: "failed-precondition"},
  );
});

test("bulk-import claimed tenant follows verification and occupancy approval rules", async () => {
  const db = fakeDb(approvalSeed({
    creationSource: "admin_bulk_import_claim",
    declaredResidentType: "tenant",
    residentType: "tenant",
    ownershipType: "tenant",
    identityVerified: true,
    identityVerificationStatus: "verified",
  }, {
    "flats/flat-a": {
      communityId: "A",
      buildingId: "building-a",
      status: "occupied",
      residentUserId: "current-resident",
    },
    "users/current-resident": activeOccupant("owner"),
  }));
  await assert.rejects(
    () => approveResidentRegistrationCore({
      db,
      auth: phoneAuth("admin-a"),
      data: approvalData("tenant"),
    }),
    {code: "failed-precondition"},
  );
});

test("tenant can upload and re-upload proof while operational access stays restricted", async () => {
  const db = fakeDb({
    "communities/A": {isActive: true},
    "users/tenant-a": {
      role: "resident",
      communityId: "A",
      phoneNumber: "+639171100000",
      residentType: "tenant",
      ownershipType: "tenant",
      approvalStatus: "pending",
      isActive: false,
      identityVerified: false,
      identityVerificationStatus: "rejected",
    },
  });
  const saved = [];
  const bucket = {
    file: (path) => ({save: async (bytes, options) => saved.push({path, bytes, options})}),
  };
  const result = await submitResidentIdentityProofCore({
    db,
    bucket,
    auth: phoneAuth("tenant-a"),
    data: {contentType: "image/png", base64: Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, 1]).toString("base64")},
  });
  assert.equal(result.status, "pending");
  assert.equal(saved.length, 1);
  const tenant = db.values.get("users/tenant-a");
  assert.equal(tenant.identityVerificationStatus, "pending");
  assert.equal(tenant.identityVerified, false);
  assert.match(tenant.identityProofStoragePath, /^residentIdentityProofs\/A\/tenant-a\//);
});

test("replacement upload preserves the new proof and cleans up only the previous owned path", async () => {
  const oldPath = "residentIdentityProofs/A/tenant-a/old.png";
  const events = [];
  const db = fakeDb({
    "communities/A": {isActive: true},
    "users/tenant-a": {
      role: "resident",
      communityId: "A",
      phoneNumber: "+639171100000",
      residentType: "tenant",
      ownershipType: "tenant",
      approvalStatus: "pending",
      isActive: false,
      identityVerified: false,
      identityVerificationStatus: "rejected",
      identityProofStoragePath: oldPath,
    },
  }, {onUpdate: async () => events.push("update")});
  const bucket = {
    file: (path) => ({
      save: async () => events.push(`save:${path}`),
      delete: async () => events.push(`delete:${path}`),
    }),
  };

  await submitResidentIdentityProofCore({
    db,
    bucket,
    auth: phoneAuth("tenant-a"),
    data: {contentType: "image/png", base64: Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, 1]).toString("base64")},
  });

  const newPath = db.values.get("users/tenant-a").identityProofStoragePath;
  assert.notEqual(newPath, oldPath);
  assert.match(newPath, /^residentIdentityProofs\/A\/tenant-a\/[^/]+\.png$/);
  assert.deepEqual(events.slice(1), ["update", `delete:${oldPath}`]);
});

test("replacement cleanup never deletes an arbitrary or cross-resident path", async () => {
  for (const previousPath of [
    "residentIdentityProofs/A/other-resident/old.png",
    "residentIdentityProofs/A/tenant-a/nested/old.png",
    "unrelated/private-object.png",
  ]) {
    const deleted = [];
    const db = fakeDb({
      "communities/A": {isActive: true},
      "users/tenant-a": {
        role: "resident",
        communityId: "A",
        phoneNumber: "+639171100000",
        residentType: "tenant",
        ownershipType: "tenant",
        approvalStatus: "pending",
        isActive: false,
        identityVerified: false,
        identityVerificationStatus: "rejected",
        identityProofStoragePath: previousPath,
      },
    });
    const bucket = {
      file: () => ({save: async () => {}, delete: async () => deleted.push(previousPath)}),
    };
    await submitResidentIdentityProofCore({
      db,
      bucket,
      auth: phoneAuth("tenant-a"),
      data: {contentType: "image/png", base64: Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, 1]).toString("base64")},
    });
    assert.deepEqual(deleted, []);
  }
});

test("failed old-proof cleanup does not lose the newly submitted proof", async () => {
  const oldPath = "residentIdentityProofs/A/tenant-a/old.png";
  const db = fakeDb({
    "communities/A": {isActive: true},
    "users/tenant-a": {
      role: "resident",
      communityId: "A",
      phoneNumber: "+639171100000",
      residentType: "tenant",
      ownershipType: "tenant",
      approvalStatus: "pending",
      isActive: false,
      identityVerified: false,
      identityVerificationStatus: "rejected",
      identityProofStoragePath: oldPath,
    },
  });
  const bucket = {
    file: () => ({save: async () => {}, delete: async () => { throw new Error("cleanup failed"); }}),
  };
  const result = await submitResidentIdentityProofCore({
    db,
    bucket,
    auth: phoneAuth("tenant-a"),
    data: {contentType: "image/png", base64: Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, 1]).toString("base64")},
  });
  assert.equal(result.status, "pending");
  assert.notEqual(db.values.get("users/tenant-a").identityProofStoragePath, oldPath);
});

test("previous proof is retained when the Firestore replacement commit fails", async () => {
  const oldPath = "residentIdentityProofs/A/tenant-a/old.png";
  const saved = [];
  const deleted = [];
  const db = fakeDb({
    "communities/A": {isActive: true},
    "users/tenant-a": {
      role: "resident",
      communityId: "A",
      phoneNumber: "+639171100000",
      residentType: "tenant",
      ownershipType: "tenant",
      approvalStatus: "pending",
      isActive: false,
      identityVerified: false,
      identityVerificationStatus: "rejected",
      identityProofStoragePath: oldPath,
    },
  }, {onUpdate: async () => { throw new Error("commit failed"); }});
  const bucket = {
    file: (path) => ({
      save: async () => saved.push(path),
      delete: async () => deleted.push(path),
    }),
  };
  await assert.rejects(() => submitResidentIdentityProofCore({
    db,
    bucket,
    auth: phoneAuth("tenant-a"),
    data: {contentType: "image/png", base64: Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, 1]).toString("base64")},
  }), /commit failed/);
  assert.equal(saved.length, 1);
  assert.deepEqual(deleted, []);
  assert.equal(db.values.get("users/tenant-a").identityProofStoragePath, oldPath);
});

test("pending resident can still submit proof", async () => {
  const db = fakeDb({
    "communities/A": {isActive: true},
    "users/tenant-a": {
      role: "resident",
      communityId: "A",
      phoneNumber: "+639171100000",
      residentType: "tenant",
      ownershipType: "tenant",
      approvalStatus: "pending",
      isActive: false,
      identityVerified: false,
      identityVerificationStatus: "pending",
    },
  });
  const result = await submitResidentIdentityProofCore({
    db,
    bucket: {file: () => ({save: async () => {}})},
    auth: phoneAuth("tenant-a"),
    data: {contentType: "image/png", base64: Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, 1]).toString("base64")},
  });
  assert.equal(result.status, "pending");
});

test("verified resident cannot use the standard proof upload flow", async () => {
  let uploaded = false;
  const db = fakeDb({
    "users/tenant-a": {
      role: "resident",
      communityId: "A",
      phoneNumber: "+639171100000",
      residentType: "tenant",
      ownershipType: "tenant",
      approvalStatus: "approved",
      isActive: true,
      identityVerified: true,
      identityVerificationStatus: "verified",
    },
  });
  await assert.rejects(
    () => submitResidentIdentityProofCore({
      db,
      bucket: {file: () => ({save: async () => { uploaded = true; }})},
      auth: phoneAuth("tenant-a"),
      data: {contentType: "image/png", base64: Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, 1]).toString("base64")},
    }),
    {code: "failed-precondition"},
  );
  assert.equal(uploaded, false);
});

test("trusted tenant move-out deactivates the resident and vacates only the matching unit", async () => {
  const db = fakeDb({
    "admins/admin-a": {uid: "admin-a", role: "admin", isActive: true, authorizedCommunityIds: ["A"]},
    "communities/A": {isActive: true},
    "buildings/building-a": {communityId: "A", name: "Ivory"},
    "users/tenant-a": {
      role: "resident",
      communityId: "A",
      residentType: "tenant",
      ownershipType: "tenant",
      approvalStatus: "approved",
      isActive: true,
      status: "active",
      occupancyStatus: "current",
      buildingId: "building-a",
      flatId: "flat-a",
    },
    "flats/flat-a": {
      communityId: "A",
      buildingId: "building-a",
      residentUserId: "tenant-a",
      status: "occupied",
    },
  });
  const result = await moveOutResidentCore({
    db,
    auth: phoneAuth("admin-a"),
    data: {communityId: "A", userId: "tenant-a"},
  });
  assert.equal(result.status, "moved_out");
  assert.equal(db.values.get("users/tenant-a").status, "inactive");
  assert.equal(db.values.get("users/tenant-a").isActive, false);
  assert.equal(db.values.get("users/tenant-a").occupancyStatus, "moved_out");
  assert.equal(db.values.get("flats/flat-a").status, "vacant");
  assert.equal(db.values.get("flats/flat-a").residentUserId, null);
});

test("move-out preserves another resident's occupant reference", async () => {
  const db = fakeDb({
    "admins/admin-a": {uid: "admin-a", role: "admin", isActive: true, authorizedCommunityIds: ["A"]},
    "communities/A": {isActive: true},
    "buildings/building-a": {communityId: "A"},
    "users/tenant-a": activeOccupant("tenant"),
    "flats/flat-a": {
      communityId: "A",
      buildingId: "building-a",
      residentUserId: "other-resident",
      status: "occupied",
    },
  });
  const result = await moveOutResidentCore({
    db,
    auth: phoneAuth("admin-a"),
    data: {communityId: "A", userId: "tenant-a"},
  });
  assert.equal(result.occupantCleared, false);
  assert.equal(db.values.get("users/tenant-a").isActive, false);
  assert.equal(db.values.get("flats/flat-a").residentUserId, "other-resident");
  assert.equal(db.values.get("flats/flat-a").status, "occupied");
});

test("move-out accepts matching legacy aliases and rejects conflicts", async () => {
  for (const aliases of [
    {residentUid: "tenant-a"},
    {residentUserId: "tenant-a", residentUid: "tenant-a"},
  ]) {
    const db = fakeDb({
      "admins/admin-a": {uid: "admin-a", role: "admin", isActive: true, authorizedCommunityIds: ["A"]},
      "communities/A": {isActive: true},
      "buildings/building-a": {communityId: "A"},
      "users/tenant-a": activeOccupant("tenant"),
      "flats/flat-a": {
        communityId: "A",
        buildingId: "building-a",
        status: "occupied",
        ...aliases,
      },
    });
    const result = await moveOutResidentCore({
      db,
      auth: phoneAuth("admin-a"),
      data: {communityId: "A", userId: "tenant-a"},
    });
    assert.equal(result.occupantCleared, true);
    assert.equal(db.values.get("flats/flat-a").residentUserId, null);
    assert.equal("residentUid" in db.values.get("flats/flat-a"), false);
  }

  const conflictDb = fakeDb({
    "admins/admin-a": {uid: "admin-a", role: "admin", isActive: true, authorizedCommunityIds: ["A"]},
    "communities/A": {isActive: true},
    "buildings/building-a": {communityId: "A"},
    "users/tenant-a": activeOccupant("tenant"),
    "flats/flat-a": {
      communityId: "A",
      buildingId: "building-a",
      residentUserId: "tenant-a",
      residentUid: "other-resident",
      status: "occupied",
    },
  });
  await assert.rejects(
    () => moveOutResidentCore({
      db: conflictDb,
      auth: phoneAuth("admin-a"),
      data: {communityId: "A", userId: "tenant-a"},
    }),
    {code: "failed-precondition"},
  );
  assert.equal(conflictDb.values.get("users/tenant-a").isActive, true);
});

test("a new resident can be approved after the prior occupant properly moves out", async () => {
  const db = fakeDb({
    "admins/admin-a": {uid: "admin-a", role: "admin", isActive: true, authorizedCommunityIds: ["A"]},
    "communities/A": {isActive: true},
    "buildings/building-a": {communityId: "A", name: "Ivory"},
    "users/old-resident": activeOccupant("owner"),
    "flats/flat-a": {
      communityId: "A",
      buildingId: "building-a",
      residentUserId: "old-resident",
      status: "occupied",
    },
  });
  await moveOutResidentCore({
    db,
    auth: phoneAuth("admin-a"),
    data: {communityId: "A", userId: "old-resident"},
  });
  db.values.set("users/resident-a", {
    role: "resident",
    communityId: "A",
    approvalStatus: "pending",
    isActive: false,
    declaredResidentType: "owner",
    identityVerified: false,
    identityVerificationStatus: "verification_required",
  });
  const approval = await approveResidentRegistrationCore({
    db,
    auth: phoneAuth("admin-a"),
    data: approvalData("owner"),
  });
  assert.equal(approval.status, "approved");
  assert.equal(db.values.get("flats/flat-a").residentUserId, "resident-a");
  assert.equal(db.values.get("users/old-resident").occupancyStatus, "moved_out");
});

test("normal declared tenant can be proof-verified before canonical Admin approval", async () => {
  const db = fakeDb(approvalSeed({
    declaredResidentType: "tenant",
    identityVerificationStatus: "pending",
    identityProofStoragePath: "residentIdentityProofs/A/resident-a/proof.png",
  }));
  await reviewResidentIdentityProofCore({
    db,
    auth: phoneAuth("admin-a"),
    data: {communityId: "A", userId: "resident-a", decision: "verified"},
  });
  assert.equal(db.values.get("users/resident-a").identityVerified, true);
  assert.equal(db.values.get("users/resident-a").isActive, false);

  const approval = await approveResidentRegistrationCore({
    db,
    auth: phoneAuth("admin-a"),
    data: approvalData("tenant"),
  });
  assert.equal(approval.isActive, true);
  assert.equal(db.values.get("users/resident-a").residentType, "tenant");
});

test("identity review cannot reactivate an approved resident assigned to another occupant", async () => {
  const db = fakeDb({
    "admins/admin-a": {uid: "admin-a", role: "admin", isActive: true, authorizedCommunityIds: ["A"]},
    "communities/A": {isActive: true},
    "buildings/building-a": {communityId: "A"},
    "users/tenant-a": {
      ...activeOccupant("tenant"),
      isActive: false,
      status: "inactive",
      identityVerified: false,
      identityVerificationStatus: "pending",
      identityProofStoragePath: "residentIdentityProofs/A/tenant-a/proof.png",
    },
    "flats/flat-a": {
      communityId: "A",
      buildingId: "building-a",
      status: "occupied",
      residentUserId: "other-resident",
    },
  });
  await reviewResidentIdentityProofCore({
    db,
    auth: phoneAuth("admin-a"),
    data: {communityId: "A", userId: "tenant-a", decision: "verified"},
  });
  assert.equal(db.values.get("users/tenant-a").identityVerificationStatus, "verified");
  assert.equal(db.values.get("users/tenant-a").isActive, false);
  assert.equal(db.values.get("users/tenant-a").status, "inactive");
});
