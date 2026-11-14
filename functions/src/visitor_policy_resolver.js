"use strict";

const { communityPolicy, validatePolicy, millis } = require("./visitor_policy");

function resolveEffectiveVisitorPolicy(community, nowMs) {
  if (!Number.isSafeInteger(nowMs) || nowMs < 0) {
    throw new Error("A valid server timestamp is required.");
  }

  const active = communityPolicy(community);
  const scheduled = community?.scheduledVisitorPolicy;

  if (scheduled == null) return active;

  if (
    typeof scheduled !== "object" ||
    Array.isArray(scheduled) ||
    Object.keys(scheduled).some(
      (key) => !["effectiveAt", "policy", "revision", "updatedBy", "updatedAt"].includes(key)
    )
  ) {
    throw new Error("Invalid scheduled visitor policy.");
  }

  const effectiveAt = millis(scheduled.effectiveAt);

  if (effectiveAt == null || effectiveAt < 0) {
    throw new Error("Invalid scheduled visitor policy activation time.");
  }

  // Validate even before activation so corrupt schedules cannot be ignored.
  const replacement = validatePolicy(scheduled.policy);

  if (replacement.timeZone !== active.timeZone) {
    throw new Error("Scheduled policy time zone does not match the community.");
  }

  return nowMs >= effectiveAt
    ? {
        ...replacement,
        revision: scheduled.revision,
        updatedBy: scheduled.updatedBy,
        updatedAt: scheduled.updatedAt,
        // Keep the original cutover across later schedules and disable/enable
        // cycles. First enforcement begins at the scheduled instant.
        enforcementStartedAt: active.enforcementStartedAt ??
          (!active.enabled && replacement.enabled ? effectiveAt : null),
      }
    : active;
}

// A refresh deadline is guidance only. Every operation still authorizes using
// the effective policy and its own trusted server timestamp.
function visitorPolicyRevalidationAt(community, nowMs) {
  const policy = resolveEffectiveVisitorPolicy(community, nowMs);
  const candidates = [millis(community?.scheduledVisitorPolicy?.effectiveAt)];
  if (policy.enabled) {
    for (const range of [policy.emergency, policy.pets.restriction]) {
      if (range) candidates.push(range.startAt, range.endAt);
    }
  }
  const future = candidates.filter((value) => value != null && value > nowMs);
  return future.length ? Math.min(...future) : null;
}

module.exports = { resolveEffectiveVisitorPolicy, visitorPolicyRevalidationAt };
