const test = require("node:test");
const assert = require("node:assert/strict");
const { readFileSync } = require("node:fs");
const { join } = require("node:path");
const { initializeApp, deleteApp } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");
const {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} = require("@firebase/rules-unit-testing");
const {
  reportContentCore,
  resolveModerationReportCore,
  listModerationReportsCore,
} = require("../src/content_moderation");
const {
  dispatchModerationDecisionCore,
} = require("../src/moderation_notifications");
const enabled = Boolean(process.env.FIRESTORE_EMULATOR_HOST);
const suite = (name, run) => test(name, { skip: !enabled }, run);
const projectId = "demo-hominode-moderation-decisions";
const phone = "+639170000000";
const auth = (uid) => ({
  uid,
  token: { phone_number: phone, firebase: { sign_in_provider: "phone" } },
});
let app, db, env;
test.before(async () => {
  if (!enabled) return;
  app = initializeApp({ projectId }, "moderation-decisions-emulator");
  db = getFirestore(app);
  env = await initializeTestEnvironment({
    projectId,
    firestore: {
      host: "127.0.0.1",
      port: Number(process.env.FIRESTORE_EMULATOR_HOST.split(":").pop()),
      rules: readFileSync(join(__dirname, "../../firestore.rules"), "utf8"),
    },
  });
  for (const communityId of ["A", "B"])
    await db.collection("communities").doc(communityId).set({ isActive: true });
  await db
    .collection("admins")
    .doc("admin")
    .set({
      uid: "admin",
      phoneNumber: phone,
      name: "Moderator",
      role: "admin",
      isActive: true,
      authorizedCommunityIds: ["A"],
    });
  for (const uid of ["author", "reporter", "bystander", "foreign"])
    await db
      .collection("users")
      .doc(uid)
      .set({
        uid,
        phoneNumber: phone,
        name: uid,
        role: "resident",
        residentType: "owner",
        ownershipType: "owner",
        identityVerified: false,
        identityVerificationStatus: "not_required",
        approvalStatus: "approved",
        isActive: true,
        status: "active",
        communityId: uid === "foreign" ? "B" : "A",
      });
});
test.after(async () => {
  if (env) await env.cleanup();
  if (app) await deleteApp(app);
});
async function decision(action, comment = false) {
  const postId = `${action}-${comment ? "comment" : "post"}`;
  await db
    .collection("posts")
    .doc(postId)
    .set({
      communityId: "A",
      authorId: "author",
      content: "Post preview",
      moderationVersion: 1,
    });
  if (comment)
    await db
      .collection(`posts/${postId}/comments`)
      .doc("comment")
      .set({
        communityId: "A",
        authorId: "author",
        comment: "Comment preview",
        moderationVersion: 1,
      });
  const report = await reportContentCore({
    db,
    auth: auth("reporter"),
    data: {
      postId,
      ...(comment ? { commentId: "comment" } : {}),
      reason: "Spam: Reporter name is confidential",
    },
  });
  const args = {
    db,
    auth: auth("admin"),
    data: {
      communityId: "A",
      reportId: report.reportId,
      action,
      reasonCode: action === "hide" ? "spam" : "no_violation",
      publicExplanation: "Please follow community guidelines.",
      internalNote: "Confidential Admin-only note",
    },
  };
  const outcomes = await Promise.all([
    resolveModerationReportCore(args),
    resolveModerationReportCore(args),
  ]);
  assert.equal(outcomes.filter((r) => r.duplicate).length, 1);
  const audit = (
    await db
      .collection("moderationAudit")
      .where("reportId", "==", report.reportId)
      .get()
  ).docs[0];
  const deliveries = await Promise.all([
    dispatchModerationDecisionCore({ db, auditId: audit.id }),
    dispatchModerationDecisionCore({ db, auditId: audit.id }),
  ]);
  assert.equal(deliveries.filter((r) => r.duplicate).length, 1);
  const notices = await db
    .collection("notifications")
    .where("sourceEntityId", "==", postId)
    .get();
  assert.equal(notices.size, 1);
  return { audit, notice: notices.docs[0] };
}

suite(
  "dismissal reason, audit, private inbox and recipient-only rules work together",
  async () => {
    const { audit, notice } = await decision("dismiss");
    assert.equal(audit.data().reasonLabel, "No community guideline violation");
    assert.equal(notice.data().recipientId, "reporter");
    const recipient = env
      .authenticatedContext("reporter", auth("reporter").token)
      .firestore();
    await assertSucceeds(
      recipient.collection("notifications").doc(notice.id).get(),
    );
    for (const uid of ["author", "bystander", "foreign", "admin"]) {
      const client = env.authenticatedContext(uid, auth(uid).token).firestore();
      await assertFails(
        client.collection("notifications").doc(notice.id).get(),
      );
    }
  },
);

suite(
  "post/comment hides notify only authors and never disclose reporter/internal data",
  async () => {
    for (const comment of [false, true]) {
      const { notice } = await decision("hide", comment);
      assert.equal(notice.data().recipientId, "author");
      assert(!JSON.stringify(notice.data()).includes("reporter"));
      assert(
        !JSON.stringify(notice.data()).includes("Confidential Admin-only note"),
      );
      const author = env
        .authenticatedContext("author", auth("author").token)
        .firestore();
      await assertSucceeds(
        author.collection("notifications").doc(notice.id).get(),
      );
      const reporter = env
        .authenticatedContext("reporter", auth("reporter").token)
        .firestore();
      await assertFails(
        reporter.collection("notifications").doc(notice.id).get(),
      );
      await assertFails(author.collection("moderationAudit").get());
    }
    const queue = await listModerationReportsCore({
      db,
      auth: auth("admin"),
      data: { communityId: "A" },
    });
    assert(
      queue.history.some(
        (h) =>
          h.actorName === "Moderator" &&
          h.authorName === "author" &&
          h.internalNote === "Confidential Admin-only note",
      ),
    );
  },
);
