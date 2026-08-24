import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'admin_tenant_context.dart';

class AdminService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final String _collection = 'admins'; // Changed from 'users' to 'admins'

  String? getCurrentCommunityId() {
    try {
      return AdminTenantContext.instance.requireCommunityId();
    } on StateError {
      return null;
    }
  }

  String requireCurrentCommunityId() =>
      AdminTenantContext.instance.requireCommunityId();

  // Get current admin ID (Firebase Auth UID)
  String? getCurrentAdminId() {
    final user = _auth.currentUser;
    if (user == null) {
      print('AdminService: No user logged in');
      return null;
    }
    print('AdminService: Current admin ID: ${user.uid}');
    return user.uid;
  }

  // Get admin profile data from users collection
  Future<Map<String, dynamic>?> getAdminProfile() async {
    try {
      final adminId = getCurrentAdminId();
      if (adminId == null) {
        print('AdminService: Cannot get profile - no admin logged in');
        return null;
      }

      print('AdminService: Fetching profile for admin: $adminId');
      final doc = await _firestore.collection(_collection).doc(adminId).get();

      if (!doc.exists) {
        print('AdminService: Admin profile not found in Firestore');
        return null;
      }

      final data = doc.data();
      print('AdminService: Profile fetched successfully');
      print('  Name: ${data?['name']}');
      print('  Email: ${data?['email']}');
      print('  Role: ${data?['role']}');

      return data;
    } catch (e) {
      print('AdminService ERROR: Failed to get admin profile: $e');
      return null;
    }
  }

  // Add building to admin's buildingIds array (DEPRECATED - not needed with direct adminId filtering)
  // Kept for backward compatibility but does nothing
  Future<void> addBuildingToAdmin(String buildingId) async {
    // No longer needed - buildings are filtered by adminId directly
    print(
      'AdminService: addBuildingToAdmin called but not needed (using direct adminId filtering)',
    );
    return;
  }

  // Watch selected community's building IDs.
  Stream<List<String>> watchAdminBuildingIds() {
    final communityId = getCurrentCommunityId();
    if (communityId == null) {
      return Stream.value([]);
    }

    return _firestore
        .collection('buildings')
        .where('communityId', isEqualTo: communityId)
        .snapshots()
        .map((snapshot) {
          final ids = snapshot.docs.map((doc) => doc.id).toList();
          print('AdminService: Found ${ids.length} building IDs');
          return ids;
        });
  }

  // Get admin's building IDs (one-time fetch) - queries buildings collection
  Future<List<String>> getAdminBuildingIds() async {
    try {
      final communityId = getCurrentCommunityId();
      if (communityId == null) {
        return [];
      }

      print('AdminService: Fetching building IDs for community: $communityId');

      final snapshot = await _firestore
          .collection('buildings')
          .where('communityId', isEqualTo: communityId)
          .get();

      final ids = snapshot.docs.map((doc) => doc.id).toList();
      print('AdminService: Found ${ids.length} building IDs');
      return ids;
    } catch (e) {
      print('AdminService ERROR: Failed to get building IDs: $e');
      return [];
    }
  }

  // Get residents query snapshot for admin
  Future<QuerySnapshot> getResidentsForAdmin() async {
    try {
      final communityId = requireCurrentCommunityId();

      print('AdminService: Fetching residents for community: $communityId');

      final snapshot = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'resident')
          .where('communityId', isEqualTo: communityId)
          .get();

      print('AdminService: Found ${snapshot.docs.length} residents');
      return snapshot;
    } catch (e) {
      print('AdminService ERROR: Failed to get residents: $e');
      throw Exception('Failed to get residents for admin: $e');
    }
  }

  // Get flats query snapshot for admin
  Future<QuerySnapshot> getFlatsForAdmin() async {
    try {
      final communityId = requireCurrentCommunityId();
      final snapshot = await _firestore
          .collection('flats')
          .where('communityId', isEqualTo: communityId)
          .get();

      print('AdminService: Found ${snapshot.docs.length} flats');
      return snapshot;
    } catch (e) {
      print('AdminService ERROR: Failed to get flats: $e');
      throw Exception('Failed to get flats for admin: $e');
    }
  }

  // Get admin's buildings
  Future<List<DocumentSnapshot>> getAdminBuildings() async {
    try {
      final buildingIds = await getAdminBuildingIds();

      if (buildingIds.isEmpty) {
        print('AdminService: No buildings found for admin');
        return [];
      }

      print('AdminService: Fetching ${buildingIds.length} buildings');

      final snapshot = await _firestore
          .collection('buildings')
          .where(FieldPath.documentId, whereIn: buildingIds)
          .get();

      print('AdminService: Found ${snapshot.docs.length} buildings');
      return snapshot.docs;
    } catch (e) {
      print('AdminService ERROR: Failed to get buildings: $e');
      throw Exception('Failed to get buildings for admin: $e');
    }
  }
}
