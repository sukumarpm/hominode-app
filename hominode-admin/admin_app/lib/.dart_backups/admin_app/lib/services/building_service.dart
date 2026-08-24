import 'package:cloud_firestore/cloud_firestore.dart';
import 'flat_service.dart';
import 'admin_service.dart';

class BuildingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'buildings';
  final FlatService _flatService = FlatService();
  final AdminService _adminService = AdminService();

  // Add a new building
  Future<String> addBuilding({
    required String name,
    required int floors,
    required int flatsPerFloor,
    required int totalFlats,
    required Map<String, String> flatBhkConfig,
  }) async {
    try {
      final adminId = _adminService.getCurrentAdminId();
      if (adminId == null) {
        throw StateError('Admin not logged in');
      }
      final communityId = _adminService.requireCurrentCommunityId();
      if (floors <= 0 || flatsPerFloor <= 0) {
        throw ArgumentError('Floors and flats per floor must be positive.');
      }
      if (totalFlats != floors * flatsPerFloor) {
        throw ArgumentError('Total flats does not match the building layout.');
      }
      // A Firestore batch supports at most 500 writes. Reserve one for the
      // building so its canonical document and every flat commit atomically.
      if (totalFlats > 499) {
        throw ArgumentError(
          'A building can contain at most 499 flats per atomic creation.',
        );
      }

      // Fetch admin details
      final adminProfile = await _adminService.getAdminProfile();
      final docRef = _firestore.collection(_collection).doc();

      final buildingData = {
        'buildingId': docRef.id,
        'buildingName': name,
        'name': name,
        'floors': floors,
        'flatsPerFloor': flatsPerFloor,
        'totalFlats': totalFlats,
        'occupied': 0,
        'vacant': totalFlats,
        'occupancyRate': 0,
        'adminId': adminId, // Link building to admin
        'communityId': communityId,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // Add admin details if available
      if (adminProfile != null) {
        buildingData['adminName'] = adminProfile['name'] ?? '';
        buildingData['adminEmail'] = adminProfile['email'] ?? '';
        buildingData['adminPhone'] = adminProfile['phone'] ?? '';
        buildingData['organization'] = adminProfile['organization'] ?? '';
      }

      final batch = _firestore.batch();
      batch.set(docRef, buildingData);
      final queuedFlatWrites = _flatService.addFlatsToBatch(
        batch: batch,
        adminId: adminId,
        buildingId: docRef.id,
        buildingName: name,
        floors: floors,
        flatsPerFloor: flatsPerFloor,
        flatBhkConfig: flatBhkConfig,
        communityId: communityId,
      );
      if (queuedFlatWrites != totalFlats) {
        throw StateError(
          'Generated $queuedFlatWrites flat writes; expected $totalFlats.',
        );
      }
      print(
        'BuildingService: generated flats=$totalFlats, '
        'queued flat writes=$queuedFlatWrites, target=flats, '
        'buildingId=${docRef.id}, communityId=$communityId',
      );
      await batch.commit();

      print(
        'BuildingService: batch commit succeeded for buildings/${docRef.id} '
        'and $queuedFlatWrites flats',
      );

      final verification = await _firestore
          .collection('flats')
          .where('buildingId', isEqualTo: docRef.id)
          .where('communityId', isEqualTo: communityId)
          .get(const GetOptions(source: Source.server));
      print(
        'BuildingService: post-commit flat verification '
        'count=${verification.docs.length}, expected=$totalFlats, '
        'buildingId=${docRef.id}, communityId=$communityId',
      );
      if (verification.docs.length != totalFlats) {
        throw StateError(
          'Building committed but flat verification returned '
          '${verification.docs.length} of $totalFlats documents.',
        );
      }

      return docRef.id;
    } on FirebaseException catch (error, stackTrace) {
      print(
        'BuildingService Firebase failure: plugin=${error.plugin}, '
        'code=${error.code}, message=${error.message}\n$stackTrace',
      );
      rethrow;
    } catch (error, stackTrace) {
      print('BuildingService failure: $error\n$stackTrace');
      rethrow;
    }
  }

  // Get all buildings for the selected community.
  Stream<List<BuildingModel>> getBuildings() {
    final communityId = _adminService.getCurrentCommunityId();
    if (communityId == null) {
      return Stream.error(
        StateError('No authorized community is selected for this admin.'),
      );
    }
    return _firestore
        .collection(_collection)
        .where('communityId', isEqualTo: communityId)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs.map((doc) {
            final building = doc.data();
            return BuildingModel(
              id: doc.id,
              name: building['name'] ?? '',
              buildingId: building['buildingId'] ?? doc.id,
              buildingName: building['buildingName'] ?? building['name'] ?? '',
              floors: building['floors'] ?? 0,
              flatsPerFloor: building['flatsPerFloor'] ?? 0,
              totalFlats: building['totalFlats'] ?? 0,
              occupied: building['occupied'] ?? 0,
              vacant: building['vacant'] ?? 0,
              occupancyRate: building['occupancyRate'] ?? 0,
              createdAt: (building['createdAt'] as Timestamp?)?.toDate(),
              updatedAt: (building['updatedAt'] as Timestamp?)?.toDate(),
            );
          }).toList(),
        );
  }

  // Helper method: Fetch buildings from buildings collection (fallback)
  Future<List<BuildingModel>> _getBuildingsFromCollection(
    String communityId,
  ) async {
    print('📥 Fetching from buildings collection...');
    final snapshot = await _firestore
        .collection(_collection)
        .where('communityId', isEqualTo: communityId)
        .get();

    print('✅ Found ${snapshot.docs.length} buildings in buildings collection');
    return snapshot.docs.map((doc) {
      final data = doc.data();
      print('   - ${data['name']} (${doc.id})');
      return BuildingModel(
        id: doc.id,
        name: data['name'] ?? '',
        buildingId: data['buildingId'] ?? doc.id,
        buildingName: data['buildingName'] ?? data['name'] ?? '',
        floors: data['floors'] ?? 0,
        flatsPerFloor: data['flatsPerFloor'] ?? 0,
        totalFlats: data['totalFlats'] ?? 0,
        occupied: data['occupied'] ?? 0,
        vacant: data['vacant'] ?? 0,
        occupancyRate: data['occupancyRate'] ?? 0,
        createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
        updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      );
    }).toList();
  }

  // Update building
  Future<void> updateBuilding({
    required String id,
    required String name,
    required int floors,
    required int flatsPerFloor,
    required int totalFlats,
  }) async {
    try {
      // Get current building data to preserve occupancy and get adminId
      final doc = await _firestore.collection(_collection).doc(id).get();
      final currentData = doc.data();
      final currentOccupied = (currentData?['occupied'] ?? 0) as int;
      final adminId = currentData?['adminId'] as String?;

      // Calculate new values
      final occupied = currentOccupied > totalFlats
          ? totalFlats
          : currentOccupied;
      final vacant = totalFlats - occupied;
      final occupancyRate = totalFlats > 0
          ? ((occupied / totalFlats) * 100).round()
          : 0;

      await _firestore.collection(_collection).doc(id).update({
        'name': name,
        'buildingName': name, // Keep buildingName in sync with name
        'floors': floors,
        'flatsPerFloor': flatsPerFloor,
        'totalFlats': totalFlats,
        'occupied': occupied,
        'vacant': vacant,
        'occupancyRate': occupancyRate,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Update building info in admin's document
      if (adminId != null) {
        await _updateBuildingInAdminDocument(
          adminId: adminId,
          buildingId: id,
          buildingName: name,
          floors: floors,
          flatsPerFloor: flatsPerFloor,
          totalFlats: totalFlats,
          occupied: occupied,
          vacant: vacant,
          occupancyRate: occupancyRate,
        );
      }

      print('BuildingService: Building $id updated successfully');
    } catch (e) {
      throw Exception('Failed to update building: $e');
    }
  }

  // Delete building
  Future<void> deleteBuilding(String id) async {
    try {
      print('🔵 BUILDING DELETION FLOW: Starting...');

      // STEP 1: Validate building exists
      print('📋 STEP 1: Validating building...');
      final buildingDoc = await _firestore
          .collection(_collection)
          .doc(id)
          .get();
      if (!buildingDoc.exists) {
        throw Exception('Building not found');
      }
      final buildingData = buildingDoc.data();
      final adminId = buildingData?['adminId'] as String?;
      final buildingName = buildingData?['name'] as String?;
      print('✅ STEP 1 PASSED: Building validated - $buildingName');

      // STEP 2: Delete all flats for this building
      print('📝 STEP 2: Deleting all flats...');
      final flatsSnapshot = await _firestore
          .collection('flats')
          .where('buildingId', isEqualTo: id)
          .get();
      print('   - Found ${flatsSnapshot.docs.length} flats to delete');

      final flatBatch = _firestore.batch();
      for (var flatDoc in flatsSnapshot.docs) {
        flatBatch.delete(flatDoc.reference);
      }
      await flatBatch.commit();
      print('✅ STEP 2 PASSED: All flats deleted');

      // STEP 3: Update all users assigned to this building
      print('🔔 STEP 3: Updating users assigned to building...');
      final usersSnapshot = await _firestore
          .collection('users')
          .where('buildingId', isEqualTo: id)
          .get();
      print('   - Found ${usersSnapshot.docs.length} users to update');

      final userBatch = _firestore.batch();
      for (var userDoc in usersSnapshot.docs) {
        userBatch.update(userDoc.reference, {
          'buildingId': null,
          'flatId': null,
          'status': 'unassigned',
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      await userBatch.commit();
      print('✅ STEP 3 PASSED: All users updated - status set to unassigned');

      // STEP 4: Remove building from admin's document
      print('📋 STEP 4: Removing building from admin document...');
      if (adminId != null) {
        await _removeBuildingFromAdminDocument(
          adminId: adminId,
          buildingId: id,
        );
      }
      print('✅ STEP 4 PASSED: Building removed from admin document');

      // STEP 5: Delete the building document
      print('📝 STEP 5: Deleting building document...');
      await _firestore.collection(_collection).doc(id).delete();
      print('✅ STEP 5 PASSED: Building document deleted');

      print('✅ BUILDING DELETION FLOW: COMPLETE');
      print('   - Building: $buildingName');
      print('   - Flats deleted: ${flatsSnapshot.docs.length}');
      print('   - Users updated: ${usersSnapshot.docs.length}');
    } catch (e) {
      print('❌ ERROR: $e');
      throw Exception('Failed to delete building: $e');
    }
  }

  // Update occupancy (called when residents are assigned/removed)
  Future<void> updateOccupancy({
    required String id,
    required int occupied,
  }) async {
    try {
      final doc = await _firestore.collection(_collection).doc(id).get();
      final data = doc.data();
      final totalFlats = data?['totalFlats'] ?? 0;

      final vacant = totalFlats - occupied;
      final occupancyRate = totalFlats > 0
          ? ((occupied / totalFlats) * 100).round()
          : 0;

      await _firestore.collection(_collection).doc(id).update({
        'occupied': occupied,
        'vacant': vacant,
        'occupancyRate': occupancyRate,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to update occupancy: $e');
    }
  }

  // Sync occupancy from flats collection
  Future<void> syncOccupancyFromFlats(String buildingId) async {
    try {
      final stats = await _flatService.getOccupancyStats(buildingId);

      // Get building data to find adminId and name
      final buildingDoc = await _firestore
          .collection(_collection)
          .doc(buildingId)
          .get();
      final buildingData = buildingDoc.data();
      final adminId = buildingData?['adminId'] as String?;
      final buildingName =
          buildingData?['buildingName'] ?? buildingData?['name'] ?? '';
      final floors = buildingData?['floors'] ?? 0;
      final flatsPerFloor = buildingData?['flatsPerFloor'] ?? 0;

      // Update building document
      await _firestore.collection(_collection).doc(buildingId).update({
        'occupied': stats.occupied,
        'vacant': stats.vacant,
        'occupancyRate': stats.occupancyRate,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Update building info in admin's document
      if (adminId != null) {
        await _updateBuildingInAdminDocument(
          adminId: adminId,
          buildingId: buildingId,
          buildingName: buildingName,
          floors: floors,
          flatsPerFloor: flatsPerFloor,
          totalFlats: stats.total,
          occupied: stats.occupied,
          vacant: stats.vacant,
          occupancyRate: stats.occupancyRate,
        );
      }

      print('BuildingService: Occupancy synced for building $buildingId');
    } catch (e) {
      throw Exception('Failed to sync occupancy: $e');
    }
  }

  // Add building details to admin's document in admins collection
  // Uses FieldValue.arrayUnion() to add to arrays without overwriting
  Future<void> _addBuildingToAdminDocument({
    required String adminId,
    required String buildingId,
    required String buildingName,
    required int floors,
    required int flatsPerFloor,
    required int totalFlats,
  }) async {
    try {
      print(
        '\n╔══════════════════════════════════════════════════════════════╗',
      );
      print('║   ADDING BUILDING TO ADMIN DOCUMENT - START                  ║');
      print('╚══════════════════════════════════════════════════════════════╝');
      print('📋 Input Parameters:');
      print('   AdminId: $adminId');
      print('   BuildingId: $buildingId');
      print('   BuildingName: $buildingName');
      print('   Floors: $floors');
      print('   FlatsPerFloor: $flatsPerFloor');
      print('   TotalFlats: $totalFlats');

      // Check if admin document exists
      print('\n📥 Step 1: Checking admin document...');
      print('   Path: admins/$adminId');
      final adminDoc = await _firestore.collection('admins').doc(adminId).get();

      print('   Document exists: ${adminDoc.exists}');

      if (!adminDoc.exists) {
        print('\n❌ ERROR: Admin document not found!');
        print('   Expected path: admins/$adminId');
        print('   Creating admin document with building data...');

        // Create admin document with building data
        await _firestore.collection('admins').doc(adminId).set({
          'buildingIds': [buildingId],
          'buildings': [
            {
              'buildingId': buildingId,
              'buildingName': buildingName,
              'floors': floors,
              'flatsPerFloor': flatsPerFloor,
              'totalFlats': totalFlats,
              'occupied': 0,
              'vacant': totalFlats,
              'occupancyRate': 0,
              'addedAt': FieldValue.serverTimestamp(),
            },
          ],
          'buildingNames': [buildingName],
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        print('   ✅ Admin document created with building data');
        print(
          '╚══════════════════════════════════════════════════════════════╝\n',
        );
        return;
      }

      final adminData = adminDoc.data()!;
      print('   ✅ Document found');
      print('   Fields: ${adminData.keys.toList()}');

      // Get current arrays
      final currentBuildings = (adminData['buildings'] as List<dynamic>?) ?? [];
      final currentBuildingIds =
          (adminData['buildingIds'] as List<dynamic>?) ?? [];
      final currentBuildingNames =
          (adminData['buildingNames'] as List<dynamic>?) ?? [];

      print('\n📊 Step 2: Current state:');
      print('   buildings array length: ${currentBuildings.length}');
      print('   buildingIds array length: ${currentBuildingIds.length}');
      print('   buildingNames array length: ${currentBuildingNames.length}');

      // Create building data object
      final buildingData = {
        'buildingId': buildingId,
        'buildingName': buildingName,
        'floors': floors,
        'flatsPerFloor': flatsPerFloor,
        'totalFlats': totalFlats,
        'occupied': 0,
        'vacant': totalFlats,
        'occupancyRate': 0,
        'addedAt': FieldValue.serverTimestamp(),
      };

      print('\n🏗️  Step 3: Creating building data object...');
      print('   Fields: ${buildingData.keys.toList()}');

      // Update admin document using FieldValue.arrayUnion()
      print('\n💾 Step 4: Updating Firestore document...');
      print('   Using FieldValue.arrayUnion() for all arrays');

      await _firestore.collection('admins').doc(adminId).update({
        'buildingIds': FieldValue.arrayUnion([buildingId]),
        'buildings': FieldValue.arrayUnion([buildingData]),
        'buildingNames': FieldValue.arrayUnion([buildingName]),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      print('   ✅ Firestore update completed');

      // Verify the update
      print('\n🔍 Step 5: Verifying update...');
      final verifyDoc = await _firestore
          .collection('admins')
          .doc(adminId)
          .get();
      if (verifyDoc.exists) {
        final verifyData = verifyDoc.data()!;
        final verifyBuildings =
            (verifyData['buildings'] as List<dynamic>?) ?? [];
        final verifyBuildingIds =
            (verifyData['buildingIds'] as List<dynamic>?) ?? [];
        final verifyBuildingNames =
            (verifyData['buildingNames'] as List<dynamic>?) ?? [];

        print('   buildings array length: ${verifyBuildings.length}');
        print('   buildingIds array length: ${verifyBuildingIds.length}');
        print('   buildingNames array length: ${verifyBuildingNames.length}');
        print(
          '   Contains buildingId: ${verifyBuildingIds.contains(buildingId)}',
        );
        print(
          '   Contains buildingName: ${verifyBuildingNames.contains(buildingName)}',
        );

        if (verifyBuildingIds.contains(buildingId) &&
            verifyBuildingNames.contains(buildingName)) {
          print('   ✅ Verification PASSED');
        } else {
          print('   ❌ Verification FAILED - Data not found in arrays!');
        }
      }

      print(
        '\n╔══════════════════════════════════════════════════════════════╗',
      );
      print('║   ADDING BUILDING TO ADMIN DOCUMENT - SUCCESS                ║');
      print('╚══════════════════════════════════════════════════════════════╝');
      print('✅ Building added to admin document successfully');
      print('   BuildingId added to buildingIds array');
      print('   Building data added to buildings array');
      print('   BuildingName added to buildingNames array');
      print('   Path: admins/$adminId');
      print(
        '╚══════════════════════════════════════════════════════════════╝\n',
      );
    } catch (e, stackTrace) {
      print(
        '\n╔══════════════════════════════════════════════════════════════╗',
      );
      print('║   ADDING BUILDING TO ADMIN DOCUMENT - FAILED                 ║');
      print('╚══════════════════════════════════════════════════════════════╝');
      print('❌ Error: $e');
      print('❌ Stack trace:');
      print(stackTrace);
      print(
        '╚══════════════════════════════════════════════════════════════╝\n',
      );
      // Don't throw - this is supplementary data, main building creation should succeed
    }
  }

  // Remove building from admin's document
  Future<void> _removeBuildingFromAdminDocument({
    required String adminId,
    required String buildingId,
  }) async {
    try {
      print('\n🔵 Removing building from admin document...');
      print('   - AdminId: $adminId');
      print('   - BuildingId: $buildingId');

      final adminDoc = await _firestore.collection('admins').doc(adminId).get();

      if (!adminDoc.exists) {
        print('⚠️  Admin document not found');
        return;
      }

      final adminData = adminDoc.data()!;
      final currentBuildings = (adminData['buildings'] as List<dynamic>?) ?? [];
      final currentBuildingNames =
          (adminData['buildingNames'] as List<dynamic>?) ?? [];

      // Find the building to remove
      Map<String, dynamic>? buildingToRemove;
      String? buildingNameToRemove;

      for (var building in currentBuildings) {
        if (building['buildingId'] == buildingId) {
          buildingToRemove = Map<String, dynamic>.from(building);
          buildingNameToRemove = building['buildingName'];
          break;
        }
      }

      if (buildingToRemove == null) {
        print('⚠️  Building not found in admin document');
        return;
      }

      // Use FieldValue.arrayRemove() to remove from arrays
      await _firestore.collection('admins').doc(adminId).update({
        'buildingIds': FieldValue.arrayRemove([buildingId]),
        'buildings': FieldValue.arrayRemove([buildingToRemove]),
        'buildingNames': buildingNameToRemove != null
            ? FieldValue.arrayRemove([buildingNameToRemove])
            : FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      print('✅ Building removed from admin document successfully\n');
    } catch (e) {
      print('❌ Failed to remove building from admin document: $e');
    }
  }

  // Update building info in admin's document
  Future<void> _updateBuildingInAdminDocument({
    required String adminId,
    required String buildingId,
    required String buildingName,
    required int floors,
    required int flatsPerFloor,
    required int totalFlats,
    required int occupied,
    required int vacant,
    required int occupancyRate,
  }) async {
    try {
      print('\n🔵 Updating building in admin document...');

      final adminDoc = await _firestore.collection('admins').doc(adminId).get();

      if (!adminDoc.exists) {
        print('⚠️  Admin document not found');
        return;
      }

      final adminData = adminDoc.data()!;
      final currentBuildings = (adminData['buildings'] as List<dynamic>?) ?? [];
      final currentBuildingNames =
          (adminData['buildingNames'] as List<dynamic>?) ?? [];

      // Find and remove old building data
      Map<String, dynamic>? oldBuildingData;
      String? oldBuildingName;

      for (var building in currentBuildings) {
        if (building['buildingId'] == buildingId) {
          oldBuildingData = Map<String, dynamic>.from(building);
          oldBuildingName = building['buildingName'];
          break;
        }
      }

      if (oldBuildingData == null) {
        print('⚠️  Building not found in admin document');
        return;
      }

      // Create new building data
      final newBuildingData = {
        'buildingId': buildingId,
        'buildingName': buildingName,
        'floors': floors,
        'flatsPerFloor': flatsPerFloor,
        'totalFlats': totalFlats,
        'occupied': occupied,
        'vacant': vacant,
        'occupancyRate': occupancyRate,
        'addedAt': oldBuildingData['addedAt'], // Preserve original timestamp
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // Remove old data and add new data
      final Map<String, dynamic> updateData = {
        'buildingIds': FieldValue.arrayUnion([
          buildingId,
        ]), // Ensure ID is in array
        'buildings': FieldValue.arrayRemove([oldBuildingData]),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // Remove old building name if it changed
      if (oldBuildingName != null && oldBuildingName != buildingName) {
        updateData['buildingNames'] = FieldValue.arrayRemove([oldBuildingName]);
      }

      await _firestore.collection('admins').doc(adminId).update(updateData);

      // Add new building data
      await _firestore.collection('admins').doc(adminId).update({
        'buildings': FieldValue.arrayUnion([newBuildingData]),
        'buildingNames': FieldValue.arrayUnion([buildingName]),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      print('✅ Building updated in admin document successfully\n');
    } catch (e) {
      print('❌ Failed to update building in admin document: $e');
    }
  }
}

// Building Model
class BuildingModel {
  final String id;
  final String name;
  final String? buildingId; // Same as id, stored for consistency
  final String? buildingName; // Same as name, stored for consistency
  final int floors;
  final int flatsPerFloor;
  final int totalFlats;
  final int occupied;
  final int vacant;
  final int occupancyRate;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  BuildingModel({
    required this.id,
    required this.name,
    this.buildingId,
    this.buildingName,
    required this.floors,
    required this.flatsPerFloor,
    required this.totalFlats,
    required this.occupied,
    required this.vacant,
    required this.occupancyRate,
    this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'buildingId': buildingId ?? id,
      'buildingName': buildingName ?? name,
      'floors': floors,
      'flatsPerFloor': flatsPerFloor,
      'totalFlats': totalFlats,
      'occupied': occupied,
      'vacant': vacant,
      'occupancyRate': occupancyRate,
    };
  }
}
