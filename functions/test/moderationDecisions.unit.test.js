const test = require("node:test");
const assert = require("node:assert/strict");
const { sosStore } = require("./helpers/sos_store");
const {
  reportContentCore,
  resolveModerationReportCore,
  listModerationReportsCore,
} = require("../src/content_moderation");
const {
  dispatchModerationDecisionCore,
  notificationIdForDecision,
} = require("../src/moderation_notifications");
const { notificationAudienceKey } = require("../src/notifications");
const phone = "+639170000000";
const reporter = "private-reporter-uid",
  author = "author-uid";
const auth = (uid) => ({
  uid,
  token: { phone_number: phone, firebase: { sign_in_provider: "phone" } },
});
async function fixture(comment = false) {
  const db = sosStore();
  await db.collection("communities").doc("A").set({ isActive: true });
  for (const [uid, name] of [
    [reporter, "Reporter Private Name"],
    [author, "Content Author"],
  ])
    await db.collection("users").doc(uid).set({
      uid,
      name,
      phoneNumber: phone,
      communityId: "A",
      role: "resident",
      residentType: "owner",
      approvalStatus: "approved",
      isActive: true,
      status: "active",
    });
  await db
    .collection("admins")
    .doc("admin")
    .set({
      uid: "admin",
      name: "Moderator Name",
      role: "admin",
      isActive: true,
      authorizedCommunityIds: ["A"],
    });
  await db.collection("posts").doc("post").set({
    communityId: "A",
    authorId: author,
    content: "Post preview",
    moderationVersion: 1,
  });
  if (comment)
    await db.collection("posts/post/comments").doc("comment").set({
      communityId: "A",
      authorId: author,
      comment: "Comment preview",
      moderationVersion: 1,
    });
  const report = await reportContentCore({
    db,
    auth: auth(reporter),
    data: {
      postId: "post",
      ...(comment ? { commentId: "comment" } : {}),
      reason: "Harassment: Reporter Private Name was targeted",
    },
  });
  const f = { db, reportId: report.reportId };
  f.resolve = (patch = {}) =>
    resolveModerationReportCore({
      db,
      auth: auth("admin"),
      data: {
        communityId: "A",
        reportId: f.reportId,
        action: "hide",
        reasonCode: "harassment",
        publicExplanation: "Personal attacks are not permitted.",
        internalNote: "Confidential internal note",
        ...patch,
      },
    });
  f.audit = async () => (await db.collection("moderationAudit").get()).docs[0];
  f.dispatch = async (messaging) =>
    dispatchModerationDecisionCore({
      db,
      messaging,
      auditId: (await f.audit()).id,
    });
  return f;
}

test("new decisions require valid action-specific reasons before any writes", async () => {
  for (const patch of [
    { reasonCode: undefined },
    { action: "dismiss", reasonCode: undefined },
    { reasonCode: "no_violation" },
    { publicExplanation: "x".repeat(301) },
    { internalNote: "x".repeat(1001) },
  ]) {
    const f = await fixture();
    await assert.rejects(f.resolve(patch), { code: "invalid-argument" });
    assert.equal(
      (await f.db.collection("moderationAudit").get()).docs.length,
      0,
    );
    assert.equal(
      (await f.db.collection("moderationReports").doc(f.reportId).get()).data()
        .status,
      "open",
    );
  }
});

test("hide and dismiss audit persists public/private reasons and presentation names without changing decision semantics", async () => {
  for (const action of ["hide", "dismiss"]) {
    const f = await fixture();
    await f.resolve({
      action,
      reasonCode: action === "hide" ? "harassment" : "no_violation",
    });
    const audit = (await f.audit()).data();
    assert.equal(audit.internalNote, "Confidential internal note");
    assert.equal(audit.authorName, "Content Author");
    assert.equal(audit.actorName, "Moderator Name");
    assert(audit.publicReason.includes("Personal attacks are not permitted."));
    const hidden = (await f.db.collection("posts").doc("post").get()).data()
      .moderationState;
    assert.equal(hidden, action === "hide" ? "hidden" : undefined);
    const queue = await listModerationReportsCore({
      db: f.db,
      auth: auth("admin"),
      data: { communityId: "A" },
    });
    assert.equal(queue.reports.length, 0);
    assert.equal(queue.history[0].publicReason, audit.publicReason);
    assert.equal(queue.history[0].internalNote, audit.internalNote);
    assert.equal(queue.history[0].contentSnapshot, "Post preview");
  }
});

test("dismissal notifies only reporter using the current inbox schema with its public reason", async () => {
  const f = await fixture();
  await f.resolve({ action: "dismiss", reasonCode: "no_violation" });
  const result = await f.dispatch();
  assert.equal(result.deliveryStatus, "no_devices");
  const notice = (await f.db.collection("notifications").get()).docs[0].data();
  assert.equal(notice.recipientId, reporter);
  assert.equal(notice.type, "general");
  for (const field of ["audience", "role", "appId"])
    assert.equal(notice[field], "resident");
  assert.match(notice.message, /reviewed and dismissed/);
  assert.match(notice.message, /No community guideline violation/);
  assert.equal(notice.data.route, "notifications");
});

test("post/comment hide notifications reach author with no reporter identity, report text, or internal notes", async () => {
  for (const comment of [false, true]) {
    const f = await fixture(comment);
    await f.resolve();
    await f.dispatch();
    const notices = (await f.db.collection("notifications").get()).docs;
    assert.equal(notices.length, 1);
    const notice = notices[0].data();
    assert.equal(notice.recipientId, author);
    assert.match(
      notice.message,
      new RegExp(`Your ${comment ? "comment" : "post"} was hidden`),
    );
    assert.match(notice.message, /Personal attacks/);
    const text = JSON.stringify(notice);
    for (const secret of [
      reporter,
      "Reporter Private Name",
      "Confidential internal note",
      f.reportId,
    ])
      assert(!text.includes(secret), secret);
  }
});

test("repeated and concurrent decisions/delivery create one audit and one inbox notice with at most one push", async () => {
  const f = await fixture();
  const decisions = await Promise.all([f.resolve(), f.resolve()]);
  assert.equal(decisions.filter((r) => r.duplicate).length, 1);
  assert.equal((await f.db.collection("moderationAudit").get()).docs.length, 1);
  await f.db
    .collection("notificationDevices")
    .doc("device")
    .set({
      uid: author,
      communityId: "A",
      role: "resident",
      appId: "resident",
      active: true,
      token: "token",
      audienceKey: notificationAudienceKey({
        uid: author,
        communityId: "A",
        role: "resident",
        appId: "resident",
      }),
    });
  let sends = 0;
  const messaging = {
    sendEachForMulticast: async () => {
      sends++;
      return {
        successCount: 1,
        failureCount: 0,
        responses: [{ success: true }],
      };
    },
  };
  await Promise.all([f.dispatch(messaging), f.dispatch(messaging)]);
  assert.equal(sends, 1);
  assert.equal((await f.db.collection("notifications").get()).docs.length, 1);
  assert.equal((await f.resolve({ reasonCode: "spam" })).duplicate, true);
  assert.equal((await f.audit()).data().reasonCode, "harassment");
});

test("cross-community moderation and recipients are blocked, including a recipient who moves before delivery", async () => {
  const f = await fixture();
  await assert.rejects(
    resolveModerationReportCore({
      db: f.db,
      auth: auth("admin"),
      data: {
        communityId: "B",
        reportId: f.reportId,
        action: "hide",
        reasonCode: "spam",
      },
    }),
    { code: "permission-denied" },
  );
  await f.db.collection("users").doc(author).update({ communityId: "B" });
  await f.resolve();
  assert.equal((await f.audit()).data().notificationRecipientId, null);
  await f.dispatch();
  assert.equal((await f.db.collection("notifications").get()).docs.length, 0);
  const moved = await fixture();
  await moved.resolve();
  await moved.db.collection("users").doc(author).update({ communityId: "B" });
  assert.equal((await moved.dispatch()).recipientUnavailable, true);
  assert.equal(
    (await moved.db.collection("notifications").get()).docs.length,
    0,
  );
});

test("push failure retains completed decision and private inbox; retry does not send another push", async () => {
  const f = await fixture();
  await f.resolve();
  await f.db
    .collection("notificationDevices")
    .doc("device")
    .set({
      uid: author,
      communityId: "A",
      role: "resident",
      appId: "resident",
      active: true,
      token: "token",
      audienceKey: notificationAudienceKey({
        uid: author,
        communityId: "A",
        role: "resident",
        appId: "resident",
      }),
    });
  let sends = 0;
  const messaging = {
    sendEachForMulticast: async () => {
      sends++;
      throw Error("Synthetic FCM outage");
    },
  };
  assert.equal((await f.dispatch(messaging)).deliveryStatus, "failed");
  assert.equal((await f.dispatch(messaging)).duplicate, true);
  assert.equal(sends, 1);
  assert.equal(
    (await f.db.collection("moderationReports").doc(f.reportId).get()).data()
      .status,
    "hidden",
  );
  const notification = await f.db
    .collection("notifications")
    .doc(
      notificationIdForDecision((await f.audit()).id, (await f.audit()).data()),
    )
    .get();
  assert.equal(notification.exists, true);
  assert.equal(notification.data().deliveryStatus, "failed");
});

test("inbox storage failure can retry independently without reversing a completed decision", async () => {
  const f = await fixture();
  await f.resolve();
  const run = f.db.runTransaction.bind(f.db);
  let fail = true;
  f.db.runTransaction = (work) =>
    run((tx) =>
      work({
        ...tx,
        create: (ref, data) => {
          if (fail && ref.path.startsWith("notifications/")) {
            fail = false;
            throw Error("Synthetic storage outage");
          }
          tx.create(ref, data);
        },
      }),
    );
  await assert.rejects(f.dispatch(), /Synthetic storage outage/);
  assert.equal(
    (await f.db.collection("posts").doc("post").get()).data().moderationState,
    "hidden",
  );
  await f.dispatch();
  assert.equal((await f.db.collection("notifications").get()).docs.length, 1);
});

test("legacy audit records never generate notifications and legacy history remains readable", async () => {
  const f = await fixture();
  await f.db.collection("moderationAudit").doc("legacy").set({
    communityId: "A",
    reportId: f.reportId,
    postId: "post",
    action: "dismiss",
    actorId: "admin",
  });
  assert.equal(
    (await dispatchModerationDecisionCore({ db: f.db, auditId: "legacy" }))
      .ignored,
    true,
  );
  const queue = await listModerationReportsCore({
    db: f.db,
    auth: auth("admin"),
    data: { communityId: "A" },
  });
  assert.equal(queue.history[0].actorName, "Moderator Name");
  assert.equal(queue.history[0].authorName, "Content Author");
  assert.equal(queue.history[0].publicReason, undefined);
  assert.equal((await f.db.collection("notifications").get()).docs.length, 0);
});

test("resolving a second report of already-hidden content does not notify its author again", async () => {
  const f = await fixture();
  const second = "second-reporter";
  await f.db.collection("users").doc(second).set({
    uid: second,
    phoneNumber: phone,
    communityId: "A",
    role: "resident",
    residentType: "owner",
    approvalStatus: "approved",
    isActive: true,
    status: "active",
  });
  const report = await reportContentCore({
    db: f.db,
    auth: auth(second),
    data: { postId: "post", reason: "Spam" },
  });
  await f.resolve();
  await resolveModerationReportCore({
    db: f.db,
    auth: auth("admin"),
    data: {
      communityId: "A",
      reportId: report.reportId,
      action: "hide",
      reasonCode: "spam",
    },
  });
  const audits = (await f.db.collection("moderationAudit").get()).docs;
  assert.equal(audits.length, 2);
  for (const audit of audits)
    await dispatchModerationDecisionCore({ db: f.db, auditId: audit.id });
  assert.equal((await f.db.collection("notifications").get()).docs.length, 1);
});

test("author-visible notification IDs cannot identify which Resident reported the content", async () => {
  const f = await fixture();
  await f.resolve();
  const audit = (await f.audit()).data();
  assert.equal(
    notificationIdForDecision("reporter-A-dependent-audit", audit),
    notificationIdForDecision("reporter-B-dependent-audit", audit),
  );
});
