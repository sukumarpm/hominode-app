// lib/src/services/resident_service.dart
// Firestore service for resident management

import 'package:cloud_firestore/cloud_firestore.dart';

class ResidentService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String usersCollection = 'users';
  static const String billsCollection = 'bills';
  static const String flatsCollection = 'flats';
  static const String buildingsCollection = 'buildings';

  /// Get all residents
  Future<List<Map<String, dynamic>>> getResidents() async {
    try {
      final snapshot = await _firestore
          .collection(usersCollection)
          .where('role', isEqualTo: 'resident')
          .get();

      final residents = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();

      print('✅ Fetched ${residents.length} residents');
      return residents;
    } catch (e) {
      print('❌ Error fetching residents: $e');
      return [];
    }
  }

  /// Stream residents (real-time)
  Stream<List<Map<String, dynamic>>> streamResidents() {
    return _firestore
        .collection(usersCollection)
        .where('role', isEqualTo: 'resident')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    });
  }

  /// Get residents by building
  Future<List<Map<String, dynamic>>> getResidentsByBuilding(String buildingId) async {
    try {
      final snapshot = await _firestore
          .collection(usersCollection)
          .where('role', isEqualTo: 'resident')
          .where('buildingId', isEqualTo: buildingId)
          .get();

      final residents = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();

      print('✅ Fetched ${residents.length} residents for building $buildingId');
      return residents;
    } catch (e) {
      print('❌ Error fetching residents by building: $e');
      return [];
    }
  }

  /// Get residents by flat
  Future<List<Map<String, dynamic>>> getResidentsByFlat(String flatId) async {
    try {
      final snapshot = await _firestore
          .collection(usersCollection)
          .where('role', isEqualTo: 'resident')
          .where('flatId', isEqualTo: flatId)
          .get();

      final residents = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();

      print('✅ Fetched ${residents.length} residents for flat $flatId');
      return residents;
    } catch (e) {
      print('❌ Error fetching residents by flat: $e');
      return [];
    }
  }

  /// Search residents by name or email
  Future<List<Map<String, dynamic>>> searchResidents(String query) async {
    try {
      final snapshot = await _firestore
          .collection(usersCollection)
          .where('role', isEqualTo: 'resident')
          .get();

      final residents = snapshot.docs
          .map((doc) {
            final data = doc.data();
            data['id'] = doc.id;
            return data;
          })
          .where((resident) {
            final name = (resident['name'] as String?)?.toLowerCase() ?? '';
            final email = (resident['email'] as String?)?.toLowerCase() ?? '';
            final searchQuery = query.toLowerCase();
            return name.contains(searchQuery) || email.contains(searchQuery);
          })
          .toList();

      print('✅ Found ${residents.length} residents matching "$query"');
      return residents;
    } catch (e) {
      print('❌ Error searching residents: $e');
      return [];
    }
  }

  /// Get resident details with related data
  Future<Map<String, dynamic>?> getResidentDetails(String residentId) async {
    try {
      final userDoc = await _firestore.collection(usersCollection).doc(residentId).get();
      
      if (!userDoc.exists) {
        return null;
      }

      final data = userDoc.data()!;
      data['id'] = userDoc.id;

      // Get flat details if assigned
      if (data['flatId'] != null) {
        final flatDoc = await _firestore
            .collection(flatsCollection)
            .doc(data['flatId'])
            .get();
        
        if (flatDoc.exists) {
          data['flatDetails'] = flatDoc.data();
        }
      }

      // Get building details if assigned
      if (data['buildingId'] != null) {
        final buildingDoc = await _firestore
            .collection(buildingsCollection)
            .doc(data['buildingId'])
            .get();
        
        if (buildingDoc.exists) {
          data['buildingDetails'] = buildingDoc.data();
        }
      }

      print('✅ Fetched resident details: $residentId');
      return data;
    } catch (e) {
      print('❌ Error fetching resident details: $e');
      return null;
    }
  }

  /// Get resident bills
  Future<List<Map<String, dynamic>>> getResidentBills(String residentId) async {
    try {
      final snapshot = await _firestore
          .collection(billsCollection)
          .where('residentId', isEqualTo: residentId)
          .get();

      final bills = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();

      // Sort by due date (newest first)
      bills.sort((a, b) {
        final aDate = (a['dueDate'] as Timestamp?)?.toDate() ?? DateTime.now();
        final bDate = (b['dueDate'] as Timestamp?)?.toDate() ?? DateTime.now();
        return bDate.compareTo(aDate);
      });

      print('✅ Fetched ${bills.length} bills for resident $residentId');
      return bills;
    } catch (e) {
      print('❌ Error fetching resident bills: $e');
      return [];
    }
  }

  /// Get resident payment history
  Future<List<Map<String, dynamic>>> getResidentPaymentHistory(String residentId) async {
    try {
      final snapshot = await _firestore
          .collection(billsCollection)
          .where('residentId', isEqualTo: residentId)
          .where('status', isEqualTo: 'paid')
          .get();

      final payments = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();

      // Sort by paid date (newest first)
      payments.sort((a, b) {
        final aDate = (a['paidAt'] as Timestamp?)?.toDate() ?? DateTime.now();
        final bDate = (b['paidAt'] as Timestamp?)?.toDate() ?? DateTime.now();
        return bDate.compareTo(aDate);
      });

      print('✅ Fetched ${payments.length} payments for resident $residentId');
      return payments;
    } catch (e) {
      print('❌ Error fetching resident payment history: $e');
      return [];
    }
  }

  /// Update resident details
  Future<bool> updateResident({
    required String residentId,
    String? name,
    String? phone,
    String? email,
    String? profileImage,
    String? flatNumber,
  }) async {
    try {
      final updates = <String, dynamic>{};
      
      if (name != null) updates['name'] = name;
      if (phone != null) updates['phone'] = phone;
      if (email != null) updates['email'] = email;
      if (profileImage != null) updates['profileImage'] = profileImage;
      if (flatNumber != null) updates['flatNumber'] = flatNumber;
      
      if (updates.isNotEmpty) {
        updates['updatedAt'] = FieldValue.serverTimestamp();
        
        await _firestore
            .collection(usersCollection)
            .doc(residentId)
            .update(updates);
      }

      print('✅ Resident updated: $residentId');
      return true;
    } catch (e) {
      print('❌ Error updating resident: $e');
      return false;
    }
  }

  /// Activate resident
  Future<bool> activateResident(String residentId) async {
    try {
      await _firestore.collection(usersCollection).doc(residentId).update({
        'isActive': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      print('✅ Resident activated: $residentId');
      return true;
    } catch (e) {
      print('❌ Error activating resident: $e');
      return false;
    }
  }

  /// Deactivate resident
  Future<bool> deactivateResident(String residentId) async {
    try {
      await _firestore.collection(usersCollection).doc(residentId).update({
        'isActive': false,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      print('✅ Resident deactivated: $residentId');
      return true;
    } catch (e) {
      print('❌ Error deactivating resident: $e');
      return false;
    }
  }

  /// Delete resident
  Future<bool> deleteResident(String residentId) async {
    try {
      await _firestore.collection(usersCollection).doc(residentId).delete();

      print('✅ Resident deleted: $residentId');
      return true;
    } catch (e) {
      print('❌ Error deleting resident: $e');
      return false;
    }
  }

  /// Get resident statistics
  Future<Map<String, dynamic>> getResidentStatistics(String residentId) async {
    try {
      // Get total bills
      final billsSnapshot = await _firestore
          .collection(billsCollection)
          .where('residentId', isEqualTo: residentId)
          .get();

      // Get pending bills
      final pendingBills = billsSnapshot.docs
          .where((doc) => doc.data()['status'] == 'pending')
          .length;

      // Get paid bills
      final paidBills = billsSnapshot.docs
          .where((doc) => doc.data()['status'] == 'paid')
          .length;

      // Calculate total paid amount
      double totalPaid = 0;
      for (var doc in billsSnapshot.docs) {
        if (doc.data()['status'] == 'paid') {
          totalPaid += (doc.data()['amount'] as num?)?.toDouble() ?? 0;
        }
      }

      return {
        'totalBills': billsSnapshot.docs.length,
        'pendingBills': pendingBills,
        'paidBills': paidBills,
        'totalPaid': totalPaid,
      };
    } catch (e) {
      print('❌ Error fetching resident statistics: $e');
      return {
        'totalBills': 0,
        'pendingBills': 0,
        'paidBills': 0,
        'totalPaid': 0.0,
      };
    }
  }
}
