const {RegistrationError} = require("./register_resident");
const {
  normalizeSlug,
  RESERVED_SLUGS,
  SLUG_PATTERN,
  reservationRef,
} = require("./tenant_management");

async function resolveResidentCommunityCore({db, data}) {
  const suppliedSlug = String(data?.slug ?? "").trim();
  const slug = normalizeSlug(suppliedSlug);
  if (
    suppliedSlug !== slug ||
    slug.length < 3 ||
    slug.length > 63 ||
    !SLUG_PATTERN.test(slug) ||
    RESERVED_SLUGS.has(slug)
  ) {
    throw new RegistrationError("invalid-argument", "Enter a valid community hostname.");
  }

  const matches = await db
    .collection("communities")
    .where("slug", "==", slug)
    .limit(2)
    .get();

  if (matches.empty) {
    throw new RegistrationError("not-found", "Community not found.");
  }
  if (matches.size !== 1) {
    throw new RegistrationError(
      "failed-precondition",
      "This community hostname is ambiguous.",
    );
  }

  const community = matches.docs[0];
  const communityData = community.data();
  if (communityData.isActive !== true) {
    throw new RegistrationError(
      "failed-precondition",
      "This community is currently unavailable.",
    );
  }

  const reservation = await reservationRef(db, "slugs", slug).get();
  if (
    reservation.exists &&
    reservation.data()?.communityId !== community.id
  ) {
    throw new RegistrationError(
      "failed-precondition",
      "This community hostname is ambiguous.",
    );
  }

  return {
    communityId: community.id,
    slug,
    name: String(communityData.name ?? "").trim() || slug,
  };
}

module.exports = {resolveResidentCommunityCore};
