const test = require('node:test');
const assert = require('node:assert/strict');
const {randomUUID} = require('node:crypto');
const {initializeApp, deleteApp} = require('firebase-admin/app');
const {getFirestore, Timestamp} = require('firebase-admin/firestore');
const {createAmenityBookingCore, getAmenityAvailabilityCore, cancelAmenityBookingCore} = require('../src/amenity_booking');
const enabled = !!process.env.FIRESTORE_EMULATOR_HOST;
let app;
let db;
test.before(() => {
  if (!enabled) return;
  app = initializeApp({projectId: 'demo-hominode-booking'}, 'amenity-booking-tests');
  db = getFirestore(app);
});
test.after(async () => {if (app) await deleteApp(app);});
const integration = (name, fn) => test(name, {skip: !enabled}, fn);
const dateMs = Date.parse('2035-11-15T00:00:00Z');
const future = () => Timestamp.fromMillis(Date.now() + 86400000);
const past = () => Timestamp.fromMillis(Date.now() - 86400000);
async function fixture() {
  const communityId = `C-${randomUUID().toUpperCase()}`;
  const uid = `r-${randomUUID()}`;
  const amenityId = `a-${randomUUID()}`;
  const resident = {uid, role: 'resident', communityId, isActive: true, status: 'active', approvalStatus: 'approved',
    residentType: 'tenant', identityVerified: true, identityVerificationStatus: 'verified', buildingId: 'building', flatId: 'unit'};
  const userRef = db.collection('users').doc(uid);
  const communityRef = db.collection('communities').doc(communityId);
  const subscriptionRef = db.collection('subscriptions').doc(communityId);
  const amenityRef = db.collection('amenities').doc(amenityId);
  const batch = db.batch();
  batch.set(userRef, resident);
  batch.set(communityRef, {isActive: true, timeZone: 'Asia/Manila'});
  batch.set(subscriptionRef, {planId: 'plus', status: 'active'});
  batch.set(amenityRef, {communityId, name: 'Pool', isAvailable: true, timeSlots: ['Morning', 'Evening'],
    allowMultipleBookings: false, maxCapacity: 10, isFree: true});
  await batch.commit();
  const create = (patch = {}, caller = uid) => createAmenityBookingCore({db, auth: {uid: caller},
    data: {amenityId, dateMs, timeSlot: 'Morning', ...patch}});
  const availability = (patch = {}) => getAmenityAvailabilityCore({db, auth: {uid},
    data: {amenityId, startDateMs: dateMs, endDateMs: dateMs, ...patch}});
  const cancel = (bookingId, caller = uid) => cancelAmenityBookingCore({db, auth: {uid: caller}, data: {bookingId}});
  return {communityId, uid, amenityId, resident, userRef, communityRef, subscriptionRef, amenityRef, create, availability, cancel};
}
integration('approved verified tenant with Plus creates a canonical trusted-date booking', async () => {
  const f = await fixture();
  const result = await f.create({timezoneOffsetMinutes: 840});
  const booking = (await db.collection('bookings').doc(result.bookingId).get()).data();
  assert.equal(booking.communityId, f.communityId);
  assert.equal(booking.userId, f.uid);
  assert.equal(booking.bookingDateKey, '2035-11-15');
  assert.equal(booking.date.toMillis(), Date.parse('2035-11-14T16:00:00Z'));
  assert.equal(booking.bookingTimeZone, 'Asia/Manila');
  assert.match(booking.bookingDayKey, /^[a-f0-9]{64}$/);
  assert.match(booking.bookingSlotKey, /^[a-f0-9]{64}$/);
  assert.equal((await db.collection('amenityBookingSlots').doc(booking.bookingSlotKey).get()).exists, true);
  assert.equal((await f.availability()).dates['2035-11-15'].slots.Morning.available, false);
});
for (const [name, subscription, allowed] of [
  ['Pro active', {planId: 'pro', status: 'active'}, true],
  ['Essential with forged feature', {planId: 'essential', status: 'active', features: {facilityBooking: true}}, false],
  ['missing', null, false],
  ...['expired', 'suspended', 'cancelled'].map(status => [status, {planId: 'plus', status, endsAt: future()}, false]),
  ...['trial', 'grace'].flatMap(status => [
    [`${status} before end`, {planId: 'plus', status, endsAt: future()}, true],
    [`${status} after end`, {planId: 'plus', status, endsAt: past()}, false],
    [`${status} missing end`, {planId: 'plus', status}, false],
  ]),
  ['active after end', {planId: 'plus', status: 'active', endsAt: past()}, false],
  ['active future start', {planId: 'plus', status: 'active', startsAt: future()}, false],
]) integration(`booking subscription: ${name}`, async () => {
  const f = await fixture();
  if (subscription) await f.subscriptionRef.set(subscription); else await f.subscriptionRef.delete();
  if (allowed) assert.equal((await f.create()).status, 'confirmed');
  else await assert.rejects(f.create(), {code: 'permission-denied'});
  // Read-only availability is not a premium operation.
  assert((await f.availability()).dates['2035-11-15']);
});
integration('tenant verification and active approved resident/community are authoritative', async () => {
  for (const patch of [{identityVerified: false}, {identityVerificationStatus: 'pending'}, {approvalStatus: 'pending'},
    {isActive: false}, {status: 'inactive'}, {role: 'admin'}, {uid: 'impostor'}, {ownershipType: 'owner'}]) {
    const f = await fixture(); await f.userRef.update(patch);
    await assert.rejects(f.create(), {code: 'permission-denied'});
  }
  const f = await fixture(); await f.communityRef.update({isActive: false});
  await assert.rejects(f.create(), {code: 'permission-denied'});
});
integration('owner verification follows community policy; legacy ownershipType remains supported', async () => {
  const f = await fixture();
  await f.userRef.set({...f.resident, residentType: 'owner', identityVerified: false, identityVerificationStatus: 'pending'});
  assert.equal((await f.create()).status, 'confirmed');
  await f.communityRef.update({ownerIdentityVerificationRequired: true});
  await assert.rejects(f.create({timeSlot: 'Evening'}), {code: 'permission-denied'});
  const {residentType, ...legacy} = f.resident;
  await f.userRef.set({...legacy, ownershipType: 'owner'});
  assert.equal((await f.create({timeSlot: 'Evening'})).status, 'confirmed');
});
integration('client community/role/identity overrides and foreign-community amenities cannot bypass scope', async () => {
  const f = await fixture(); const other = await fixture();
  for (const patch of [{communityId: other.communityId}, {role: 'admin'}, {identityVerified: true}]) {
    await assert.rejects(f.create(patch), {code: 'invalid-argument'});
  }
  await assert.rejects(f.create({amenityId: other.amenityId}), {code: 'failed-precondition'});
  await f.userRef.update({communityId: f.communityId.toLowerCase()});
  await db.collection('communities').doc(f.communityId.toLowerCase()).set({isActive: true, timeZone: 'Asia/Manila'});
  await assert.rejects(f.create(), {code: 'permission-denied'});
});
integration('missing or invalid trusted timezone fails safely despite client offset', async () => {
  for (const timeZone of [null, 'Not/A_Timezone']) {
    const f = await fixture(); await f.communityRef.set({isActive: true, ...(timeZone ? {timeZone} : {})});
    await assert.rejects(f.create({timezoneOffsetMinutes: -480}), {code: 'failed-precondition'});
    await assert.rejects(f.availability({timezoneOffsetMinutes: -480}), {code: 'failed-precondition'});
  }
});
integration('mixed offsets and timestamps within one trusted date cannot evade capacity', async () => {
  const f = await fixture();
  await f.create({dateMs: Date.parse('2035-11-14T16:00:00Z'), timezoneOffsetMinutes: -480});
  await assert.rejects(f.create({dateMs: Date.parse('2035-11-15T08:00:00Z'), timezoneOffsetMinutes: 480}), {code: 'failed-precondition'});
  for (const timezoneOffsetMinutes of [-840, 0, 840]) {
    const view = await f.availability({timezoneOffsetMinutes});
    assert.equal(view.dates['2035-11-15'].slots.Morning.bookingCount, 1);
  }
});
integration('exclusive capacity holds for concurrent residents with different client offsets', async () => {
  const f = await fixture();
  const callers = [f.uid, `r-${randomUUID()}`, `r-${randomUUID()}`];
  for (const uid of callers.slice(1)) await db.collection('users').doc(uid).set({...f.resident, uid});
  const results = await Promise.allSettled(callers.map((uid, i) => f.create({timezoneOffsetMinutes: (i - 1) * 480}, uid)));
  assert.equal(results.filter(r => r.status === 'fulfilled').length, 1);
  for (const r of results.filter(r => r.status === 'rejected')) assert.equal(r.reason.code, 'failed-precondition');
  assert.equal((await db.collection('bookings').where('amenityId', '==', f.amenityId).get()).size, 1);
});
integration('shared capacity holds under concurrent group bookings', async () => {
  const f = await fixture(); await f.amenityRef.update({allowMultipleBookings: true, maxCapacity: 3});
  const results = await Promise.allSettled([f.create({numberOfPeople: 2}), f.create({numberOfPeople: 2})]);
  assert.equal(results.filter(r => r.status === 'fulfilled').length, 1);
  assert.equal(results.find(r => r.status === 'rejected').reason.code, 'failed-precondition');
  assert.equal((await f.create({numberOfPeople: 1})).remainingSpotsAfterBooking, 0);
});
integration('legacy active bookings consume capacity and cancellation releases it', async () => {
  const f = await fixture(); const ref = db.collection('bookings').doc();
  await ref.set({communityId: f.communityId, amenityId: f.amenityId, userId: f.uid,
    date: Timestamp.fromMillis(dateMs), timeSlot: 'Morning', status: 'approved', numberOfPeople: 1});
  await assert.rejects(f.create(), {code: 'failed-precondition'});
  await f.cancel(ref.id);
  assert.equal((await f.create()).status, 'confirmed');
});
integration('canonical capacity identity survives a trusted timezone configuration change', async () => {
  const f = await fixture(); await f.create();
  await f.communityRef.update({timeZone: 'America/Los_Angeles'});
  const shifted = Date.parse('2035-11-15T12:00:00Z');
  await assert.rejects(f.create({dateMs: shifted}), {code: 'failed-precondition'});
  assert.equal((await f.availability({startDateMs: shifted, endDateMs: shifted})).dates['2035-11-15'].slots.Morning.bookingCount, 1);
});
integration('trusted date boundaries handle short and long DST days', async () => {
  for (const [instant, start, nextStart, hours] of [
    ['2035-03-11T12:00:00Z', '2035-03-11T05:00:00Z', '2035-03-12T04:00:00Z', 23],
    ['2035-11-04T12:00:00Z', '2035-11-04T04:00:00Z', '2035-11-05T05:00:00Z', 25],
  ]) {
    const f = await fixture(); await f.communityRef.update({timeZone: 'America/New_York'});
    const result = await f.create({dateMs: Date.parse(instant)});
    const booking = (await db.collection('bookings').doc(result.bookingId).get()).data();
    assert.equal(booking.date.toMillis(), Date.parse(start));
    assert.equal((Date.parse(nextStart) - booking.date.toMillis()) / 3600000, hours);
    await assert.rejects(f.create({dateMs: Date.parse(nextStart) - 1}), {code: 'failed-precondition'});
    assert.equal((await f.create({dateMs: Date.parse(nextStart)})).status, 'confirmed');
  }
});
integration('downgrade/expiry prevents new bookings but preserves cancellation', async () => {
  for (const patch of [{planId: 'essential'}, {status: 'expired'}, {status: 'suspended'}, {status: 'cancelled'}]) {
    const f = await fixture(); const booking = await f.create();
    await f.subscriptionRef.update(patch);
    await assert.rejects(f.create({timeSlot: 'Evening'}), {code: 'permission-denied'});
    assert.equal((await f.cancel(booking.bookingId)).status, 'cancelled');
    assert.equal((await f.cancel(booking.bookingId)).idempotent, true);
  }
});
integration('cancellation remains available after lost operational eligibility and missing subscription/timezone', async () => {
  const f = await fixture(); const booking = await f.create();
  await f.userRef.update({isActive: false, status: 'inactive', approvalStatus: 'rejected', identityVerified: false, identityVerificationStatus: 'pending'});
  await f.communityRef.set({isActive: false}); await f.subscriptionRef.delete();
  assert.equal((await f.cancel(booking.bookingId)).status, 'cancelled');
});
integration('cancellation still enforces owner, current community, resident role, and terminal status', async () => {
  const f = await fixture(); const other = await fixture(); const booking = await f.create();
  await assert.rejects(f.cancel(booking.bookingId, other.uid), {code: 'permission-denied'});
  await f.userRef.update({communityId: other.communityId});
  await assert.rejects(f.cancel(booking.bookingId), {code: 'permission-denied'});
  await f.userRef.update({communityId: f.communityId, role: 'admin'});
  await assert.rejects(f.cancel(booking.bookingId), {code: 'permission-denied'});
  await f.userRef.update({role: 'resident'});
  await db.collection('bookings').doc(booking.bookingId).update({status: 'completed'});
  await assert.rejects(f.cancel(booking.bookingId), {code: 'failed-precondition'});
});
