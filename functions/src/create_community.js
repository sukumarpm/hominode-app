const {
  FieldValue,
} = require("firebase-admin/firestore");

const {
  RegistrationError,
} = require("./register_resident");

const {
  normalizeCommunityId,
  normalizeSlug,
  validateTenantMetadata,
  requireActiveSuperAdmin,
  rejectLegacyDuplicate,
  reservationRef,
} = require("./tenant_management");

const validateCommunityInput = (data) =>
  validateTenantMetadata(data);

function locationsMatch(existing, expected) {
  const existingConfigured =
    existing.locationConfigured === true;

  const expectedConfigured =
    expected.locationConfigured === true;

  if (existingConfigured !== expectedConfigured) {
    return false;
  }

  if (!expectedConfigured) {
    return true;
  }

  const existingLocation = existing.location;
  const expectedLocation = expected.location;

  if (
    !existingLocation ||
    !expectedLocation
  ) {
    return false;
  }

  return (
    existingLocation.latitude ===
    expectedLocation.latitude &&
    existingLocation.longitude ===
    expectedLocation.longitude &&
    existingLocation.formattedAddress ===
    expectedLocation.formattedAddress &&
    (existingLocation.placeId ?? null) ===
    (expectedLocation.placeId ?? null) &&
    existingLocation.attendanceRadiusMeters ===
    expectedLocation.attendanceRadiusMeters
  );
}

function isIdempotentCommunity(
  existing,
  expected,
  creatorUid,
) {
  return (
    existing.name === expected.name &&
    existing.slug === expected.slug &&
    (existing.websitePath ?? existing.slug) ===
    expected.websitePath &&
    existing.isActive === true &&
    existing.createdBy === creatorUid &&
    locationsMatch(existing, expected)
  );
}

async function createCommunityCore({
  db,
  auth,
  data,
}) {
  const uid = await requireActiveSuperAdmin(
    db,
    auth,
  );

  const input =
    validateCommunityInput(data);

  await rejectLegacyDuplicate(
    db,
    "slug",
    input.slug,
    input.communityId,
  );

  await rejectLegacyDuplicate(
    db,
    "websitePath",
    input.websitePath,
    input.communityId,
  );

  const communityRef = db
    .collection("communities")
    .doc(input.communityId);

  return db.runTransaction(
    async (transaction) => {
      const community =
        await transaction.get(
          communityRef,
        );

      if (community.exists) {
        if (
          !isIdempotentCommunity(
            community.data(),
            input,
            uid,
          )
        ) {
          throw new RegistrationError(
            "already-exists",
            "A conflicting community already exists.",
          );
        }

        return {
          communityId: input.communityId,
          idempotent: true,
        };
      }

      const slugRef = reservationRef(
        db,
        "slugs",
        input.slug,
      );

      const pathRef = reservationRef(
        db,
        "websitePaths",
        input.websitePath,
      );

      if (
        (await transaction.get(slugRef))
          .exists
      ) {
        throw new RegistrationError(
          "already-exists",
          "Another community already uses this slug.",
        );
      }

      if (
        (await transaction.get(pathRef))
          .exists
      ) {
        throw new RegistrationError(
          "already-exists",
          "Another community already uses this websitePath.",
        );
      }

      transaction.set(
        slugRef,
        {
          communityId:
            input.communityId,
        },
      );

      transaction.set(
        pathRef,
        {
          communityId:
            input.communityId,
        },
      );

      const {
        communityId,
        ...metadata
      } = input;

      const createData = {
        ...metadata,

        // New communities without a location
        // explicitly start unconfigured.
        locationConfigured:
          metadata.locationConfigured === true,

        isActive: true,

        createdAt:
          FieldValue.serverTimestamp(),

        updatedAt:
          FieldValue.serverTimestamp(),

        createdBy: uid,
      };

      if (metadata.location) {
        createData.location = {
          ...metadata.location,
          updatedAt:
            FieldValue.serverTimestamp(),
        };
      } else {
        delete createData.location;
      }

      transaction.set(
        communityRef,
        createData,
      );

      return {
        communityId,
        idempotent: false,
      };
    },
  );
}

module.exports = {
  normalizeCommunityId,
  normalizeSlug,
  validateCommunityInput,
  locationsMatch,
  isIdempotentCommunity,
  createCommunityCore,
};