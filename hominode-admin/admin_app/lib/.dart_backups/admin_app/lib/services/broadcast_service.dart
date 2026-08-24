import 'package:cloud_firestore/cloud_firestore.dart';
import 'admin_service.dart';

class BroadcastService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AdminService _adminService = AdminService();

  // Send broadcast message
  Future<String?> sendBroadcast({
    required String title,
    required String content,
    required String type, // 'Push', 'Email', 'SMS'
    required List<String> recipientIds,
    String? recipientFilter, // 'all', 'building', 'floor', 'flat', etc.
  }) async {
    try {
      final adminId = _adminService.getCurrentAdminId();
      if (adminId == null) throw Exception('Admin not logged in');

      final buildingIds = await _adminService.getAdminBuildingIds();
      if (buildingIds.isEmpty) {
        throw Exception('No buildings associated with admin');
      }

      final broadcastRef = _firestore.collection('broadcasts').doc();

      await broadcastRef.set({
        'id': broadcastRef.id,
        'title': title,
        'content': content,
        'type': type,
        'recipientIds': recipientIds,
        'recipientCount': recipientIds.length,
        'recipientFilter': recipientFilter ?? 'custom',
        'deliveredCount': recipientIds.length, // Assume all delivered for now
        'readCount': 0,
        'adminId': adminId,
        'communityId': _adminService.requireCurrentCommunityId(),
        'buildingIds': buildingIds,
        'sentAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      return broadcastRef.id;
    } catch (e) {
      print('Error sending broadcast: $e');
      return null;
    }
  }

  // Get broadcasts for admin
  Stream<List<Map<String, dynamic>>> getBroadcasts() {
    final adminId = _adminService.getCurrentAdminId();
    if (adminId == null) return Stream.value([]);

    return _firestore
        .collection('broadcasts')
        .where(
          'communityId',
          isEqualTo: _adminService.requireCurrentCommunityId(),
        )
        .orderBy('sentAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = doc.data();
            return {
              'id': doc.id,
              'title': data['title'] ?? '',
              'content': data['content'] ?? '',
              'type': data['type'] ?? 'Push',
              'recipientCount': data['recipientCount'] ?? 0,
              'deliveredCount': data['deliveredCount'] ?? 0,
              'readCount': data['readCount'] ?? 0,
              'sentAt':
                  (data['sentAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
            };
          }).toList();
        });
  }

  // Get all residents from admin's buildings
  Future<List<Map<String, dynamic>>> getAllResidents() async {
    try {
      final snapshot = await _adminService.getResidentsForAdmin();
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'id': doc.id,
          'name': data['name'] ?? 'Unknown',
          'flatId': data['flatId'] ?? '',
          'flatLabel': data['flatLabel'] ?? '',
          'buildingId': data['buildingId'] ?? '',
        };
      }).toList();
    } catch (e) {
      print('Error getting residents: $e');
      return [];
    }
  }

  // Get residents by building
  Future<List<Map<String, dynamic>>> getResidentsByBuilding(
    String buildingId,
  ) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'resident')
          .where(
            'communityId',
            isEqualTo: _adminService.requireCurrentCommunityId(),
          )
          .where('buildingId', isEqualTo: buildingId)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'name': data['name'] ?? 'Unknown',
          'flatId': data['flatId'] ?? '',
          'flatLabel': data['flatLabel'] ?? '',
        };
      }).toList();
    } catch (e) {
      print('Error getting residents by building: $e');
      return [];
    }
  }

  // Get all flats from admin's buildings
  Future<List<Map<String, dynamic>>> getAllFlats() async {
    try {
      final snapshot = await _adminService.getFlatsForAdmin();
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'id': doc.id,
          'flatLabel': data['flatLabel'] ?? '',
          'buildingId': data['buildingId'] ?? '',
          'buildingName': data['buildingName'] ?? '',
          'status': data['status'] ?? 'vacant',
          'residentId': data['residentId'],
          'residentName': data['residentName'],
        };
      }).toList();
    } catch (e) {
      print('Error getting flats: $e');
      return [];
    }
  }

  // Get recipient options for dropdown
  Future<List<Map<String, dynamic>>> getRecipientOptions() async {
    try {
      final residents = await getAllResidents();
      final flats = await getAllFlats();
      final buildings = await _adminService.getAdminBuildings();

      List<Map<String, dynamic>> options = [];

      // All Residents
      options.add({
        'label': 'All Residents (${residents.length})',
        'value': 'all_residents',
        'type': 'all',
        'count': residents.length,
        'recipientIds': residents.map((r) => r['id'] as String).toList(),
      });

      // By Building
      for (var building in buildings) {
        final buildingData = building.data() as Map<String, dynamic>;
        final buildingId = building.id;
        final buildingName = buildingData['name'] ?? 'Building';
        final buildingResidents = residents
            .where((r) => r['buildingId'] == buildingId)
            .toList();

        if (buildingResidents.isNotEmpty) {
          options.add({
            'label': '$buildingName (${buildingResidents.length} residents)',
            'value': 'building_$buildingId',
            'type': 'building',
            'count': buildingResidents.length,
            'recipientIds': buildingResidents
                .map((r) => r['id'] as String)
                .toList(),
          });
        }
      }

      // By Flat (occupied flats only)
      final occupiedFlats = flats
          .where((f) => f['status'] == 'occupied' && f['residentId'] != null)
          .toList();
      for (var flat in occupiedFlats) {
        options.add({
          'label':
              'Flat ${flat['flatLabel']} (${flat['residentName'] ?? 'Resident'})',
          'value': 'flat_${flat['id']}',
          'type': 'flat',
          'count': 1,
          'recipientIds': [flat['residentId']],
        });
      }

      return options;
    } catch (e) {
      print('Error getting recipient options: $e');
      return [];
    }
  }
}
