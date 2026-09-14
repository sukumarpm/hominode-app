import 'package:cloud_firestore/cloud_firestore.dart';

import '../session/web_session.dart';

class ResidentComplaintException implements Exception {
  const ResidentComplaintException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ResidentComplaint {
  const ResidentComplaint({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.status,
    required this.createdAt,
    this.updatedAt,
    this.flatLabel,
    this.assignedTo,
    this.technicianPhone,
    this.assignedStaffId,
    this.assignedStaffRole,
    this.progress,
    this.resolution,
    this.resolvedAt,
    this.imageUrl,
  });

  final String id;
  final String title;
  final String description;
  final String category;
  final String status;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? flatLabel;
  final String? assignedTo;
  final String? technicianPhone;
  final String? assignedStaffId;
  final String? assignedStaffRole;
  final String? progress;
  final String? resolution;
  final DateTime? resolvedAt;
  final String? imageUrl;

  bool get isCompleted => status == 'completed';
  bool get isInProgress => status == 'inprogress';
}

class ResidentComplaintService {
  ResidentComplaintService({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  static const String complaintsCollection = 'complaints';

  final FirebaseFirestore _db;

  Stream<List<ResidentComplaint>> watchMyComplaints(WebSession session) async* {
    final profile = await _loadValidatedProfile(session);

    final query = _db
        .collection(complaintsCollection)
        .where('communityId', isEqualTo: profile.communityId)
        .where('userId', isEqualTo: session.uid)
        .where('flatId', isEqualTo: profile.flatId);

    yield* query.snapshots().map((snapshot) {
      final complaints =
          snapshot.docs
              .where((doc) {
                final data = doc.data();
                final userId = data['userId']?.toString().trim();
                final residentId = data['residentId']?.toString().trim();
                final flatId = data['flatId']?.toString().trim();
                final communityId = data['communityId']?.toString().trim();

                final ownsComplaint =
                    userId == session.uid || residentId == session.uid;

                return communityId == profile.communityId &&
                    ownsComplaint &&
                    flatId == profile.flatId;
              })
              .map(_fromDocument)
              .toList(growable: false)
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

      return complaints;
    });
  }

  Future<void> createComplaint({
    required WebSession session,
    required String title,
    required String description,
    required String category,
  }) async {
    final profile = await _loadValidatedProfile(session);

    final cleanedTitle = title.trim();
    final cleanedDescription = description.trim();
    final cleanedCategory = category.trim().toLowerCase();

    if (cleanedTitle.isEmpty) {
      throw const ResidentComplaintException('Complaint title is required.');
    }
    if (cleanedDescription.isEmpty) {
      throw const ResidentComplaintException(
        'Complaint description is required.',
      );
    }
    if (cleanedCategory.isEmpty) {
      throw const ResidentComplaintException('Complaint category is required.');
    }

    await _db.collection(complaintsCollection).add({
      'userId': session.uid,
      'residentId': session.uid,
      'userName': profile.name,
      'userEmail': profile.email,
      'flatId': profile.flatId,
      'flatLabel': profile.flatLabel,
      'adminId': profile.adminId,
      'communityId': profile.communityId,
      'title': cleanedTitle,
      'description': cleanedDescription,
      'category': cleanedCategory,
      'status': 'pending',
      'assignedTo': null,
      'technicianPhone': null,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<_ResidentComplaintProfile> _loadValidatedProfile(
    WebSession session,
  ) async {
    final communityId = session.activeTenant?.communityId.trim() ?? '';
    final sessionFlatId = session.flatId?.trim() ?? '';
    if (session.role != WebRole.resident ||
        communityId.isEmpty ||
        sessionFlatId.isEmpty) {
      throw const ResidentComplaintException(
        'An authenticated resident with an active unit is required.',
      );
    }

    final document = await _db.collection('users').doc(session.uid).get();
    final data = document.data();
    if (!document.exists || data == null) {
      throw const ResidentComplaintException('Resident profile not found.');
    }

    if (data['role'] != 'resident' ||
        data['isActive'] != true ||
        data['approvalStatus'] != 'approved') {
      throw const ResidentComplaintException(
        'Your resident profile is not active and approved.',
      );
    }

    final profileCommunityId = data['communityId']?.toString().trim() ?? '';
    final profileFlatId = data['flatId']?.toString().trim() ?? '';
    if (profileCommunityId != communityId || profileFlatId != sessionFlatId) {
      throw const ResidentComplaintException(
        'Your resident community or unit assignment has changed. Sign in again.',
      );
    }

    final flatLabel = _firstString(data, const ['flatLabel', 'flatNumber']);

    return _ResidentComplaintProfile(
      communityId: profileCommunityId,
      flatId: profileFlatId,
      flatLabel: flatLabel ?? session.flatLabel ?? profileFlatId,
      name:
          _firstString(data, const ['name', 'fullName']) ??
          session.displayName ??
          'Resident',
      email: _firstString(data, const ['email']) ?? '',
      adminId: data['adminId'],
    );
  }

  ResidentComplaint _fromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();

    final createdAt =
        _asDate(data['createdAt']) ??
        _asDate(data['submittedAt']) ??
        DateTime.now();
    final updatedAt = _asDate(data['updatedAt']);
    final resolvedAt = _asDate(data['resolvedAt']);

    final rawStatus = _normalizeStatus(data);

    return ResidentComplaint(
      id: document.id,
      title:
          _firstString(data, const ['title', 'subject', 'complaintTitle']) ??
          'Complaint',
      description: _firstString(data, const ['description']) ?? '',
      category:
          _firstString(data, const ['category', 'type', 'complaintType']) ??
          'other',
      status: rawStatus,
      createdAt: createdAt,
      updatedAt: updatedAt,
      flatLabel: _firstString(data, const ['flatLabel']),
      assignedTo: _firstString(data, const ['assignedTo']),
      technicianPhone: _firstString(data, const ['technicianPhone']),
      assignedStaffId: _firstString(data, const ['assignedStaffId']),
      assignedStaffRole: _firstString(data, const ['assignedStaffRole']),
      progress: _firstString(data, const [
        'progressUpdate',
        'progress',
        'latestUpdate',
        'updateNote',
      ]),
      resolution: _firstString(data, const [
        'resolution',
        'resolutionNote',
        'resolutionDetails',
      ]),
      resolvedAt: resolvedAt,
      imageUrl: _firstString(data, const ['imageUrl']),
    );
  }

  String _normalizeStatus(Map<String, dynamic> data) {
    final isResolved = data['isResolved'] == true;
    if (isResolved || data['resolvedAt'] != null) {
      return 'completed';
    }

    final status = _firstString(data, const [
      'status',
      'complaintStatus',
      'resolutionStatus',
    ]);
    if (status == null) return 'pending';

    final normalized = status
        .toLowerCase()
        .replaceAll('_', '')
        .replaceAll('-', '');
    if (normalized == 'completed' ||
        normalized == 'resolved' ||
        normalized == 'closed') {
      return 'completed';
    }
    if (normalized == 'inprogress' || normalized == 'assigned') {
      return 'inprogress';
    }
    if (normalized == 'pending' || normalized == 'open') {
      return 'pending';
    }

    return normalized;
  }
}

class _ResidentComplaintProfile {
  const _ResidentComplaintProfile({
    required this.communityId,
    required this.flatId,
    required this.flatLabel,
    required this.name,
    required this.email,
    required this.adminId,
  });

  final String communityId;
  final String flatId;
  final String flatLabel;
  final String name;
  final String email;
  final Object? adminId;
}

String? _firstString(Map<String, dynamic> data, List<String> keys) {
  for (final key in keys) {
    final value = data[key]?.toString().trim();
    if (value != null && value.isNotEmpty) return value;
  }
  return null;
}

DateTime? _asDate(Object? value) => switch (value) {
  Timestamp timestamp => timestamp.toDate(),
  DateTime date => date,
  String text => DateTime.tryParse(text),
  _ => null,
};
