// lib/src/services/organization_service.dart
// Organization Service - Fetches organization name from admins collection

import 'package:cloud_firestore/cloud_firestore.dart';

/// Organization Service
/// Fetches organization details from Firestore admins collection
class OrganizationService {
  // Singleton pattern
  static final OrganizationService instance = OrganizationService._internal();
  factory OrganizationService() => instance;
  OrganizationService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Cache organization data
  String? _cachedOrganizationName;
  String? _cachedBuildingName;

  /// Get organization name based on building name
  /// 
  /// Flow:
  /// 1. Get user's building name from users collection
  /// 2. Query admins collection where buildingName matches
  /// 3. Return organizationName from admin document
  /// 
  /// Returns organization name or fallback text
  Future<String> getOrganizationName({
    required String buildingName,
    bool forceRefresh = false,
  }) async {
    try {
      // Return cached data if available and not forcing refresh
      if (!forceRefresh && 
          _cachedBuildingName == buildingName && 
          _cachedOrganizationName != null) {
        print('✅ Returning cached organization name: $_cachedOrganizationName');
        return _cachedOrganizationName!;
      }

      print('📥 Fetching organization name for building: $buildingName');

      // Query admins collection for matching building name
      final querySnapshot = await _firestore
          .collection('admins')
          .where('buildingName', isEqualTo: buildingName)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        print('⚠️  No admin found for building: $buildingName');
        return 'Your Apartment'; // Fallback
      }

      final adminData = querySnapshot.docs.first.data();
      final organizationName = adminData['organizationName'] as String?;

      if (organizationName == null || organizationName.isEmpty) {
        print('⚠️  Organization name not set for building: $buildingName');
        return 'Your Apartment'; // Fallback
      }

      // Cache the data
      _cachedOrganizationName = organizationName;
      _cachedBuildingName = buildingName;

      print('✅ Organization name fetched: $organizationName');
      return organizationName;

    } catch (e) {
      print('❌ Error fetching organization name: $e');
      return 'Your Apartment'; // Fallback on error
    }
  }

  /// Get organization name for current user
  /// 
  /// Fetches user's building name first, then gets organization name
  Future<String> getOrganizationNameForUser(String userId) async {
    try {
      print('📥 Fetching organization name for user: $userId');

      // Get user document
      final userDoc = await _firestore.collection('users').doc(userId).get();

      if (!userDoc.exists) {
        print('❌ User document not found');
        return 'Your Apartment';
      }

      final userData = userDoc.data()!;
      
      // Try to get building name from different possible fields
      String? buildingName;
      
      // Check for buildingName field
      if (userData.containsKey('buildingName')) {
        buildingName = userData['buildingName'] as String?;
      }
      
      // Check for buildingId and fetch building name
      if (buildingName == null && userData.containsKey('buildingId')) {
        final buildingId = userData['buildingId'] as String?;
        if (buildingId != null) {
          final buildingDoc = await _firestore
              .collection('buildings')
              .doc(buildingId)
              .get();
          
          if (buildingDoc.exists) {
            buildingName = buildingDoc.data()?['name'] as String?;
          }
        }
      }

      if (buildingName == null || buildingName.isEmpty) {
        print('⚠️  Building name not found for user');
        return 'Your Apartment';
      }

      print('✅ User building name: $buildingName');

      // Get organization name for this building
      return await getOrganizationName(buildingName: buildingName);

    } catch (e) {
      print('❌ Error fetching organization name for user: $e');
      return 'Your Apartment';
    }
  }

  /// Clear cached data
  void clearCache() {
    _cachedOrganizationName = null;
    _cachedBuildingName = null;
    print('🗑️  Organization cache cleared');
  }
}
