const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const {
  AUDIT_ACTIONS,
  buildAuditLog,
  writeAuditLogBestEffort,
} = require("../src/audit_log");

const requiredActions = [
  "resident.approve",
  "resident.reject",
  "resident.deactivate",
  "resident.reactivate",
  "resident.move_out",
  "resident.reassign",
  "identity_verification.approve",
  "identity_verification.reject",
  "admin.create",
  "admin.set_active",
  "admin.assignments_update",
  "security_staff.create",
  "security_staff.assign",
  "security_staff.assignment_remove",
  "community.configuration_update",
  "community.status_update",
  "community.location_update",
].sort();

function auditDb({fail = false} = {}) {
  const records = new Map();
  let sequence = 0;
  return {
    records,
    collection(name) {
      assert.equal(name, "auditLogs");
      return {
        doc() {
          const id = `audit-${++sequence}`;
          return {
            id,
            async create(value) {
              if (fail) throw new Error("audit unavailable");
              records.set(id, value);
            },
          };
        },
      };
    },
  };
}

function validFields(overrides = {}) {
  return {
    actorUid: "admin-a",
    actorRole: "admin",
    communityId: "COMMUNITY_A",
    action: AUDIT_ACTIONS.residentApprove,
    targetType: "resident",
    targetId: "resident-a",
    summary: "Resident registration approved.",
    metadata: {previousStatus: "pending", newStatus: "approved"},
    ...overrides,
  };
}

test("critical action allowlist is exact and wired into trusted mutation modules", () => {
  assert.deepEqual(Object.values(AUDIT_ACTIONS).sort(), requiredActions);
  const sourceByModule = {
    resident_identity: [
      "residentApprove",
      "residentReject",
      "residentDeactivate",
      "residentReactivate",
      "residentMoveOut",
      "residentReassign",
      "identityApprove",
      "identityReject",
    ],
    admin_management: ["adminCreate", "adminSetActive", "adminAssignmentsUpdate"],
    security_management: ["securityCreate", "securityAssign", "securityAssignmentRemove"],
    tenant_management: ["communityConfigurationUpdate", "communityStatusUpdate"],
    community_location_management: ["communityLocationUpdate"],
  };
  for (const [moduleName, actions] of Object.entries(sourceByModule)) {
    const source = fs.readFileSync(
      path.join(__dirname, `../src/${moduleName}.js`),
      "utf8",
    );
    for (const action of actions) {
      assert.match(source, new RegExp(`AUDIT_ACTIONS\\.${action}\\b`));
    }
  }
});

test("audit schema contains required trusted fields and only small metadata", () => {
  const entry = buildAuditLog(validFields());
  assert.equal(entry.actorUid, "admin-a");
  assert.equal(entry.actorRole, "admin");
  assert.equal(entry.communityId, "COMMUNITY_A");
  assert.equal(entry.action, "resident.approve");
  assert.equal(entry.targetType, "resident");
  assert.equal(entry.targetId, "resident-a");
  assert.equal(entry.summary, "Resident registration approved.");
  assert.equal(entry.timestamp.constructor.name, "ServerTimestampTransform");
  assert.deepEqual(entry.metadata, {
    previousStatus: "pending",
    newStatus: "approved",
  });
  assert.throws(
    () => buildAuditLog(validFields({metadata: {document: {secret: true}}})),
    /metadata document is invalid/,
  );
});

test("best-effort writer appends an auto-ID audit record", async () => {
  const db = auditDb();
  const result = await writeAuditLogBestEffort({db, ...validFields()});
  assert.equal(result.written, true);
  assert.equal(db.records.size, 1);
  assert.equal(db.records.get(result.id).targetId, "resident-a");
});

test("audit storage failure is reported but never rejects the caller", async () => {
  const messages = [];
  const logger = {error: (...values) => messages.push(values)};
  const result = await writeAuditLogBestEffort({
    db: auditDb({fail: true}),
    logger,
    ...validFields(),
  });
  assert.deepEqual(result, {written: false});
  assert.equal(messages.length, 1);
  assert.equal(messages[0][1].action, "resident.approve");
  assert.equal(messages[0][1].targetId, "resident-a");
});
