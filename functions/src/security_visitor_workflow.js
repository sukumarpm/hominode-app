const crypto = require("node:crypto");
const {FieldValue} = require("firebase-admin/firestore");
const {RegistrationError} = require("./register_resident");
const {requireSecurity, pendingVisitor, previouslyApprovedVisitor, isVisitValid} = require("./visitor_gate");
const {visitorEligible} = require("./visitor_credentials");

const VISITOR_LIST_LIMIT = 250;
const CHECKOUT_BATCH_LIMIT = 50;

function fail(code, message) {
  throw new RegistrationError(code, message);
}

function requiredText(value, label, maxLength) {
  if (typeof value !== "string" || !value.trim() || value.trim().length > maxLength) {
    fail("invalid-argument", `A valid ${label} is required.`);
  }
  return value.trim();
}

function timestampMillis(value) {
  if (value && typeof value.toMillis === "function") return value.toMillis();
  if (value instanceof Date) return value.getTime();
  if (Number.isFinite(value)) return value;
  return null;
}

function operationHash(value) {
  return crypto.createHash("sha256").update(value).digest("hex");
}

function securityStillAuthorized(profileSnapshot, communitySnapshot, security, auth) {
  const profile = profileSnapshot.data();
  return profileSnapshot.exists && profile?.uid === security.uid && profile.role === "security" &&
    profile.isActive === true && profile.communityId === security.communityId &&
    profile.phoneNumber === auth.token.phone_number && communitySnapshot.exists &&
    communitySnapshot.data()?.isActive === true;
}

function sanitizedVisitor(visitorId, data, category) {
  const denied = data.gateAccessStatus === "denied" || data.gateEntryDeniedAt != null;
  return {
    visitorId,
    visitorName: String(data.visitorName || "Visitor").slice(0, 120),
    phoneNumber: String(data.phoneNumber || data.phone || "").slice(0, 40),
    hostName: String(data.hostName || data.residentName || "Resident").slice(0, 120),
    flatId: String(data.flatId || "").slice(0, 120),
    flatLabel: String(data.flatLabel || data.flatId || "").slice(0, 80),
    purpose: String(data.purpose || "").slice(0, 300),
    status: String(data.status || ""),
    adminApproved: data.isApproved === true,
    gateAccessStatus: denied ? "denied" : "eligible",
    gateEntryDenialReason: denied ? String(data.gateEntryDenialReason || "").slice(0, 500) : null,
    gateEntryDeniedAt: denied ? timestampMillis(data.gateEntryDeniedAt) : null,
    expectedArrival: timestampMillis(data.expectedArrival ?? data.expectedTime),
    actualArrival: category === "inside" || category === "completed"
      ? timestampMillis(data.actualArrival) : null,
    departure: category === "completed" ? timestampMillis(data.departure) : null,
  };
}

async function listSecurityVisitorsCore({db, auth, data, now = Date.now}) {
  const security = await requireSecurity(db, auth);
  const category = requiredText(data?.category, "visitor list category", 16);
  const statuses = {
    expected: ["expected", "pending", "approved"],
    inside: ["inside"],
    completed: ["completed"],
  }[category];
  if (!statuses) fail("invalid-argument", "The visitor list category is invalid.");

  const visitorsRef = db.collection("visitors");
  const baseQuery = visitorsRef.where("communityId", "==", security.communityId);
  const result = category === "completed"
    ? await Promise.all([
      baseQuery.where("status", "in", statuses).limit(VISITOR_LIST_LIMIT).get(),
      // Denial is an independent terminal gate outcome. Query both markers so
      // older records with only the timestamp remain visible in History.
      baseQuery.where("gateAccessStatus", "==", "denied")
        .limit(VISITOR_LIST_LIMIT).get(),
      baseQuery.where("gateEntryDeniedAt", "!=", null)
        .limit(VISITOR_LIST_LIMIT).get(),
    ])
    : [await baseQuery.where("status", "in", statuses).limit(VISITOR_LIST_LIMIT).get()];
  const visitors = [];
  const seenVisitorIds = new Set();
  for (const snapshot of result.flatMap((queryResult) => queryResult.docs)) {
    if (seenVisitorIds.has(snapshot.id)) continue;
    seenVisitorIds.add(snapshot.id);
    const visitor = snapshot.data();
    if (visitor.communityId !== security.communityId) continue;
    if (category === "expected") {
      const denied = visitor.gateAccessStatus === "denied" || visitor.gateEntryDeniedAt != null;
      if (denied || !visitorEligible(visitor, now())) continue;
      visitors.push(sanitizedVisitor(snapshot.id, visitor, category));
    } else if (category === "inside" && visitor.status === "inside" &&
        visitor.actualArrival != null && visitor.departure == null &&
        visitor.gateAccessStatus !== "denied" && visitor.gateEntryDeniedAt == null) {
      visitors.push(sanitizedVisitor(snapshot.id, visitor, category));
    } else if (category === "completed" &&
        (visitor.gateAccessStatus === "denied" || visitor.gateEntryDeniedAt != null)) {
      visitors.push(sanitizedVisitor(snapshot.id, visitor, category));
    } else if (category === "completed" && visitor.status === "completed" && visitor.departure != null) {
      visitors.push(sanitizedVisitor(snapshot.id, visitor, category));
    }
  }
  visitors.sort((left, right) => {
    const leftTime = category === "inside" ? left.actualArrival :
      category === "completed" ? (left.gateEntryDeniedAt || left.departure) : left.expectedArrival;
    const rightTime = category === "inside" ? right.actualArrival :
      category === "completed" ? (right.gateEntryDeniedAt || right.departure) : right.expectedArrival;
    return (rightTime || 0) - (leftTime || 0);
  });
  return {visitors, refreshedAt: now()};
}

async function denyVisitorEntryCore({db, auth, data, now = Date.now}) {
  const security = await requireSecurity(db, auth);
  const visitorId = requiredText(data?.visitorId, "visitor ID", 160);
  const reason = requiredText(data?.reason, "denial reason", 500);
  const operationId = requiredText(data?.operationId, "operation ID", 100);
  if (!/^[A-Za-z0-9_-]{16,100}$/.test(operationId)) {
    fail("invalid-argument", "A valid operation ID is required.");
  }
  const operationKey = operationHash(`${security.uid}|${security.communityId}|deny|${operationId}`);
  const visitorRef = db.collection("visitors").doc(visitorId);
  const securityRef = db.collection("securityStaff").doc(security.uid);
  const communityRef = db.collection("communities").doc(security.communityId);
  const operationRef = db.collection("visitorGateOperations").doc(operationKey);
  const eventRef = db.collection("visitorGateEvents").doc(operationKey);

  return db.runTransaction(async (transaction) => {
    const [securitySnapshot, communitySnapshot, visitorSnapshot, operationSnapshot] = await Promise.all([
      transaction.get(securityRef), transaction.get(communityRef),
      transaction.get(visitorRef), transaction.get(operationRef),
    ]);
    if (!securityStillAuthorized(securitySnapshot, communitySnapshot, security, auth)) {
      fail("permission-denied", "Security authorization is no longer valid.");
    }
    if (!visitorSnapshot.exists) fail("not-found", "Visitor request is unavailable.");
    const visitor = visitorSnapshot.data();
    if (visitor.communityId !== security.communityId) {
      fail("permission-denied", "Visitor request is unavailable.");
    }
    const previous = operationSnapshot.data();
    if (operationSnapshot.exists) {
      if (previous.action !== "deny" || previous.visitorId !== visitorId ||
          previous.securityUid !== security.uid || previous.communityId !== security.communityId) {
        fail("already-exists", "This operation ID has already been used.");
      }
      return {visitorId, status: "denied", idempotent: true};
    }
    if (visitor.gateAccessStatus === "denied" || visitor.gateEntryDeniedAt != null) {
      fail("failed-precondition", "Entry was already denied for this invitation.");
    }
    if ((!pendingVisitor(visitor) && !previouslyApprovedVisitor(visitor)) ||
        !isVisitValid(visitor, now())) {
      fail("failed-precondition", "This visitor is not eligible for entry denial.");
    }

    transaction.update(visitorRef, {
      gateAccessStatus: "denied",
      gateEntryDeniedAt: FieldValue.serverTimestamp(),
      gateEntryDeniedBy: security.uid,
      gateEntryDenialReason: reason,
      updatedAt: FieldValue.serverTimestamp(),
    });
    transaction.create(operationRef, {
      action: "deny", securityUid: security.uid, communityId: security.communityId,
      visitorId, status: "denied", createdAt: FieldValue.serverTimestamp(),
    });
    transaction.create(eventRef, {
      eventType: "visitor_entry_denied", securityUid: security.uid,
      communityId: security.communityId, visitorId, reason,
      outcome: "denied", createdAt: FieldValue.serverTimestamp(),
    });
    return {visitorId, status: "denied", idempotent: false};
  });
}

async function checkoutOne({db, security, auth, visitorId, operationId}) {
  const operationKey = operationHash(
    `${security.uid}|${security.communityId}|checkout|${operationId}|${visitorId}`,
  );
  const visitorRef = db.collection("visitors").doc(visitorId);
  const securityRef = db.collection("securityStaff").doc(security.uid);
  const communityRef = db.collection("communities").doc(security.communityId);
  const operationRef = db.collection("visitorGateOperations").doc(operationKey);
  const eventRef = db.collection("visitorGateEvents").doc(operationKey);

  return db.runTransaction(async (transaction) => {
    const [securitySnapshot, communitySnapshot, visitorSnapshot, operationSnapshot] = await Promise.all([
      transaction.get(securityRef), transaction.get(communityRef),
      transaction.get(visitorRef), transaction.get(operationRef),
    ]);
    if (!securityStillAuthorized(securitySnapshot, communitySnapshot, security, auth)) {
      return {visitorId, success: false, message: "Security authorization is no longer valid."};
    }
    const previous = operationSnapshot.data();
    if (operationSnapshot.exists && previous.action === "checkout" &&
        previous.visitorId === visitorId && previous.securityUid === security.uid &&
        previous.communityId === security.communityId) {
      return {visitorId, success: true, status: "completed", idempotent: true};
    }
    if (!visitorSnapshot.exists || visitorSnapshot.data()?.communityId !== security.communityId) {
      return {visitorId, success: false, message: "Visitor is unavailable in this community."};
    }
    const visitor = visitorSnapshot.data();
    if (visitor.status !== "inside" || visitor.actualArrival == null || visitor.departure != null) {
      return {visitorId, success: false, message: "Visitor is no longer inside."};
    }

    transaction.update(visitorRef, {
      status: "completed",
      departure: FieldValue.serverTimestamp(),
      checkedOutBy: security.uid,
      updatedAt: FieldValue.serverTimestamp(),
    });
    transaction.create(operationRef, {
      action: "checkout", securityUid: security.uid,
      communityId: security.communityId, visitorId, status: "completed",
      createdAt: FieldValue.serverTimestamp(),
    });
    transaction.create(eventRef, {
      eventType: "visitor_checked_out", securityUid: security.uid,
      communityId: security.communityId, visitorId,
      outcome: "completed", createdAt: FieldValue.serverTimestamp(),
    });
    return {visitorId, success: true, status: "completed", idempotent: false};
  });
}

async function checkoutVisitorsCore({db, auth, data}) {
  const security = await requireSecurity(db, auth);
  const rawIds = data?.visitorIds;
  if (!Array.isArray(rawIds) || rawIds.length < 1 || rawIds.length > CHECKOUT_BATCH_LIMIT) {
    fail("invalid-argument", `Select between 1 and ${CHECKOUT_BATCH_LIMIT} visitors.`);
  }
  const visitorIds = rawIds.map((id) => requiredText(id, "visitor ID", 160));
  if (new Set(visitorIds).size !== visitorIds.length) {
    fail("invalid-argument", "A visitor can appear only once in a checkout batch.");
  }
  const operationId = requiredText(data?.operationId, "operation ID", 100);
  if (!/^[A-Za-z0-9_-]{16,100}$/.test(operationId)) {
    fail("invalid-argument", "A valid operation ID is required.");
  }
  const results = [];
  for (const visitorId of visitorIds) {
    try {
      results.push(await checkoutOne({db, security, auth, visitorId, operationId}));
    } catch (_) {
      // Each visitor is independent; a failed transaction does not roll back
      // other successful checkouts. The same operation ID makes retries safe.
      results.push({visitorId, success: false, message: "Checkout could not be confirmed. Retry this batch safely."});
    }
  }
  return {
    results,
    succeeded: results.filter((result) => result.success).length,
    failed: results.filter((result) => !result.success).length,
  };
}

module.exports = {
  CHECKOUT_BATCH_LIMIT,
  VISITOR_LIST_LIMIT,
  checkoutVisitorsCore,
  denyVisitorEntryCore,
  listSecurityVisitorsCore,
};
