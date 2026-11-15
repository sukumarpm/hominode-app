const test = require("node:test");
const assert = require("node:assert/strict");
const { parsePhoneNumberFromString } = require("libphonenumber-js/max");
const { normalizeResidentOnboardingPhone: normalizePhone } = require("../src/resident_bulk_import");

test("Add Resident: documented 940 format is accepted despite library metadata omission, without proving assignment", () => {
  const phone = parsePhoneNumberFromString("+639400000000");
  assert.equal(phone.country, "PH");
  assert.equal(phone.nationalNumber.length, 10);
  assert.equal(phone.isPossible(), true);
  assert.equal(phone.isValid(), false);
  assert.equal(normalizePhone(phone.number, "PH"), "+639400000000");
  assert.equal(normalizePhone("9400000000", "PH"), "+639400000000");
  assert.equal(normalizePhone("09400000000", "PH"), "+639400000000");
  assert.equal(normalizePhone("+63 9400000000", "IN"), "+639400000000");
  assert.equal(normalizePhone("09401234567", "PH"), "+639401234567");
});

test("Add Resident: international numbers and explicit national countries normalize to E.164", () => {
  for (const [input, country, expected] of [
    ["+63 (917) 123-4567", "IN", "+639171234567"],
    ["0917 123 4567", "PH", "+639171234567"],
    ["9171234567", "PH", "+639171234567"],
    ["+639421234567", null, "+639421234567"],
    ["+91 98765 43210", "PH", "+919876543210"],
    ["09876543210", "IN", "+919876543210"],
    ["98765 43210", "IN", "+919876543210"],
    ["+1 (415) 555-2671", "IN", "+14155552671"],
    ["(415) 555-2671", "US", "+14155552671"],
    ["020 7946 0958", "GB", "+442079460958"],
    ["02 3661 8300", "IT", "+390236618300"],
  ]) assert.equal(normalizePhone(input, country), expected, input);
});

test("Add Resident: local input requires country context and malformed input stays rejected", () => {
  assert.throws(() => normalizePhone("09171234567", null), { rowCode: "missing_country_context" });
  for (const [input, country] of [
    ["+63940000000", null], ["+6394000000000", null], ["+6309400000000", null],
    ["+63917123456", null], ["+6391712345678", null], ["+6309171234567", null],
    ["+910000000000", null], ["+91987654321", null],
    ["+9198765432100", null], ["++639171234567", null],
    ["call +639171234567", null], ["+639171234567 ext 2", null],
    ["+999123456789", null], ["1234567890123456", "US"],
  ]) assert.throws(() => normalizePhone(input, country), { rowCode: "invalid_phone_number" }, input);
});
