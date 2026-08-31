import 'package:cloud_firestore/cloud_firestore.dart';

class DashboardRecord {
  const DashboardRecord({
    required this.title,
    required this.subtitle,
    this.status,
    this.date,
  });

  final String title;
  final String subtitle;
  final String? status;
  final DateTime? date;
}

class PlatformMetrics {
  const PlatformMetrics({
    required this.communities,
    required this.activeCommunities,
    required this.admins,
    required this.activeAdmins,
    required this.recentActivities,
    this.buildings,
    this.residents,
    this.activeComplaints,
  });

  final int communities;
  final int activeCommunities;
  final int admins;
  final int activeAdmins;
  final int? buildings;
  final int? residents;
  final int? activeComplaints;
  final List<DashboardRecord> recentActivities;

  int get inactiveCommunities => communities - activeCommunities;
}

class AdminDashboardData {
  const AdminDashboardData({
    required this.residents,
    required this.buildings,
    required this.pendingVisitors,
    required this.openComplaints,
    required this.visitorsToday,
    required this.recentComplaints,
    required this.paidAmount,
    required this.pendingAmount,
    required this.overdueAmount,
  });

  final int? residents;
  final int? buildings;
  final int? pendingVisitors;
  final int? openComplaints;
  final List<DashboardRecord>? visitorsToday;
  final List<DashboardRecord>? recentComplaints;
  final double? paidAmount;
  final double? pendingAmount;
  final double? overdueAmount;

  double? get outstandingAmount {
    if (pendingAmount == null || overdueAmount == null) return null;
    return pendingAmount! + overdueAmount!;
  }
}

class ResidentDashboardData {
  const ResidentDashboardData({
    required this.openComplaints,
    required this.visitorsToday,
    required this.pendingBills,
    required this.pendingAmount,
    required this.activeNotices,
    required this.recentNotices,
    required this.upcomingEvents,
  });

  final int? openComplaints;
  final int? visitorsToday;
  final int? pendingBills;
  final double? pendingAmount;
  final int? activeNotices;
  final List<DashboardRecord>? recentNotices;
  final List<DashboardRecord>? upcomingEvents;
}

class DashboardMetrics {
  const DashboardMetrics(this.values);

  final Map<String, int?> values;

  int? operator [](String key) => values[key];
}

class DashboardRepository {
  DashboardRepository([FirebaseFirestore? firestore])
    : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  Future<PlatformMetrics> platformMetrics() async {
    // Super Admin is intentionally limited to the platform registry by the
    // existing rules. Operational tenant collections are not queried here.
    final results = await Future.wait([
      _db.collection('communities').get(),
      _db.collection('admins').where('role', isEqualTo: 'admin').get(),
    ]);

    final communities = results[0].docs;
    final admins = results[1].docs;
    final activities = <DashboardRecord>[
      for (final doc in communities)
        if (_recordDate(doc.data()) case final date?)
          DashboardRecord(
            title: 'Community registry updated',
            subtitle:
                _firstString(doc.data(), const ['name', 'brandName']) ??
                'Community registry record',
            status: doc.data()['isActive'] == true ? 'Active' : 'Inactive',
            date: date,
          ),
      for (final doc in admins)
        if (_recordDate(doc.data()) case final date?)
          DashboardRecord(
            title: 'Administrator registry updated',
            subtitle:
                _firstString(doc.data(), const ['name', 'displayName']) ??
                'Community administrator',
            status: doc.data()['isActive'] == true ? 'Active' : 'Inactive',
            date: date,
          ),
    ]..sort(_newestRecordFirst);

    return PlatformMetrics(
      communities: communities.length,
      activeCommunities: communities
          .where((doc) => doc.data()['isActive'] == true)
          .length,
      admins: admins.length,
      activeAdmins: admins
          .where((doc) => doc.data()['isActive'] == true)
          .length,
      recentActivities: activities.take(5).toList(growable: false),
    );
  }

  Future<AdminDashboardData> adminDashboard(String communityId) async {
    final results = await Future.wait([
      _tenantDocs('users', communityId),
      _tenantDocs('buildings', communityId),
      _tenantDocs('visitors', communityId),
      _tenantDocs('complaints', communityId),
      _tenantDocs('bills', communityId),
    ]);

    final users = results[0];
    final buildings = results[1];
    final visitors = results[2];
    final complaints = results[3];
    final bills = results[4];
    final now = DateTime.now();

    final visitorsToday =
        visitors
            ?.where((doc) => _sameDay(_visitorDate(doc.data()), now))
            .map(
              (doc) => DashboardRecord(
                title:
                    _firstString(doc.data(), const [
                      'visitorName',
                      'name',
                      'guestName',
                    ]) ??
                    'Visitor',
                subtitle: _joinNonEmpty([
                  _firstString(doc.data(), const ['flatLabel', 'flatNumber']),
                  _firstString(doc.data(), const ['purpose', 'visitPurpose']),
                ]),
                status: _visitorStatus(doc.data()),
                date: _visitorDate(doc.data()),
              ),
            )
            .toList()
          ?..sort(_newestRecordFirst);

    final recentComplaints =
        complaints
            ?.map(
              (doc) => DashboardRecord(
                title:
                    _firstString(doc.data(), const [
                      'title',
                      'subject',
                      'complaintTitle',
                      'category',
                    ]) ??
                    'Complaint',
                subtitle: _joinNonEmpty([
                  _firstString(doc.data(), const [
                    'residentName',
                    'userName',
                    'submittedByName',
                  ]),
                  _firstString(doc.data(), const ['flatLabel', 'flatNumber']),
                ]),
                status: _complaintStatus(doc.data()),
                date: _complaintDate(doc.data()),
              ),
            )
            .toList()
          ?..sort(_newestRecordFirst);

    return AdminDashboardData(
      residents: users?.where((doc) {
        final role = doc.data()['role']?.toString().trim().toLowerCase();
        return role == null || role.isEmpty || role == 'resident';
      }).length,
      buildings: buildings?.length,
      pendingVisitors: visitors
          ?.where((doc) => _visitorStatus(doc.data()) == 'pending')
          .length,
      openComplaints: complaints
          ?.where((doc) => _isOpenComplaint(_complaintStatus(doc.data())))
          .length,
      visitorsToday: visitorsToday?.take(5).toList(growable: false),
      recentComplaints: recentComplaints?.take(5).toList(growable: false),
      paidAmount: _billTotal(bills, const {'paid', 'settled', 'approved'}),
      pendingAmount: _billTotal(bills, const {'pending', 'due', 'unpaid'}),
      overdueAmount: _billTotal(bills, const {'overdue'}),
    );
  }

  Future<ResidentDashboardData> residentDashboard({
    required String communityId,
    required String uid,
    String? flatId,
  }) async {
    final results = await Future.wait([
      _residentDocs('complaints', communityId, field: 'userId', value: uid),
      _residentDocs('visitors', communityId, field: 'hostUserId', value: uid),
      flatId == null || flatId.isEmpty
          ? Future.value(null)
          : _residentDocs('bills', communityId, field: 'flatId', value: flatId),
      _residentDocs('notices', communityId),
      _residentDocs('events', communityId),
    ]);

    final complaints = results[0];
    final visitors = results[1];
    final bills = results[2];
    final notices = results[3];
    final events = results[4];
    final now = DateTime.now();
    final visibleNotices = notices?.where((doc) {
      final data = doc.data();
      final active =
          data['isActive'] == true ||
          data['status']?.toString().toLowerCase() == 'published';
      final expiry = _extractDate(data, const ['expiryDate', 'expiresAt']);
      final targets = data['targetFlats'];
      final targetFlats = targets is Iterable
          ? targets.map((value) => value.toString()).toList()
          : const <String>[];
      final targetedToResident =
          targetFlats.isEmpty ||
          (flatId != null && flatId.isNotEmpty && targetFlats.contains(flatId));
      return active &&
          targetedToResident &&
          (expiry == null || !expiry.isBefore(now));
    }).toList();

    visibleNotices?.sort(
      (a, b) =>
          _dateOrEpoch(b.data(), const [
            'publishDate',
            'publishedAt',
            'createdAt',
          ]).compareTo(
            _dateOrEpoch(a.data(), const [
              'publishDate',
              'publishedAt',
              'createdAt',
            ]),
          ),
    );

    final upcomingEvents = events?.where((doc) {
      final date = _eventDate(doc.data());
      return date != null && !date.isBefore(_startOfDay(now));
    }).toList();
    upcomingEvents?.sort(
      (a, b) => _eventDate(a.data())!.compareTo(_eventDate(b.data())!),
    );

    final pendingBills = bills
        ?.where(
          (doc) => const {
            'pending',
            'due',
            'unpaid',
            'overdue',
          }.contains(_billStatus(doc.data())),
        )
        .toList();

    return ResidentDashboardData(
      openComplaints: complaints
          ?.where((doc) => _isOpenComplaint(_complaintStatus(doc.data())))
          .length,
      visitorsToday: visitors
          ?.where((doc) => _sameDay(_visitorDate(doc.data()), now))
          .length,
      pendingBills: pendingBills?.length,
      pendingAmount: pendingBills?.fold<double>(
        0,
        (total, doc) => total + _billAmount(doc.data()),
      ),
      activeNotices: visibleNotices?.length,
      recentNotices: visibleNotices
          ?.take(4)
          .map(
            (doc) => DashboardRecord(
              title:
                  _firstString(doc.data(), const [
                    'title',
                    'subject',
                    'name',
                  ]) ??
                  'Community notice',
              subtitle:
                  _firstString(doc.data(), const [
                    'content',
                    'message',
                    'description',
                  ]) ??
                  'No additional details',
              status: _firstString(doc.data(), const ['priority', 'category']),
              date: _extractDate(doc.data(), const [
                'publishDate',
                'publishedAt',
                'createdAt',
              ]),
            ),
          )
          .toList(growable: false),
      upcomingEvents: upcomingEvents
          ?.take(4)
          .map(
            (doc) => DashboardRecord(
              title:
                  _firstString(doc.data(), const [
                    'title',
                    'name',
                    'eventName',
                  ]) ??
                  'Community event',
              subtitle:
                  _firstString(doc.data(), const [
                    'location',
                    'venue',
                    'description',
                  ]) ??
                  'Community event',
              status: _firstString(doc.data(), const ['status', 'category']),
              date: _eventDate(doc.data()),
            ),
          )
          .toList(growable: false),
    );
  }

  // Kept for the existing My Community page.
  Future<DashboardMetrics> adminMetrics(String communityId) async {
    final results = await Future.wait([
      _tenantDocs('users', communityId),
      _tenantDocs('buildings', communityId),
      _tenantDocs('visitors', communityId),
      _tenantDocs('complaints', communityId),
    ]);
    return DashboardMetrics({
      'residents': results[0]?.where((doc) {
        final role = doc.data()['role']?.toString().trim().toLowerCase();
        return role == null || role.isEmpty || role == 'resident';
      }).length,
      'buildings': results[1]?.length,
      'visitors': results[2]?.length,
      'complaints': results[3]?.length,
    });
  }

  Future<DashboardMetrics> residentMetrics({
    required String communityId,
    required String uid,
    String? flatId,
  }) async {
    final data = await residentDashboard(
      communityId: communityId,
      uid: uid,
      flatId: flatId,
    );
    return DashboardMetrics({
      'complaints': data.openComplaints,
      'visitors': data.visitorsToday,
      'bills': data.pendingBills,
      'notices': data.activeNotices,
      'events': data.upcomingEvents?.length,
    });
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>?> _tenantDocs(
    String collection,
    String communityId,
  ) async {
    try {
      final snapshot = await _db
          .collection(collection)
          .where('communityId', isEqualTo: communityId)
          .get();
      return snapshot.docs
          .where((doc) => doc.data()['communityId']?.toString() == communityId)
          .toList(growable: false);
    } on FirebaseException {
      return null;
    }
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>?> _residentDocs(
    String collection,
    String communityId, {
    String? field,
    String? value,
  }) async {
    try {
      Query<Map<String, dynamic>> query = _db
          .collection(collection)
          .where('communityId', isEqualTo: communityId);
      if (field != null && value != null) {
        query = query.where(field, isEqualTo: value);
      }
      final snapshot = await query.get();
      return snapshot.docs
          .where((doc) => doc.data()['communityId']?.toString() == communityId)
          .toList(growable: false);
    } on FirebaseException {
      return null;
    }
  }
}

int _newestRecordFirst(DashboardRecord first, DashboardRecord second) {
  final firstDate = first.date ?? DateTime.fromMillisecondsSinceEpoch(0);
  final secondDate = second.date ?? DateTime.fromMillisecondsSinceEpoch(0);
  return secondDate.compareTo(firstDate);
}

String? _firstString(Map<String, dynamic> data, List<String> keys) {
  for (final key in keys) {
    final value = data[key]?.toString().trim();
    if (value != null && value.isNotEmpty) return value;
  }
  return null;
}

String _joinNonEmpty(Iterable<String?> values) {
  final parts = values.whereType<String>().where((value) => value.isNotEmpty);
  return parts.isEmpty ? 'Details unavailable' : parts.join(' · ');
}

DateTime? _extractDate(Map<String, dynamic> data, List<String> keys) {
  for (final key in keys) {
    final value = data[key];
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) {
      final parsed = DateTime.tryParse(value);
      if (parsed != null) return parsed;
    }
  }
  return null;
}

DateTime? _recordDate(Map<String, dynamic> data) =>
    _extractDate(data, const ['updatedAt', 'createdAt', 'approvedAt']);

DateTime? _visitorDate(Map<String, dynamic> data) => _extractDate(data, const [
  'visitDate',
  'visitAt',
  'expectedAt',
  'createdAt',
]);

DateTime? _complaintDate(Map<String, dynamic> data) => _extractDate(
  data,
  const ['createdAt', 'submittedAt', 'reportedAt', 'updatedAt'],
);

DateTime? _eventDate(Map<String, dynamic> data) => _extractDate(data, const [
  'eventDate',
  'startDate',
  'startsAt',
  'scheduledAt',
]);

DateTime _dateOrEpoch(Map<String, dynamic> data, List<String> keys) =>
    _extractDate(data, keys) ?? DateTime.fromMillisecondsSinceEpoch(0);

DateTime _startOfDay(DateTime date) =>
    DateTime(date.year, date.month, date.day);

bool _sameDay(DateTime? first, DateTime second) =>
    first != null &&
    first.year == second.year &&
    first.month == second.month &&
    first.day == second.day;

String _visitorStatus(Map<String, dynamic> data) {
  final value = _firstString(data, const [
    'status',
    'visitStatus',
    'approvalStatus',
  ])?.toLowerCase().replaceAll('_', '').replaceAll(' ', '');
  if (value == null || value.isEmpty || value == 'pendingapproval') {
    return 'pending';
  }
  return value;
}

String _complaintStatus(Map<String, dynamic> data) {
  final value = _firstString(data, const [
    'status',
    'complaintStatus',
    'resolutionStatus',
  ])?.toLowerCase().replaceAll('_', '').replaceAll(' ', '');
  return value == null || value.isEmpty ? 'open' : value;
}

bool _isOpenComplaint(String status) =>
    status == 'open' || status == 'pending' || status == 'inprogress';

String _billStatus(Map<String, dynamic> data) {
  final value = _firstString(data, const [
    'status',
    'billStatus',
    'paymentStatus',
  ])?.toLowerCase().replaceAll('_', '').replaceAll(' ', '');
  return value == null || value.isEmpty || value == 'pendingapproval'
      ? 'pending'
      : value;
}

double _billAmount(Map<String, dynamic> data) {
  for (final key in const [
    'amount',
    'totalAmount',
    'billAmount',
    'total',
    'dueAmount',
  ]) {
    final value = data[key];
    if (value is num) return value.toDouble();
    if (value is String) {
      final parsed = double.tryParse(value.replaceAll(',', ''));
      if (parsed != null) return parsed;
    }
  }
  return 0;
}

double? _billTotal(
  List<QueryDocumentSnapshot<Map<String, dynamic>>>? bills,
  Set<String> statuses,
) {
  if (bills == null) return null;
  return bills
      .where((doc) => statuses.contains(_billStatus(doc.data())))
      .fold<double>(0, (total, doc) => total + _billAmount(doc.data()));
}
