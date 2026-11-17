"use strict";
const test = require("node:test");
const assert = require("node:assert/strict");
const {logOperationalFailure} = require("../src/safe_operational_log");
const {captureConsoleErrors} = require("./helpers/capture_console_errors");

test("emits only allowlisted diagnostic fields and validated correlation identifiers", async () => {
  const result = await captureConsoleErrors(async () => {
    logOperationalFailure("email_delivery_failed", {
      correlationId: "HD-INQ-20261117-0011223344",
      rowNumber: 3,
      error: {message: "SYNTHETIC_SECRET", cause: {response: "SYNTHETIC_PROVIDER_BODY"}},
      email: "synthetic@example.invalid",
    });
  });
  assert.deepEqual(result.calls, [["Operational failure", {
    category: "email_delivery_failed",
    operation: "support_email_delivery",
    correlationId: "HD-INQ-20261117-0011223344",
    rowNumber: 3,
  }]]);
  assert.doesNotMatch(JSON.stringify(result.calls), /SYNTHETIC_SECRET|SYNTHETIC_PROVIDER_BODY|synthetic@example\.invalid/);
});

test("unrecognized categories and malformed context values are replaced or omitted", async () => {
  const result = await captureConsoleErrors(async () => {
    logOperationalFailure("SYNTHETIC_SECRET", {
      correlationId: "SYNTHETIC_SECRET",
      rowNumber: 2 ** 60,
      cause: {message: "SYNTHETIC_PROVIDER_BODY"},
    });
  });
  assert.deepEqual(result.calls, [["Operational failure", {
    category: "unknown_operational_failure",
    operation: "unknown_operation",
  }]]);
  assert.doesNotMatch(JSON.stringify(result.calls), /SYNTHETIC_SECRET|SYNTHETIC_PROVIDER_BODY/);
});
