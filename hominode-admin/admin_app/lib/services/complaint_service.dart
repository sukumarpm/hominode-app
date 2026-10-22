import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;
import 'admin_service.dart';
import 'notification_firestore_service.dart';
import '../models/notification_models.dart';
import '../models/complaint_models.dart';

typedef ComplaintNotificationSender =
    Future<void> Function({
      required String recipientId,
      required String title,
      required String message,
      required Map<String, dynamic> metadata,
    });

typedef ComplaintWorkflowTransactionRunner =
    Future<T> Function<T>(TransactionHandler<T> transactionHandler);

class ComplaintWorkflowUpdateResult {
  const ComplaintWorkflowUpdateResult({
    required this.notificationSent,
    this.notificationError,
  });

  final bool notificationSent;
  final String? notificationError;
}

class ComplaintService {
  ComplaintService({
    FirebaseFirestore? firestore,
    AdminService? adminService,
    NotificationFirestoreService? notificationService,
    String? Function()? adminIdProvider,
    String Function()? communityIdProvider,
    ComplaintNotificationSender? notificationSender,
    ComplaintWorkflowTransactionRunner? transactionRunner,
  }) : _firestoreOverride = firestore,
       _adminServiceOverride = adminService,
       _notificationServiceOverride = notificationService,
       _adminIdProvider = adminIdProvider,
       _communityIdProvider = communityIdProvider,
       _notificationSender = notificationSender,
       _transactionRunner = transactionRunner;

  final FirebaseFirestore? _firestoreOverride;
  late final FirebaseFirestore _firestore =
      _firestoreOverride ?? FirebaseFirestore.instance;
  final AdminService? _adminServiceOverride;
  late final AdminService _adminService =
      _adminServiceOverride ?? AdminService();
  final NotificationFirestoreService? _notificationServiceOverride;
  late final NotificationFirestoreService _notificationService =
      _notificationServiceOverride ?? NotificationFirestoreService();
  final String? Function()? _adminIdProvider;
  final String Function()? _communityIdProvider;
  final ComplaintNotificationSender? _notificationSender;
  final ComplaintWorkflowTransactionRunner? _transactionRunner;
  final String _collection = 'complaints';

  String? _currentAdminId() {
    final provider = _adminIdProvider;
    return provider == null ? _adminService.getCurrentAdminId() : provider();
  }

  String _currentCommunityId() {
    final provider = _communityIdProvider;
    return provider == null
        ? _adminService.requireCurrentCommunityId()
        : provider();
  }

  Future<void> _sendComplaintNotification({
    required String recipientId,
    required String title,
    required String message,
    required Map<String, dynamic> metadata,
  }) async {
    final sender = _notificationSender;
    if (sender != null) {
      await sender(
        recipientId: recipientId,
        title: title,
        message: message,
        metadata: metadata,
      );
      return;
    }
    await _notificationService.createNotification(
      recipientId: recipientId,
      title: title,
      message: message,
      type: NotificationType.complaint,
      priority: NotificationPriority.high,
      metadata: metadata,
    );
  }

  // Get all complaints filtered by adminId
  Stream<List<ComplaintModel>> getComplaints() {
    final adminId = _currentAdminId();
    if (adminId == null) return Stream.value([]);

    return _firestore
        .collection(_collection)
        .where('communityId', isEqualTo: _currentCommunityId())
        .snapshots()
        .map((snapshot) {
          final complaints = snapshot.docs.map((doc) {
            final data = doc.data();
            return ComplaintModel.fromMap(doc.id, data);
          }).toList();

          // Sort in memory to avoid index requirement
          complaints.sort((a, b) {
            if (a.createdAt == null && b.createdAt == null) return 0;
            if (a.createdAt == null) return 1;
            if (b.createdAt == null) return -1;
            return b.createdAt!.compareTo(a.createdAt!);
          });

          return complaints;
        });
  }

  // Get pending complaints (not resolved) filtered by adminId
  Stream<List<ComplaintModel>> getPendingComplaints() {
    final adminId = _currentAdminId();
    if (adminId == null) return Stream.value([]);

    return _firestore
        .collection(_collection)
        .where('communityId', isEqualTo: _currentCommunityId())
        .where(
          'status',
          whereIn: ['pending', 'in-progress', 'inProgress', 'inprogress'],
        )
        .snapshots()
        .map((snapshot) {
          final complaints = snapshot.docs.map((doc) {
            final data = doc.data();
            return ComplaintModel.fromMap(doc.id, data);
          }).toList();

          // Sort in memory to avoid index requirement
          complaints.sort((a, b) {
            if (a.createdAt == null && b.createdAt == null) return 0;
            if (a.createdAt == null) return 1;
            if (b.createdAt == null) return -1;
            return b.createdAt!.compareTo(a.createdAt!);
          });

          return complaints;
        });
  }

  // Get pending complaints count filtered by adminId
  Stream<int> getPendingComplaintsCount() {
    final adminId = _currentAdminId();
    if (adminId == null) return Stream.value(0);

    return _firestore
        .collection(_collection)
        .where('communityId', isEqualTo: _currentCommunityId())
        .where(
          'status',
          whereIn: ['pending', 'in-progress', 'inProgress', 'inprogress'],
        )
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  static String statusValue(ComplaintStatus status) {
    switch (status) {
      case ComplaintStatus.pending:
        return 'pending';
      case ComplaintStatus.inProgress:
        return 'inprogress';
      case ComplaintStatus.resolved:
        return 'completed';
    }
  }

  /// Persists the admin-owned workflow in one tenant-scoped transaction.
  /// Resident notification is best-effort and reported independently.
  Future<ComplaintWorkflowUpdateResult> updateManualWorkflow({
    required String complaintId,
    required ComplaintStatus status,
    required String? assignedTeam,
    required String? assignedTo,
    required String? progressNote,
    required String? resolutionNote,
  }) async {
    final adminId = _currentAdminId()?.trim();
    if (adminId == null || adminId.isEmpty) {
      throw StateError('Admin authentication is required.');
    }
    final communityId = _currentCommunityId().trim();
    if (communityId.isEmpty) {
      throw StateError('Select an authorized community first.');
    }
    if (complaintId.trim().isEmpty) {
      throw ArgumentError.value(complaintId, 'complaintId');
    }

    // Null means the admin left this field unchanged; an empty string clears it.
    final normalizedTeam = assignedTeam?.trim();
    final person = assignedTo?.trim();
    _traceAssignmentValidationInputs(normalizedTeam, person);
    final progress = progressNote?.trim();
    final resolution = resolutionNote?.trim();
    if ((progress?.length ?? 0) > 2000 || (resolution?.length ?? 0) > 2000) {
      throw ArgumentError('Complaint notes must be 2000 characters or fewer.');
    }
    if ([
      progress,
      resolution,
    ].whereType<String>().any(_containsPrivateContact)) {
      throw ArgumentError(
        'Complaint updates are resident-visible. Do not include private phone numbers or email addresses.',
      );
    }

    final ref = _firestore.collection(_collection).doc(complaintId);
    late Map<String, dynamic> savedComplaint;
    Future<void> transactionHandler(Transaction transaction) async {
      final snapshot = await transaction.get(ref);
      if (!snapshot.exists) throw StateError('Complaint not found.');
      final current = snapshot.data();
      if (current == null || current['communityId'] != communityId) {
        throw StateError('Complaint is outside the selected community.');
      }

      final existingPerson = current['assignedTo']?.toString().trim();
      final unchangedLegacyPerson = person != null && person == existingPerson;
      final existingTeam = current['assignedTeam']?.toString().trim();
      final unchangedLegacyTeam =
          normalizedTeam != null && normalizedTeam == existingTeam;
      if (normalizedTeam != null &&
          !unchangedLegacyTeam &&
          normalizedTeam.length > 80) {
        throw ArgumentError.value(assignedTeam, 'assignedTeam');
      }
      if (person != null && !unchangedLegacyPerson && person.length > 240) {
        throw ArgumentError.value(assignedTo, 'assignedTo');
      }
      if (person != null &&
          person.isNotEmpty &&
          !unchangedLegacyPerson &&
          _containsPrivateContact(person)) {
        _traceRejectedAssignment(person);
        throw ArgumentError(
          'Enter a person or vendor name only. Use the community support contact for resident contact details.',
        );
      }

      final now = Timestamp.now();
      final updates = <String, dynamic>{
        'status': statusValue(status),
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (normalizedTeam != null) {
        updates['assignedTeam'] = normalizedTeam.isEmpty
            ? null
            : normalizedTeam;
      }
      if (person != null) {
        updates['assignedTo'] = person.isEmpty ? null : person;
      }
      if (progress?.isNotEmpty == true) {
        updates['progressNotes'] = [
          ..._noteHistory(current['progressNotes']),
          {'text': progress, 'createdAt': now, 'createdBy': adminId},
        ];
        // Preserve the existing Admin Web timeline contract.
        updates['progressUpdate'] = progress;
      }
      if (resolution?.isNotEmpty == true) {
        updates['resolutionNotes'] = [
          ..._noteHistory(current['resolutionNotes']),
          {'text': resolution, 'createdAt': now, 'createdBy': adminId},
        ];
      }
      if (status == ComplaintStatus.resolved) {
        updates['resolvedAt'] = now;
      }
      transaction.update(ref, updates);
      savedComplaint = {...current, ...updates};
    }

    final transactionRunner = _transactionRunner;
    if (transactionRunner == null) {
      await _firestore.runTransaction(transactionHandler);
    } else {
      await transactionRunner(transactionHandler);
    }

    final residentId =
        (savedComplaint['residentId'] ?? savedComplaint['userId'] ?? '')
            .toString()
            .trim();
    if (residentId.isEmpty) {
      return const ComplaintWorkflowUpdateResult(notificationSent: false);
    }
    final title = (savedComplaint['title'] ?? 'Complaint').toString();
    final updateParts = <String>['Status: ${status.label}'];
    if (normalizedTeam != null || person != null) {
      final savedTeam = (savedComplaint['assignedTeam'] ?? '')
          .toString()
          .trim();
      final savedPerson = (savedComplaint['assignedTo'] ?? '')
          .toString()
          .trim();
      // A legacy assignedTo can hold contact data. Keep it in Firestore, but
      // never include private contact details in resident-visible messages.
      final assignment = [
        if (savedTeam.isNotEmpty) savedTeam,
        if (savedPerson.isNotEmpty && !_containsPrivateContact(savedPerson))
          savedPerson,
      ];
      final hasStoredAssignment =
          savedTeam.isNotEmpty || savedPerson.isNotEmpty;
      updateParts.add(
        assignment.isNotEmpty
            ? 'Assigned to ${assignment.join(' — ')}'
            : hasStoredAssignment
            ? 'Assignment updated'
            : 'Assignment cleared',
      );
    }
    if (progress?.isNotEmpty == true) updateParts.add('Progress: $progress');
    if (resolution?.isNotEmpty == true) {
      updateParts.add('Resolution: $resolution');
    }
    try {
      await _sendComplaintNotification(
        recipientId: residentId,
        title: 'Complaint updated',
        message: '$title: ${updateParts.join('. ')}.',
        metadata: {
          'complaintId': complaintId,
          'status': statusValue(status),
          'title': title,
        },
      );
      return const ComplaintWorkflowUpdateResult(notificationSent: true);
    } catch (error) {
      return ComplaintWorkflowUpdateResult(
        notificationSent: false,
        notificationError: error.toString(),
      );
    }
  }

  bool _containsPrivateContact(String value) {
    final containsEmail = RegExp(
      r'\b[\w.+-]+@[\w.-]+\.[A-Za-z]{2,}\b',
    ).hasMatch(value);
    final digitCount = RegExp(r'\d').allMatches(value).length;
    return containsEmail || digitCount >= 7;
  }

  void _traceAssignmentValidationInputs(String? team, String? person) {
    if (!kDebugMode) return;
    debugPrint(
      '[ComplaintWorkflowTrace] updateManualWorkflow inputs: '
      'assignedTeam=${_classifyAssignmentValue(team, isTeam: true)}, '
      'assignedTo=${_classifyAssignmentValue(person)}\n'
      'Call stack:\n${StackTrace.current}',
    );
  }

  void _traceRejectedAssignment(String value) {
    if (!kDebugMode) return;
    debugPrint(
      '[ComplaintWorkflowTrace] rejected field=assignedTo '
      'classification=${_classifyAssignmentValue(value)}\n'
      'Validator stack:\n${StackTrace.current}',
    );
  }

  String _classifyAssignmentValue(String? value, {bool isTeam = false}) {
    final normalized = value?.trim();
    if (normalized == null) return 'omitted';
    if (normalized.isEmpty) return 'empty';
    if (isTeam) {
      return switch (normalized.toLowerCase()) {
        'management' => 'team:management',
        'security' => 'team:security',
        'maintenance' => 'team:maintenance',
        _ => 'team:other',
      };
    }
    if (RegExp(r'\b[\w.+-]+@[\w.-]+\.[A-Za-z]{2,}\b').hasMatch(normalized)) {
      return 'email-like';
    }
    if (RegExp(r'\d').allMatches(normalized).length >= 7) {
      return 'phone-like';
    }
    return 'text';
  }

  List<Map<String, dynamic>> _noteHistory(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((entry) => Map<String, dynamic>.from(entry))
        .toList(growable: true);
  }
}

// Complaint Model
class ComplaintModel {
  final String id;
  final String title;
  final String description;
  final String category;
  final String priority;
  final String status; // pending, in-progress, resolved
  final String residentId;
  final String? residentName;
  final String? flatId;
  final String? flatLabel;
  final String? assignedTo;
  final String? assignedTeam;
  final List<Map<String, dynamic>> progressNotes;
  final List<Map<String, dynamic>> resolutionNotes;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  ComplaintModel({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.priority,
    required this.status,
    required this.residentId,
    this.residentName,
    this.flatId,
    this.flatLabel,
    this.assignedTo,
    this.assignedTeam,
    this.progressNotes = const [],
    this.resolutionNotes = const [],
    this.createdAt,
    this.updatedAt,
  });

  factory ComplaintModel.fromMap(String id, Map<String, dynamic> data) {
    return ComplaintModel(
      id: id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      category: data['category'] ?? '',
      priority: data['priority'] ?? 'low',
      status: data['status'] ?? 'pending',
      residentId: data['residentId'] ?? '',
      residentName: data['residentName'],
      flatId: data['flatId'],
      flatLabel: data['flatLabel'] ?? data['unitLabel'],
      assignedTo: data['assignedTo'],
      assignedTeam: data['assignedTeam'] as String?,
      progressNotes: _parseComplaintNotes(data['progressNotes']),
      resolutionNotes: _parseComplaintNotes(data['resolutionNotes']),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'category': category,
      'priority': priority,
      'status': status,
      'residentId': residentId,
      'residentName': residentName,
      'flatId': flatId,
      if (flatLabel != null) 'flatLabel': flatLabel,
      'assignedTo': assignedTo,
      'assignedTeam': assignedTeam,
      'progressNotes': progressNotes,
      'resolutionNotes': resolutionNotes,
    };
  }
}

List<Map<String, dynamic>> _parseComplaintNotes(dynamic raw) {
  if (raw is! List) return const [];
  return raw
      .whereType<Map>()
      .map((note) => Map<String, dynamic>.from(note))
      .toList(growable: false);
}
