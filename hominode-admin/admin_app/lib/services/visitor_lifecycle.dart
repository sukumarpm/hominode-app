/// Physical queues are independent from optional Admin approval metadata.
enum AdminVisitorQueue { expected, inside, history }

String canonicalVisitorStatus(Map<String, dynamic> data) {
  final raw =
      (data['status'] ?? data['visitStatus'] ?? data['approvalStatus'] ?? '')
          .toString()
          .trim()
          .toLowerCase();
  if (data['departure'] != null ||
      data['checkOutTime'] != null ||
      const {
        'completed',
        'departed',
        'checked_out',
        'checked-out',
        'exited',
        'history',
      }.contains(raw)) {
    return 'departed';
  }
  if (data['gateAccessStatus'] == 'denied' ||
      data['gateEntryDeniedAt'] != null ||
      const {'denied', 'entry_denied', 'denied-entry'}.contains(raw)) {
    return 'denied';
  }
  if (raw == 'rejected') return 'rejected';
  if (raw == 'cancelled' || raw == 'canceled') return 'cancelled';
  if (data['actualArrival'] == null && data['checkInTime'] == null) {
    if (data['authorizationState'] == 'rejected') return 'rejected';
    if (data['authorizationState'] == 'revoked') return 'cancelled';
  }
  if (data['actualArrival'] != null ||
      data['checkInTime'] != null ||
      const {
        'inside',
        'arrived',
        'checked_in',
        'entered',
        'active',
      }.contains(raw)) {
    return 'inside';
  }
  if (data['isApproved'] == true || raw == 'approved') return 'approved';
  if (raw == 'expected') return 'expected';
  if (const {'pending', 'pendingapproval', 'pending_approval'}.contains(raw)) {
    return 'pending';
  }
  return 'unknown';
}

AdminVisitorQueue adminVisitorQueue(Map<String, dynamic> data) {
  final status = canonicalVisitorStatus(data);
  if (const {'expected', 'pending', 'approved'}.contains(status)) {
    return AdminVisitorQueue.expected;
  }
  if (status == 'inside') return AdminVisitorQueue.inside;
  // Keep terminal and unrecognized records visible instead of silently dropping them.
  return AdminVisitorQueue.history;
}

bool visitorBelongsInExpectedQueue(Map<String, dynamic> data) =>
    adminVisitorQueue(data) == AdminVisitorQueue.expected;
bool visitorBelongsInPendingQueue(Map<String, dynamic> data) {
  if (!visitorBelongsInExpectedQueue(data)) return false;
  if (data['authorizationState'] != null) {
    return data['authorizationState'] == 'pending_admin';
  }
  return (data['visitorPolicySnapshot'] as Map?)?['enforced'] != false &&
      data['isApproved'] != true &&
      const {'expected', 'pending'}.contains(canonicalVisitorStatus(data));
}

bool visitorBelongsInActiveQueue(Map<String, dynamic> data) =>
    adminVisitorQueue(data) == AdminVisitorQueue.inside;
bool visitorBelongsInHistoryQueue(Map<String, dynamic> data) =>
    adminVisitorQueue(data) == AdminVisitorQueue.history;

bool visitorRequiresAdminApproval(Map<String, dynamic> data) =>
    visitorBelongsInExpectedQueue(data) &&
    data['authorizationState'] == 'pending_admin';

// Stored approvals can become stale after a policy save or emergency starts.
// The server evaluates current policy before granting or renewing approval.
bool visitorCanDecide(Map<String, dynamic> data) =>
    visitorBelongsInExpectedQueue(data) &&
    (data['authorizationState'] == null ||
        const {
          'pending_admin',
          'auto_authorized',
          'admin_authorized',
        }.contains(data['authorizationState']));

enum AdminVisitorAction { approve, reject, reapprove, revoke }

/// Presentation only. The callable rechecks policy, host and revision.
List<AdminVisitorAction> visitorDecisionActions(
  Map<String, dynamic> data, {
  Map<String, dynamic>? policy,
  DateTime? now,
  String? residentType,
}) {
  if (!visitorBelongsInExpectedQueue(data) ||
      data['status']?.toString().trim().toLowerCase() == 'revoked')
    return const [];
  final state = data['authorizationState'];
  if (state == 'pending_admin' ||
      (state == null && data['isApproved'] != true)) {
    return const [AdminVisitorAction.approve, AdminVisitorAction.reject];
  }
  if (!(const {'admin_authorized', 'auto_authorized'}.contains(state) ||
      (state == null && data['isApproved'] == true)))
    return const [];

  final ms = (now ?? DateTime.now()).millisecondsSinceEpoch;
  final emergency = policy?['emergency'] as Map?;
  final start = emergency?['startAt'] as num?,
      end = emergency?['endAt'] as num?;
  final emergencyActive =
      start != null && end != null && ms >= start && ms < end;
  final needsApproval =
      policy?['enabled'] == true &&
      (emergencyActive ||
          policy?['approvalMode'] == 'all_approval_required' ||
          (policy?['approvalMode'] == 'tenant_approval_required' &&
              residentType == 'tenant'));
  final approvedAt = data['approvedAt'] as DateTime?;
  final actor = data['authorizationActorUid'];
  final revision = policy?['revision'];
  final approvalCurrent =
      state == 'admin_authorized' &&
      data['authorizationManaged'] == true &&
      data['isApproved'] == true &&
      actor is String &&
      actor.isNotEmpty &&
      data['approvedBy'] == actor &&
      revision is int &&
      revision > 0 &&
      data['authorizationPolicyRevision'] == revision &&
      approvedAt != null &&
      approvedAt.millisecondsSinceEpoch <= ms &&
      (!emergencyActive || approvedAt.millisecondsSinceEpoch >= start!);
  return [
    if (needsApproval && !approvalCurrent) AdminVisitorAction.reapprove,
    AdminVisitorAction.revoke,
  ];
}

String visitorAuthorizationLabel(Map<String, dynamic> data) {
  switch (data['authorizationState']) {
    case 'pending_admin':
      return 'Pending Admin approval';
    case 'auto_authorized':
      return 'Resident authorized';
    case 'admin_authorized':
      return 'Admin authorized';
    case 'rejected':
      return 'Rejected';
    case 'revoked':
      return 'Revoked';
  }
  if ((data['visitorPolicySnapshot'] as Map?)?['enforced'] == false) {
    return 'Resident authorized';
  }
  return data['isApproved'] == true
      ? 'Legacy approval recorded'
      : 'Admin approval: Not recorded';
}

int pendingVisitorCount(
  Iterable<Map<String, dynamic>> rows,
  String communityId,
) => rows
    .where(
      (row) =>
          row['communityId'] == communityId &&
          visitorBelongsInPendingQueue(row),
    )
    .length;
