const {RegistrationError} = require('./register_resident');
const {requireOperationalAdmin} = require('./resident_identity');
const {hasValue, hasResidentLink, unitLabel, normalizeLabel} = require('./unit_schema');
const {buildAuditLog, AUDIT_COLLECTION} = require('./audit_log');

const clean = (v) => typeof v === 'string' ? v.trim() : '';
const state = (v) => clean(v).toLowerCase().replaceAll('-', '_');
const isTimestamp = (v) => v instanceof Date ? Number.isFinite(v.getTime()) :
  v && typeof v.toMillis === 'function' ? Number.isFinite(v.toMillis()) :
    typeof v === 'string' && v.trim() !== '' && Number.isFinite(Date.parse(v));
const MAX_WRITES = 500;
const MAX_QUERY_DOCUMENTS = 2000;
const MAX_READ_DOCUMENTS = 12000;

// Explicit schema inventory. Unknown states in these business collections block.
// Community scans also cover nested assignments and legacy reference fields.
const POLICIES = Object.freeze({
  users: 'resident', residents: 'resident', residentOnboarding: 'onboarding',
  sosAlerts: 'sos',
  residentAllocations: 'allocation', unitAssignments: 'allocation', reservations: 'allocation',
  familyMembers: 'assignment', family_members: 'assignment', vehicles: 'assignment',
  parkingSlots: 'parking', parking_violations: 'resolved',
  amenities: 'configuration', gates: 'configuration',
  domesticStaff: 'assignment', securityStaff: 'assignment', staff: 'assignment', vendors: 'assignment',
  bookings: 'booking', amenityBookings: 'booking', amenity_bookings: 'booking',
  complaints: 'resolved', maintenanceRequests: 'resolved', serviceRequests: 'resolved',
  requests: 'resolved', emergencyContacts: 'assignment', emergencyRequests: 'resolved',
  bills: 'bill', payments: 'payment', visitors: 'visitor', parcels: 'parcel',
  staffAttendance: 'attendance', securityAttendanceOpen: 'allocation',
  notices: 'publication', events_announcements: 'publication', events: 'publication',
  announcements: 'publication', broadcasts: 'publication', posters: 'publication', pinnedPosts: 'publication',
  documents: 'history', apartmentImages: 'history', apartment_images: 'history',
  posts: 'history', community_wall: 'history', comments: 'history', reports: 'history',
  chats: 'history', adminChats: 'history', messages: 'history', chatRequests: 'history',
  listings: 'publication', marketplaces: 'publication', marketplace: 'publication', marketplaceRequests: 'booking',
  residentImportJobs: 'import', residentImportRows: 'import',
  notifications: 'history', auditLogs: 'audit',
});
const buildingKeys = new Set(['buildingId', 'assignedBuildingId']);
const unitKeys = new Set(['flatId', 'unitId', 'assignedFlatId', 'assignedUnitId']);
const buildingArrays = new Set(['targetBuildings', 'targetBuildingIds', 'assignedBuildingIds']);
const unitArrays = new Set(['flatIds', 'unitIds', 'targetFlats', 'targetUnitIds']);
const indirectKeys = new Set(['gateId', 'amenityId', 'parkingSlotId', 'slotId', 'billId', 'staffId', 'securityId', 'userId', 'residentId']);

function inputFor(data) {
  if (!data || Object.keys(data).some((k) => !['communityId', 'buildingId'].includes(k))) {
    throw new RegistrationError('invalid-argument', 'Community and building are required.');
  }
  const input = {communityId: clean(data.communityId), buildingId: clean(data.buildingId)};
  if (!input.communityId || input.communityId.length > 80 || !input.buildingId ||
      input.buildingId.length > 128 || /\//.test(input.communityId + input.buildingId)) {
    throw new RegistrationError('invalid-argument', 'Community and building are required.');
  }
  return input;
}

function references(data, input, units, related = new Set(), collection = '') {
  let current = false;
  let historical = false;
  const unitIds = new Set();
  function visit(value, depth = 0) {
    if (!value || typeof value !== 'object' || depth > 8) return;
    for (const [key, v] of Object.entries(value)) {
      if (buildingKeys.has(key) && v === input.buildingId) current = true;
      if (unitKeys.has(key) && units.has(v)) {current = true; unitIds.add(v);}
      if (buildingArrays.has(key) && Array.isArray(v) && v.includes(input.buildingId)) current = true;
      if (unitArrays.has(key) && Array.isArray(v)) {
        for (const id of v) if (units.has(id)) {current = true; unitIds.add(id);}
      }
      // buildingIds is admin visibility metadata in parking/vehicle/notice records.
      if (key === 'buildingIds' && ['apartmentImages', 'apartment_images', 'visitors'].includes(collection) &&
          Array.isArray(v) && v.includes(input.buildingId)) current = true;
      if (key === 'previousBuildingId' && v === input.buildingId) historical = true;
      if (['previousFlatId', 'previousUnitId'].includes(key) && units.has(v)) {historical = true; unitIds.add(v);}
      if (indirectKeys.has(key) && related.has(v)) current = true;
      if (v && typeof v === 'object' && !(v instanceof Date) && typeof v.toDate !== 'function') visit(v, depth + 1);
    }
  }
  visit(data);
  return {current, historical, unitIds};
}

function classifyDependency(policy, data) {
  const s = state(data.status);
  const inactive = data.isActive === false && ['', 'inactive', 'disabled', 'archived', 'removed', 'terminated', 'off_duty'].includes(s);
  switch (policy) {
    case 'sos': return ['resolved', 'cancelled'].includes(s) ? 'history' : 'block';
    case 'audit': case 'history': return 'history';
    case 'resident':
      // Deactivated/suspended residents can still own an occupied unit.
      return (state(data.occupancyStatus) === 'moved_out' || s === 'moved_out' || s === 'rejected') &&
        data.isActive !== true ? 'history' : 'block';
    case 'onboarding':
      return ['cancelled', 'canceled', 'released', 'rejected', 'expired'].includes(s) &&
        !hasValue(data.claimedByUid) && data.approvalStatus !== 'approved' && data.isActive !== true ? 'history' : 'block';
    case 'parking':
      return s === 'vacant' && !hasResidentLink(data) && !['vehicleId', 'userId', 'residentId', 'reservedOnboardingId']
        .some((k) => hasValue(data[k])) ? 'delete' : 'block';
    case 'configuration':
      return inactive && !hasValue(data.assignedSecurityId) ? 'history' : 'block';
    case 'assignment': return inactive ? 'history' : 'block';
    case 'visitor':
      return ['rejected', 'cancelled', 'departed', 'checked_out', 'completed'].includes(s) ||
        isTimestamp(data.departure) || isTimestamp(data.checkedOutAt) ? 'history' : 'block';
    case 'resolved': return ['resolved', 'closed', 'completed', 'cancelled', 'rejected'].includes(s) ? 'history' : 'block';
    case 'booking': return ['completed', 'cancelled', 'canceled', 'rejected'].includes(s) ? 'history' : 'block';
    case 'bill': return ['paid', 'cancelled', 'void'].includes(s) ? 'history' : 'block';
    case 'payment': return ['completed', 'failed', 'rejected', 'refunded', 'cancelled'].includes(s) ? 'history' : 'block';
    case 'parcel': return ['collected', 'delivered', 'returned', 'cancelled'].includes(s) ? 'history' : 'block';
    case 'attendance': return s === 'completed' || isTimestamp(data.checkOutTime) ? 'history' : 'block';
    case 'publication': return inactive || ['archived', 'expired', 'completed', 'cancelled', 'closed'].includes(s) ? 'history' : 'block';
    case 'import': return ['completed', 'completed_with_errors', 'committed', 'imported'].includes(s) ? 'history' : 'block';
    default: return 'block';
  }
}

// Only fill missing display fields; never rewrite canonical references or existing history.
function historyPatch(data, match, buildingName, units) {
  const patch = {};
  const previousOnly = match.historical && !match.current;
  const nameKey = previousOnly ? 'previousBuildingName' : 'buildingName';
  if (!hasValue(data[nameKey])) patch[nameKey] = buildingName;
  const id = previousOnly ? data.previousFlatId || data.previousUnitId : data.flatId || data.unitId;
  if (units.has(id)) {
    const label = unitLabel(units.get(id)) || id;
    for (const key of previousOnly ? ['previousFlatLabel'] : ['flatLabel', 'unitLabel']) {
      if (!hasValue(data[key])) patch[key] = label;
    }
  }
  // Multi-target/nested records retain an ID-keyed display snapshot.
  if (match.unitIds.size && !units.has(id)) {
    const labels = {...data.deletedUnitLabels};
    for (const unitId of match.unitIds) if (!labels[unitId]) labels[unitId] = unitLabel(units.get(unitId)) || unitId;
    if (JSON.stringify(labels) !== JSON.stringify(data.deletedUnitLabels)) patch.deletedUnitLabels = labels;
  }
  return patch;
}

async function readDependencies(db, tx, input, units) {
  const records = new Map();
  const queries = [];
  const ids = [...units.keys()];
  for (const collection of Object.keys(POLICIES)) {
    if (POLICIES[collection] === 'audit') continue; // Append-only, never an allocation.
    const ref = db.collection(collection);
    queries.push([collection, ref.where('communityId', '==', input.communityId)]);
    // These probes deliberately omit tenant filtering: malformed/cross-tenant
    // canonical references must not slip through a scoped community scan.
    queries.push([collection, ref.where('buildingId', '==', input.buildingId)]);
    for (let i = 0; i < ids.length; i += 30) {
      for (const field of ['flatId', 'unitId']) queries.push([collection, ref.where(field, 'in', ids.slice(i, i + 30))]);
    }
    for (const field of buildingArrays) queries.push([collection, ref.where(field, 'array-contains', input.buildingId)]);
    if (['apartmentImages', 'apartment_images', 'visitors'].includes(collection)) queries.push([collection, ref.where('buildingIds', 'array-contains', input.buildingId)]);
    if (collection === 'notices') {
      for (let i = 0; i < ids.length; i += 30) queries.push([collection, ref.where('targetFlats', 'array-contains-any', ids.slice(i, i + 30))]);
    }
    if (['users', 'residents', 'residentOnboarding'].includes(collection)) {
      queries.push([collection, ref.where('previousBuildingId', '==', input.buildingId)]);
      for (let i = 0; i < ids.length; i += 30) queries.push([collection, ref.where('previousFlatId', 'in', ids.slice(i, i + 30))]);
    }
  }
  let next = 0;
  const drain = () => Promise.all(Array.from({length: 16}, async () => {
    while (next < queries.length) {
      const [collection, query] = queries[next++];
      const snapshot = await tx.get(query.limit(MAX_QUERY_DOCUMENTS + 1));
      if (snapshot.docs.length > MAX_QUERY_DOCUMENTS) {
        throw new RegistrationError('failed-precondition', 'Building deletion needs a larger dependency review. No changes were made.');
      }
      for (const doc of snapshot.docs) records.set(doc.ref.path, {collection, doc});
      if (records.size > MAX_READ_DOCUMENTS) {
        throw new RegistrationError('failed-precondition', 'Community history exceeds the automatic deletion review limit. No changes were made.');
      }
    }
  }));
  await drain();
  // Probe indirect links without a tenant filter as well. A legacy booking with
  // only amenityId or vehicle with only slotId still prevents unsafe deletion.
  const links = {
    amenities: [['bookings', 'amenityId'], ['amenityBookings', 'amenityId'], ['amenity_bookings', 'amenityId']],
    gates: [['securityStaff', 'gateId'], ['staffAttendance', 'gateId'], ['visitors', 'gateId']],
    parkingSlots: [['vehicles', 'slotId'], ['vehicles', 'parkingSlotId'], ['parking_violations', 'slotId']],
    bills: [['payments', 'billId']],
    staff: [['staffAttendance', 'staffId']],
    securityStaff: [['staffAttendance', 'securityId'], ['securityAttendanceOpen', 'securityId']],
    users: [['vehicles', 'userId'], ['familyMembers', 'userId'], ['family_members', 'userId']],
  };
  for (const [parentCollection, targets] of Object.entries(links)) {
    const parentIds = [...records.values()].filter(({collection, doc}) => collection === parentCollection &&
      references(doc.data(), input, units, new Set(), collection).current).map(({doc}) => doc.id);
    for (const [collection, field] of targets) {
      for (let i = 0; i < parentIds.length; i += 30) queries.push([collection, db.collection(collection).where(field, 'in', parentIds.slice(i, i + 30))]);
    }
  }
  await drain();
  return [...records.values()];
}

async function inspectDeletion(db, tx, auth, input) {
  const actor = await requireOperationalAdmin(db, auth, input.communityId, tx);
  const buildingRef = db.collection('buildings').doc(input.buildingId);
  const snapshot = await tx.get(buildingRef);
  if (!snapshot.exists) throw new RegistrationError('not-found', 'Building not found. Refresh the building list.');
  const building = snapshot.data();
  if (building.communityId !== input.communityId) throw new RegistrationError('permission-denied', 'Building is outside the selected community.');
  const buildingName = clean(building.buildingName) || clean(building.name) || input.buildingId;
  const flatSnapshot = await tx.get(db.collection('flats').where('buildingId', '==', input.buildingId).limit(501));
  const units = new Map(flatSnapshot.docs.map((d) => [d.id, d.data()]));
  const conflicts = [];
  const writes = flatSnapshot.docs.map((doc) => ({kind: 'delete', ref: doc.ref}));
  writes.push({kind: 'delete', ref: buildingRef});
  for (const [id, unit] of units) {
    const label = unitLabel(unit) || id;
    if (unit.communityId !== input.communityId) conflicts.push('A unit has inconsistent community references.');
    else if (!['vacant', 'maintenance'].includes(state(unit.status)) || hasResidentLink(unit) || hasValue(unit.reservedOnboardingId)) {
      conflicts.push(`${label} — ${state(unit.status) === 'reserved' ? 'Reserved' : state(unit.status) === 'occupied' ? 'Occupied' : 'active links or cannot be confirmed unused'}`);
    }
  }
  if (units.size > 499) conflicts.push('The building exceeds the automatic deletion limit of 499 units.');
  // Return cheap, useful unit conflicts without an expensive dependency scan.
  if (!conflicts.length) {
    const records = await readDependencies(db, tx, input, units);
    const related = new Set();
    // Resolve indirect references (e.g. booking -> amenity, staff -> gate,
    // payment -> bill, family/vehicle -> current resident reference).
    let changed = true;
    while (changed) {
      changed = false;
      for (const {collection, doc} of records) {
        const m = references(doc.data(), input, units, related, collection);
        if (m.current && !related.has(doc.id) &&
            ['users', 'residents', 'amenities', 'gates', 'parkingSlots', 'bills', 'staff', 'securityStaff'].includes(collection)) {
          related.add(doc.id); changed = true;
        }
      }
    }
    const counts = new Map();
    for (const {collection, doc} of records) {
      const value = doc.data();
      const match = references(value, input, units, related, collection);
      // Old imports may carry only visible references. They are ambiguous and
      // block while active; canonical fields always take precedence.
      if (collection === 'residentOnboarding' && !hasValue(value.buildingId) &&
          normalizeLabel(value.buildingReference) === normalizeLabel(buildingName)) match.current = true;
      // A pending legacy label-only allocation cannot be excluded using the
      // current name: either the building or unit may have been renamed. Fail
      // closed until canonical references are repaired; never relabel unrelated
      // terminal history merely because it lacks canonical references.
      if (collection === 'residentOnboarding' && !hasValue(value.buildingId) &&
          ['buildingReference', 'unitReference'].some((key) => hasValue(value[key])) &&
          classifyDependency('onboarding', value) === 'block') match.current = true;
      if (!match.current && !match.historical) continue;
      if (hasValue(value.communityId) && value.communityId !== input.communityId) {
        counts.set('records with inconsistent community references', (counts.get('records with inconsistent community references') || 0) + 1);
        continue;
      }
      const kind = match.current ? classifyDependency(POLICIES[collection], value) : 'history';
      if (kind === 'block') counts.set(collection, (counts.get(collection) || 0) + 1);
      else if (kind === 'delete') writes.push({kind: 'delete', ref: doc.ref});
      else if (POLICIES[collection] !== 'audit') {
        const patch = historyPatch(value, match, buildingName, units);
        if (Object.keys(patch).length) writes.push({kind: 'update', ref: doc.ref, data: patch});
      }
    }
    for (const [collection, count] of counts) conflicts.push(`${count} active or unresolved ${collection} reference${count === 1 ? '' : 's'}`);
    // Keep legacy admin summaries consistent without clearing user assignments.
    if (clean(building.adminId)) {
      const ref = db.collection('admins').doc(building.adminId);
      const admin = (await tx.get(ref)).data();
      const patch = {};
      if (Array.isArray(admin?.buildingIds) && admin.buildingIds.includes(input.buildingId)) patch.buildingIds = admin.buildingIds.filter((id) => id !== input.buildingId);
      if (Array.isArray(admin?.buildings) && admin.buildings.some((b) => b?.buildingId === input.buildingId)) {
        const oldNames = new Set([buildingName, ...admin.buildings.filter((b) => b?.buildingId === input.buildingId).map((b) => b.buildingName)]);
        patch.buildings = admin.buildings.filter((b) => b?.buildingId !== input.buildingId);
        if (Array.isArray(admin.buildingNames)) patch.buildingNames = admin.buildingNames.filter((name) => !oldNames.has(name) || patch.buildings.some((b) => b?.buildingName === name));
      }
      if (Object.keys(patch).length) writes.push({kind: 'update', ref, data: patch});
    }
  }
  if (writes.length > MAX_WRITES) conflicts.push(`Deletion needs ${writes.length} writes; the atomic limit is 500. A reviewed history-label backfill or unused child-configuration cleanup is required first. Historical records must be retained. No changes were made.`);
  const summary = {canDelete: conflicts.length === 0, buildingId: input.buildingId, buildingName,
    unitCount: units.size, conflictCount: conflicts.length, reasons: conflicts.slice(0, 12), writeCount: writes.length};
  return {summary, writes, actor, unitSnapshot: [...units].map(([id, unit]) => ({unitId: id, unitLabel: unitLabel(unit) || id}))};
}

async function validateBuildingDeletionCore({db, auth, data}) {
  const input = inputFor(data);
  return db.runTransaction(async (tx) => (await inspectDeletion(db, tx, auth, input)).summary);
}

async function deleteBuildingCore({db, auth, data}) {
  const input = inputFor(data);
  const result = await db.runTransaction(async (tx) => {
    const {summary, writes, actor, unitSnapshot} = await inspectDeletion(db, tx, auth, input);
    if (!summary.canDelete) throw new RegistrationError('failed-precondition',
      `Cannot delete ${summary.buildingName}. ${summary.conflictCount} conflict(s): ${summary.reasons.join('; ')}${summary.conflictCount > summary.reasons.length ? '; additional conflicts require review.' : '.'}`);
    for (const write of writes) tx[write.kind](write.ref, ...(write.data ? [write.data] : []));
    return {...summary, actorUid: actor.uid, unitSnapshot};
  });
  // Match the existing audit convention. Kept outside the atomic deletion so
  // 499 units + building fit the 500-write cap. The snapshot preserves the
  // meaning of canonical IDs in older append-only audit records, without PII.
  const audit = buildAuditLog({actorUid: result.actorUid, actorRole: 'admin', communityId: input.communityId,
    action: 'building.delete', targetType: 'building', targetId: input.buildingId,
    summary: `Deleted building ${result.buildingName}`.slice(0, 240),
    metadata: {buildingName: result.buildingName.slice(0, 200), unitCount: result.unitCount, result: 'deleted'}});
  try {
    await db.collection(AUDIT_COLLECTION).doc().create({...audit,
      buildingSnapshot: {buildingId: input.buildingId, buildingName: result.buildingName, units: result.unitSnapshot}});
  } catch (error) {
    // A completed deletion must never be reported as failed due to best-effort
    // audit availability. This matches writeAuditLogBestEffort's convention.
    console.error('Critical audit log write failed.', {action: 'building.delete', targetId: input.buildingId,
      error: error?.message || 'Audit unavailable'});
  }
  return {status: 'deleted', buildingId: input.buildingId, unitCount: result.unitCount};
}

module.exports = {deleteBuildingCore, validateBuildingDeletionCore, classifyDependency, references, POLICIES};
