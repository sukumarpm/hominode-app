const { RegistrationError } = require("./register_resident");
const booleans = ["push_notifications", "event_reminders", "dnd_enabled"];
const integers = {
  dnd_start_hour: [0, 23],
  dnd_start_minute: [0, 59],
  dnd_end_hour: [0, 23],
  dnd_end_minute: [0, 59],
  timezone_offset_minutes: [-840, 840],
};
function eventPushPreferences(value) {
  if (!value || typeof value !== "object" || Array.isArray(value))
    throw new RegistrationError(
      "invalid-argument",
      "Invalid notification preferences.",
    );
  const result = {};
  for (const key of Object.keys(value)) {
    if (booleans.includes(key) && typeof value[key] === "boolean")
      result[key] = value[key];
    else if (
      integers[key] &&
      Number.isInteger(value[key]) &&
      value[key] >= integers[key][0] &&
      value[key] <= integers[key][1]
    )
      result[key] = value[key];
    else
      throw new RegistrationError(
        "invalid-argument",
        "Invalid notification preference field.",
      );
  }
  return result;
}
function eventPushAllowed(device, nowMs = Date.now()) {
  const p = device.eventPreferences || {};
  if (p.push_notifications === false || p.event_reminders === false)
    return false;
  if (p.dnd_enabled !== true) return true;
  const date = new Date(nowMs + (p.timezone_offset_minutes || 0) * 60000);
  const minute = date.getUTCHours() * 60 + date.getUTCMinutes();
  const start = (p.dnd_start_hour ?? 22) * 60 + (p.dnd_start_minute ?? 0);
  const end = (p.dnd_end_hour ?? 7) * 60 + (p.dnd_end_minute ?? 0);
  return start === end
    ? false
    : start > end
      ? !(minute >= start || minute <= end)
      : !(minute >= start && minute <= end);
}
module.exports = { eventPushPreferences, eventPushAllowed };
