const {FieldValue} = require("firebase-admin/firestore");
const {RegistrationError} = require("./register_resident");
const {requireOperationalAdmin} = require("./resident_identity");
const {STRUCTURE_TYPES, UNIT_TYPES, structureType, defaultUnitType, normalizeLabel} = require('./unit_schema');

const clean = (value) => typeof value === "string" ? value.trim() : "";
const bhkTypes = new Set(["1BHK", "2BHK", "3BHK", "4BHK", "5BHK"]);
const areas = {"1BHK": "650 Sqft", "2BHK": "1200 Sqft", "3BHK": "1800 Sqft", "4BHK": "2400 Sqft", "5BHK": "3000 Sqft"};
const position = (floor, number) => `${floor}:${number}`;
const present = (value) => value != null && (typeof value !== "string" || value.trim() !== "");
const label = (flat) => clean(flat.data.flatLabel) || clean(flat.data.flatId) || flat.id;

function validateInput(data) {
  const allowed = new Set(["communityId", "buildingId", "name", "floors", "flatsPerFloor", "totalFlats", "flatBhkConfig", "structureType", "unitType"]);
  if (!data || typeof data !== "object" || Array.isArray(data) ||
      Object.keys(data).some((key) => !allowed.has(key))) {
    throw new RegistrationError("invalid-argument", "Invalid building edit request.");
  }
  const input = {...data, communityId: clean(data.communityId), buildingId: clean(data.buildingId), name: clean(data.name)};
  if (input.structureType != null && !STRUCTURE_TYPES.includes(input.structureType) ||
      input.unitType != null && !UNIT_TYPES.includes(input.unitType)) {
    throw new RegistrationError('invalid-argument', 'Unsupported housing structure or unit type.');
  }
  if (input.structureType != null && input.structureType !== 'apartment_building') {
    input.floors = 1;
    input.flatsPerFloor = input.totalFlats;
  }
  if (!input.communityId || !input.buildingId || /\//.test(input.communityId + input.buildingId) ||
      input.name.length < 2 || input.name.length > 200 ||
      !Number.isSafeInteger(input.floors) || input.floors < 1 ||
      !Number.isSafeInteger(input.flatsPerFloor) || input.flatsPerFloor < 1 ||
      input.totalFlats !== input.floors * input.flatsPerFloor || input.totalFlats > 499) {
    throw new RegistrationError("invalid-argument", "Enter a building name and positive dimensions with at most 499 units.");
  }
  const config = input.flatBhkConfig;
  if (!config || typeof config !== "object" || Array.isArray(config) ||
      Object.entries(config).some(([key, value]) => !key || !bhkTypes.has(value))) {
    throw new RegistrationError("invalid-argument", "Invalid unit configuration.");
  }
  return input;
}

// Config keys are doc:<canonical document ID> for survivors and pos:<floor>:<number>
// for new apartment units, index:<unitIndex> for new cluster units.
// Visible names are never identity or configuration keys.
function planReconciliation(input, flats, building = {}) {
  const nextStructure = input.structureType || structureType(building);
  const clustered = nextStructure !== 'apartment_building';
  const wasClustered = structureType(building) !== 'apartment_building';
  const converting = clustered !== wasClustered;
  const existingTypes = new Set(flats.map((flat) => flat.data.unitType || 'apartment'));
  const additionUnitType = input.unitType || (nextStructure === structureType(building) && existingTypes.size === 1 && UNIT_TYPES.includes([...existingTypes][0]) ? [...existingTypes][0] : defaultUnitType(nextStructure));
  const originalFlats = new Map(flats.map((flat) => [flat.id, flat.data]));
  if (converting && input.totalFlats !== flats.length) {
    throw new RegistrationError('failed-precondition', 'Change structure type with the current unit count first, then edit the layout.');
  }
  if (clustered) input = {...input, floors: 1, flatsPerFloor: input.totalFlats};
  flats = flats.map((flat) => {
    let index = flat.data.unitIndex;
    if (converting && !wasClustered) {
      if (!Number.isSafeInteger(flat.data.floor) || flat.data.floor < 1 || flat.data.floor > building.floors ||
          !Number.isSafeInteger(flat.data.flatNumber) || flat.data.flatNumber < 1 || flat.data.flatNumber > building.flatsPerFloor) {
        throw new RegistrationError('failed-precondition', 'Existing apartment positions are ambiguous.');
      }
      index = (flat.data.floor - 1) * building.flatsPerFloor + flat.data.flatNumber;
    }
    if (clustered || wasClustered) {
      if (!Number.isSafeInteger(index) || index < 1 || converting && index > input.totalFlats) {
        throw new RegistrationError('failed-precondition', 'Existing unit indexes are missing or ambiguous.');
      }
      return {...flat, data: {...flat.data, unitIndex: index,
        floor: clustered ? 1 : Math.floor((index - 1) / input.flatsPerFloor) + 1,
        flatNumber: clustered ? index : (index - 1) % input.flatsPerFloor + 1}};
    }
    return flat;
  });
  const byPosition = new Map();
  for (const flat of flats) {
    const {floor, flatNumber, communityId, buildingId} = flat.data;
    if (communityId !== input.communityId || buildingId !== input.buildingId) {
      throw new RegistrationError("failed-precondition", "Building contains units with inconsistent community references.");
    }
    const key = position(floor, flatNumber);
    if (!Number.isSafeInteger(floor) || floor < 1 || !Number.isSafeInteger(flatNumber) || flatNumber < 1 || byPosition.has(key)) {
      throw new RegistrationError("failed-precondition", "Unit positions are missing or ambiguous. Correct floor and flatNumber before editing this building.");
    }
    byPosition.set(key, flat);
  }
  const removed = flats.filter(({data}) => data.floor > input.floors || data.flatNumber > input.flatsPerFloor);
  const conflicts = removed.filter(({data}) =>
    !["vacant", "maintenance"].includes(clean(data.status).toLowerCase()) ||
    ["residentUserId", "residentId", "residentUid", "reservedOnboardingId"].some((key) => present(data[key])) ||
    (data.residentIds != null && (!Array.isArray(data.residentIds) || data.residentIds.length > 0)));
  if (conflicts.length) {
    throw new RegistrationError("failed-precondition", `Cannot reduce building layout. Units ${conflicts.map(label).join(", ")} are occupied or reserved, or cannot be confirmed unused.`);
  }
  const removedIds = new Set(removed.map((flat) => flat.id));
  const survivors = flats.filter((flat) => !removedIds.has(flat.id));
  const validConfigKeys = new Set(survivors.map((flat) => `doc:${flat.id}`));
  const additions = [];
  const usedLabels = new Set(flats.flatMap(({data}) => [data.flatLabel, data.flatId, data.unitId].map(normalizeLabel).filter(Boolean)));
  let labelNumber = 1;
  for (let floor = 1; floor <= input.floors; floor++) {
    for (let flatNumber = 1; flatNumber <= input.flatsPerFloor; flatNumber++) {
      if (byPosition.has(position(floor, flatNumber))) continue;
      const configKey = clustered ? `index:${flatNumber}` : `pos:${position(floor, flatNumber)}`;
      validConfigKeys.add(configKey);
      let flatLabel;
      do {
        const prefix = {villa_cluster: 'Villa-', row_house_cluster: 'RH-', townhouse_cluster: 'TH-'}[nextStructure] || (clustered ? 'Unit-' : input.name[0].toUpperCase());
        flatLabel = `${prefix}${String(labelNumber++).padStart(clustered ? 2 : 3, "0")}`;
      } while (usedLabels.has(normalizeLabel(flatLabel)));
      usedLabels.add(normalizeLabel(flatLabel));
      const type = input.flatBhkConfig[configKey] || "2BHK";
      additions.push({floor: clustered ? 0 : floor, flatNumber,
        ...(clustered ? {unitIndex: flatNumber} : {}),
        unitType: additionUnitType, unitLabelNormalized: normalizeLabel(flatLabel), flatLabel, flatId: flatLabel, type, bhkType: type, area: areas[type], status: "vacant"});
    }
  }
  for (const key of Object.keys(input.flatBhkConfig)) {
    if (!validConfigKeys.has(key)) {
      throw new RegistrationError("failed-precondition", "Unit configuration is stale or invalid. Reopen the building and try again.");
    }
  }
  const updates = survivors.map((flat) => {
    const changes = {};
    if (converting) {
      changes.floor = clustered ? 0 : flat.data.floor;
      changes.flatNumber = flat.data.flatNumber;
      changes.unitIndex = clustered ? flat.data.unitIndex : FieldValue.delete();
    }
    if (input.unitType && originalFlats.get(flat.id).unitType !== input.unitType) changes.unitType = input.unitType;
    if (flat.data.buildingName !== input.name) changes.buildingName = input.name;
    const type = input.flatBhkConfig[`doc:${flat.id}`];
    if (type && (flat.data.type !== type || flat.data.bhkType !== type)) {
      changes.type = type;
      changes.bhkType = type;
    }
    return {id: flat.id, changes};
  }).filter(({changes}) => Object.keys(changes).length);
  const stats = {totalFlats: survivors.length + additions.length, occupied: 0, reserved: 0, vacant: 0, maintenance: 0};
  for (const flat of [...survivors.map(({data}) => data), ...additions]) {
    const status = clean(flat.status).toLowerCase();
    stats[["occupied", "reserved", "vacant", "maintenance"].includes(status) ? status : "maintenance"]++;
  }
  stats.occupancyRate = stats.totalFlats ? Math.round(stats.occupied / stats.totalFlats * 100) : 0;
  return {removed, additions, updates, stats};
}

async function reconcileBuildingCore({db, auth, data}) {
  const validated = validateInput(data);
  return db.runTransaction(async (transaction) => {
    let input = {...validated};
    // Authorization is read in the same transaction, including revocation/tenant state.
    await requireOperationalAdmin(db, auth, input.communityId, transaction);
    const buildingRef = db.collection("buildings").doc(input.buildingId);
    const buildingSnapshot = await transaction.get(buildingRef);
    if (!buildingSnapshot.exists) throw new RegistrationError("not-found", "Building not found.");
    const building = buildingSnapshot.data();
    if (building.communityId !== input.communityId) {
      throw new RegistrationError("permission-denied", "Building is outside the selected community.");
    }
    if (!input.structureType) input.structureType = structureType(building);
    if (input.structureType !== structureType(building) && !input.unitType) input.unitType = defaultUnitType(input.structureType);
    // Server transaction query reads protect the full set, not a client-side snapshot.
    const flatsSnapshot = await transaction.get(db.collection("flats").where("buildingId", "==", input.buildingId));
    const plan = planReconciliation(input, flatsSnapshot.docs.map((doc) => ({id: doc.id, data: doc.data()})), building);
    const writes = [];
    const timestamp = FieldValue.serverTimestamp();
    const clustered = input.structureType !== 'apartment_building';
    const summary = {buildingName: input.name, structureType: input.structureType,
      floors: clustered ? 0 : input.floors, flatsPerFloor: clustered ? 0 : input.flatsPerFloor, ...plan.stats};
    writes.push({kind: "update", ref: buildingRef, data: {...summary, name: input.name, updatedAt: timestamp}});
    for (const flat of plan.removed) writes.push({kind: "delete", ref: db.collection("flats").doc(flat.id)});
    for (const update of plan.updates) {
      // Patch only explicit changes: preserve labels, IDs, timestamps, and all links.
      writes.push({kind: "update", ref: db.collection("flats").doc(update.id), data: update.changes});
    }
    for (const flat of plan.additions) {
      const ref = db.collection("flats").doc();
      writes.push({kind: "create", ref, data: {
        ...flat, id: ref.id, buildingId: input.buildingId, buildingName: input.name,
        communityId: input.communityId, adminId: building.adminId || auth.uid,
        residentName: null, residentId: null, residentUserId: null, reservedOnboardingId: null,
        createdAt: timestamp, updatedAt: timestamp,
      }});
    }
    // Keep current references synchronized; historical previousBuildingName stays historical.
    if (building.name !== input.name || building.buildingName !== input.name) {
      for (const collection of ["users", "residentOnboarding"]) {
        const snapshot = await transaction.get(db.collection(collection)
          .where("communityId", "==", input.communityId).where("buildingId", "==", input.buildingId));
        for (const doc of snapshot.docs) {
          const current = doc.data();
          const changes = {};
          if (current.buildingName !== input.name) changes.buildingName = input.name;
          if (collection === "residentOnboarding" && current.buildingReference !== input.name) changes.buildingReference = input.name;
          if (Object.keys(changes).length) writes.push({kind: "update", ref: doc.ref, data: changes});
        }
      }
    }
    if (clean(building.adminId)) {
      const ref = db.collection("admins").doc(building.adminId);
      const snapshot = await transaction.get(ref);
      const admin = snapshot.data();
      if (snapshot.exists && Array.isArray(admin.buildings)) {
        const existing = admin.buildings.find((entry) => entry?.buildingId === input.buildingId);
        if (existing) {
          const buildings = admin.buildings.map((entry) => entry?.buildingId === input.buildingId ? {...entry, ...summary} : entry);
          const changes = {buildings, updatedAt: timestamp};
          if (Array.isArray(admin.buildingNames)) {
            // Preserve unrelated entries, including another building with the old name.
            const names = admin.buildingNames.filter((name) => name !== existing.buildingName ||
              buildings.some((entry) => entry?.buildingName === name));
            changes.buildingNames = [...new Set([...names, input.name])];
          }
          writes.push({kind: "update", ref, data: changes});
        }
      }
    }
    if (writes.length > 500) {
      throw new RegistrationError("resource-exhausted", `This edit requires ${writes.length} writes; the atomic limit is 500. Edit the layout and building name separately, or reduce the configuration changes.`);
    }
    // All validation and reads finish before any writes are queued. Never chunk an edit.
    for (const write of writes) {
      if (write.kind === "delete") transaction.delete(write.ref);
      else transaction[write.kind](write.ref, write.data);
    }
    return {success: true, buildingId: input.buildingId, ...plan.stats};
  });
}

// Trusted creation shares the exact reconciliation position/label generator.
async function createBuildingCore({db, auth, data}) {
  const buildingRef = db.collection('buildings').doc();
  const input = validateInput({...data, buildingId: buildingRef.id});
  input.structureType = input.structureType || 'apartment_building';
  return db.runTransaction(async (transaction) => {
    const actor = await requireOperationalAdmin(db, auth, input.communityId, transaction);
    const plan = planReconciliation(input, [], {structureType: input.structureType});
    const timestamp = FieldValue.serverTimestamp();
    transaction.create(buildingRef, {
      buildingId: buildingRef.id, name: input.name, buildingName: input.name, communityId: input.communityId,
      adminId: actor.uid, structureType: input.structureType,
      floors: input.structureType === 'apartment_building' ? input.floors : 0,
      flatsPerFloor: input.structureType === 'apartment_building' ? input.flatsPerFloor : 0,
      ...plan.stats, createdAt: timestamp, updatedAt: timestamp,
    });
    for (const flat of plan.additions) {
      const ref = db.collection('flats').doc();
      transaction.create(ref, {...flat, id: ref.id, buildingId: buildingRef.id, buildingName: input.name,
        communityId: input.communityId, adminId: actor.uid, residentUserId: null, residentId: null,
        reservedOnboardingId: null, createdAt: timestamp, updatedAt: timestamp});
    }
    return {success: true, buildingId: buildingRef.id, ...plan.stats};
  });
}
module.exports = {validateInput, planReconciliation, reconcileBuildingCore, createBuildingCore};
