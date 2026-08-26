const {FieldValue} = require("firebase-admin/firestore");
const {parsePhoneNumberFromString} = require("libphonenumber-js/max");
const {RegistrationError, verifiedPhoneAuth} = require("./register_resident");
const {importRowId, residentOnboardingId} = require("./resident_import_ids");

const MAX_ROWS = 500;
const REQUIRED_ROW_KEYS = ["building", "unit", "residentName", "phoneNumber", "residentType"];
const ALLOWED_ROW_KEYS = new Set([
  ...REQUIRED_ROW_KEYS,
  "rowNumber",
  "email",
  "countryCode",
  "alternatePhone",
  "moveInDate",
]);
const TOP_LEVEL_KEYS = new Set(["communityId", "sourceFileName", "importJobId", "rows"]);

const clean = (value) => String(value ?? "").trim();
const referenceKey = (value) => clean(value).toLocaleLowerCase("en").replace(/\s+/g, " ");
const validCountryCode = (value) => {
  const code = clean(value).toUpperCase();
  return /^[A-Z]{2}$/.test(code) ? code : null;
};
const publicError = (rowNumber, code, message, source = {}) => ({
  rowNumber,
  residentName: clean(source.residentName).slice(0, 120),
  phoneNumber: clean(source.phoneNumber).slice(0, 32),
  building: clean(source.building).slice(0, 120),
  unit: clean(source.unit).slice(0, 120),
  residentType: clean(source.residentType).slice(0, 20),
  status: "error",
  code,
  message,
});

function assertPlainObject(value, message) {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    throw new RegistrationError("invalid-argument", message);
  }
}

function validatePayload(data, {requireJobId = false} = {}) {
  assertPlainObject(data, "A bulk import payload is required.");
  if (Object.keys(data).some((key) => !TOP_LEVEL_KEYS.has(key))) {
    throw new RegistrationError("invalid-argument", "Unsupported bulk import field.");
  }
  const communityId = clean(data.communityId);
  if (!communityId || communityId.length > 128) {
    throw new RegistrationError("invalid-argument", "A valid communityId is required.");
  }
  if (!Array.isArray(data.rows) || data.rows.length < 1) {
    throw new RegistrationError("invalid-argument", "At least one resident row is required.");
  }
  if (data.rows.length > MAX_ROWS) {
    throw new RegistrationError("invalid-argument", `A maximum of ${MAX_ROWS} rows may be imported at once.`);
  }
  const sourceFileName = clean(data.sourceFileName);
  if (sourceFileName.length > 180) {
    throw new RegistrationError("invalid-argument", "The source file name is too long.");
  }
  const importJobId = clean(data.importJobId);
  if ((requireJobId || importJobId) && !/^[A-Za-z0-9_-]{12,100}$/.test(importJobId)) {
    throw new RegistrationError("invalid-argument", "A valid importJobId is required for retry safety.");
  }
  const suppliedRowNumbers = new Set();
  data.rows.forEach((row) => {
    assertPlainObject(row, "Every imported row must be an object.");
    if (Object.keys(row).some((key) => !ALLOWED_ROW_KEYS.has(key))) {
      throw new RegistrationError("invalid-argument", "An imported row contains unsupported fields.");
    }
    if (Object.hasOwn(row, "rowNumber")) {
      if (!Number.isInteger(row.rowNumber) || row.rowNumber < 2 || suppliedRowNumbers.has(row.rowNumber)) {
        throw new RegistrationError("invalid-argument", "Every supplied rowNumber must be a unique integer of 2 or greater.");
      }
      suppliedRowNumbers.add(row.rowNumber);
    }
  });
  return {communityId, rows: data.rows, sourceFileName: sourceFileName || null, importJobId};
}

async function requireImportAdmin(db, auth, communityId) {
  const {uid} = verifiedPhoneAuth(auth);
  const adminSnapshot = await db.collection("admins").doc(uid).get();
  const admin = adminSnapshot.data();
  const ids = admin?.authorizedCommunityIds;
  if (!adminSnapshot.exists || admin?.uid !== uid || admin?.role !== "admin" ||
      admin?.isActive !== true || !Array.isArray(ids) || ids.length < 1 ||
      ids.some((id) => typeof id !== "string" || !id.trim())) {
    throw new RegistrationError("permission-denied", "An active operational Admin profile is required.");
  }
  if (!ids.includes(communityId)) {
    throw new RegistrationError("permission-denied", "This Admin is not authorized for the requested community.");
  }
  const communitySnapshot = await db.collection("communities").doc(communityId).get();
  const community = communitySnapshot.data();
  if (!communitySnapshot.exists || community?.isActive !== true) {
    throw new RegistrationError("failed-precondition", "The requested community is inactive or unavailable.");
  }
  return {uid, community};
}

function checkedText(value, {field, min = 0, max}) {
  const result = clean(value);
  if (result.length < min || result.length > max) {
    throw Object.assign(new Error(`${field} is invalid.`), {rowCode: `invalid_${field}`});
  }
  if (/^[=@]/.test(result)) {
    throw Object.assign(new Error(`${field} cannot begin with a spreadsheet formula marker.`), {rowCode: "unsafe_formula_value"});
  }
  return result;
}

function normalizePhone(value, countryCode) {
  const raw = clean(value).replace(/[\s().-]/g, "");
  if (!raw) throw Object.assign(new Error("Phone number is required."), {rowCode: "invalid_phone_number"});
  if (!raw.startsWith("+") && !countryCode) {
    throw Object.assign(new Error("A countryCode is required for a national phone number."), {rowCode: "missing_country_context"});
  }
  const parsed = parsePhoneNumberFromString(raw, raw.startsWith("+") ? undefined : countryCode);
  if (!parsed || !parsed.isValid()) {
    throw Object.assign(new Error("Enter a valid phone number."), {rowCode: "invalid_phone_number"});
  }
  return parsed.number;
}

function normalizeRow(row, index, communityCountryCode) {
  const rowNumber = Number.isInteger(row.rowNumber) && row.rowNumber > 0 ? row.rowNumber : index + 2;
  try {
    const residentName = checkedText(row.residentName, {field: "resident_name", min: 2, max: 120});
    const building = checkedText(row.building, {field: "building", min: 1, max: 120});
    const unit = checkedText(row.unit, {field: "unit", min: 1, max: 120});
    const residentType = clean(row.residentType).toLowerCase();
    if (!new Set(["owner", "tenant"]).has(residentType)) {
      throw Object.assign(new Error("residentType must be owner or tenant."), {rowCode: "invalid_resident_type"});
    }
    const suppliedCountry = clean(row.countryCode);
    const countryCode = suppliedCountry ? validCountryCode(suppliedCountry) : communityCountryCode;
    if (suppliedCountry && !countryCode) {
      throw Object.assign(new Error("countryCode must be a two-letter ISO code."), {rowCode: "invalid_country_code"});
    }
    const phoneNumber = normalizePhone(row.phoneNumber, countryCode);
    const alternatePhone = clean(row.alternatePhone) ? normalizePhone(row.alternatePhone, countryCode) : null;
    const email = clean(row.email).toLowerCase() || null;
    if (email && (email.length > 254 || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email))) {
      throw Object.assign(new Error("Enter a valid email address."), {rowCode: "invalid_email"});
    }
    const moveInDate = clean(row.moveInDate) || null;
    if (moveInDate && (!/^\d{4}-\d{2}-\d{2}$/.test(moveInDate) || Number.isNaN(Date.parse(`${moveInDate}T00:00:00Z`)))) {
      throw Object.assign(new Error("moveInDate must use YYYY-MM-DD."), {rowCode: "invalid_move_in_date"});
    }
    const canonical = JSON.stringify({residentName, phoneNumber, building: referenceKey(building), unit: referenceKey(unit), residentType, email, alternatePhone, moveInDate});
    return {rowNumber, residentName, phoneNumber, countryCode, alternatePhone, email, moveInDate, residentType, building, unit, canonical};
  } catch (error) {
    return publicError(rowNumber, error.rowCode ?? "invalid_row", error.message ?? "The row is invalid.", row);
  }
}

function aliases(document, fields) {
  const result = new Set([referenceKey(document.id)]);
  const data = document.data();
  fields.forEach((field) => {
    const value = data?.[field];
    if (value != null && clean(value)) result.add(referenceKey(value));
  });
  return result;
}

function exactMatches(documents, value, fields) {
  const key = referenceKey(value);
  return documents.filter((document) => aliases(document, fields).has(key));
}

async function loadTenantData(db, communityId, importJobId) {
  const [buildings, flats, users, onboarding, importRows] = await Promise.all([
    db.collection("buildings").where("communityId", "==", communityId).get(),
    db.collection("flats").where("communityId", "==", communityId).get(),
    db.collection("users").where("communityId", "==", communityId).get(),
    db.collection("residentOnboarding").where("communityId", "==", communityId).get(),
    importJobId
      ? db.collection("residentImportRows").where("importJobId", "==", importJobId).get()
      : Promise.resolve({docs: []}),
  ]);
  return {
    buildings: buildings.docs.filter((doc) => doc.data()?.isActive !== false),
    flats: flats.docs.filter((doc) => doc.data()?.isActive !== false),
    users: users.docs,
    onboarding: onboarding.docs,
    importRows: importRows.docs,
  };
}

function userPhone(data) {
  return clean(data?.phoneNumber || data?.phone).replace(/[\s().-]/g, "");
}

function validateNormalizedRows({normalizedRows, tenantData, communityId, importJobId}) {
  const seenPhones = new Set();
  const seenRows = new Set();
  const seenResidentUnits = new Set();
  const seenOwnerFlats = new Set();
  const existingPhones = new Set(tenantData.users.map((doc) => userPhone(doc.data())).filter(Boolean));
  const onboardingByPhone = new Map(tenantData.onboarding.map((doc) => [userPhone(doc.data()), doc.data()]));
  const ownerByFlat = new Map();
  const importedRowIds = new Set(
    tenantData.importRows
      .filter((doc) => doc.data()?.communityId === communityId && doc.data()?.status === "imported")
      .map((doc) => doc.id),
  );
  tenantData.users.forEach((doc) => {
    const data = doc.data();
    if (clean(data?.ownershipType).toLowerCase() === "owner" && clean(data?.flatId)) ownerByFlat.set(clean(data.flatId), doc.id);
  });
  tenantData.onboarding.forEach((doc) => {
    const data = doc.data();
    if (clean(data?.residentType).toLowerCase() === "owner" && clean(data?.flatId)) ownerByFlat.set(clean(data.flatId), doc.id);
  });

  return normalizedRows.map((row) => {
    if (row.status === "error") return row;
    const rowId = importJobId ? importRowId(importJobId, row.rowNumber) : null;
    if (rowId && importedRowIds.has(rowId)) {
      return {...row, status: "already_imported", importRowId: rowId};
    }
    if (seenRows.has(row.canonical)) return publicError(row.rowNumber, "duplicate_in_file", "This row is duplicated in the uploaded file.", row);
    seenRows.add(row.canonical);
    if (seenPhones.has(row.phoneNumber)) return publicError(row.rowNumber, "duplicate_in_file", "This phone number appears more than once in the uploaded file.", row);
    seenPhones.add(row.phoneNumber);

    const buildings = exactMatches(tenantData.buildings, row.building, ["buildingId", "buildingName", "name"]);
    if (buildings.length === 0) return publicError(row.rowNumber, "building_not_found", "No exact building match exists in this community.", row);
    if (buildings.length > 1) return publicError(row.rowNumber, "ambiguous_building", "More than one building has this reference.", row);
    const building = buildings[0];
    const flatsInBuilding = tenantData.flats.filter((doc) => clean(doc.data()?.buildingId) === building.id || clean(doc.data()?.buildingId) === clean(building.data()?.buildingId));
    const flats = exactMatches(flatsInBuilding, row.unit, ["flatId", "flatLabel", "unitId", "unitNumber", "flatNumber"]);
    if (flats.length === 0) return publicError(row.rowNumber, "unit_not_found", "No exact unit match exists in the selected building.", row);
    if (flats.length > 1) return publicError(row.rowNumber, "ambiguous_unit", "More than one unit has this reference in the selected building.", row);
    const flat = flats[0];
    const residentUnitKey = `${referenceKey(row.residentName)}\n${flat.id}`;
    if (seenResidentUnits.has(residentUnitKey)) return publicError(row.rowNumber, "duplicate_in_file", "This resident and unit combination is duplicated.", row);
    seenResidentUnits.add(residentUnitKey);
    if (existingPhones.has(row.phoneNumber)) return publicError(row.rowNumber, "resident_already_exists", "A resident with this phone already exists in this community.", row);
    const pending = onboardingByPhone.get(row.phoneNumber);
    if (pending) {
      if (importJobId && pending.importJobId === importJobId && pending.importRowId === rowId) {
        return {...row, status: "already_imported", importRowId: rowId, buildingId: building.id, buildingName: clean(building.data()?.name || building.data()?.buildingName), flatId: flat.id, unitId: clean(flat.data()?.unitId || flat.data()?.flatId || flat.id), flatLabel: clean(flat.data()?.flatLabel || flat.data()?.flatId || flat.data()?.flatNumber || row.unit)};
      }
      return publicError(row.rowNumber, "pending_registration_exists", "A pending imported registration already uses this phone in this community.", row);
    }
    if (row.residentType === "owner" && (ownerByFlat.has(flat.id) || seenOwnerFlats.has(flat.id))) return publicError(row.rowNumber, "unit_relationship_conflict", "This unit already has a different owner resident.", row);
    if (row.residentType === "owner") seenOwnerFlats.add(flat.id);
    return {...row, status: "ready", importRowId: rowId, buildingId: building.id, buildingName: clean(building.data()?.name || building.data()?.buildingName), flatId: flat.id, unitId: clean(flat.data()?.unitId || flat.data()?.flatId || flat.id), flatLabel: clean(flat.data()?.flatLabel || flat.data()?.flatId || flat.data()?.flatNumber || row.unit)};
  });
}

function summary(rows) {
  return rows.reduce((result, row) => {
    result.totalRows += 1;
    if (row.status === "ready") result.validRows += 1;
    else if (row.status === "already_imported") result.alreadyImportedRows += 1;
    else result.errorRows += 1;
    return result;
  }, {totalRows: 0, validRows: 0, errorRows: 0, alreadyImportedRows: 0});
}

async function prepareValidation({db, auth, data, requireJobId = false}) {
  const input = validatePayload(data, {requireJobId});
  const actor = await requireImportAdmin(db, auth, input.communityId);
  const communityCountryCode = validCountryCode(actor.community?.phoneCountryCode || actor.community?.countryCode);
  const normalizedRows = input.rows.map((row, index) => normalizeRow(row, index, communityCountryCode));
  const tenantData = await loadTenantData(db, input.communityId, input.importJobId);
  const rows = validateNormalizedRows({normalizedRows, tenantData, communityId: input.communityId, importJobId: input.importJobId});
  return {input, actor, rows};
}

async function validateResidentBulkImportCore(args) {
  const prepared = await prepareValidation(args);
  return {communityId: prepared.input.communityId, rows: prepared.rows.map(publicRow), summary: summary(prepared.rows)};
}

function publicRow(row) {
  const {canonical, ...result} = row;
  return result;
}

async function commitRow({db, input, actor, row}) {
  const markerRef = db.collection("residentImportRows").doc(row.importRowId);
  const onboardingRef = db.collection("residentOnboarding").doc(residentOnboardingId(input.communityId, row.phoneNumber));
  return db.runTransaction(async (transaction) => {
    const [markerSnapshot, onboardingSnapshot] = await Promise.all([
      transaction.get(markerRef),
      transaction.get(onboardingRef),
    ]);
    if (markerSnapshot.exists) {
      const marker = markerSnapshot.data();
      if (marker?.communityId === input.communityId && marker?.importJobId === input.importJobId && marker?.status === "imported") {
        return {...publicRow(row), status: "already_imported"};
      }
      return publicError(row.rowNumber, "idempotency_conflict", "This import row identifier is already in use.", row);
    }
    if (onboardingSnapshot.exists) {
      const pending = onboardingSnapshot.data();
      if (pending?.communityId === input.communityId && pending?.importJobId === input.importJobId && pending?.importRowId === row.importRowId) {
        return {...publicRow(row), status: "already_imported"};
      }
      return publicError(row.rowNumber, "pending_registration_exists", "A pending imported registration already uses this phone in this community.", row);
    }
    transaction.create(onboardingRef, {
      communityId: input.communityId,
      residentName: row.residentName,
      phoneNumber: row.phoneNumber,
      alternatePhone: row.alternatePhone,
      email: row.email,
      countryCode: row.countryCode,
      moveInDate: row.moveInDate,
      residentType: row.residentType,
      ownershipType: row.residentType,
      buildingId: row.buildingId,
      buildingName: row.buildingName,
      buildingReference: row.building,
      flatId: row.flatId,
      unitId: row.unitId,
      flatLabel: row.flatLabel,
      unitReference: row.unit,
      role: "resident",
      approvalStatus: "pending",
      isActive: false,
      identityVerified: false,
      identityVerificationStatus: "verification_required",
      status: "pending_registration",
      claimedByUid: null,
      importJobId: input.importJobId,
      importRowId: row.importRowId,
      creationSource: "admin_bulk_import",
      createdBy: actor.uid,
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });
    transaction.create(markerRef, {
      communityId: input.communityId,
      importJobId: input.importJobId,
      onboardingId: onboardingRef.id,
      rowNumber: row.rowNumber,
      status: "imported",
      createdBy: actor.uid,
      createdAt: FieldValue.serverTimestamp(),
    });
    return {...publicRow(row), status: "imported"};
  });
}

async function mapLimited(items, limit, action) {
  const output = new Array(items.length);
  let cursor = 0;
  async function worker() {
    while (cursor < items.length) {
      const index = cursor++;
      try {
        output[index] = await action(items[index]);
      } catch (error) {
        console.error("Resident bulk import row failed.", {rowNumber: items[index].rowNumber, error});
        output[index] = publicError(items[index].rowNumber, "row_write_failed", "This row could not be imported. It is safe to retry.", items[index]);
      }
    }
  }
  await Promise.all(Array.from({length: Math.min(limit, items.length)}, worker));
  return output;
}

async function importResidentsBulkCore(args) {
  const prepared = await prepareValidation({...args, requireJobId: true});
  const {db} = args;
  const {input, actor} = prepared;
  const jobRef = db.collection("residentImportJobs").doc(input.importJobId);
  const currentJob = await jobRef.get();
  if (currentJob.exists) {
    const current = currentJob.data();
    if (current?.communityId !== input.communityId || current?.createdByAdminUid !== actor.uid) {
      throw new RegistrationError("permission-denied", "The importJobId belongs to another tenant or Admin.");
    }
    if (!Array.isArray(current.rowNumbers) ||
        prepared.rows.some((row) => !current.rowNumbers.includes(row.rowNumber))) {
      throw new RegistrationError("failed-precondition", "Retry rows must belong to the original import job.");
    }
  } else {
    await jobRef.create({
      communityId: input.communityId,
      createdByAdminUid: actor.uid,
      createdAt: FieldValue.serverTimestamp(),
      sourceFileName: input.sourceFileName,
      totalRows: input.rows.length,
      rowNumbers: prepared.rows.map((row) => row.rowNumber),
      validRows: prepared.rows.filter((row) => row.status === "ready").length,
      successCount: 0,
      failedCount: prepared.rows.filter((row) => row.status === "error").length,
      status: "processing",
    });
  }
  const readyRows = prepared.rows.filter((row) => row.status === "ready");
  const committed = await mapLimited(readyRows, 10, (row) => commitRow({db, input, actor, row}));
  const byImportRowId = new Map(committed.map((row) => [row.importRowId, row]));
  const results = prepared.rows.map((row) => byImportRowId.get(row.importRowId) ?? publicRow(row));
  const importedMarkers = await db.collection("residentImportRows")
    .where("importJobId", "==", input.importJobId).get();
  const job = (await jobRef.get()).data();
  const totalRows = Number.isInteger(job?.totalRows) ? job.totalRows : input.rows.length;
  const jobSuccessCount = importedMarkers.docs.filter((doc) => doc.data()?.status === "imported").length;
  const jobFailedCount = Math.max(0, totalRows - jobSuccessCount);
  await jobRef.update({
    successCount: jobSuccessCount,
    failedCount: jobFailedCount,
    status: jobFailedCount === 0 ? "completed" : jobSuccessCount > 0 ? "completed_with_errors" : "failed",
    completedAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  });
  const successCount = results.filter((row) => row.status === "imported" || row.status === "already_imported").length;
  const failedCount = results.filter((row) => row.status === "error").length;
  return {importJobId: input.importJobId, communityId: input.communityId, rows: results, summary: {totalRows: results.length, successCount, failedCount}};
}

module.exports = {
  MAX_ROWS,
  ALLOWED_ROW_KEYS,
  normalizePhone,
  normalizeRow,
  validatePayload,
  requireImportAdmin,
  validateResidentBulkImportCore,
  importResidentsBulkCore,
};
