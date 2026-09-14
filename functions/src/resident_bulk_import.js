const {unitLabel, unitMatchesLabel, hasResidentLink, hasValue, occupancyStats} = require('./unit_schema');
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

async function requireImportAdmin(db, auth, communityId, transaction) {
  const {uid} = verifiedPhoneAuth(auth);
  const read = (ref) => transaction ? transaction.get(ref) : ref.get();
  const adminSnapshot = await read(db.collection("admins").doc(uid));
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
  const communitySnapshot = await read(db.collection("communities").doc(communityId));
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

async function loadTenantData(db, communityId, importJobId, transaction) {
  const read = (query) => transaction ? transaction.get(query) : query.get();
  const [buildings, flats, users, onboarding, importRows] = await Promise.all([
    ...['buildings', 'flats', 'users', 'residentOnboarding'].map((collection) =>
      read(db.collection(collection).where('communityId', '==', communityId))),
    importJobId ? read(db.collection('residentImportRows').where('importJobId', '==', importJobId)) : {docs: []},
  ]);
  return {buildings: buildings.docs.filter((doc) => doc.data().isActive !== false),
    flats: flats.docs, users: users.docs, onboarding: onboarding.docs, importRows: importRows.docs};
}

function userPhone(data) {
  return clean(data?.phoneNumber || data?.phone).replace(/[\s().-]/g, "");
}

function validateNormalizedRows({normalizedRows, tenantData, communityId, importJobId}) {
  const seenPhones = new Set();
  const seenUnits = new Set();
  return normalizedRows.map((row) => {
    if (row.status === 'error') return row;
    const fail = (code, message) => ({...publicError(row.rowNumber, code, message, row), importRowId: rowId});
    const rowId = importJobId ? importRowId(importJobId, row.rowNumber) : null;
    if (seenPhones.has(row.phoneNumber)) return fail('duplicate_in_file', 'This phone number appears more than once in the uploaded file.');
    seenPhones.add(row.phoneNumber);
    const marker = tenantData.importRows.find((doc) => doc.id === rowId)?.data();
    if (marker?.communityId === communityId && marker.status === 'imported') {
      if (marker.canonical && marker.canonical !== row.canonical) return fail('idempotency_conflict', 'This completed row has different contents. Start a new import for an update.');
      return {...row, status: 'already_imported', importRowId: rowId};
    }
    const buildings = tenantData.buildings.filter((doc) => referenceKey(doc.id) === referenceKey(row.building) ||
      referenceKey(doc.data().buildingName || doc.data().name) === referenceKey(row.building));
    if (!buildings.length) return fail('building_not_found', `Building ${row.building} was not found in this community.`);
    if (buildings.length !== 1) return fail('ambiguous_building', 'Multiple buildings use this reference. Resolve the duplicate before importing.');
    const building = buildings[0];
    const matches = tenantData.flats.filter((doc) => doc.data().buildingId === building.id && unitMatchesLabel(doc.data(), row.unit));
    if (!matches.length) {
      const elsewhere = tenantData.flats.some((doc) => doc.data().buildingId !== building.id && unitMatchesLabel(doc.data(), row.unit));
      return fail(elsewhere ? 'wrong_building' : 'unit_not_found', elsewhere
        ? `Unit ${row.unit} exists in another building, not ${row.building}.`
        : `Unit ${row.unit} was not found in ${row.building}.`);
    }
    if (matches.length !== 1) return fail('ambiguous_unit', 'Multiple units use this label. Resolve the duplicate before importing.');
    const flat = matches[0];
    const unit = flat.data();
    if (seenUnits.has(flat.id)) return fail('duplicate_unit_allocation', 'This unit is allocated more than once in this file.');
    const users = tenantData.users.filter((doc) => userPhone(doc.data()) === row.phoneNumber);
    const pending = tenantData.onboarding.filter((doc) => userPhone(doc.data()) === row.phoneNumber);
    if (users.length > 1 || pending.length > 1) return fail('ambiguous_resident', 'Multiple resident records use this phone. Resolve them before importing.');
    const user = users[0];
    const onboarding = pending[0];
    let action = 'reserve_new';
    let targetId;
    if (user) {
      const profile = user.data();
      const {trustedResidentType, resolveFlatOccupant} = require('./resident_identity');
      if (profile.role !== 'resident' || trustedResidentType(profile) !== row.residentType) {
        return fail('resident_already_exists', 'Existing resident role or resident type does not match; use the resident workflow.');
      }
      if (profile.flatId === flat.id && profile.buildingId === building.id) {
        let occupant;
        try { occupant = resolveFlatOccupant(unit).uid; } catch (_) { return fail('unit_relationship_conflict', 'Unit occupant references are ambiguous.'); }
        const ownOccupied = unit.status === 'occupied' && occupant === user.id && profile.isActive === true && profile.approvalStatus === 'approved';
        const ownReservation = unit.status === 'reserved' && !hasResidentLink(unit) &&
          unit.reservedOnboardingId === residentOnboardingId(communityId, row.phoneNumber) && profile.approvalStatus === 'pending';
        if (!ownOccupied && !ownReservation) return fail('unit_relationship_conflict', 'Existing resident allocation does not match the unit state. Use the resident workflow.');
        action = 'update_resident'; targetId = user.id;
      } else if (profile.approvalStatus === 'approved' && profile.isActive === false &&
          profile.status === 'inactive' && profile.occupancyStatus === 'moved_out' && !profile.flatId && !profile.buildingId) {
        const {identityVerificationRequired, identityIsVerified} = require('./resident_identity');
        if (identityVerificationRequired(row.residentType, tenantData.community || {}) && !identityIsVerified(profile)) {
          return fail('identity_required', 'Identity verification is required before reassignment.');
        }
        action = 'reassign'; targetId = user.id;
      } else {
        return fail('resident_already_exists', 'This resident has another allocation. Complete the trusted move-out/reassignment workflow first.');
      }
    } else if (onboarding) {
      const record = onboarding.data();
      if (record.claimedByUid != null || record.status !== 'pending_registration' || record.approvalStatus !== 'pending' || record.residentType !== row.residentType) {
        return fail('pending_registration_exists', 'This onboarding cannot be updated through bulk import.');
      }
      if (record.flatId && (record.flatId !== flat.id || record.buildingId !== building.id)) {
        return fail('pending_registration_exists', 'Cancel the existing reservation before assigning another unit.');
      }
      const ownReservation = unit.status === 'reserved' && !hasResidentLink(unit) && unit.reservedOnboardingId === onboarding.id && record.flatId === flat.id;
      action = ownReservation ? 'update_onboarding' : 'reserve_existing'; targetId = onboarding.id;
    }
    if (!['update_resident', 'update_onboarding'].includes(action)) {
      if (unit.status !== 'vacant' || hasResidentLink(unit) || hasValue(unit.reservedOnboardingId) || unit.isActive === false) {
        return fail(unit.status === 'reserved' ? 'unit_reserved' : unit.status === 'occupied' ? 'unit_occupied' : 'unit_not_assignable',
          `Unit ${row.unit} is ${unit.status === 'reserved' ? 'reserved' : unit.status === 'occupied' ? 'already occupied' : 'not safely vacant'}.`);
      }
    }
    if (tenantData.users.some((doc) => doc.id !== user?.id && doc.data().flatId === flat.id) ||
        tenantData.onboarding.some((doc) => doc.id !== onboarding?.id && doc.data().flatId === flat.id &&
          !(action === 'update_resident' && doc.data().claimedByUid === user.id))) {
      return fail('unit_relationship_conflict', 'Another resident or onboarding record already references this unit.');
    }
    seenUnits.add(flat.id);
    return {...row, status: 'ready', action, targetId, importRowId: rowId,
      buildingId: building.id, buildingName: clean(building.data().buildingName || building.data().name),
      flatId: flat.id, flatLabel: unitLabel(unit), unitId: unitLabel(unit)};
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
  tenantData.community = actor.community;
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

async function commitRow({db, auth, input, row}) {
  const markerRef = db.collection('residentImportRows').doc(row.importRowId);
  // Re-resolve the current names and all allocation conflicts inside every row transaction.
  async function prepare(transaction) {
    const actor = await requireImportAdmin(db, auth, input.communityId, transaction);
    const scoped = (collection) => db.collection(collection).where('communityId', '==', input.communityId);
    const snapshots = await Promise.all([
      transaction.get(scoped('buildings')),
      transaction.get(scoped('flats').where('buildingId', '==', row.buildingId)),
      ...['users', 'residentOnboarding'].flatMap((collection) => ['phoneNumber', 'phone', 'flatId'].map((field) =>
        transaction.get(scoped(collection).where(field, '==', field === 'flatId' ? row.flatId : row.phoneNumber)))),
      transaction.get(markerRef),
    ]);
    const unique = (groups) => [...new Map(groups.flatMap((group) => group.docs).map((doc) => [doc.id, doc])).values()];
    const tenantData = {buildings: snapshots[0].docs.filter((doc) => doc.data().isActive !== false),
      flats: snapshots[1].docs, users: unique(snapshots.slice(2, 5)), onboarding: unique(snapshots.slice(5, 8)),
      importRows: snapshots[8].exists ? [snapshots[8]] : []};
    tenantData.community = actor.community;
    const current = validateNormalizedRows({normalizedRows: [row], tenantData, communityId: input.communityId, importJobId: input.importJobId})[0];
    if (current.status !== 'ready') return {current};
    if (current.flatId !== row.flatId || current.buildingId !== row.buildingId || current.action !== row.action || current.targetId !== row.targetId) {
      return {current: {...publicError(row.rowNumber, 'allocation_changed', 'Allocation changed after validation. Validate this row again.', row), importRowId: row.importRowId}};
    }
    return {current, actor, tenantData};
  }
  function metadata(current) {
    return {residentName: current.residentName, email: current.email, alternatePhone: current.alternatePhone,
      moveInDate: current.moveInDate, updatedAt: FieldValue.serverTimestamp()};
  }
  function writeMarker(transaction, current, actor) {
    transaction.create(markerRef, {communityId: input.communityId, importJobId: input.importJobId,
      canonical: row.canonical, flatId: current.flatId, buildingId: current.buildingId,
      rowNumber: row.rowNumber, status: 'imported', action: current.action,
      createdBy: actor.uid, createdAt: FieldValue.serverTimestamp()});
  }
  if (row.action === 'reassign') {
    // The existing lifecycle still enforces moved-out state and identity verification.
    const {reassignResidentCore} = require('./resident_identity');
    await reassignResidentCore({db, auth,
      data: {communityId: input.communityId, userId: row.targetId, buildingId: row.buildingId, flatId: row.flatId},
      transactionExtras: async (transaction) => {
        const prepared = await prepare(transaction);
        if (prepared.current.status !== 'ready') throw new RegistrationError('failed-precondition', prepared.current.message || 'Row already completed; retry to refresh the result.');
        return () => {
          const {residentName, ...contact} = metadata(prepared.current);
          transaction.update(db.collection('users').doc(row.targetId), {...contact, name: residentName, fullName: residentName});
          writeMarker(transaction, prepared.current, prepared.actor);
        };
      },
    });
    return {...publicRow(row), status: 'imported'};
  }
  return db.runTransaction(async (transaction) => {
    const {current, actor, tenantData} = await prepare(transaction);
    if (current.status !== 'ready') return publicRow(current);
    const timestamp = FieldValue.serverTimestamp();
    const onboardingId = current.targetId || residentOnboardingId(input.communityId, current.phoneNumber);
    const onboardingRef = db.collection('residentOnboarding').doc(onboardingId);
    if (current.action === 'update_resident') {
      const {residentName, ...contact} = metadata(current);
      transaction.update(db.collection('users').doc(current.targetId), {...contact, name: residentName, fullName: residentName});
      const flat = tenantData.flats.find((doc) => doc.id === current.flatId).data();
      transaction.update(db.collection('flats').doc(current.flatId), {
        [flat.status === 'occupied' ? 'residentName' : 'reservedForName']: residentName, updatedAt: timestamp,
      });
    } else {
      const references = {buildingId: current.buildingId, buildingName: current.buildingName,
        buildingReference: current.buildingName, flatId: current.flatId, unitId: current.flatLabel,
        flatLabel: current.flatLabel, unitReference: current.flatLabel};
      if (current.action === 'reserve_new') {
        transaction.create(onboardingRef, {...metadata(current), ...references,
          communityId: input.communityId, phoneNumber: current.phoneNumber, countryCode: current.countryCode,
          residentType: current.residentType, ownershipType: current.residentType, role: 'resident',
          approvalStatus: 'pending', isActive: false, identityVerified: false, identityVerificationStatus: 'verification_required',
          status: 'pending_registration', claimedByUid: null, importJobId: input.importJobId, importRowId: row.importRowId,
          creationSource: 'admin_bulk_import', createdBy: actor.uid, createdAt: timestamp});
      } else transaction.update(onboardingRef, {...metadata(current), ...references});
      if (['reserve_new', 'reserve_existing'].includes(current.action)) {
        transaction.update(db.collection('flats').doc(current.flatId), {status: 'reserved',
          reservedOnboardingId: onboardingId, reservedForName: current.residentName,
          reservedResidentType: current.residentType, reservedBy: actor.uid, reservedAt: timestamp, updatedAt: timestamp});
        const units = tenantData.flats.filter((doc) => doc.data().buildingId === current.buildingId);
        transaction.update(db.collection('buildings').doc(current.buildingId), {
          ...occupancyStats(units, new Map([[current.flatId, 'reserved']])), updatedAt: timestamp});
      } else {
        transaction.update(db.collection('flats').doc(current.flatId), {reservedForName: current.residentName, updatedAt: timestamp});
      }
    }
    writeMarker(transaction, current, actor);
    return {...publicRow(current), status: 'imported'};
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
        output[index] = {...publicError(items[index].rowNumber, error.code || "row_write_failed",
          error instanceof RegistrationError ? error.message : "This row could not be imported. It is safe to retry.", items[index]), importRowId: items[index].importRowId};
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
  const committed = await mapLimited(readyRows, 10, (row) => commitRow({db, auth: args.auth, input, row}));
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
  validateNormalizedRows,
  commitRow,
  validateResidentBulkImportCore,
  importResidentsBulkCore,
};
