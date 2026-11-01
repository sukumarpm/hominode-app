const {createHash} = require('node:crypto');
const {FieldValue} = require('firebase-admin/firestore');
const {HttpsError} = require('firebase-functions/v2/https');
const {hasVerifiedPhoneAuth} = require('./phone_auth');
const {operationalAccessFailure, requireOperationalAdmin} = require('./resident_identity');

const fail = (code, message) => { throw new HttpsError(code, message); };
const id = value => typeof value === 'string' && value.length > 0 && value.length <= 128 && !/[\/\u0000-\u001f]/.test(value) && value === value.trim();
const key = (...values) => createHash('sha256').update(JSON.stringify(values)).digest('hex');
const ms = value => value?.toMillis?.() ?? (Number.isSafeInteger(value) ? value : null);
function exact(data, fields) {
  if (!data || typeof data !== 'object' || Array.isArray(data) || Object.keys(data).some(k => !fields.includes(k))) fail('invalid-argument', 'Invalid moderation request.');
}
async function resident(db, auth, tx) {
  if (!hasVerifiedPhoneAuth(auth)) fail('unauthenticated', 'Verified phone authentication is required.');
  const profileSnap = await tx.get(db.collection('users').doc(auth.uid));
  const profile = profileSnap.data();
  if (!profileSnap.exists || profile.uid !== auth.uid || profile.phoneNumber !== auth.token.phone_number || !id(profile.communityId)) fail('permission-denied', 'Resident access is unavailable.');
  const community = await tx.get(db.collection('communities').doc(profile.communityId));
  if (!community.exists || operationalAccessFailure(profile, {...community.data(), id: profile.communityId})) fail('permission-denied', 'Resident access is unavailable.');
  return profile;
}
function targetRef(db, postId, commentId) {
  if (!id(postId) || (commentId != null && !id(commentId))) fail('invalid-argument', 'Invalid content reference.');
  const post = db.collection('posts').doc(postId);
  return {post, target: commentId ? db.collection(`posts/${postId}/comments`).doc(commentId) : post};
}
function visible(value) { return value && value.moderationState !== 'hidden' && value.status !== 'deleted' && value.status !== 'hidden'; }
async function postCommunity(db, tx, post) {
  if (id(post?.communityId)) return post.communityId;
  if (!id(post?.buildingId)) return null;
  const building = await tx.get(db.collection('buildings').doc(post.buildingId));
  return building.exists && id(building.data().communityId) ? building.data().communityId : null;
}
async function reportContentCore({db, auth, data}) {
  exact(data, ['postId', 'commentId', 'reason']);
  if (typeof data.reason !== 'string' || !data.reason.trim() || data.reason.length > 500) fail('invalid-argument', 'Provide a report reason.');
  const {post, target} = targetRef(db, data.postId, data.commentId);
  return db.runTransaction(async tx => {
    const profile = await resident(db, auth, tx);
    const postSnap = await tx.get(post), targetSnap = data.commentId ? await tx.get(target) : postSnap;
    const p = postSnap.data(), item = targetSnap.data();
    const community = postSnap.exists ? await postCommunity(db, tx, p) : null;
    if (!postSnap.exists || !targetSnap.exists || community !== profile.communityId || (data.commentId && item.communityId !== profile.communityId) || !visible(p) || !visible(item)) fail('not-found', 'Content is unavailable.');
    if (item.moderationVersion !== 1) fail('failed-precondition', 'Only new content can be reported.');
    if (!id(item.authorId) || item.authorId === auth.uid) fail('failed-precondition', 'You cannot report your own content.');
    const reportId = key(profile.communityId, auth.uid, data.postId, data.commentId || '');
    const ref = db.collection('moderationReports').doc(reportId), existing = await tx.get(ref);
    if (existing.exists) return {success: true, duplicate: true, reportId};
    tx.create(ref, {communityId: profile.communityId, reporterId: auth.uid, authorId: item.authorId,
      postId: data.postId, commentId: data.commentId || null, targetType: data.commentId ? 'comment' : 'post',
      reason: data.reason.trim(), contentSnapshot: String(data.commentId ? item.comment || '' : item.content || '').slice(0, 10000),
      status: 'open', createdAt: FieldValue.serverTimestamp()});
    return {success: true, duplicate: false, reportId};
  });
}
async function blockContentUserCore({db, auth, data}) {
  exact(data, ['userId', 'blocked']);
  if (!id(data.userId) || typeof data.blocked !== 'boolean' || data.userId === auth?.uid) fail('invalid-argument', 'Invalid resident.');
  return db.runTransaction(async tx => {
    const profile = await resident(db, auth, tx);
    const target = await tx.get(db.collection('users').doc(data.userId));
    if (data.blocked && (!target.exists || target.data().communityId !== profile.communityId || target.data().role !== 'resident')) fail('not-found', 'Resident is unavailable.');
    const ref = db.collection('moderationBlocks').doc(key(profile.communityId, auth.uid, data.userId));
    if (data.blocked) tx.set(ref, {communityId: profile.communityId, blockerId: auth.uid, blockedId: data.userId, createdAt: FieldValue.serverTimestamp()});
    else tx.delete(ref);
    return {success: true};
  });
}
async function listBlockedContentUsersCore({db, auth, data}) {
  exact(data, []);
  const profile = await db.runTransaction(tx => resident(db, auth, tx));
  const rows = await db.collection('moderationBlocks').where('blockerId', '==', auth.uid).limit(1001).get();
  if (rows.docs.length > 1000) fail('resource-exhausted', 'Blocked-user limit exceeded.');
  const entries = rows.docs.map(d => d.data()).filter(x => x.communityId === profile.communityId && id(x.blockedId));
  const users = await Promise.all(entries.map(async entry => {
    const target = await db.collection('users').doc(entry.blockedId).get();
    const value = target.data();
    return {userId: entry.blockedId, name: value?.communityId === profile.communityId ? (value.name || value.fullName || 'Resident') : 'Resident'};
  }));
  return {users};
}
const DECISION_REASONS = Object.freeze({
  dismiss: {no_violation: 'No community guideline violation', insufficient_context: 'Insufficient context', duplicate_report: 'Duplicate report', resolved: 'Issue already resolved'},
  hide: {inappropriate_content: 'Inappropriate content', harassment: 'Harassment or bullying', spam: 'Spam', privacy: 'Privacy or personal information', other_violation: 'Other community guideline violation'},
});
function decisionText(value, max, field) {
  if (value == null) return '';
  if (typeof value !== 'string' || value.length > max || /[\u0000-\u0008\u000b\u000c\u000e-\u001f]/.test(value)) fail('invalid-argument', `Invalid ${field}.`);
  return value.trim();
}
function displayName(value, fallback) {
  return String(value?.name || value?.fullName || value?.displayName || fallback).slice(0,120);
}
async function enrichModerationRows(db, communityId, reports, history) {
  const reportCache = new Map(reports.map(r=>[r.id,Promise.resolve(r)]));
  const names = new Map();
  const name = (collection, uid, fallback) => {
    if (!id(uid)) return Promise.resolve(fallback);
    const cacheKey = `${collection}/${uid}`;
    if (!names.has(cacheKey)) names.set(cacheKey, db.collection(collection).doc(uid).get().then(s=> {
      const p=s.data();
      const scoped = collection === 'admins' ? p?.role === 'admin' && p.authorizedCommunityIds?.includes(communityId) : p?.role === 'resident' && p.communityId === communityId;
      return s.exists && scoped ? displayName(p,fallback) : fallback;
    }));
    return names.get(cacheKey);
  };
  const reportFor = reportId => {
    if (!id(reportId)) return Promise.resolve({});
    if (!reportCache.has(reportId)) reportCache.set(reportId,db.collection('moderationReports').doc(reportId).get().then(s=>s.data()?.communityId===communityId ? s.data() : {}));
    return reportCache.get(reportId);
  };
  return {
    reports: await Promise.all(reports.map(async r=>({...r,authorName:await name('users',r.authorId,'Resident')}))),
    history: await Promise.all(history.map(async h=> {
      const r=await reportFor(h.reportId);
      return {...h,targetType:h.targetType || r.targetType || 'content',contentSnapshot:h.contentSnapshot ?? r.contentSnapshot ?? '',
        reportReason:h.reportReason ?? r.reason ?? '',authorName:h.authorName || await name('users',r.authorId,'Resident'),
        actorName:h.actorName || await name('admins',h.actorId,'Community Admin')};
    })),
  };
}
async function listModerationReportsCore({db, auth, data}) {
  exact(data, ['communityId', 'historyOffset']);
  if (!id(data.communityId)) fail('invalid-argument', 'Community is required.');
  const historyOffset = data.historyOffset ?? 0;
  if (!Number.isSafeInteger(historyOffset) || historyOffset < 0 || historyOffset > 100000) fail('invalid-argument', 'Invalid history page.');
  await requireOperationalAdmin(db, auth, data.communityId);
  let historyQuery = db.collection('moderationAudit').where('communityId', '==', data.communityId);
  if (historyOffset) historyQuery = historyQuery.offset(historyOffset);
  const [reports, history] = await Promise.all([
    db.collection('moderationReports').where('communityId', '==', data.communityId).where('status', '==', 'open').limit(501).get(),
    historyQuery.limit(1001).get(),
  ]);
  const rows = (snapshot, limit) => snapshot.docs.slice(0, limit).map(doc => { const {createdAt, resolvedAt, ...value} = doc.data(); return {id: doc.id, ...value, createdAtMs: ms(createdAt), resolvedAtMs: ms(resolvedAt)}; }).sort((a,b) => (b.createdAtMs || 0) - (a.createdAtMs || 0));
  const enriched = await enrichModerationRows(db, data.communityId, rows(reports, 500), rows(history, 1000));
  return {...enriched, reportsTruncated: reports.docs.length > 500, historyTruncated: history.docs.length > 1000};
}
async function resolveModerationReportCore({db, auth, data}) {
  exact(data, ['communityId', 'reportId', 'action', 'reasonCode', 'publicExplanation', 'internalNote']);
  if (!id(data.communityId) || !id(data.reportId) || !['dismiss', 'hide'].includes(data.action)) fail('invalid-argument', 'Invalid moderation action.');
  return db.runTransaction(async tx => {
    await requireOperationalAdmin(db, auth, data.communityId, tx);
    const ref = db.collection('moderationReports').doc(data.reportId), snap = await tx.get(ref), report = snap.data();
    if (!snap.exists || report.communityId !== data.communityId) fail('not-found', 'Report is unavailable.');
    if (report.status !== 'open') return {success: true, duplicate: true};
    const reasonLabel = DECISION_REASONS[data.action][data.reasonCode];
    if (typeof data.reasonCode !== 'string' || !Object.hasOwn(DECISION_REASONS[data.action], data.reasonCode)) fail('invalid-argument', 'Select a public decision reason.');
    const publicExplanation = decisionText(data.publicExplanation,300,'public explanation');
    const internalNote = decisionText(data.internalNote,1000,'internal note');
    const publicReason = publicExplanation ? `${reasonLabel}: ${publicExplanation}` : reasonLabel;
    const {post, target} = targetRef(db, report.postId, report.commentId);
    const postSnap = await tx.get(post), targetSnap = report.commentId ? await tx.get(target) : postSnap;
    const community = postSnap.exists ? await postCommunity(db, tx, postSnap.data()) : null;
    if (data.action === 'hide' && (!postSnap.exists || !targetSnap.exists || targetSnap.data().moderationVersion !== 1 || community !== data.communityId || (report.commentId && targetSnap.data().communityId !== data.communityId))) fail('failed-precondition', 'Content is unavailable or changed community.');
    if (data.action === 'hide' && targetSnap.data().authorId !== report.authorId) fail('failed-precondition', 'Content author changed before review.');
    const recipientId = data.action === 'dismiss' ? report.reporterId : report.authorId;
    const [recipient, author, moderator] = await Promise.all([
      id(recipientId) ? tx.get(db.collection('users').doc(recipientId)) : Promise.resolve(null),
      id(report.authorId) ? tx.get(db.collection('users').doc(report.authorId)) : Promise.resolve(null),
      tx.get(db.collection('admins').doc(auth.uid)),
    ]);
    const recipientData = recipient?.data();
    const alreadyHidden = data.action === 'hide' && (targetSnap.data().moderationState === 'hidden' || ['hidden','deleted'].includes(targetSnap.data().status));
    const recipientEligible = recipient?.exists && recipientData.uid === recipientId && recipientData.role === 'resident' &&
      recipientData.communityId === data.communityId && recipientData.approvalStatus === 'approved' && recipientData.isActive === true &&
      (recipientData.status == null || recipientData.status === 'active');
    const timestamp = FieldValue.serverTimestamp();
    if (data.action === 'hide') tx.update(target, {moderationState: 'hidden'});
    tx.update(ref, {status: data.action === 'hide' ? 'hidden' : 'dismissed', resolvedAt: timestamp, resolvedBy: auth.uid});
    tx.create(db.collection('moderationAudit').doc(key(data.communityId, data.reportId)), {
      communityId: data.communityId, reportId: data.reportId, postId: report.postId, commentId: report.commentId || null,
      action: data.action, actorId: auth.uid, actorName: displayName(moderator.data(),'Community Admin'), createdAt: timestamp,
      decisionVersion: 1, reasonCode: data.reasonCode, reasonLabel, publicExplanation, publicReason, internalNote,
      targetType: report.commentId ? 'comment' : 'post', authorId: report.authorId,
      authorName: author?.data()?.communityId === data.communityId ? displayName(author.data(),'Resident') : 'Resident',
      contentSnapshot: String(report.contentSnapshot || '').slice(0,10000), reportReason: String(report.reason || '').slice(0,500),
      notificationRecipientId: recipientEligible && !alreadyHidden ? recipientId : null,
    });
    if (data.action === 'hide') tx.set(db.collection('moderationChanges').doc(data.communityId), {updatedAt: FieldValue.serverTimestamp()});
    return {success: true, duplicate: false};
  });
}
async function readVisibleWallCore({db, auth, data}) {
  exact(data, ['postId']);
  const profile = await db.runTransaction(tx => resident(db, auth, tx));
  const building = id(profile.buildingId) ? await db.collection('buildings').doc(profile.buildingId).get() : null;
  const buildingMatches = building?.exists && building.data().communityId === profile.communityId;
  const blocked = await db.collection('moderationBlocks').where('blockerId', '==', auth.uid).limit(1001).get();
  if (blocked.docs.length > 1000) fail('resource-exhausted', 'Blocked-user limit exceeded.');
  const excluded = new Set(blocked.docs.map(d => d.data()).filter(x => x.communityId === profile.communityId).map(x => x.blockedId));
  if (data.postId != null) {
    const {post} = targetRef(db, data.postId);
    const p = await post.get();
    if (!p.exists || (p.data().communityId !== profile.communityId &&
        !(p.data().communityId == null && buildingMatches && p.data().buildingId === profile.buildingId)) ||
        !visible(p.data()) || excluded.has(p.data().authorId)) fail('not-found', 'Post is unavailable.');
    const docs = await db.collection(`posts/${data.postId}/comments`).limit(1001).get();
    if (docs.docs.length > 1000) fail('resource-exhausted', 'Comment limit exceeded.');
    return {comments: docs.docs.filter(d => visible(d.data()) && (d.data().communityId == null || d.data().communityId === profile.communityId) && !excluded.has(d.data().authorId)).map(d => { const {createdAt, ...value} = d.data(); return {id:d.id, ...value, createdAtMs:ms(createdAt)}; })};
  }
  // Canonical posts belong to the community, regardless of the author's building.
  // Preserve the existing building-only access to legacy posts without communityId.
  const queries = [db.collection('posts').where('communityId', '==', profile.communityId)];
  if (buildingMatches) queries.push(db.collection('posts').where('buildingId', '==', profile.buildingId));
  const snapshots = await Promise.all(queries.map(query => query.limit(1001).get()));
  if (snapshots.some(snapshot => snapshot.docs.length > 1000)) fail('resource-exhausted', 'Post limit exceeded.');
  const posts = new Map();
  for (const snapshot of snapshots) for (const doc of snapshot.docs) {
    const value = doc.data();
    if (doc.ref.path === `posts/${doc.id}` && (value.communityId === profile.communityId ||
        (value.communityId == null && buildingMatches && value.buildingId === profile.buildingId))) posts.set(doc.id, doc);
  }
  // Never return a silently truncated feed when the existing supported bound is exceeded.
  if (posts.size > 1000) fail('resource-exhausted', 'Post limit exceeded.');
  return {posts: [...posts.values()].filter(d => visible(d.data()) && !excluded.has(d.data().authorId)).map(d => { const {createdAt, updatedAt, ...value} = d.data(); return {id:d.id, authorId:value.authorId || '', authorName:value.authorName || '', profileImage:value.profileImage || '', flat:value.flat || '', content:value.content || '', imageUrl:value.imageUrl || null, imageUrls:value.imageUrls || [], likes:value.likes || 0, likedBy:value.likedBy || [], comments:value.comments || 0, createdAtMs:ms(createdAt)}; })};
}
module.exports = {reportContentCore, blockContentUserCore, listBlockedContentUsersCore, listModerationReportsCore, resolveModerationReportCore, readVisibleWallCore};
