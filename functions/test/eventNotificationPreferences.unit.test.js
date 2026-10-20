const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const {
  eventPushAllowed: allowed,
  eventPushPreferences: validate,
} = require("../src/event_notification_preferences");
test("event push defaults and explicit opt-outs", () => {
  assert.equal(allowed({}), true);
  for (const key of ["push_notifications", "event_reminders"])
    assert.equal(allowed({ eventPreferences: { [key]: false } }), false);
});
test("DND handles same-day, overnight and local timezone offsets", () => {
  const now = Date.UTC(2026, 9, 20, 10, 0);
  assert.equal(
    allowed(
      {
        eventPreferences: {
          dnd_enabled: true,
          dnd_start_hour: 9,
          dnd_end_hour: 11,
        },
      },
      now,
    ),
    false,
  );
  assert.equal(
    allowed(
      {
        eventPreferences: {
          dnd_enabled: true,
          dnd_start_hour: 22,
          dnd_end_hour: 7,
        },
      },
      now,
    ),
    true,
  );
  assert.equal(
    allowed(
      {
        eventPreferences: {
          dnd_enabled: true,
          dnd_start_hour: 17,
          dnd_end_hour: 20,
          timezone_offset_minutes: 480,
        },
      },
      now,
    ),
    false,
  );
  assert.equal(
    allowed(
      {
        eventPreferences: {
          dnd_enabled: true,
          dnd_start_hour: 22,
          dnd_end_hour: 7,
        },
      },
      Date.UTC(2026, 9, 20, 23),
    ),
    false,
  );
});
test("malformed preference fields fail closed at registration", () => {
  for (const value of [
    null,
    [],
    { push_notifications: "false" },
    { dnd_start_hour: 24 },
    { timezone_offset_minutes: 900 },
    { role: "admin" },
  ])
    assert.throws(() => validate(value), { code: "invalid-argument" });
  assert.deepEqual(
    validate({ push_notifications: false, dnd_start_hour: 22 }),
    { push_notifications: false, dnd_start_hour: 22 },
  );
});
test("event notification export uses only creation trigger with no backfill or update trigger", () => {
  const index = fs.readFileSync(require.resolve("../src/index"), "utf8");
  assert.match(
    index,
    /exports\.notifyResidentsOfCreatedEvent = onDocumentCreated/,
  );
  assert.match(index, /document: ['"]events_announcements\/\{eventId\}['"]/);
});
