"use strict";

const EVENTS = Object.freeze({
  captcha_verification_failed: "captcha_verification",
  firestore_persistence_failed: "request_persistence",
  email_delivery_failed: "support_email_delivery",
  email_status_update_failed: "email_status_update",
  resident_import_row_failed: "resident_import_row",
});

const REQUEST_REFERENCE = /^HD-(?:DEL|INQ)-\d{8}-[A-F0-9]{10}$/;

function logOperationalFailure(category, context = {}) {
  const knownCategory = Object.hasOwn(EVENTS, category);
  const operation = knownCategory ? EVENTS[category] : "unknown_operation";
  const safeCategory = knownCategory ? category : "unknown_operational_failure";
  const fields = {category: safeCategory, operation};

  if (typeof context.correlationId === "string" && REQUEST_REFERENCE.test(context.correlationId)) {
    fields.correlationId = context.correlationId;
  }
  if (Number.isSafeInteger(context.rowNumber) && context.rowNumber >= 1 && context.rowNumber <= 500) {
    fields.rowNumber = context.rowNumber;
  }

  console.error("Operational failure", fields);
}

module.exports = {logOperationalFailure};
