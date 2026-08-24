import 'package:cloud_firestore/cloud_firestore.dart';
import 'admin_service.dart';
import 'notification_firestore_service.dart';
import '../models/notification_models.dart';

/// Parking Service - Complete parking management with Firestore integration
/// Firestore Structure:
/// vehicles: { vehicleId, userId, buildingId, vehicleNumber, vehicleType, color }
/// parkingSlots: { slotId, buildingId, slotNumber, slotType, status, vehicleId, userId }
class ParkingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AdminService _adminService = AdminService();
  final NotificationFirestoreService _notificationService =
      NotificationFirestoreService();

  // Collections
  static const String _parkingSlotsCollection = 'parkingSlots';
  static const String _vehiclesCollection = 'vehicles';
  static const String _parkingViolationsCollection = 'parking_violations';

  // ============================================================================
  // PARKING SLOTS OPERATIONS
  // ============================================================================

  /// Create a new parking slot
  Future<String> createParkingSlot({
    required String slotNumber,
    required String slotType, // 'Car', 'Bike', 'Scooter'
    required String buildingId,
    String? notes,
  }) async {
    try {
      print('🔵 PARKING SLOT CREATION: Starting...');

      // STEP 1: Validate Admin Authentication
      print('🔐 STEP 1: Validating admin authentication...');
      final adminId = _adminService.getCurrentAdminId();
      if (adminId == null) {
        throw Exception('Admin not logged in');
      }
      print('✅ STEP 1 PASSED: Admin authenticated');

      // STEP 2: Validate Input Data
      print('📋 STEP 2: Validating parking slot data...');
      if (slotNumber.isEmpty || slotType.isEmpty) {
        throw Exception('Slot number and slot type are required');
      }
      print('✅ STEP 2 PASSED: Data validated');

      // STEP 3: Create Parking Slot
      print('📝 STEP 3: Creating parking slot...');
      final adminProfile = await _adminService.getAdminProfile();
      final buildingIds = await _adminService.getAdminBuildingIds();

      final docRef = await _firestore.collection(_parkingSlotsCollection).add({
        'slotNumber': slotNumber,
        'slotType': slotType,
        'buildingId': buildingId,
        'status': 'vacant', // 'vacant' or 'occupied'
        'vehicleId': null,
        'userId': null,
        'notes': notes ?? '',
        // Multi-tenancy fields
        'adminId': adminId,
        'communityId': _adminService.requireCurrentCommunityId(),
        'buildingIds': buildingIds,
        'adminName': adminProfile?['name'] ?? '',
        'adminEmail': adminProfile?['email'] ?? '',
        'adminPhone': adminProfile?['phone'] ?? '',
        'organization': adminProfile?['organization'] ?? '',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      print('✅ STEP 3 PASSED: Parking slot created');

      print('✅ PARKING SLOT CREATION: COMPLETE');
      return docRef.id;
    } catch (e) {
      print('❌ ERROR: $e');
      throw Exception('Failed to create parking slot: $e');
    }
  }

  /// Get all parking slots for admin's buildings
  Stream<List<ParkingSlotModel>> getParkingSlots() {
    final adminId = _adminService.getCurrentAdminId();
    if (adminId == null) return Stream.value([]);

    return _firestore
        .collection(_parkingSlotsCollection)
        .where(
          'communityId',
          isEqualTo: _adminService.requireCurrentCommunityId(),
        )
        .snapshots()
        .map((snapshot) {
          final slots = snapshot.docs
              .map((doc) => ParkingSlotModel.fromFirestore(doc))
              .toList();
          // Sort locally to avoid Firestore index requirement
          slots.sort((a, b) => a.slotNumber.compareTo(b.slotNumber));
          return slots;
        });
  }

  /// Get parking slot details with vehicle and user info
  Future<ParkingSlotDetailModel?> getParkingSlotDetails(String slotId) async {
    try {
      final slotDoc = await _firestore
          .collection(_parkingSlotsCollection)
          .doc(slotId)
          .get();

      if (!slotDoc.exists) return null;

      final slot = ParkingSlotModel.fromFirestore(slotDoc);
      VehicleModel? vehicle;
      Map<String, dynamic>? userDetails;

      // Fetch vehicle details if slot is occupied
      if (slot.vehicleId != null) {
        final vehicleDoc = await _firestore
            .collection(_vehiclesCollection)
            .doc(slot.vehicleId!)
            .get();
        if (vehicleDoc.exists) {
          vehicle = VehicleModel.fromFirestore(vehicleDoc);
        }

        // Fetch user details if userId is available
        if (slot.userId != null) {
          final userDoc = await _firestore
              .collection('users')
              .doc(slot.userId!)
              .get();
          if (userDoc.exists) {
            userDetails = userDoc.data();
          }
        }
      }

      return ParkingSlotDetailModel(
        slot: slot,
        vehicle: vehicle,
        userDetails: userDetails,
      );
    } catch (e) {
      print('❌ ERROR fetching slot details: $e');
      return null;
    }
  }

  /// Update parking slot
  Future<void> updateParkingSlot(
    String slotId, {
    String? slotNumber,
    String? slotType,
    String? status,
    String? vehicleId,
    String? userId,
    String? notes,
  }) async {
    try {
      print('🔵 PARKING SLOT UPDATE: Starting...');

      // STEP 1: Validate Admin
      print('🔐 STEP 1: Validating admin...');
      final adminId = _adminService.getCurrentAdminId();
      if (adminId == null) throw Exception('Admin not logged in');
      print('✅ STEP 1 PASSED');

      // STEP 2: Validate slot exists
      print('📋 STEP 2: Validating slot...');
      final doc = await _firestore
          .collection(_parkingSlotsCollection)
          .doc(slotId)
          .get();
      if (!doc.exists) throw Exception('Parking slot not found');
      print('✅ STEP 2 PASSED');

      // STEP 3: Update slot
      print('📝 STEP 3: Updating parking slot...');
      final updates = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (slotNumber != null) updates['slotNumber'] = slotNumber;
      if (slotType != null) updates['slotType'] = slotType;
      if (status != null) updates['status'] = status;
      if (vehicleId != null) updates['vehicleId'] = vehicleId;
      if (userId != null) updates['userId'] = userId;
      if (notes != null) updates['notes'] = notes;

      await _firestore
          .collection(_parkingSlotsCollection)
          .doc(slotId)
          .update(updates);
      print('✅ STEP 3 PASSED');

      print('✅ PARKING SLOT UPDATE: COMPLETE');
    } catch (e) {
      print('❌ ERROR: $e');
      throw Exception('Failed to update parking slot: $e');
    }
  }

  /// Delete parking slot
  Future<void> deleteParkingSlot(String slotId) async {
    try {
      print('🔵 PARKING SLOT DELETION: Starting...');

      // STEP 1: Validate Admin
      print('🔐 STEP 1: Validating admin...');
      final adminId = _adminService.getCurrentAdminId();
      if (adminId == null) throw Exception('Admin not logged in');
      print('✅ STEP 1 PASSED');

      // STEP 2: Validate slot exists
      print('📋 STEP 2: Validating slot...');
      final doc = await _firestore
          .collection(_parkingSlotsCollection)
          .doc(slotId)
          .get();
      if (!doc.exists) throw Exception('Parking slot not found');
      print('✅ STEP 2 PASSED');

      // STEP 3: Delete slot
      print('📝 STEP 3: Deleting parking slot...');
      await _firestore.collection(_parkingSlotsCollection).doc(slotId).delete();
      print('✅ STEP 3 PASSED');

      print('✅ PARKING SLOT DELETION: COMPLETE');
    } catch (e) {
      print('❌ ERROR: $e');
      throw Exception('Failed to delete parking slot: $e');
    }
  }

  // ============================================================================
  // VEHICLE REGISTRATION OPERATIONS
  // ============================================================================

  /// Register a new vehicle
  Future<String> registerVehicle({
    required String vehicleNumber,
    required String vehicleType,
    required String userId,
    required String buildingId,
    String? color,
  }) async {
    try {
      print('🔵 VEHICLE REGISTRATION: Starting...');

      // STEP 1: Validate Admin
      print('🔐 STEP 1: Validating admin...');
      final adminId = _adminService.getCurrentAdminId();
      if (adminId == null) throw Exception('Admin not logged in');
      print('✅ STEP 1 PASSED');

      // STEP 2: Validate data
      print('📋 STEP 2: Validating vehicle data...');
      if (vehicleNumber.isEmpty || vehicleType.isEmpty) {
        throw Exception('Vehicle number and type are required');
      }
      print('✅ STEP 2 PASSED');

      // STEP 3: Create vehicle
      print('📝 STEP 3: Registering vehicle...');
      final adminProfile = await _adminService.getAdminProfile();
      final buildingIds = await _adminService.getAdminBuildingIds();

      final docRef = await _firestore.collection(_vehiclesCollection).add({
        'vehicleNumber': vehicleNumber,
        'vehicleType': vehicleType,
        'userId': userId,
        'buildingId': buildingId,
        'color': color ?? '',
        'registrationDate': FieldValue.serverTimestamp(),
        // Multi-tenancy fields
        'adminId': adminId,
        'communityId': _adminService.requireCurrentCommunityId(),
        'buildingIds': buildingIds,
        'adminName': adminProfile?['name'] ?? '',
        'adminEmail': adminProfile?['email'] ?? '',
        'adminPhone': adminProfile?['phone'] ?? '',
        'organization': adminProfile?['organization'] ?? '',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      print('✅ STEP 3 PASSED');

      print('✅ VEHICLE REGISTRATION: COMPLETE');
      return docRef.id;
    } catch (e) {
      print('❌ ERROR: $e');
      throw Exception('Failed to register vehicle: $e');
    }
  }

  /// Get all registered vehicles
  Stream<List<VehicleModel>> getVehicles() {
    final adminId = _adminService.getCurrentAdminId();
    if (adminId == null) return Stream.value([]);

    return _firestore
        .collection(_vehiclesCollection)
        .where(
          'communityId',
          isEqualTo: _adminService.requireCurrentCommunityId(),
        )
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => VehicleModel.fromFirestore(doc))
              .toList();
        });
  }

  /// Get vehicles for a specific user
  Stream<List<VehicleModel>> getUserVehicles(String userId) {
    return _firestore
        .collection(_vehiclesCollection)
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => VehicleModel.fromFirestore(doc))
              .toList();
        });
  }

  /// Update vehicle
  Future<void> updateVehicle(
    String vehicleId, {
    String? vehicleNumber,
    String? color,
  }) async {
    try {
      final updates = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (vehicleNumber != null) updates['vehicleNumber'] = vehicleNumber;
      if (color != null) updates['color'] = color;

      await _firestore
          .collection(_vehiclesCollection)
          .doc(vehicleId)
          .update(updates);
    } catch (e) {
      throw Exception('Failed to update vehicle: $e');
    }
  }

  /// Delete vehicle
  Future<void> deleteVehicle(String vehicleId) async {
    try {
      await _firestore.collection(_vehiclesCollection).doc(vehicleId).delete();
    } catch (e) {
      throw Exception('Failed to delete vehicle: $e');
    }
  }

  // ============================================================================
  // PARKING ASSIGNMENT OPERATIONS
  // ============================================================================

  /// Assign vehicle to parking slot
  Future<void> assignVehicleToSlot({
    required String slotId,
    required String vehicleId,
    required String userId,
  }) async {
    try {
      print('🔵 PARKING ASSIGNMENT: Starting...');

      // STEP 1: Validate Admin
      print('🔐 STEP 1: Validating admin...');
      final adminId = _adminService.getCurrentAdminId();
      if (adminId == null) throw Exception('Admin not logged in');
      print('✅ STEP 1 PASSED');

      // STEP 2: Validate data
      print('📋 STEP 2: Validating assignment data...');
      final slotDoc = await _firestore
          .collection(_parkingSlotsCollection)
          .doc(slotId)
          .get();
      if (!slotDoc.exists) throw Exception('Parking slot not found');

      final vehicleDoc = await _firestore
          .collection(_vehiclesCollection)
          .doc(vehicleId)
          .get();
      if (!vehicleDoc.exists) throw Exception('Vehicle not found');

      // Get slot number and vehicle number for notification
      final slotNumber = slotDoc.data()?['slotNumber'] ?? 'Unknown';
      final vehicleNumber = vehicleDoc.data()?['vehicleNumber'] ?? 'Unknown';
      print('✅ STEP 2 PASSED');

      // STEP 3: Update slot with vehicleId and userId
      print('📝 STEP 3: Assigning vehicle to slot...');
      await _firestore.collection(_parkingSlotsCollection).doc(slotId).update({
        'vehicleId': vehicleId,
        'userId': userId,
        'status': 'occupied',
        'updatedAt': FieldValue.serverTimestamp(),
      });
      print('✅ STEP 3 PASSED');

      // STEP 4: Notify Resident
      print('🔔 STEP 4: Notifying resident...');
      try {
        await _notificationService.createNotification(
          title: 'Parking Slot Assigned',
          message:
              'Your vehicle $vehicleNumber has been assigned to slot $slotNumber',
          type: NotificationType.security,
          priority: NotificationPriority.high,
          recipientId: userId,
          metadata: {
            'slotId': slotId,
            'vehicleId': vehicleId,
            'slotNumber': slotNumber,
            'vehicleNumber': vehicleNumber,
          },
        );
        print('✅ STEP 4 PASSED: Resident notified');
      } catch (notificationError) {
        print(
          '⚠️ STEP 4 WARNING: Failed to send notification: $notificationError',
        );
        // Don't throw - notification failure shouldn't block the operation
      }

      print('✅ PARKING ASSIGNMENT: COMPLETE');
    } catch (e) {
      print('❌ ERROR: $e');
      throw Exception('Failed to assign vehicle: $e');
    }
  }

  /// Remove vehicle from parking slot
  Future<void> removeVehicleFromSlot(String slotId) async {
    try {
      print('🔵 REMOVE VEHICLE FROM SLOT: Starting...');

      // STEP 1: Validate Admin
      print('🔐 STEP 1: Validating admin...');
      final adminId = _adminService.getCurrentAdminId();
      if (adminId == null) throw Exception('Admin not logged in');
      print('✅ STEP 1 PASSED');

      // STEP 2: Validate slot exists and get details
      print('📋 STEP 2: Validating slot...');
      final doc = await _firestore
          .collection(_parkingSlotsCollection)
          .doc(slotId)
          .get();
      if (!doc.exists) throw Exception('Parking slot not found');

      final slotData = doc.data();
      final userId = slotData?['userId'];
      final slotNumber = slotData?['slotNumber'] ?? 'Unknown';
      print('✅ STEP 2 PASSED');

      // STEP 3: Clear vehicleId and userId, set status to vacant
      print('📝 STEP 3: Clearing slot assignment...');
      await _firestore.collection(_parkingSlotsCollection).doc(slotId).update({
        'vehicleId': null,
        'userId': null,
        'status': 'vacant',
        'updatedAt': FieldValue.serverTimestamp(),
      });
      print('✅ STEP 3 PASSED');

      // STEP 4: Notify Resident
      print('🔔 STEP 4: Notifying resident...');
      if (userId != null) {
        try {
          await _notificationService.createNotification(
            title: 'Parking Slot Cleared',
            message: 'Your vehicle has been removed from slot $slotNumber',
            type: NotificationType.security,
            priority: NotificationPriority.medium,
            recipientId: userId,
            metadata: {'slotId': slotId, 'slotNumber': slotNumber},
          );
          print('✅ STEP 4 PASSED: Resident notified');
        } catch (notificationError) {
          print(
            '⚠️ STEP 4 WARNING: Failed to send notification: $notificationError',
          );
        }
      }

      print('✅ REMOVE VEHICLE FROM SLOT: COMPLETE');
    } catch (e) {
      print('❌ ERROR: $e');
      throw Exception('Failed to remove vehicle: $e');
    }
  }

  // ============================================================================
  // PARKING VIOLATION OPERATIONS
  // ============================================================================

  /// Report parking violation
  Future<String> reportViolation({
    required String slotId,
    required String vehicleNumber,
    required String violationType,
    required String buildingId,
    String? description,
    double? fineAmount,
  }) async {
    try {
      print('🔵 PARKING VIOLATION REPORT: Starting...');

      // STEP 1: Validate Admin
      print('🔐 STEP 1: Validating admin...');
      final adminId = _adminService.getCurrentAdminId();
      if (adminId == null) throw Exception('Admin not logged in');
      print('✅ STEP 1 PASSED');

      // STEP 2: Validate data
      print('📋 STEP 2: Validating violation data...');
      if (vehicleNumber.isEmpty || violationType.isEmpty) {
        throw Exception('Vehicle number and violation type are required');
      }
      print('✅ STEP 2 PASSED');

      // STEP 3: Create violation record
      print('📝 STEP 3: Creating violation record...');
      final adminProfile = await _adminService.getAdminProfile();
      final buildingIds = await _adminService.getAdminBuildingIds();

      final docRef = await _firestore
          .collection(_parkingViolationsCollection)
          .add({
            'slotId': slotId,
            'vehicleNumber': vehicleNumber,
            'violationType': violationType,
            'buildingId': buildingId,
            'description': description ?? '',
            'fineAmount': fineAmount ?? 0.0,
            'status': 'pending',
            'reportedAt': FieldValue.serverTimestamp(),
            // Multi-tenancy fields
            'adminId': adminId,
            'communityId': _adminService.requireCurrentCommunityId(),
            'buildingIds': buildingIds,
            'adminName': adminProfile?['name'] ?? '',
            'adminEmail': adminProfile?['email'] ?? '',
            'adminPhone': adminProfile?['phone'] ?? '',
            'organization': adminProfile?['organization'] ?? '',
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
      print('✅ STEP 3 PASSED');

      // STEP 4: Notify Residents (if vehicle owner found)
      print('🔔 STEP 4: Notifying residents...');
      try {
        // Try to find vehicle owner
        final vehicleQuery = await _firestore
            .collection(_vehiclesCollection)
            .where('vehicleNumber', isEqualTo: vehicleNumber)
            .limit(1)
            .get();

        if (vehicleQuery.docs.isNotEmpty) {
          final vehicleData = vehicleQuery.docs.first.data();
          final userId = vehicleData['userId'];

          if (userId != null) {
            await _notificationService.createNotification(
              title: 'Parking Violation Reported',
              message:
                  'A parking violation has been reported for your vehicle $vehicleNumber. Fine: ₹${fineAmount?.toStringAsFixed(2) ?? '0.00'}',
              type: NotificationType.security,
              priority: NotificationPriority.high,
              recipientId: userId,
              metadata: {
                'violationId': docRef.id,
                'vehicleNumber': vehicleNumber,
                'violationType': violationType,
                'fineAmount': fineAmount ?? 0.0,
              },
            );
          }
        }
        print('✅ STEP 4 PASSED: Residents notified');
      } catch (notificationError) {
        print(
          '⚠️ STEP 4 WARNING: Failed to send notification: $notificationError',
        );
      }

      print('✅ PARKING VIOLATION REPORT: COMPLETE');
      return docRef.id;
    } catch (e) {
      print('❌ ERROR: $e');
      throw Exception('Failed to report violation: $e');
    }
  }

  /// Get parking violations
  Stream<List<ParkingViolationModel>> getViolations() {
    final adminId = _adminService.getCurrentAdminId();
    if (adminId == null) return Stream.value([]);

    return _firestore
        .collection(_parkingViolationsCollection)
        .where(
          'communityId',
          isEqualTo: _adminService.requireCurrentCommunityId(),
        )
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snapshot) {
          final violations = snapshot.docs
              .map((doc) => ParkingViolationModel.fromFirestore(doc))
              .toList();
          // Sort locally by reportedAt (newest first)
          violations.sort(
            (a, b) => (b.reportedAt ?? DateTime.now()).compareTo(
              a.reportedAt ?? DateTime.now(),
            ),
          );
          return violations;
        });
  }

  /// Resolve violation
  Future<void> resolveViolation(String violationId) async {
    try {
      await _firestore
          .collection(_parkingViolationsCollection)
          .doc(violationId)
          .update({
            'status': 'resolved',
            'updatedAt': FieldValue.serverTimestamp(),
          });
    } catch (e) {
      throw Exception('Failed to resolve violation: $e');
    }
  }
}

// ============================================================================
// MODELS
// ============================================================================

class ParkingSlotModel {
  final String id;
  final String slotNumber;
  final String slotType;
  final String buildingId;
  final String status; // 'vacant' or 'occupied'
  final String? vehicleId;
  final String? userId;
  final String notes;
  final DateTime? createdAt;

  ParkingSlotModel({
    required this.id,
    required this.slotNumber,
    required this.slotType,
    required this.buildingId,
    required this.status,
    this.vehicleId,
    this.userId,
    this.notes = '',
    this.createdAt,
  });

  factory ParkingSlotModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ParkingSlotModel(
      id: doc.id,
      slotNumber: data['slotNumber'] ?? '',
      slotType: data['slotType'] ?? '',
      buildingId: data['buildingId'] ?? '',
      status: data['status'] ?? 'vacant',
      vehicleId: data['vehicleId'],
      userId: data['userId'],
      notes: data['notes'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  bool get isOccupied => status == 'occupied';
}

class ParkingSlotDetailModel {
  final ParkingSlotModel slot;
  final VehicleModel? vehicle;
  final Map<String, dynamic>? userDetails;

  ParkingSlotDetailModel({required this.slot, this.vehicle, this.userDetails});

  String get ownerName => userDetails?['name'] ?? 'Unknown';
  String get ownerPhone => userDetails?['phone'] ?? '';
  String get ownerEmail => userDetails?['email'] ?? '';
}

class VehicleModel {
  final String id;
  final String vehicleNumber;
  final String vehicleType;
  final String userId;
  final String buildingId;
  final String color;
  final DateTime? registrationDate;

  VehicleModel({
    required this.id,
    required this.vehicleNumber,
    required this.vehicleType,
    required this.userId,
    required this.buildingId,
    this.color = '',
    this.registrationDate,
  });

  factory VehicleModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return VehicleModel(
      id: doc.id,
      vehicleNumber: data['vehicleNumber'] ?? '',
      vehicleType: data['vehicleType'] ?? '',
      userId: data['userId'] ?? '',
      buildingId: data['buildingId'] ?? '',
      color: data['color'] ?? '',
      registrationDate: (data['registrationDate'] as Timestamp?)?.toDate(),
    );
  }
}

class ParkingViolationModel {
  final String id;
  final String slotId;
  final String vehicleNumber;
  final String violationType;
  final String buildingId;
  final String description;
  final double fineAmount;
  final String status;
  final DateTime? reportedAt;

  ParkingViolationModel({
    required this.id,
    required this.slotId,
    required this.vehicleNumber,
    required this.violationType,
    required this.buildingId,
    this.description = '',
    this.fineAmount = 0.0,
    this.status = 'pending',
    this.reportedAt,
  });

  factory ParkingViolationModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ParkingViolationModel(
      id: doc.id,
      slotId: data['slotId'] ?? '',
      vehicleNumber: data['vehicleNumber'] ?? '',
      violationType: data['violationType'] ?? '',
      buildingId: data['buildingId'] ?? '',
      description: data['description'] ?? '',
      fineAmount: (data['fineAmount'] as num?)?.toDouble() ?? 0.0,
      status: data['status'] ?? 'pending',
      reportedAt: (data['reportedAt'] as Timestamp?)?.toDate(),
    );
  }
}
