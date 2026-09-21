const test = require('node:test');
const assert = require('node:assert/strict');
const {createAmenityBookingCore, cancelAmenityBookingCore} = require('../src/amenity_booking');

const data = {amenityId: 'pool', dateMs: Date.parse('2035-11-15T00:00:00Z'), timeSlot: 'Morning'};
function profileStore(profile, community = {isActive: true}) {
  const records = {'users/r': profile, 'communities/C': community};
  return {
    collection: name => ({doc: id => ({path: `${name}/${id || 'new'}`})}),
    runTransaction: callback => callback({get: async ref => ({exists: !!records[ref.path], data: () => records[ref.path]})}),
  };
}
const resident = {uid: 'r', role: 'resident', communityId: 'C', approvalStatus: 'approved',
  isActive: true, status: 'active', residentType: 'tenant', identityVerified: true, identityVerificationStatus: 'verified'};
for (const [name, patch] of Object.entries({unapproved: {approvalStatus: 'pending'}, inactive: {isActive: false},
  suspended: {status: 'suspended'}, wrongRole: {role: 'admin'}, wrongUid: {uid: 'other'},
  unverified: {identityVerified: false}, missingVerificationState: {identityVerificationStatus: undefined},
  conflictingType: {ownershipType: 'owner'}})) {
  test(`creation rejects ${name} canonical profile`, async () => {
    await assert.rejects(createAmenityBookingCore({db: profileStore({...resident, ...patch}), auth: {uid: 'r'}, data}), {code: 'permission-denied'});
  });
}
test('creation rejects inactive or missing canonical community', async () => {
  for (const community of [{isActive: false}, null]) {
    await assert.rejects(createAmenityBookingCore({db: profileStore(resident, community), auth: {uid: 'r'}, data}), {code: 'permission-denied'});
  }
});
test('creation rejects client role/community/verification overrides before accessing Firestore', async () => {
  for (const extra of [{role: 'resident'}, {communityId: 'PREMIUM'}, {identityVerified: true}]) {
    await assert.rejects(createAmenityBookingCore({db: {}, auth: {uid: 'r'}, data: {...data, ...extra}}), {code: 'invalid-argument'});
  }
});
test('creation and cancellation require authentication', async () => {
  for (const core of [createAmenityBookingCore, cancelAmenityBookingCore]) {
    await assert.rejects(core({db: {}, data}), {code: 'unauthenticated'});
  }
});
