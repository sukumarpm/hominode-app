const { FieldValue, Timestamp } = require("firebase-admin/firestore");
const { RegistrationError } = require("./register_resident");
const { requireActiveCommunityAdmin } = require("./security_management");
const { authorizedResident, credentialHash } = require("./visitor_credentials");
const { buildAuditLog } = require("./audit_log");
const {
  resolveEffectiveVisitorPolicy,
  visitorPolicyRevalidationAt,
} = require("./visitor_policy_resolver");
const {
  WINDOW_MS,
  millis,
  keys,
  communityPolicy,
  validatePolicy,
  invitationDecision,
  bringingPet,
  assertVisitorHost,
} = require("./visitor_policy");

function fail(code, message) {
  throw new RegistrationError(code, message);
}
function id(value) {
  if (
    typeof value !== "string" ||
    !value.trim() ||
    value !== value.trim() ||
    value.length > 128 ||
    value.includes("/")
  ) {
    fail("invalid-argument", "A valid document ID is required.");
  }
  return value;
}
function revision(value) {
  if (!Number.isSafeInteger(value) || value < 0)
    fail("invalid-argument", "An expected revision is required.");
  return value;
}
function reason(value) {
  if (value == null) return null;
  if (typeof value !== "string" || value.length > 200)
    fail("invalid-argument", "Reason must be at most 200 characters.");
  return value.trim() || null;
}
// Reuse the existing Admin authority helper against transaction snapshots, so
// account removal or community deactivation conflicts with the same commit.
function readerDb(db, transaction) {
  return {
    collection: (name) => ({
      doc: (key) => ({
        get: () => transaction.get(db.collection(name).doc(key)),
      }),
    }),
  };
}
function audit(
  db,
  tx,
  actor,
  communityId,
  action,
  targetType,
  targetId,
  before,
  after,
  metadata,
) {
  tx.create(db.collection("auditLogs").doc(), {
    ...buildAuditLog({
      actorUid: actor.uid,
      actorRole: actor.role,
      communityId,
      action,
      targetType,
      targetId,
      summary: "Visitor authorization or policy updated.",
      metadata,
    }),
    before,
    after,
  });
}

function wire(value) {
  if (typeof value?.toMillis === "function") return value.toMillis();
  if (Array.isArray(value)) return value.map(wire);
  if (value && typeof value === "object")
    return Object.fromEntries(
      Object.entries(value).map(([key, item]) => [key, wire(item)]),
    );
  return value;
}
async function getResidentVisitorContextCore({
  db,
  auth,
  data,
  now = Date.now,
}) {
  keys(data, ["expectedArrival"]);
  const arrival = millis(data.expectedArrival);
  if (arrival == null || arrival < now())
    fail("invalid-argument", "Choose a future arrival time.");
  return db.runTransaction(async (tx) => {
    const host = await authorizedResident(db, auth, (ref) => tx.get(ref));
    const args = {
      community: host.community,
      profile: host.profile,
      arrival,
      now: now(),
    };
    const decision = invitationDecision({ ...args, pet: false });
    let petPermitted = true;
    try {
      invitationDecision({ ...args, pet: true });
    } catch (error) {
      if (error.code !== "failed-precondition") throw error;
      petPermitted = false;
    }
    return {
      communityId: host.communityId,
      authorizationState: decision.authorizationState,
      petPermitted,
      policyRevision: decision.snapshot.revision,
      serverTime: args.now,
      revalidateAt: visitorPolicyRevalidationAt(host.community, args.now),
    };
  });
}

async function getCommunityVisitorPolicyCore({
  db,
  auth,
  data,
  now = Date.now,
}) {
  keys(data, ["communityId"]);
  const communityId = id(data.communityId);
  const actor = await requireActiveCommunityAdmin(db, auth, communityId);
  const serverTime = now();
  const effective = resolveEffectiveVisitorPolicy(actor.community, serverTime);
  const scheduled = actor.community.scheduledVisitorPolicy;
  const effectiveAt = millis(scheduled?.effectiveAt);
  return {
    communityId,
    timeZone: actor.community.timeZone || null,
    policy: wire(effective),
    writeRevision: visitorPolicyWriteRevision(actor.community),
    pendingSchedule: scheduled && effectiveAt > serverTime ? {
      effectiveAt,
      revision: revision(scheduled.revision),
      policy: validatePolicy(scheduled.policy),
    } : null,
    serverTime,
    rolloutReady: actor.community.visitorPolicyRolloutReady === true,
  };
}

function visitorPolicyWriteRevision(community) {
  return Math.max(
    revision(community.visitorPolicy?.revision ?? 0),
    revision(community.scheduledVisitorPolicy?.revision ?? 0),
  );
}
async function updateCommunityVisitorPolicyCore({
  db,
  auth,
  data,
  now = Date.now,
}) {
  keys(data, ["communityId", "policy", "expectedRevision", "reason", "effectiveAt"]);
  const communityId = id(data.communityId),
    expected = revision(data.expectedRevision);
  const input = validatePolicy(data.policy),
    why = reason(data.reason);
  const ref = db.collection("communities").doc(communityId);
  return db.runTransaction(async (tx) => {
    const actor = await requireActiveCommunityAdmin(
      readerDb(db, tx),
      auth,
      communityId,
    );
    const currentTime = now();
    const before = resolveEffectiveVisitorPolicy(
      actor.community,
      currentTime,
    );
    const latestRevision = visitorPolicyWriteRevision(actor.community);

    if (latestRevision !== expected)
      fail("aborted", "Visitor policy changed. Reload before saving.");
    // The timeZone is community-owned; an Admin may not reinterpret schedules
    // using a different zone. Communities without one require operator setup.
    if (input.timeZone !== actor.community.timeZone) {
      fail(
        "failed-precondition",
        "Set the canonical community timeZone before configuring visitor policy.",
      );
    }
    const effectiveAt =
      data.effectiveAt == null ? currentTime : millis(data.effectiveAt);

    if (
      effectiveAt == null ||
      !Number.isSafeInteger(effectiveAt) ||
      effectiveAt < 0
    ) {
      fail("invalid-argument", "Invalid policy effective time.");
    }
    // Immediate saves omit effectiveAt. A submitted schedule must still be
    // future at server evaluation, rather than silently activating now.
    if (data.effectiveAt != null && effectiveAt <= currentTime) {
      fail("invalid-argument", "Choose a future policy effective time.");
    }

    const policy = {
      ...input,
      revision: expected + 1,
      updatedBy: actor.uid,
      updatedAt: FieldValue.serverTimestamp(),
      enforcementStartedAt:
        before.enforcementStartedAt ??
        (input.enabled ? Timestamp.fromMillis(effectiveAt) : null),
    };

    if (effectiveAt > currentTime) {
      tx.update(ref, {
        visitorPolicy: {
          ...validatePolicy({
            schemaVersion: before.schemaVersion,
            enabled: before.enabled,
            timeZone: before.timeZone,
            approvalMode: before.approvalMode,
            emergency: before.emergency,
            pets: before.pets,
          }),
          revision: before.revision || 0,
          updatedBy: before.updatedBy || null,
          updatedAt: before.updatedAt || null,
          enforcementStartedAt: before.enforcementStartedAt || null,
        },
        scheduledVisitorPolicy: {
          effectiveAt: Timestamp.fromMillis(effectiveAt),
          policy: input,
          revision: expected + 1,
          updatedBy: actor.uid,
          updatedAt: FieldValue.serverTimestamp(),
        },
      });
    } else {
      tx.update(ref, {
        visitorPolicy: policy,
        scheduledVisitorPolicy: FieldValue.delete(),
      });
    }
    audit(
      db,
      tx,
      { ...actor, role: "admin" },
      communityId,
      "visitor.policy_update",
      "visitor_policy",
      communityId,
      before,
      policy,
      {
        reason: why,
        effectivePolicy: input.approvalMode,
        revision: policy.revision,
      },
    );
    return {
      communityId,
      revision: policy.revision,
      enabled: input.enabled,
      effectiveAt,
      scheduled: effectiveAt > currentTime,
    };
  });
}

async function decideVisitorInvitationCore({ db, auth, data }) {
  keys(data, [
    "communityId",
    "visitorId",
    "action",
    "expectedRevision",
    "reason",
  ]);
  const communityId = id(data.communityId),
    visitorId = id(data.visitorId);
  const expected = revision(data.expectedRevision),
    why = reason(data.reason);
  if (!["approve", "reject", "revoke"].includes(data.action))
    fail("invalid-argument", "Invalid visitor decision.");
  return db.runTransaction(async (tx) => {
    const actor = await requireActiveCommunityAdmin(
      readerDb(db, tx),
      auth,
      communityId,
    );
    const ref = db.collection("visitors").doc(visitorId),
      snapshot = await tx.get(ref);
    const visitor = snapshot.data();
    if (!snapshot.exists || visitor.communityId !== communityId)
      fail("permission-denied", "Visitor access denied.");
    if ((visitor.authorizationRevision || 0) !== expected)
      fail("aborted", "Visitor changed. Reload before deciding.");
    if (
      visitor.actualArrival != null ||
      visitor.departure != null ||
      !["expected", "pending", "approved"].includes(visitor.status) ||
      visitor.gateAccessStatus === "denied" ||
      visitor.gateEntryDeniedAt != null
    ) {
      fail(
        "failed-precondition",
        "This visitor cannot receive an authorization decision.",
      );
    }
    const before =
      visitor.authorizationState ||
      (visitor.isApproved ? "admin_authorized" : "auto_authorized");
    if (
      ["rejected", "revoked"].includes(before) ||
      (data.action === "approve" &&
        !["pending_admin", "auto_authorized"].includes(before)) ||
      (data.action === "revoke" &&
        !["auto_authorized", "admin_authorized"].includes(before))
    ) {
      fail("failed-precondition", "Invalid authorization transition.");
    }
    const state = {
      approve: "admin_authorized",
      reject: "rejected",
      revoke: "revoked",
    }[data.action];
    if (data.action === "approve")
      await assertVisitorHost({
        db,
        read: (ref) => tx.get(ref),
        visitor: { ...visitor, authorizationManaged: true },
        community: actor.community,
      });
    const patch = {
      authorizationManaged: true,
      authorizationState: state,
      authorizationRevision: expected + 1,
      authorizationActorUid: actor.uid,
      authorizationReason: why,
      authorizationUpdatedAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
      status:
        data.action === "approve"
          ? "approved"
          : data.action === "reject"
            ? "rejected"
            : "cancelled",
      isApproved: data.action === "approve",
    };
    if (data.action === "approve")
      Object.assign(patch, {
        approvedBy: actor.uid,
        approvedAt: FieldValue.serverTimestamp(),
      });
    if (data.action === "reject")
      Object.assign(patch, {
        rejectedBy: actor.uid,
        rejectedAt: FieldValue.serverTimestamp(),
        rejectionReason: why,
      });
    tx.update(ref, patch);
    audit(
      db,
      tx,
      { ...actor, role: "admin" },
      communityId,
      `visitor.${data.action}`,
      "visitor",
      visitorId,
      before,
      state,
      {
        reason: why,
        revision: expected + 1,
        effectivePolicy:
          visitor.visitorPolicySnapshot?.approvalMode || "resident_authorized",
      },
    );
    return {
      visitorId,
      authorizationState: state,
      authorizationRevision: expected + 1,
    };
  });
}

async function mutateResidentVisitorCore({
  db,
  auth,
  data,
  hmacKey,
  now = Date.now,
}) {
  keys(data, [
    "visitorId",
    "action",
    "expectedRevision",
    "expectedArrival",
    "bringingPet",
    "reason",
  ]);
  const visitorId = id(data.visitorId),
    expected = revision(data.expectedRevision),
    why = reason(data.reason);
  if (!["cancel", "reschedule"].includes(data.action))
    fail("invalid-argument", "Invalid visitor action.");
  if (
    data.action === "cancel" &&
    (data.expectedArrival !== undefined || data.bringingPet !== undefined)
  ) {
    fail("invalid-argument", "Cancellation cannot change visit details.");
  }
  return db.runTransaction(async (tx) => {
    const host = await authorizedResident(db, auth, (ref) => tx.get(ref));
    const ref = db.collection("visitors").doc(visitorId),
      snapshot = await tx.get(ref);
    const visitor = snapshot.data();
    if (
      !snapshot.exists ||
      visitor.hostUserId !== host.uid ||
      visitor.communityId !== host.communityId
    ) {
      fail("permission-denied", "Visitor access denied.");
    }
    if ((visitor.authorizationRevision || 0) !== expected)
      fail("aborted", "Visitor changed. Reload before updating.");
    if (
      visitor.actualArrival != null ||
      visitor.departure != null ||
      !["expected", "pending", "approved"].includes(visitor.status) ||
      visitor.gateAccessStatus === "denied" ||
      visitor.gateEntryDeniedAt != null ||
      ["rejected", "revoked"].includes(visitor.authorizationState)
    ) {
      fail("failed-precondition", "This visit can no longer be changed.");
    }
    let patch;
    if (data.action === "cancel") {
      patch = {
        status: "cancelled",
        isApproved: false,
        authorizationState: "revoked",
        cancelledBy: host.uid,
      };
    } else {
      const arrival =
        data.expectedArrival === undefined
          ? millis(visitor.expectedArrival)
          : millis(data.expectedArrival);
      const nowMs = now();
      if (
        arrival == null ||
        (data.expectedArrival !== undefined
          ? arrival < nowMs
          : arrival + WINDOW_MS < nowMs)
      ) {
        fail("invalid-argument", "Choose a valid arrival time.");
      }
      const pet =
        data.bringingPet === undefined
          ? bringingPet(visitor.bringingPet)
          : bringingPet(data.bringingPet);
      const decision = invitationDecision({
        community: host.community,
        profile: host.profile,
        arrival,
        pet,
        now: nowMs,
      });
      const credentialRef = db
        .collection("visitorHostCredentials")
        .doc(visitorId);
      const credential = await tx.get(credentialRef);
      if (!credential.exists)
        fail(
          "failed-precondition",
          "Create a new invitation to replace this legacy pass.",
        );
      const secret = credential.data();
      if (
        secret.hostUserId !== host.uid ||
        secret.communityId !== host.communityId ||
        secret.credentialVersion !== 1
      ) {
        fail(
          "failed-precondition",
          "Visitor credential scope is inconsistent.",
        );
      }
      const from = Timestamp.fromMillis(arrival - WINDOW_MS),
        until = Timestamp.fromMillis(arrival + WINDOW_MS);
      const indexes = [
        db
          .collection("visitorGateCredentialIndex")
          .doc(credentialHash(hmacKey, "qr", secret.qrToken)),
        db
          .collection("visitorGateCredentialIndex")
          .doc(credentialHash(hmacKey, "manual", secret.manualCode)),
      ];
      const indexSnapshots = await Promise.all(
        indexes.map((index) => tx.get(index)),
      );
      if (
        indexSnapshots.some(
          (index) =>
            !index.exists ||
            index.data().visitorId !== visitorId ||
            index.data().communityId !== host.communityId,
        )
      )
        fail(
          "failed-precondition",
          "Visitor credential indexes are inconsistent.",
        );
      tx.update(credentialRef, { validFrom: from, expiresAt: until });
      indexes.forEach((index) =>
        tx.update(index, { validFrom: from, expiresAt: until }),
      );
      patch = {
        status: "expected",
        isApproved: false,
        approvedBy: null,
        approvedAt: null,
        expectedArrival: Timestamp.fromMillis(arrival),
        bringingPet: pet,
        credentialValidFrom: from,
        credentialExpiresAt: until,
        authorizationState: decision.authorizationState,
        visitorPolicySnapshot: decision.snapshot,
      };
    }
    Object.assign(patch, {
      authorizationManaged: true,
      authorizationRevision: expected + 1,
      authorizationUpdatedAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });
    tx.update(ref, patch);
    audit(
      db,
      tx,
      { ...host, role: "resident" },
      host.communityId,
      `visitor.${data.action}`,
      "visitor",
      visitorId,
      visitor.authorizationState || "legacy",
      patch.authorizationState,
      {
        reason: why,
        revision: expected + 1,
        effectivePolicy:
          patch.visitorPolicySnapshot?.approvalMode || "unchanged",
      },
    );
    return {
      visitorId,
      authorizationState: patch.authorizationState,
      authorizationRevision: expected + 1,
    };
  });
}

async function getVisitorPolicyHistoryCore({ db, auth, data }) {
  keys(data, ["communityId", "beforeId"]);
  const communityId = id(data.communityId);
  await requireActiveCommunityAdmin(db, auth, communityId);
  let query = db
    .collection("auditLogs")
    .where("communityId", "==", communityId)
    .where("targetType", "in", ["visitor", "visitor_policy"])
    .orderBy("timestamp", "desc");
  if (data.beforeId != null) {
    const cursor = await db
      .collection("auditLogs")
      .doc(id(data.beforeId))
      .get();
    if (
      !cursor.exists ||
      cursor.data().communityId !== communityId ||
      !["visitor", "visitor_policy"].includes(cursor.data().targetType)
    )
      fail("permission-denied", "Invalid history cursor.");
    query = query.startAfter(cursor);
  }
  const page = await query.limit(50).get();
  return {
    events: page.docs.map((doc) => ({ id: doc.id, ...wire(doc.data()) })),
    nextBeforeId: page.size === 50 ? page.docs[49].id : null,
  };
}

module.exports = {
  getCommunityVisitorPolicyCore,
  updateCommunityVisitorPolicyCore,
  decideVisitorInvitationCore,
  mutateResidentVisitorCore,
  getVisitorPolicyHistoryCore,
  getResidentVisitorContextCore,
};
