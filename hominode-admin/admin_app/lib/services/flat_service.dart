import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../models/unit_schema.dart';
import 'admin_tenant_context.dart';

class FlatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'flats';

  /// Adds canonical flat documents to the caller's atomic building batch.
  int addFlatsToBatch({
    required WriteBatch batch,
    required String buildingId,
    required String buildingName,
    required int floors,
    required int flatsPerFloor,
    required Map<String, String> flatBhkConfig,
    required String adminId,
    required String communityId,
  }) {
    if (buildingName.trim().isEmpty) {
      throw ArgumentError('Building name cannot be empty.');
    }
    if (floors <= 0 || flatsPerFloor <= 0) {
      throw ArgumentError('Floors and flats per floor must be positive.');
    }
    var flatCounter = 1;
    final prefix = buildingName[0].toUpperCase();
    for (var floor = 1; floor <= floors; floor++) {
      for (var flatNumber = 1; flatNumber <= flatsPerFloor; flatNumber++) {
        final flatId = '$prefix${flatCounter.toString().padLeft(3, '0')}';
        final bhkType = flatBhkConfig[flatId] ?? '2BHK';
        final ref = _firestore.collection(_collection).doc();
        batch.set(ref, {
          'id': ref.id,
          'flatId': flatId,
          'flatLabel': flatId,
          'buildingId': buildingId,
          'buildingName': buildingName,
          'floor': floor,
          'flatNumber': flatNumber,
          'type': bhkType,
          'bhkType': bhkType,
          'area': _getAreaForBhk(bhkType),
          'status': 'vacant',
          'residentName': null,
          'residentId': null,
          'residentUserId': null,
          'adminId': adminId,
          'communityId': communityId,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        flatCounter++;
      }
    }
    return flatCounter - 1;
  }

  // Generate flats for a building with BHK configuration and admin details
  // Flat IDs follow format: A001, A002, A003... (letter + 3-digit number)
  Future<void> generateFlatsForBuilding({
    required String buildingId,
    required String buildingName,
    required int floors,
    required int flatsPerFloor,
    required Map<String, String> flatBhkConfig,
    String? adminId,
    required String communityId,
  }) async {
    try {
      print('🔵 FLAT GENERATION FLOW: Starting...');
      print('📋 STEP 1: Validating input parameters...');
      print('   - buildingId: $buildingId');
      print('   - buildingName: $buildingName');
      print('   - floors: $floors');
      print('   - flatsPerFloor: $flatsPerFloor');
      print('   - adminId: $adminId');

      // STEP 1: Validate input
      if (buildingName.isEmpty) {
        throw Exception('Building name cannot be empty');
      }
      if (floors <= 0 || flatsPerFloor <= 0) {
        throw Exception('Floors and flatsPerFloor must be greater than 0');
      }
      print('✅ STEP 1 PASSED: Input parameters validated');

      // STEP 2: Fetch admin details
      print('📋 STEP 2: Fetching admin details...');
      Map<String, dynamic>? adminData;
      if (adminId != null) {
        try {
          final adminDoc = await _firestore
              .collection('admins')
              .doc(adminId)
              .get();
          if (adminDoc.exists) {
            adminData = adminDoc.data();
            print('✅ Admin details fetched');
          }
        } catch (e) {
          print('⚠️  Error fetching admin data: $e');
        }
      }
      print('✅ STEP 2 PASSED: Admin details retrieved');

      // STEP 3: Generate flat IDs and create batch
      print('📝 STEP 3: Generating flat IDs and creating batch...');
      final batch = _firestore.batch();
      int flatCounter = 1;

      // Get first letter of building name for flat ID prefix
      final flatIdPrefix = buildingName[0].toUpperCase();
      print('   - Flat ID prefix: $flatIdPrefix');
      print('   - Total flats to create: ${floors * flatsPerFloor}');

      for (int floor = 1; floor <= floors; floor++) {
        for (int flatNum = 1; flatNum <= flatsPerFloor; flatNum++) {
          // Generate flat ID in format: A001, A002, A003, etc.
          final flatId =
              '$flatIdPrefix${flatCounter.toString().padLeft(3, '0')}';
          final bhkType =
              flatBhkConfig[flatId] ??
              '2BHK'; // Default to 2BHK if not specified
          final flatLabel = flatId; // e.g., "A001", "A002"
          final docRef = _firestore.collection(_collection).doc();

          // Build flat data with admin details
          final flatData = {
            'id': docRef.id,
            'flatId': flatId,
            'flatLabel': flatLabel,
            'buildingId': buildingId,
            'buildingName': buildingName,
            'floor': floor,
            'flatNumber': flatNum,
            'type': bhkType,
            'bhkType': bhkType, // Store BHK type explicitly
            'area': _getAreaForBhk(bhkType),
            'status': 'vacant',
            'residentName': null,
            'residentId': null,
            'residentUserId': null, // Initialize userId field
            'adminId': adminId, // Link flat to admin
            'communityId': communityId,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          };

          // Add admin details if available
          if (adminData != null) {
            flatData['adminName'] = adminData['name'] ?? '';
            flatData['adminEmail'] = adminData['email'] ?? '';
            flatData['adminPhone'] = adminData['phone'] ?? '';
            flatData['organization'] = adminData['organization'] ?? '';
          }

          batch.set(docRef, flatData);
          flatCounter++;
        }
      }
      print('✅ STEP 3 PASSED: Flat IDs generated and batch prepared');

      // STEP 4: Commit batch to Firestore
      print('💾 STEP 4: Committing batch to Firestore...');
      await batch.commit();
      print('✅ STEP 4 PASSED: Batch committed successfully');

      // STEP 5: Verify flats were created
      print('🔍 STEP 5: Verifying flat creation...');
      final verifySnapshot = await _firestore
          .collection(_collection)
          .where('buildingId', isEqualTo: buildingId)
          .where('communityId', isEqualTo: communityId)
          .get();
      print('   - Flats created: ${verifySnapshot.docs.length}');
      print('   - Expected: ${floors * flatsPerFloor}');

      if (verifySnapshot.docs.length == floors * flatsPerFloor) {
        print('✅ STEP 5 PASSED: All flats verified');
        print('✅ FLAT GENERATION FLOW: COMPLETE');
        print('   - Building: $buildingName');
        print(
          '   - Flat ID format: ${flatIdPrefix}001 to $flatIdPrefix${(floors * flatsPerFloor).toString().padLeft(3, '0')}',
        );
        print('   - Total flats: ${floors * flatsPerFloor}');
      } else {
        print('❌ STEP 5 FAILED: Flat count mismatch');
        throw Exception(
          'Flat count mismatch: expected ${floors * flatsPerFloor}, got ${verifySnapshot.docs.length}',
        );
      }
    } catch (e) {
      print('❌ ERROR: $e');
      throw Exception('Failed to generate flats: $e');
    }
  }

  Future<void> renameUnit({
    required String flatDocumentId,
    required String buildingId,
    required String newLabel,
  }) async {
    final communityId = AdminTenantContext.instance.requireCommunityId().trim();

    final normalizedLabel = newLabel.trim();

    if (normalizedLabel.isEmpty) {
      throw ArgumentError('Unit name cannot be empty.');
    }

    final callable = FirebaseFunctions.instanceFor(
      region: 'asia-southeast1',
    ).httpsCallable('renameUnit');

    await callable.call({
      'communityId': communityId,
      'buildingId': buildingId.trim(),
      'flatId': flatDocumentId.trim(),
      'newLabel': normalizedLabel,
    });
  }

  Future<FlatModel?> getFlatFromServer(String flatDocumentId) async {
    final snapshot = await _firestore
        .collection(_collection)
        .doc(flatDocumentId)
        .get(const GetOptions(source: Source.server));

    if (!snapshot.exists || snapshot.data() == null) {
      return null;
    }

    final data = snapshot.data()!;

    return FlatModel(
      id: snapshot.id,
      unitType: HousingUnitType.fromValue(data['unitType']),
      unitIndex: (data['unitIndex'] as num?)?.toInt(),
      flatId: visibleUnitLabel(data, snapshot.id),
      buildingId: data['buildingId'] ?? '',
      buildingName: data['buildingName'] ?? '',
      floor: data['floor'] ?? 0,
      flatNumber: data['flatNumber'] ?? 0,
      type: data['type'] ?? '',
      area: data['area'] ?? '',
      status: data['status'] ?? 'vacant',
      residentName: data['residentName'],
      residentId: data['residentId'],
      residentUserId: FlatModel.resolveResidentUserId(data),
      reservedOnboardingId: data['reservedOnboardingId'],
      reservedForName: data['reservedForName'],
      reservedResidentType: data['reservedResidentType'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Future<List<FlatModel>> getFlatsForBuildingFromServer(
    String buildingId,
  ) async {
    final communityId = AdminTenantContext.instance.requireCommunityId();

    final snapshot = await _firestore
        .collection(_collection)
        .where('buildingId', isEqualTo: buildingId)
        .where('communityId', isEqualTo: communityId)
        .get(const GetOptions(source: Source.server));

    final flats = snapshot.docs.map((doc) {
      final data = doc.data();

      return FlatModel(
        id: doc.id,
        unitType: HousingUnitType.fromValue(data['unitType']),
        unitIndex: (data['unitIndex'] as num?)?.toInt(),
        flatId: visibleUnitLabel(data, doc.id),
        buildingId: data['buildingId'] ?? '',
        buildingName: data['buildingName'] ?? '',
        floor: data['floor'] ?? 0,
        flatNumber: data['flatNumber'] ?? 0,
        type: data['bhkType'] ?? data['type'] ?? '',
        area: data['area'] ?? '',
        status: data['status'] ?? 'vacant',

        residentName: data['residentName'],
        residentId: data['residentId'],
        residentUserId: FlatModel.resolveResidentUserId(data),

        reservedOnboardingId: data['reservedOnboardingId'],
        reservedForName: data['reservedForName'],
        reservedResidentType: data['reservedResidentType'],

        createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
        updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      );
    }).toList();

    flats.sort((a, b) {
      final floorCompare = b.floor.compareTo(a.floor);
      if (floorCompare != 0) return floorCompare;
      return a.flatNumber.compareTo(b.flatNumber);
    });

    return flats;
  }

  String _getAreaForBhk(String bhkType) {
    switch (bhkType) {
      case '1BHK':
        return '650 Sqft';
      case '2BHK':
        return '1200 Sqft';
      case '3BHK':
        return '1800 Sqft';
      case '4BHK':
        return '2400 Sqft';
      case '5BHK':
        return '3000 Sqft';
      default:
        return '1200 Sqft';
    }
  }

  String _getArea(int flatNum) {
    final areas = ['1200 Sqft', '1500 Sqft', '1800 Sqft', '2000 Sqft'];
    return areas[flatNum % areas.length];
  }

  // Get flats for a building
  Stream<List<FlatModel>> getFlatsForBuilding(String buildingId) {
    return _firestore
        .collection(_collection)
        .where('buildingId', isEqualTo: buildingId)
        .where(
          'communityId',
          isEqualTo: AdminTenantContext.instance.requireCommunityId(),
        )
        .snapshots()
        .map((snapshot) {
          final flats = snapshot.docs.map((doc) {
            final data = doc.data();
            return FlatModel(
              id: doc.id,
              unitType: HousingUnitType.fromValue(data['unitType']),
              unitIndex: (data['unitIndex'] as num?)?.toInt(),
              flatId: visibleUnitLabel(data, doc.id),
              buildingId: data['buildingId'] ?? '',
              buildingName: data['buildingName'] ?? '',
              floor: data['floor'] ?? 0,
              flatNumber: data['flatNumber'] ?? 0,
              type: data['type'] ?? '',
              area: data['area'] ?? '',
              status: data['status'] ?? 'vacant',
              residentName: data['residentName'],
              residentId: data['residentId'],
              residentUserId: FlatModel.resolveResidentUserId(data),
              reservedOnboardingId: data['reservedOnboardingId'],
              reservedForName: data['reservedForName'],
              reservedResidentType: data['reservedResidentType'],
              createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
              updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
            );
          }).toList();

          // Sort in memory: floor descending, then flatNumber ascending
          flats.sort((a, b) {
            final floorCompare = b.floor.compareTo(a.floor);
            if (floorCompare != 0) return floorCompare;
            return a.flatNumber.compareTo(b.flatNumber);
          });

          return flats;
        });
  }

  // Update flat status - SAFE VERSION
  Future<void> updateFlatStatus({
    required String flatDocumentId,
    required String buildingId,
    required String status,
  }) async {
    try {
      print('\n🔵 FlatService.updateFlatStatus() called');
      print('   - flatDocumentId: $flatDocumentId');
      print('   - buildingId: $buildingId');
      print('   - status: $status');

      final normalizedDocumentId = flatDocumentId.trim();
      final normalizedBuildingId = buildingId.trim();
      final selectedCommunityId = AdminTenantContext.instance
          .requireCommunityId()
          .trim();
      if (normalizedDocumentId.isEmpty || normalizedBuildingId.isEmpty) {
        throw ArgumentError('Flat and building identifiers are required.');
      }

      // Resolve exactly one canonical Firestore document, then verify it still
      // belongs to the Admin's selected tenant and building before mutation.
      print('   - STEP 1: Reading canonical flat document');
      final flatDocRef = _firestore
          .collection(_collection)
          .doc(normalizedDocumentId);
      final flatDocument = await flatDocRef.get();
      if (!flatDocument.exists || flatDocument.data() == null) {
        throw StateError('Flat not found in the selected building.');
      }
      final flatData = flatDocument.data()!;
      validateFlatMutationScope(
        flatData: flatData,
        expectedCommunityId: selectedCommunityId,
        expectedBuildingId: normalizedBuildingId,
      );
      print('   ✅ STEP 1 PASSED: Flat document found: ${flatDocRef.id}');

      final residentIds = flatData['residentIds'];
      final hasResidentPointer =
          (flatData['residentUserId'] is String &&
              (flatData['residentUserId'] as String).trim().isNotEmpty) ||
          (flatData['residentUid'] is String &&
              (flatData['residentUid'] as String).trim().isNotEmpty) ||
          (residentIds != null &&
              (residentIds is! List || residentIds.isNotEmpty));
      if (hasResidentPointer) {
        throw StateError(
          'Resident-linked flats can change occupancy only through explicit resident lifecycle actions.',
        );
      }
      if (status != 'vacant' && status != 'maintenance') {
        throw StateError(
          'Direct occupied status changes are not allowed. Use resident assignment.',
        );
      }

      // STEP 2: Prepare update data
      print('   - STEP 2: Preparing update data');
      final updateData = {
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      print('   ✅ STEP 2 PASSED: Update data prepared');

      // STEP 3: Update flat document
      print('   - STEP 3: Updating flat document');
      await flatDocRef.update(updateData);
      print('   ✅ STEP 3 PASSED: Flat document updated');

      // STEP 4: Verify update
      print('   - STEP 4: Verifying update');
      final verifyDoc = await flatDocRef.get();
      if (verifyDoc.exists) {
        final data = verifyDoc.data() as Map<String, dynamic>;
        print('   ✅ STEP 4 PASSED: Verification successful');
        print('      - Status: ${data['status']}');
      }

      print('✅ Flat status updated successfully\n');
    } catch (e) {
      print('❌ Failed to update flat status: $e\n');
      throw Exception('Failed to update flat status: $e');
    }
  }

  Future<void> assignResident({
    required String flatId,
    required String residentName,
    required String residentId,
  }) => Future<void>.error(
    StateError(
      'Direct resident assignment is retired. Use Pending Registrations approval.',
    ),
  );

  // Historical direct assignment implementation; no active lifecycle flow
  // should invoke it.
  // ignore: unused_element
  Future<void> _legacyAssignResident({
    required String flatId,
    required String residentName,
    required String residentId,
  }) async {
    try {
      print('\n🔵 FlatService.assignResident() called');
      print('   - flatId (docId): $flatId');
      print('   - residentName: $residentName');
      print('   - residentId: $residentId');

      // flatId here is the actual Firestore document ID, not the sequential ID
      await _firestore.collection(_collection).doc(flatId).update({
        'status': 'occupied',
        'residentName': residentName,
        'residentId': residentId,
        'residentUserId': residentId,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      print('✅ Flat document updated successfully');
      print('   - residentName: $residentName');
      print('   - residentId: $residentId');
      print('   - residentUserId: $residentId\n');
    } catch (e) {
      print('❌ Failed to assign resident: $e\n');
      throw Exception('Failed to assign resident: $e');
    }
  }

  Future<void> removeResident(String flatId) => Future<void>.error(
    StateError(
      'Generic flat removal is retired. Use the explicit Move Out resident action.',
    ),
  );

  // Historical direct removal implementation; trusted move-out is used now.
  // ignore: unused_element
  Future<void> _legacyRemoveResident(String flatId) async {
    try {
      print('\n🔵 FlatService.removeResident() called');
      print('   - flatId: $flatId');

      await _firestore.collection(_collection).doc(flatId).update({
        'status': 'vacant',
        'residentName': null,
        'residentId': null,
        'residentUserId': null, // Clear userId as well
        'updatedAt': FieldValue.serverTimestamp(),
      });

      print('✅ Resident removed from flat successfully\n');
    } catch (e) {
      print('❌ Failed to remove resident: $e\n');
      throw Exception('Failed to remove resident: $e');
    }
  }

  // Delete all flats for a building
  Future<void> deleteFlatsForBuilding(String buildingId) async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('buildingId', isEqualTo: buildingId)
          .where(
            'communityId',
            isEqualTo: AdminTenantContext.instance.requireCommunityId(),
          )
          .get();

      final batch = _firestore.batch();
      for (var doc in snapshot.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
    } catch (e) {
      throw Exception('Failed to delete flats: $e');
    }
  }

  // Get occupancy stats for a building
  Future<OccupancyStats> getOccupancyStats(String buildingId) async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('buildingId', isEqualTo: buildingId)
          .where(
            'communityId',
            isEqualTo: AdminTenantContext.instance.requireCommunityId(),
          )
          .get();

      int total = snapshot.docs.length;
      int occupied = 0;
      int vacant = 0;
      int reserved = 0;
      int maintenance = 0;

      for (var doc in snapshot.docs) {
        final status = doc.data()['status'] ?? 'vacant';
        if (status == 'occupied') {
          occupied++;
        } else if (status == 'vacant') {
          vacant++;
        } else if (status == 'maintenance') {
          maintenance++;
        } else if (status == 'reserved') {
          reserved++;
        }
      }

      return OccupancyStats(
        total: total,
        occupied: occupied,
        vacant: vacant,
        reserved: reserved,
        maintenance: maintenance,
        occupancyRate: total > 0 ? ((occupied / total) * 100).round() : 0,
      );
    } catch (e) {
      throw Exception('Failed to get occupancy stats: $e');
    }
  }
}

void validateFlatMutationScope({
  required Map<String, dynamic> flatData,
  required String expectedCommunityId,
  required String expectedBuildingId,
}) {
  final actualCommunityId = flatData['communityId']?.toString().trim() ?? '';
  final actualBuildingId = flatData['buildingId']?.toString().trim() ?? '';
  if (actualCommunityId != expectedCommunityId.trim() ||
      actualBuildingId != expectedBuildingId.trim()) {
    throw StateError(
      'Flat does not belong to the selected community and building.',
    );
  }
}

// Flat Model
class FlatModel {
  final HousingUnitType unitType;
  final int? unitIndex;
  bool get usesFloors => unitIndex == null;
  final String id;
  final String flatId;
  final String buildingId;
  final String buildingName;
  final int floor;
  final int flatNumber;
  final String type;
  final String area;
  final String status;

  final String? residentName;
  final String? residentId;
  final String? residentUserId;

  final String? reservedOnboardingId;
  final String? reservedForName;
  final String? reservedResidentType;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  FlatModel({
    this.unitType = HousingUnitType.apartment,
    this.unitIndex,
    required this.id,
    required this.flatId,
    required this.buildingId,
    required this.buildingName,
    required this.floor,
    required this.flatNumber,
    required this.type,
    required this.area,
    required this.status,
    this.residentName,
    this.residentId,
    this.residentUserId,
    this.reservedOnboardingId,
    this.reservedForName,
    this.reservedResidentType,
    this.createdAt,
    this.updatedAt,
  });

  static String? resolveResidentUserId(Map<String, dynamic> data) {
    String? value(Object? raw) {
      final text = raw is String ? raw.trim() : '';
      return text.isEmpty ? null : text;
    }

    final canonical = value(data['residentUserId']);
    final legacy = value(data['residentUid']);
    final residentIds = data['residentIds'];
    if (residentIds != null &&
        (residentIds is! List || residentIds.length > 1)) {
      return null;
    }
    final legacyList = residentIds is List && residentIds.length == 1
        ? value(residentIds.single)
        : null;
    if (residentIds is List && residentIds.length == 1 && legacyList == null) {
      return null;
    }
    final values = {canonical, legacy, legacyList}.whereType<String>().toSet();
    return values.length > 1 || values.isEmpty ? null : values.first;
  }

  Map<String, dynamic> toMap() {
    return {
      'unitType': unitType.value,
      if (unitIndex != null) 'unitIndex': unitIndex,
      'id': id,
      'flatId': flatId,
      'buildingId': buildingId,
      'buildingName': buildingName,
      'floor': floor,
      'flatNumber': flatNumber,
      'type': type,
      'area': area,
      'status': status,
      'residentName': residentName,
      'residentId': residentId,
      'residentUserId': residentUserId,
      'reservedOnboardingId': reservedOnboardingId,
      'reservedForName': reservedForName,
      'reservedResidentType': reservedResidentType,
    };
  }
}

// Occupancy Stats Model
class OccupancyStats {
  final int total;
  final int occupied;
  final int vacant;
  final int reserved;
  final int maintenance;
  final int occupancyRate;

  OccupancyStats({
    required this.total,
    required this.occupied,
    required this.vacant,
    required this.reserved,
    required this.maintenance,
    required this.occupancyRate,
  });
}
