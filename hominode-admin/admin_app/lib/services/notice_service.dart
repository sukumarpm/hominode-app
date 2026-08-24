import 'package:cloud_firestore/cloud_firestore.dart';
import 'admin_service.dart';

class NoticeService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AdminService _adminService = AdminService();
  final String _collection = 'notices';

  // Create a new notice
  Future<String> createNotice({
    required String title,
    required String content,
    required String type,
    required String priority,
    required String status,
    required String authorId,
    required String authorName,
    required List<String> targetFlats,
    bool isUrgent = false,
    bool requiresAcknowledgment = false,
    DateTime? expiresAt,
  }) async {
    try {
      // Get admin details for multi-tenancy
      final adminId = _adminService.getCurrentAdminId();
      if (adminId == null) {
        throw Exception('Admin not logged in');
      }

      final adminProfile = await _adminService.getAdminProfile();
      final buildingIds = await _adminService.getAdminBuildingIds();

      final docRef = await _firestore.collection(_collection).add({
        'title': title,
        'content': content,
        'type': type,
        'priority': priority,
        'status': status,
        'authorId': authorId,
        'authorName': authorName,
        'targetFlats': targetFlats,
        'isUrgent': isUrgent,
        'requiresAcknowledgment': requiresAcknowledgment,
        'expiresAt': expiresAt != null ? Timestamp.fromDate(expiresAt) : null,
        // Multi-tenancy fields
        'adminId': adminId,
        'communityId': _adminService.requireCurrentCommunityId(),
        'buildingIds': buildingIds,
        'adminName': adminProfile?['name'] ?? '',
        'adminEmail': adminProfile?['email'] ?? '',
        'adminPhone': adminProfile?['phone'] ?? '',
        'organization': adminProfile?['organization'] ?? '',
        'createdAt': FieldValue.serverTimestamp(),
        'publishedAt': status == 'published'
            ? FieldValue.serverTimestamp()
            : null,
        'viewCount': 0,
        'acknowledgmentCount': 0,
        'attachments': [],
      });

      print('NoticeService: Notice created with ID: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      print('NoticeService ERROR: Failed to create notice: $e');
      throw Exception('Failed to create notice: $e');
    }
  }

  // Get all notices filtered by admin
  Stream<List<NoticeModel>> getNotices() {
    final adminId = _adminService.getCurrentAdminId();
    if (adminId == null) return Stream.value([]);

    return _firestore
        .collection(_collection)
        .where(
          'communityId',
          isEqualTo: _adminService.requireCurrentCommunityId(),
        )
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = doc.data();
            return NoticeModel.fromMap(doc.id, data);
          }).toList();
        });
  }

  // Get notices by status filtered by admin
  Stream<List<NoticeModel>> getNoticesByStatus(String status) {
    final adminId = _adminService.getCurrentAdminId();
    if (adminId == null) return Stream.value([]);

    return _firestore
        .collection(_collection)
        .where(
          'communityId',
          isEqualTo: _adminService.requireCurrentCommunityId(),
        )
        .where('status', isEqualTo: status)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = doc.data();
            return NoticeModel.fromMap(doc.id, data);
          }).toList();
        });
  }

  // Update notice
  Future<void> updateNotice(
    String noticeId, {
    String? title,
    String? content,
    String? type,
    String? priority,
    String? status,
    List<String>? targetFlats,
    bool? isUrgent,
    bool? requiresAcknowledgment,
    DateTime? expiresAt,
  }) async {
    try {
      final Map<String, dynamic> updates = {
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (title != null) updates['title'] = title;
      if (content != null) updates['content'] = content;
      if (type != null) updates['type'] = type;
      if (priority != null) updates['priority'] = priority;
      if (status != null) {
        updates['status'] = status;
        if (status == 'published') {
          updates['publishedAt'] = FieldValue.serverTimestamp();
        }
      }
      if (targetFlats != null) updates['targetFlats'] = targetFlats;
      if (isUrgent != null) updates['isUrgent'] = isUrgent;
      if (requiresAcknowledgment != null) {
        updates['requiresAcknowledgment'] = requiresAcknowledgment;
      }
      if (expiresAt != null) {
        updates['expiresAt'] = Timestamp.fromDate(expiresAt);
      }

      await _firestore.collection(_collection).doc(noticeId).update(updates);
      print('NoticeService: Notice $noticeId updated successfully');
    } catch (e) {
      print('NoticeService ERROR: Failed to update notice: $e');
      throw Exception('Failed to update notice: $e');
    }
  }

  // Delete notice
  Future<void> deleteNotice(String noticeId) async {
    try {
      await _firestore.collection(_collection).doc(noticeId).delete();
      print('NoticeService: Notice $noticeId deleted successfully');
    } catch (e) {
      print('NoticeService ERROR: Failed to delete notice: $e');
      throw Exception('Failed to delete notice: $e');
    }
  }

  // Publish notice (change status from draft to published)
  Future<void> publishNotice(String noticeId) async {
    try {
      await _firestore.collection(_collection).doc(noticeId).update({
        'status': 'published',
        'publishedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      print('NoticeService: Notice $noticeId published successfully');
    } catch (e) {
      print('NoticeService ERROR: Failed to publish notice: $e');
      throw Exception('Failed to publish notice: $e');
    }
  }

  // Archive notice
  Future<void> archiveNotice(String noticeId) async {
    try {
      await _firestore.collection(_collection).doc(noticeId).update({
        'status': 'archived',
        'updatedAt': FieldValue.serverTimestamp(),
      });
      print('NoticeService: Notice $noticeId archived successfully');
    } catch (e) {
      print('NoticeService ERROR: Failed to archive notice: $e');
      throw Exception('Failed to archive notice: $e');
    }
  }

  // Get flats from Firestore filtered by admin's buildings
  Future<List<FlatOption>> getFlats() async {
    try {
      print('NoticeService: Fetching flats from Firestore');

      final buildingIds = await _adminService.getAdminBuildingIds();
      if (buildingIds.isEmpty) {
        print('NoticeService: No buildings assigned to admin');
        return [];
      }

      final snapshot = await _firestore
          .collection('flats')
          .where('buildingId', whereIn: buildingIds)
          .get();

      print('NoticeService: Found ${snapshot.docs.length} flats');

      final flats = snapshot.docs.map((doc) {
        final data = doc.data();
        return FlatOption(
          id: doc.id,
          flatNumber: data['id'] ?? doc.id,
          buildingName: data['buildingName'] ?? '',
          floor: data['floor']?.toString() ?? '',
          bhkType: data['bhkType'] ?? data['type'] ?? '',
          status: data['status'] ?? 'vacant',
        );
      }).toList();

      // Sort by building name, then floor (descending), then flat number
      flats.sort((a, b) {
        // First by building name
        final buildingCompare = a.buildingName.compareTo(b.buildingName);
        if (buildingCompare != 0) return buildingCompare;

        // Then by floor (descending)
        final floorA = int.tryParse(a.floor) ?? 0;
        final floorB = int.tryParse(b.floor) ?? 0;
        final floorCompare = floorB.compareTo(floorA);
        if (floorCompare != 0) return floorCompare;

        // Then by flat number
        return a.flatNumber.compareTo(b.flatNumber);
      });

      print('NoticeService: Returning ${flats.length} sorted flats');
      return flats;
    } catch (e) {
      print('NoticeService ERROR: Failed to fetch flats: $e');
      return [];
    }
  }
}

// Notice Model for Firestore
class NoticeModel {
  final String id;
  final String title;
  final String content;
  final String type;
  final String priority;
  final String status;
  final DateTime? createdAt;
  final DateTime? publishedAt;
  final DateTime? expiresAt;
  final String authorId;
  final String authorName;
  final List<String> targetFlats;
  final bool isUrgent;
  final bool requiresAcknowledgment;
  final int viewCount;
  final int acknowledgmentCount;
  final List<String> attachments;

  NoticeModel({
    required this.id,
    required this.title,
    required this.content,
    required this.type,
    required this.priority,
    required this.status,
    this.createdAt,
    this.publishedAt,
    this.expiresAt,
    required this.authorId,
    required this.authorName,
    this.targetFlats = const [],
    this.isUrgent = false,
    this.requiresAcknowledgment = false,
    this.viewCount = 0,
    this.acknowledgmentCount = 0,
    this.attachments = const [],
  });

  factory NoticeModel.fromMap(String id, Map<String, dynamic> data) {
    return NoticeModel(
      id: id,
      title: data['title'] ?? '',
      content: data['content'] ?? '',
      type: data['type'] ?? 'general',
      priority: data['priority'] ?? 'medium',
      status: data['status'] ?? 'draft',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      publishedAt: (data['publishedAt'] as Timestamp?)?.toDate(),
      expiresAt: (data['expiresAt'] as Timestamp?)?.toDate(),
      authorId: data['authorId'] ?? '',
      authorName: data['authorName'] ?? 'Unknown',
      targetFlats: List<String>.from(data['targetFlats'] ?? []),
      isUrgent: data['isUrgent'] ?? false,
      requiresAcknowledgment: data['requiresAcknowledgment'] ?? false,
      viewCount: data['viewCount'] ?? 0,
      acknowledgmentCount: data['acknowledgmentCount'] ?? 0,
      attachments: List<String>.from(data['attachments'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'content': content,
      'type': type,
      'priority': priority,
      'status': status,
      'authorId': authorId,
      'authorName': authorName,
      'targetFlats': targetFlats,
      'isUrgent': isUrgent,
      'requiresAcknowledgment': requiresAcknowledgment,
      'viewCount': viewCount,
      'acknowledgmentCount': acknowledgmentCount,
      'attachments': attachments,
    };
  }
}

// Flat Option Model
class FlatOption {
  final String id;
  final String flatNumber;
  final String buildingName;
  final String floor;
  final String bhkType;
  final String status;

  FlatOption({
    required this.id,
    required this.flatNumber,
    required this.buildingName,
    required this.floor,
    this.bhkType = '',
    this.status = 'vacant',
  });

  String get displayName {
    final parts = <String>[];

    // Add flat number
    parts.add(flatNumber);

    // Add building name if available
    if (buildingName.isNotEmpty) {
      parts.add(buildingName);
    }

    // Add BHK type if available
    if (bhkType.isNotEmpty) {
      parts.add('($bhkType)');
    }

    return parts.join(' - ');
  }

  String get subtitle {
    final parts = <String>[];

    // Add floor info
    if (floor.isNotEmpty) {
      parts.add('Floor $floor');
    }

    // Add status
    if (status.isNotEmpty) {
      final statusText = status == 'occupied'
          ? 'Occupied'
          : status == 'vacant'
          ? 'Vacant'
          : status == 'maintenance'
          ? 'Maintenance'
          : status;
      parts.add(statusText);
    }

    return parts.join(' • ');
  }
}
