const {RegistrationError} = require("./register_resident");
const {requireSecurity} = require("./visitor_gate");
const {dayBounds} = require("./amenity_booking");

function millis(value) {
  if (value && typeof value.toMillis === "function") return value.toMillis();
  if (value instanceof Date) return value.getTime();
  return null;
}

// Dashboard statistics only. These counts never establish gate eligibility.
async function getSecurityVisitorSummaryCore({db, auth, now = Date.now}) {
  return db.runTransaction(async (transaction) => {
    // Read the staff assignment, community and counts in one consistent snapshot.
    const reader = {collection: (name) => ({doc: (id) => ({
      get: () => transaction.get(db.collection(name).doc(id)),
    })})};
    const security = await requireSecurity(reader, auth);
    let timeZone;
    try {
      const configured = security.community.timeZone;
      if (typeof configured !== "string" || !configured.trim()) throw new Error("missing");
      timeZone = new Intl.DateTimeFormat("en", {timeZone: configured.trim()})
        .resolvedOptions().timeZone;
    } catch (_) {
      throw new RegistrationError("failed-precondition", "The community time zone is unavailable.");
    }
    const refreshedAt = now();
    const {key: localDate, startMs, endMs} = dayBounds(refreshedAt, timeZone);
    // No list limit: dashboard totals include every matching community record.
    // Projection avoids reading visitor identity or private credential fields.
    const visitors = await transaction.get(db.collection("visitors")
      .where("communityId", "==", security.communityId)
      .select("status", "isApproved", "actualArrival", "departure"));
    let totalToday = 0, activeInside = 0, pendingRequests = 0, exitsToday = 0;
    for (const snapshot of visitors.docs) {
      const visitor = snapshot.data();
      const arrival = millis(visitor.actualArrival), departure = millis(visitor.departure);
      if (arrival != null && arrival >= startMs && arrival <= endMs) totalToday++;
      if (visitor.status === "inside" && visitor.actualArrival != null && visitor.departure == null) {
        activeInside++;
      }
      // Preserve the existing dashboard's Pending Requests definition, including
      // legacy records with absent timestamps. This is not an approval decision.
      if (visitor.status === "expected" && visitor.isApproved === false &&
          visitor.actualArrival == null && visitor.departure == null) pendingRequests++;
      if (visitor.status === "completed" && departure != null &&
          departure >= startMs && departure <= endMs) exitsToday++;
    }
    return {communityId: security.communityId, timeZone, localDate, refreshedAt,
      totalToday, activeInside, pendingRequests, exitsToday};
  }, {readOnly: true});
}

module.exports = {getSecurityVisitorSummaryCore};
