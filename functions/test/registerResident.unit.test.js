const test = require("node:test");
const assert = require("node:assert/strict");
const {normalizeInviteCode, validateInput, verifiedPhoneAuth, isIdempotentExisting} = require("../src/register_resident");

test("normalization matches resident app", () => {
  assert.equal(normalizeInviteCode("  home-2026 "), "HOME-2026");
  assert.equal(normalizeInviteCode(" Society 42! "), "SOCIETY42");
});

test("only verified phone authentication is accepted", () => {
  assert.deepEqual(verifiedPhoneAuth({uid: "uid-1", token: {phone_number: "+919876543210", firebase: {sign_in_provider: "phone"}}}), {uid: "uid-1", phoneNumber: "+919876543210"});
  assert.throws(() => verifiedPhoneAuth({uid: "uid-1", token: {firebase: {sign_in_provider: "password"}}}), {code: "unauthenticated"});
});

test("client input contains no trusted identity or tenant fields", () => {
  const value = validateInput({inviteCode: "HOME-2026", fullName: " Resident Name ", email: "R@EXAMPLE.COM", buildingReference: "Tower A", unitReference: "A-101", residentType: "tenant", uid: "attacker", role: "admin", communityId: "other"});
  assert.deepEqual(value, {inviteCode: "HOME-2026", fullName: "Resident Name", email: "r@example.com", buildingReference: "Tower A", unitReference: "A-101", declaredResidentType: "tenant"});
  assert.throws(() => validateInput({inviteCode: "home-2026", fullName: "Resident", buildingReference: "A", unitReference: "1"}), {code: "invalid-argument"});
});

test("matching existing registration is an idempotent retry", () => {
  const expected = {uid: "uid-1", phoneNumber: "+919876543210", inviteCode: "HOME-2026", communityId: "community-a", fullName: "Resident", buildingReference: "Tower A", unitReference: "A-101", email: null, declaredResidentType: "owner"};
  assert.equal(isIdempotentExisting({uid: "uid-1", phoneNumber: "+919876543210", communityInviteCode: "HOME-2026", communityId: "community-a", role: "resident", name: "Resident", buildingReference: "Tower A", unitReference: "A-101", email: null, declaredResidentType: "owner"}, expected), true);
  assert.equal(isIdempotentExisting({uid: "uid-1", phoneNumber: "+919876543210", communityInviteCode: "HOME-2026", communityId: "community-b", role: "resident", name: "Resident", buildingReference: "Tower A", unitReference: "A-101", email: null}, expected), false);
});
