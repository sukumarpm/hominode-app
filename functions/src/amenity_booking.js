const { FieldValue, Timestamp } = require("firebase-admin/firestore");
const { RegistrationError } = require("./register_resident");

const ACTIVE_BOOKING_STATUSES = new Set(["pending", "confirmed", "approved"]);
const BOOKING_TYPES = new Set(["daily", "weekly", "monthly", "yearly"]);
const MILLIS_PER_DAY = 24 * 60 * 60 * 1000;
const MAX_AVAILABILITY_DAYS = 62;

function clean(value) {
  return typeof value === "string" ? value.trim() : "";
}

function requireObject(data) {
  if (!data || typeof data !== "object" || Array.isArray(data)) {
    throw new RegistrationError("invalid-argument", "A request object is required.");
  }
  return data;
}

function requireAllowedKeys(data, allowed) {
  const unexpected = Object.keys(data).filter((key) => !allowed.has(key));
  if (unexpected.length > 0) {
    throw new RegistrationError(
      "invalid-argument",
      `Unexpected field: ${unexpected[0]}.`,
    );
  }
}

function requireDocumentId(value, label) {
  const id = clean(value);
  if (!id || id.length > 160 || id.includes("/")) {
    throw new RegistrationError("invalid-argument", `${label} is invalid.`);
  }
  return id;
}

function requireFiniteInteger(value, label, { min, max }) {
  const number = Number(value);
  if (!Number.isInteger(number) || number < min || number > max) {
    throw new RegistrationError(
      "invalid-argument",
      `${label} must be between ${min} and ${max}.`,
    );
  }
  return number;
}

function requireTimezoneOffset(value) {
  return requireFiniteInteger(value, "timezoneOffsetMinutes", {
    min: -14 * 60,
    max: 14 * 60,
  });
}

function requireMillis(value, label) {
  const number = Number(value);
  if (!Number.isSafeInteger(number) || number <= 0) {
    throw new RegistrationError("invalid-argument", `${label} is invalid.`);
  }
  return number;
}

function requireTimeSlot(value) {
  const slot = clean(value);
  if (!slot || slot.length > 120) {
    throw new RegistrationError("invalid-argument", "A valid time slot is required.");
  }
  return slot;
}

function canonicalResidentType(profile) {
  function canonical(value) {
    const text = clean(value).toLowerCase();
    return text === "owner" || text === "tenant" ? text : null;
  }

  const rawResidentType = profile?.residentType;
  const rawOwnershipType = profile?.ownershipType;
  const residentType = rawResidentType == null ? null : canonical(rawResidentType);
  const ownershipType = rawOwnershipType == null ? null : canonical(rawOwnershipType);

  if (rawResidentType != null && residentType == null) return null;
  if (rawOwnershipType != null && ownershipType == null) return null;
  if (residentType && ownershipType && residentType !== ownershipType) return null;
  return residentType || ownershipType;
}

function requireActiveResidentProfile(snapshot, auth) {
  if (!auth?.uid) {
    throw new RegistrationError("unauthenticated", "Sign in to continue.");
  }
  if (!snapshot.exists) {
    throw new RegistrationError("permission-denied", "Resident access is unavailable.");
  }

  const profile = snapshot.data() || {};
  const communityId = clean(profile.communityId);
  if (
    profile.role !== "resident" ||
    profile.approvalStatus !== "approved" ||
    profile.isActive !== true ||
    (Object.prototype.hasOwnProperty.call(profile, "status") &&
      profile.status !== "active") ||
    !communityId
  ) {
    throw new RegistrationError(
      "permission-denied",
      "Your resident account is not active for this community.",
    );
  }

  return {
    ...profile,
    uid: auth.uid,
    communityId,
    residentType: canonicalResidentType(profile),
  };
}

async function requireResident(db, auth) {
  if (!auth?.uid) {
    throw new RegistrationError("unauthenticated", "Sign in to continue.");
  }
  const snapshot = await db.collection("users").doc(auth.uid).get();
  return requireActiveResidentProfile(snapshot, auth);
}

function requireAmenityData(snapshot, resident) {
  if (!snapshot.exists) {
    throw new RegistrationError("not-found", "This facility no longer exists.");
  }

  const amenity = snapshot.data() || {};
  if (
    clean(amenity.communityId) !== resident.communityId ||
    amenity.isAvailable !== true
  ) {
    throw new RegistrationError(
      "failed-precondition",
      "This facility is not available for booking.",
    );
  }

  const slots = Array.isArray(amenity.timeSlots)
    ? amenity.timeSlots
        .filter((value) => typeof value === "string")
        .map((value) => value.trim())
        .filter(Boolean)
    : [];

  if (slots.length === 0) {
    throw new RegistrationError(
      "failed-precondition",
      "This facility has no bookable time slots.",
    );
  }

  const allowMultipleBookings = amenity.allowMultipleBookings === true;
  const rawCapacity = Number(amenity.maxCapacity);
  const maxCapacity =
    Number.isInteger(rawCapacity) && rawCapacity > 0 ? rawCapacity : 1;

  if (allowMultipleBookings && !(Number.isInteger(rawCapacity) && rawCapacity > 0)) {
    throw new RegistrationError(
      "failed-precondition",
      "This facility has an invalid booking capacity.",
    );
  }

  return {
    ...amenity,
    timeSlots: slots,
    allowMultipleBookings,
    maxCapacity,
  };
}

async function requireAmenity(db, amenityId, resident) {
  const snapshot = await db.collection("amenities").doc(amenityId).get();
  return requireAmenityData(snapshot, resident);
}

function dayPartsFromMillis(value, timezoneOffsetMinutes) {
  const shifted = new Date(value + timezoneOffsetMinutes * 60 * 1000);
  return {
    year: shifted.getUTCFullYear(),
    month: shifted.getUTCMonth(),
    day: shifted.getUTCDate(),
  };
}

function localDateKeyFromMillis(value, timezoneOffsetMinutes) {
  const { year, month, day } = dayPartsFromMillis(value, timezoneOffsetMinutes);
  return [
    String(year).padStart(4, "0"),
    String(month + 1).padStart(2, "0"),
    String(day).padStart(2, "0"),
  ].join("-");
}

function dayBounds(value, timezoneOffsetMinutes) {
  const parts = dayPartsFromMillis(value, timezoneOffsetMinutes);
  const localMidnightAsUtc = Date.UTC(parts.year, parts.month, parts.day);
  const startMs = localMidnightAsUtc - timezoneOffsetMinutes * 60 * 1000;
  return {
    key: localDateKeyFromMillis(startMs, timezoneOffsetMinutes),
    startMs,
    endMs: startMs + MILLIS_PER_DAY - 1,
  };
}

function enumerateDays(startDateMs, endDateMs, timezoneOffsetMinutes) {
  const start = dayBounds(startDateMs, timezoneOffsetMinutes);
  const end = dayBounds(endDateMs, timezoneOffsetMinutes);
  if (end.startMs < start.startMs) {
    throw new RegistrationError(
      "invalid-argument",
      "The availability date range is invalid.",
    );
  }

  const count = Math.floor((end.startMs - start.startMs) / MILLIS_PER_DAY) + 1;
  if (count > MAX_AVAILABILITY_DAYS) {
    throw new RegistrationError(
      "invalid-argument",
      `Availability can be checked for at most ${MAX_AVAILABILITY_DAYS} days at a time.`,
    );
  }

  const days = [];
  for (let index = 0; index < count; index += 1) {
    const startMs = start.startMs + index * MILLIS_PER_DAY;
    days.push({
      key: localDateKeyFromMillis(startMs, timezoneOffsetMinutes),
      startMs,
      endMs: startMs + MILLIS_PER_DAY - 1,
    });
  }
  return days;
}

function activeBookingsFromSnapshot(snapshot, resident, amenityId) {
  return snapshot.docs
    .map((doc) => ({ id: doc.id, ...(doc.data() || {}) }))
    .filter((booking) => {
      return (
        clean(booking.communityId) === resident.communityId &&
        clean(booking.amenityId) === amenityId &&
        ACTIVE_BOOKING_STATUSES.has(clean(booking.status).toLowerCase())
      );
    });
}

function positivePeople(value) {
  const people = Number(value);
  return Number.isInteger(people) && people > 0 ? people : 1;
}

function availabilityForSlot(amenity, bookings, timeSlot, numberOfPeople) {
  const matching = bookings.filter((booking) => clean(booking.timeSlot) === timeSlot);
  const totalPeople = matching.reduce(
    (sum, booking) => sum + positivePeople(booking.numberOfPeople),
    0,
  );

  if (!amenity.allowMultipleBookings) {
    const available = matching.length === 0;
    return {
      available,
      reason: available ? "Available" : "Already booked",
      remainingSpots: available ? 1 : 0,
      totalCapacity: 1,
      bookingCount: matching.length,
      totalPersonsBooked: totalPeople,
    };
  }

  const remainingSpots = Math.max(0, amenity.maxCapacity - totalPeople);
  const available = remainingSpots >= numberOfPeople;
  return {
    available,
    reason: available ? "Available" : "Not enough capacity",
    remainingSpots,
    totalCapacity: amenity.maxCapacity,
    bookingCount: matching.length,
    totalPersonsBooked: totalPeople,
  };
}

function buildAvailability({
  amenity,
  bookings,
  days,
  timezoneOffsetMinutes,
  numberOfPeople,
}) {
  const grouped = new Map();

  for (const booking of bookings) {
    const timestamp = booking.date;
    if (!timestamp || typeof timestamp.toMillis !== "function") continue;
    const millis = timestamp.toMillis();
    const key = localDateKeyFromMillis(millis, timezoneOffsetMinutes);
    if (!grouped.has(key)) grouped.set(key, []);
    grouped.get(key).push(booking);
  }

  const dates = {};
  for (const day of days) {
    const dayBookings = grouped.get(day.key) || [];
    const slots = {};
    let fullyBooked = true;

    for (const timeSlot of amenity.timeSlots) {
      const result = availabilityForSlot(
        amenity,
        dayBookings,
        timeSlot,
        numberOfPeople,
      );
      slots[timeSlot] = result;
      if (result.available) fullyBooked = false;
    }

    dates[day.key] = { fullyBooked, slots };
  }

  return dates;
}

function numberPrice(value) {
  const number = Number(value);
  return Number.isFinite(number) && number >= 0 ? number : null;
}

function effectiveDailyPrice(amenity, resident) {
  const isFree = amenity.isFree === true;
  const explicitMode = clean(amenity.pricingMode).toLowerCase();
  const pricingMode = explicitMode || (isFree ? "free" : "flat");

  if (pricingMode === "free") {
    if (!isFree) {
      throw new RegistrationError(
        "failed-precondition",
        "This facility has invalid pricing.",
      );
    }
    return 0;
  }

  if (pricingMode === "flat") {
    const value = numberPrice(amenity.pricePerDay);
    if (isFree || value == null) {
      throw new RegistrationError(
        "failed-precondition",
        "This facility price is unavailable.",
      );
    }
    return value;
  }

  if (pricingMode === "resident_type") {
    if (isFree || numberPrice(amenity.pricePerDay) !== 0 || !resident.residentType) {
      throw new RegistrationError(
        "failed-precondition",
        "Your owner or tenant facility price is unavailable.",
      );
    }

    const value =
      resident.residentType === "owner"
        ? numberPrice(amenity.ownerPricePerDay)
        : numberPrice(amenity.tenantPricePerDay);

    if (value == null) {
      throw new RegistrationError(
        "failed-precondition",
        "Your owner or tenant facility price is unavailable.",
      );
    }
    return value;
  }

  throw new RegistrationError(
    "failed-precondition",
    "This facility has an unsupported pricing mode.",
  );
}

function packagePrice(amenity, bookingType, dailyPrice) {
  if (bookingType === "daily") return dailyPrice;

  const packageKey =
    bookingType === "weekly"
      ? "Weekly"
      : bookingType === "monthly"
        ? "Monthly"
        : "Yearly";

  const packages =
    amenity.subscriptionPackages &&
    typeof amenity.subscriptionPackages === "object" &&
    !Array.isArray(amenity.subscriptionPackages)
      ? amenity.subscriptionPackages
      : null;

  const value = packages ? numberPrice(packages[packageKey]) : null;
  if (amenity.hasSubscriptionPackages !== true || value == null) {
    throw new RegistrationError(
      "failed-precondition",
      `${packageKey} booking is not configured for this facility.`,
    );
  }
  return value;
}

function packageDates(dateMs, bookingType) {
  const durationDays =
    bookingType === "weekly"
      ? 7
      : bookingType === "monthly"
        ? 30
        : bookingType === "yearly"
          ? 365
          : 1;

  return {
    packageType:
      bookingType === "daily"
        ? null
        : bookingType[0].toUpperCase() + bookingType.slice(1),
    validityDays: durationDays,
    subscriptionStartMs: dateMs,
    subscriptionEndMs:
      bookingType === "daily"
        ? dateMs
        : dateMs + durationDays * MILLIS_PER_DAY,
  };
}

function validateFamilyMembers(value) {
  if (value == null) return [];
  if (!Array.isArray(value) || value.length > 20) {
    throw new RegistrationError(
      "invalid-argument",
      "Family members must be a short list.",
    );
  }
  return value.map((item) => {
    const name = clean(item);
    if (!name || name.length > 120) {
      throw new RegistrationError(
        "invalid-argument",
        "A family member name is invalid.",
      );
    }
    return name;
  });
}

function todayKey(timezoneOffsetMinutes) {
  return localDateKeyFromMillis(Date.now(), timezoneOffsetMinutes);
}

function validateCreateInput(data) {
  const input = requireObject(data);
  requireAllowedKeys(
    input,
    new Set([
      "amenityId",
      "dateMs",
      "timeSlot",
      "bookingType",
      "numberOfPeople",
      "familyMembers",
      "timezoneOffsetMinutes",
    ]),
  );

  const amenityId = requireDocumentId(input.amenityId, "Amenity");
  const dateMs = requireMillis(input.dateMs, "dateMs");
  const timeSlot = requireTimeSlot(input.timeSlot);
  const bookingType = clean(input.bookingType || "daily").toLowerCase();
  if (!BOOKING_TYPES.has(bookingType)) {
    throw new RegistrationError("invalid-argument", "Booking type is invalid.");
  }

  return {
    amenityId,
    dateMs,
    timeSlot,
    bookingType,
    numberOfPeople: requireFiniteInteger(input.numberOfPeople ?? 1, "numberOfPeople", {
      min: 1,
      max: 1000,
    }),
    familyMembers: validateFamilyMembers(input.familyMembers),
    timezoneOffsetMinutes: requireTimezoneOffset(input.timezoneOffsetMinutes),
  };
}

function validateAvailabilityInput(data) {
  const input = requireObject(data);
  requireAllowedKeys(
    input,
    new Set([
      "amenityId",
      "startDateMs",
      "endDateMs",
      "numberOfPeople",
      "timezoneOffsetMinutes",
    ]),
  );

  return {
    amenityId: requireDocumentId(input.amenityId, "Amenity"),
    startDateMs: requireMillis(input.startDateMs, "startDateMs"),
    endDateMs: requireMillis(input.endDateMs, "endDateMs"),
    numberOfPeople: requireFiniteInteger(input.numberOfPeople ?? 1, "numberOfPeople", {
      min: 1,
      max: 1000,
    }),
    timezoneOffsetMinutes: requireTimezoneOffset(input.timezoneOffsetMinutes),
  };
}

async function bookingQuery(db, amenityId, startMs, endMs, transaction = null) {
  const query = db
    .collection("bookings")
    .where("amenityId", "==", amenityId)
    .where("date", ">=", Timestamp.fromMillis(startMs))
    .where("date", "<=", Timestamp.fromMillis(endMs));

  return transaction ? transaction.get(query) : query.get();
}

async function getAmenityAvailabilityCore({ db, auth, data }) {
  const input = validateAvailabilityInput(data);
  const resident = await requireResident(db, auth);
  const amenity = await requireAmenity(db, input.amenityId, resident);
  const days = enumerateDays(
    input.startDateMs,
    input.endDateMs,
    input.timezoneOffsetMinutes,
  );

  if (input.numberOfPeople > amenity.maxCapacity && amenity.allowMultipleBookings) {
    return {
      amenityId: input.amenityId,
      maxCapacity: amenity.maxCapacity,
      allowMultipleBookings: amenity.allowMultipleBookings,
      dates: Object.fromEntries(
        days.map((day) => [
          day.key,
          {
            fullyBooked: true,
            slots: Object.fromEntries(
              amenity.timeSlots.map((slot) => [
                slot,
                {
                  available: false,
                  reason: "Requested group exceeds facility capacity",
                  remainingSpots: 0,
                  totalCapacity: amenity.maxCapacity,
                  bookingCount: 0,
                  totalPersonsBooked: 0,
                },
              ]),
            ),
          },
        ]),
      ),
    };
  }

  const snapshot = await bookingQuery(
    db,
    input.amenityId,
    days[0].startMs,
    days[days.length - 1].endMs,
  );
  const bookings = activeBookingsFromSnapshot(snapshot, resident, input.amenityId);

  return {
    amenityId: input.amenityId,
    maxCapacity: amenity.allowMultipleBookings ? amenity.maxCapacity : 1,
    allowMultipleBookings: amenity.allowMultipleBookings,
    dates: buildAvailability({
      amenity,
      bookings,
      days,
      timezoneOffsetMinutes: input.timezoneOffsetMinutes,
      numberOfPeople: input.numberOfPeople,
    }),
  };
}

async function createAmenityBookingCore({ db, auth, data }) {
  if (!auth?.uid) {
    throw new RegistrationError("unauthenticated", "Sign in to continue.");
  }

  const input = validateCreateInput(data);
  const bookingRef = db.collection("bookings").doc();

  return db.runTransaction(async (transaction) => {
    const residentRef = db.collection("users").doc(auth.uid);
    const residentSnapshot = await transaction.get(residentRef);
    const resident = requireActiveResidentProfile(residentSnapshot, auth);

    const amenityRef = db.collection("amenities").doc(input.amenityId);
    const amenitySnapshot = await transaction.get(amenityRef);
    const amenity = requireAmenityData(amenitySnapshot, resident);

    if (!amenity.timeSlots.includes(input.timeSlot)) {
      throw new RegistrationError(
        "failed-precondition",
        "This time slot is no longer available for the facility.",
      );
    }

    if (input.numberOfPeople > amenity.maxCapacity) {
      throw new RegistrationError(
        "failed-precondition",
        "The requested group exceeds this facility's capacity.",
      );
    }

    const selectedDay = dayBounds(input.dateMs, input.timezoneOffsetMinutes);
    if (selectedDay.key < todayKey(input.timezoneOffsetMinutes)) {
      throw new RegistrationError(
        "failed-precondition",
        "Past dates cannot be booked.",
      );
    }

    const bookingsSnapshot = await bookingQuery(
      db,
      input.amenityId,
      selectedDay.startMs,
      selectedDay.endMs,
      transaction,
    );
    const bookings = activeBookingsFromSnapshot(
      bookingsSnapshot,
      resident,
      input.amenityId,
    );
    const availability = availabilityForSlot(
      amenity,
      bookings,
      input.timeSlot,
      input.numberOfPeople,
    );

    if (!availability.available) {
      throw new RegistrationError(
        "failed-precondition",
        availability.reason === "Not enough capacity"
          ? "There is not enough remaining capacity for this time slot."
          : "This time slot has already been booked.",
      );
    }

    const dailyPrice = effectiveDailyPrice(amenity, resident);
    const price = packagePrice(amenity, input.bookingType, dailyPrice);
    const packageData = packageDates(input.dateMs, input.bookingType);

    const flatId = clean(resident.flatId);
    const buildingId = clean(resident.buildingId);
    if (!flatId || !buildingId) {
      throw new RegistrationError(
        "failed-precondition",
        "Your resident unit assignment is incomplete.",
      );
    }

    const bookingData = {
      userId: auth.uid,
      userName: clean(resident.name) || clean(resident.fullName) || "Resident",
      userEmail: clean(resident.email),
      flatId,
      flatLabel: clean(resident.flatLabel) || flatId,
      buildingId,
      organizationId: clean(resident.organizationId) || null,
      communityId: resident.communityId,

      amenityId: input.amenityId,
      amenityName: clean(amenity.name) || "Amenity",

      bookingType: input.bookingType,
      packageType: packageData.packageType,

      date: Timestamp.fromMillis(input.dateMs),
      timeSlot: input.timeSlot,

      subscriptionStartDate: Timestamp.fromMillis(
        packageData.subscriptionStartMs,
      ),
      subscriptionEndDate: Timestamp.fromMillis(
        packageData.subscriptionEndMs,
      ),
      validityDays: packageData.validityDays,

      numberOfPeople: input.numberOfPeople,

      price,
      pricePerDay: dailyPrice,

      status: "confirmed",
      cancellationDate: null,
      cancellationReason: null,

      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    };

    if (input.familyMembers.length > 0) {
      bookingData.familyMembers = input.familyMembers;
    }

    const adminId = clean(amenity.adminId);
    const adminName = clean(amenity.adminName);
    const adminEmail = clean(amenity.adminEmail);
    if (adminId) {
      bookingData.adminId = adminId;
      if (adminName) bookingData.adminName = adminName;
      if (adminEmail) bookingData.adminEmail = adminEmail;
    }

    transaction.create(bookingRef, bookingData);

    return {
      bookingId: bookingRef.id,
      status: "confirmed",
      price,
      pricePerDay: dailyPrice,
      remainingSpotsAfterBooking: amenity.allowMultipleBookings
        ? Math.max(0, availability.remainingSpots - input.numberOfPeople)
        : 0,
    };
  });
}

function validateCancelInput(data) {
  const input = requireObject(data);
  requireAllowedKeys(input, new Set(["bookingId", "reason"]));

  const reason = input.reason == null ? "" : clean(input.reason);
  if (reason.length > 500) {
    throw new RegistrationError(
      "invalid-argument",
      "Cancellation reason is too long.",
    );
  }

  return {
    bookingId: requireDocumentId(input.bookingId, "Booking"),
    reason,
  };
}

async function cancelAmenityBookingCore({ db, auth, data }) {
  if (!auth?.uid) {
    throw new RegistrationError("unauthenticated", "Sign in to continue.");
  }

  const input = validateCancelInput(data);
  const bookingRef = db.collection("bookings").doc(input.bookingId);

  return db.runTransaction(async (transaction) => {
    const residentRef = db.collection("users").doc(auth.uid);
    const residentSnapshot = await transaction.get(residentRef);
    const resident = requireActiveResidentProfile(residentSnapshot, auth);

    const bookingSnapshot = await transaction.get(bookingRef);
    if (!bookingSnapshot.exists) {
      throw new RegistrationError("not-found", "Booking was not found.");
    }

    const booking = bookingSnapshot.data() || {};
    if (
      clean(booking.userId) !== auth.uid ||
      clean(booking.communityId) !== resident.communityId
    ) {
      throw new RegistrationError(
        "permission-denied",
        "You cannot cancel this booking.",
      );
    }

    const status = clean(booking.status).toLowerCase();
    if (status === "cancelled" || status === "canceled") {
      return { bookingId: input.bookingId, status: "cancelled", idempotent: true };
    }
    if (!ACTIVE_BOOKING_STATUSES.has(status)) {
      throw new RegistrationError(
        "failed-precondition",
        "This booking can no longer be cancelled.",
      );
    }

    const update = {
      status: "cancelled",
      cancellationDate: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    };
    if (input.reason) update.cancellationReason = input.reason;

    transaction.update(bookingRef, update);

    return {
      bookingId: input.bookingId,
      status: "cancelled",
      idempotent: false,
    };
  });
}

module.exports = {
  ACTIVE_BOOKING_STATUSES,
  getAmenityAvailabilityCore,
  createAmenityBookingCore,
  cancelAmenityBookingCore,
};
