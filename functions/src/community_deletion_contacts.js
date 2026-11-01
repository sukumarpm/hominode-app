"use strict";

// Central, server-only routing: community ID -> deletion request recipient.
const COLLECTION = "communityDeletionContacts";
const COMMUNITY_ID = /^[A-Z0-9][A-Z0-9_-]{1,79}$/;
const EMAIL = /^[^\s@<>]+@[^\s@<>]+\.[^\s@<>]+$/;

function normalizeDeletionEmail(value) {
  if (typeof value !== "string") throw new Error("Community deletion email is required.");
  const email = value.trim().toLowerCase();
  if (!email || email.length > 254 || !EMAIL.test(email) || /[\r\n]/.test(value)) {
    throw new Error("Enter a valid community deletion email.");
  }
  return email;
}

function validateCommunityId(value) {
  return typeof value === "string" && COMMUNITY_ID.test(value);
}

async function findActiveRecipient(db, communityId) {
  if (!validateCommunityId(communityId)) return null;
  const [community, contact] = await Promise.all([
    db.collection("communities").doc(communityId).get(),
    db.collection(COLLECTION).doc(communityId).get(),
  ]);
  if (!community.exists || community.data()?.isActive !== true || !contact.exists) return null;
  const address = contact.data()?.email;
  let email;
  try { email = normalizeDeletionEmail(address); } catch { return null; }
  const name = String(community.data()?.name || "").trim();
  if (!name) return null;
  return { communityId, name, email };
}

async function listActiveCommunities(req, res, { db, allowedOrigins }) {
  res.set("Cache-Control", "no-store");
  res.set("X-Content-Type-Options", "nosniff");
  if (!allowedOrigins.has(req.headers.origin)) return res.status(403).json({ error: "Origin not allowed." });
  if (req.method !== "GET") return res.status(405).json({ error: "Use GET." });
  try {
    const snapshot = await db.collection("communities").where("isActive", "==", true).get();
    // Only return public IDs/names; recipient addresses never leave the server.
    const rows = await Promise.all(snapshot.docs.slice(0, 500).map(async doc => {
      const route = await findActiveRecipient(db, doc.id);
      return route ? { id: route.communityId, name: route.name } : null;
    }));
    const communities = rows.filter(Boolean).sort((a, b) => a.name.localeCompare(b.name));
    return res.status(200).json({ communities });
  } catch (error) {
    console.error("Public community options unavailable", error);
    return res.status(503).json({ error: "Communities are temporarily unavailable." });
  }
}

module.exports = {
  COLLECTION,
  normalizeDeletionEmail,
  validateCommunityId,
  findActiveRecipient,
  listActiveCommunities,
};
