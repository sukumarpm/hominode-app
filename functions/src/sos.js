const crypto = require('node:crypto');
const {FieldValue, Timestamp} = require('firebase-admin/firestore');
const {RegistrationError, verifiedPhoneAuth} = require('./register_resident');
const {operationalAccessFailure, requireOperationalAdmin, resolveFlatOccupant} = require('./resident_identity');
const {unitLabel, structureType, unitType} = require('./unit_schema');
const {buildAuditLog} = require('./audit_log');

const ACTIVE = ['triggered', 'acknowledged', 'responding'];
const TRANSITIONS = {acknowledge: {from: ['triggered'], to: 'acknowledged'},
  respond: {from: ['acknowledged'], to: 'responding'},
  resolve: {from: ['acknowledged', 'responding'], to: 'resolved'},
  cancel: {from: ['triggered'], to: 'cancelled'}};
const clean = (v) => typeof v === 'string' ? v.trim() : '';
const id = (v) => /^[A-Za-z0-9_-]{1,128}$/.test(clean(v));
const hash = (v) => crypto.createHash('sha256').update(v).digest('hex');
const phone = (v) => /^[+0-9][0-9 ()-]{2,30}$/.test(clean(v)) ? clean(v) : null;
function exact(data, keys) {
  if (!data || typeof data !== 'object' || Array.isArray(data) || Object.keys(data).some((k) => !keys.includes(k))) {
    throw new RegistrationError('invalid-argument', 'Unsupported emergency request fields.');
  }
}
function locationSnapshot(value, now = Date.now()) {
  if (value == null) return null;
  exact(value, ['latitude', 'longitude', 'accuracy', 'capturedAt']);
  const {latitude, longitude, accuracy, capturedAt} = value;
  if (![latitude, longitude, accuracy, capturedAt].every((v) => typeof v === 'number' && Number.isFinite(v)) ||
      Math.abs(latitude) > 90 || Math.abs(longitude) > 180 || accuracy < 0 || accuracy > 100000 ||
      capturedAt > now + 60000 || capturedAt < now - 600000) {
    throw new RegistrationError('invalid-argument', 'Location snapshot is invalid or expired. Send without location.');
  }
  return {latitude, longitude, accuracy, capturedAt: Timestamp.fromMillis(capturedAt)};
}
async function residentAuthority(db, tx, auth) {
  const {uid} = verifiedPhoneAuth(auth);
  const profile = (await tx.get(db.collection('users').doc(uid))).data();
  const communityId = clean(profile?.communityId);
  if (!id(communityId)) throw new RegistrationError('permission-denied', 'An active approved Resident community is required.');
  const community = (await tx.get(db.collection('communities').doc(communityId))).data();
  if (profile?.uid !== uid || operationalAccessFailure(profile, {id: communityId, ...community})) {
    throw new RegistrationError('permission-denied', 'Your approved Resident access is required. Use a phone call for urgent assistance.');
  }
  return {uid, profile, community, communityId, role: 'resident'};
}
async function responderAuthority(db, tx, auth, communityId) {
  const {uid} = verifiedPhoneAuth(auth);
  const staff = (await tx.get(db.collection('securityStaff').doc(uid))).data();
  if (staff?.uid === uid && staff.role === 'security' && staff.isActive === true && staff.communityId === communityId) {
    const community = (await tx.get(db.collection('communities').doc(communityId))).data();
    if (community?.isActive !== true) throw new RegistrationError('permission-denied', 'Community is unavailable.');
    return {uid, role: 'security', name: clean(staff.name).slice(0, 120)};
  }
  await requireOperationalAdmin(db, auth, communityId, tx);
  return {uid, role: 'admin', name: 'Community Admin'};
}
async function canonicalContext(db, tx, actor) {
  const buildingId = clean(actor.profile.buildingId);
  const unitId = clean(actor.profile.flatId);
  if (!buildingId && !unitId) return {buildingId: null, buildingName: null, unitId: null, unitLabel: null,
    structureType: null, unitType: null, unitContextAvailable: false};
  if (!id(buildingId) || !id(unitId)) throw new RegistrationError('failed-precondition', 'Your unit assignment needs review. Call Security for immediate assistance.');
  const building = (await tx.get(db.collection('buildings').doc(buildingId))).data();
  const unit = (await tx.get(db.collection('flats').doc(unitId))).data();
  if (!building || !unit || building.communityId !== actor.communityId || unit.communityId !== actor.communityId ||
      unit.buildingId !== buildingId || unit.status !== 'occupied' || resolveFlatOccupant(unit).uid !== actor.uid ||
      actor.profile.occupancyStatus === 'moved_out') {
    throw new RegistrationError('failed-precondition', 'Your current unit assignment could not be verified. Call Security for immediate assistance.');
  }
  return {buildingId, buildingName: clean(building.buildingName) || clean(building.name), unitId,
    unitLabel: unitLabel(unit) || unitId, structureType: structureType(building), unitType: unitType(unit), unitContextAvailable: true};
}
function eventWrites(db, tx, alert, actor, status, version) {
  const eventId = `${alert.id}_${version}`;
  tx.create(db.collection('sosNotificationEvents').doc(eventId), {
    alertId: alert.id, communityId: alert.communityId, residentUid: alert.residentUid,
    status, version, createdAt: FieldValue.serverTimestamp(), deliveryStatus: 'pending',
  });
  tx.create(db.collection('auditLogs').doc(), buildAuditLog({actorUid: actor.uid, actorRole: actor.role,
    communityId: alert.communityId, action: `sos.${status}`, targetType: 'sos', targetId: alert.id,
    summary: `Emergency assistance ${status}`, metadata: {status, version}}));
}
async function getSosContextCore({db, auth, data}) {
  exact(data || {}, []);
  return db.runTransaction(async (tx) => {
    const actor = await residentAuthority(db, tx, auth);
    const active = (await tx.get(db.collection('sosActive').doc(actor.uid))).data();
    return {communityId: actor.communityId, residentUid: actor.uid, activeAlertId: active?.alertId || null,
      securityPhone: phone(actor.community.securityPhone || actor.community.securityContact?.phoneNumber),
      emergencyPhone: phone(actor.profile.emergencyContactNumber || actor.profile.emergencyContact?.phoneNumber)};
  });
}
async function triggerSosCore({db, auth, data}) {
  exact(data, ['requestId', 'location']);
  if (!/^[A-Za-z0-9_-]{16,100}$/.test(clean(data.requestId))) throw new RegistrationError('invalid-argument', 'A valid emergency request ID is required.');
  const location = locationSnapshot(data.location);
  return db.runTransaction(async (tx) => {
    const actor = await residentAuthority(db, tx, auth);
    const requestRef = db.collection('sosRequests').doc(hash(`${actor.uid}|${data.requestId}`));
    const request = (await tx.get(requestRef)).data();
    if (request) return {alertId: request.alertId, communityId: actor.communityId, duplicate: true};
    const activeRef = db.collection('sosActive').doc(actor.uid);
    const active = (await tx.get(activeRef)).data();
    if (active?.alertId) {
      const alert = (await tx.get(db.collection('sosAlerts').doc(active.alertId))).data();
      if (!alert || alert.residentUid !== actor.uid || alert.communityId !== actor.communityId || !ACTIVE.includes(alert.status)) {
        throw new RegistrationError('failed-precondition', 'The active emergency needs review. Contact Security directly.');
      }
      tx.create(requestRef, {alertId: active.alertId, residentUid: actor.uid, communityId: actor.communityId, createdAt: FieldValue.serverTimestamp()});
      return {alertId: active.alertId, communityId: actor.communityId, duplicate: true};
    }
    const context = await canonicalContext(db, tx, actor);
    const ref = db.collection('sosAlerts').doc();
    const timestamp = FieldValue.serverTimestamp();
    const alert = {id: ref.id, communityId: actor.communityId, communityName: clean(actor.community.name),
      residentUid: actor.uid, residentName: clean(actor.profile.name || actor.profile.fullName || actor.profile.residentName).slice(0, 120) || 'Resident',
      ...context, status: 'triggered', version: 1, triggeredAt: timestamp, createdAt: timestamp, updatedAt: timestamp,
      triggerSource: 'resident_app', location, locationAvailable: location != null};
    tx.create(ref, alert);
    tx.set(activeRef, {alertId: ref.id, communityId: actor.communityId, residentUid: actor.uid, updatedAt: timestamp});
    tx.create(requestRef, {alertId: ref.id, residentUid: actor.uid, communityId: actor.communityId, createdAt: timestamp});
    eventWrites(db, tx, alert, actor, 'triggered', 1);
    return {alertId: ref.id, communityId: actor.communityId, duplicate: false};
  });
}
async function transitionSosCore({db, auth, data}) {
  exact(data, ['alertId', 'communityId', 'action', 'resolutionNote']);
  if (!id(data.alertId) || !id(data.communityId) || !TRANSITIONS[data.action] ||
      (data.resolutionNote != null && (typeof data.resolutionNote !== 'string' || data.resolutionNote.length > 500))) {
    throw new RegistrationError('invalid-argument', 'Invalid emergency action.');
  }
  return db.runTransaction(async (tx) => {
    const actor = data.action === 'cancel' ? await residentAuthority(db, tx, auth) : await responderAuthority(db, tx, auth, data.communityId);
    const ref = db.collection('sosAlerts').doc(data.alertId);
    const alert = (await tx.get(ref)).data();
    if (!alert || alert.communityId !== data.communityId || (data.action === 'cancel' &&
        (alert.residentUid !== actor.uid || alert.communityId !== actor.communityId))) {
      throw new RegistrationError('permission-denied', 'This emergency is not available to your account.');
    }
    const transition = TRANSITIONS[data.action];
    if (alert.status === transition.to) return {alertId: alert.id, status: alert.status, duplicate: true};
    if (!transition.from.includes(alert.status)) throw new RegistrationError('failed-precondition', `This emergency is already ${alert.status}. Refresh its current status.`);
    const activeRef = db.collection('sosActive').doc(alert.residentUid);
    const active = (await tx.get(activeRef)).data();
    if (active?.alertId !== alert.id) throw new RegistrationError('failed-precondition', 'Emergency state is inconsistent. Contact management.');
    const timestamp = FieldValue.serverTimestamp();
    const prefix = transition.to;
    const patch = {status: prefix, version: alert.version + 1, updatedAt: timestamp,
      [`${prefix}At`]: timestamp, [`${prefix}ByUid`]: actor.uid};
    if (actor.name) patch[`${prefix}ByName`] = actor.name;
    if (data.action === 'resolve') patch.resolutionNote = clean(data.resolutionNote);
    tx.update(ref, patch);
    if (!ACTIVE.includes(prefix)) tx.delete(activeRef);
    eventWrites(db, tx, alert, actor, prefix, patch.version);
    return {alertId: alert.id, status: prefix, duplicate: false};
  });
}
module.exports = {ACTIVE, TRANSITIONS, locationSnapshot, residentAuthority, triggerSosCore, transitionSosCore, getSosContextCore};
