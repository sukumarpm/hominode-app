// lib/src/services/building_service.dart
// Firestore service for building management

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/building_model.dart';

class BuildingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String collectionName = 'buildings';

  /// Add a new building
  Future<String?> addBuilding(BuildingModel building) async {
    try {
      final docRef = await _firestore.collection(collectionName).add({
        'name': building.name,
        'address': building.address,
        'description': building.description,
        'totalFloors': building.totalFloors,
        'totalFlats': building.totalFlats,
        'amenities': building.amenities,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      print('✅ Building added: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      print('❌ Error adding building: $e');
      return null;
    }
  }

  /// Get all buildings
  Future<List<BuildingModel>> getBuildings() async {
    try {
      final snapshot = await _firestore
          .collection(collectionName)
          .orderBy('name')
          .get();

      final buildings = snapshot.docs
          .map((doc) => BuildingModel.fromSnapshot(doc))
          .toList();

      print('✅ Fetched ${buildings.length} buildings');
      return buildings;
    } catch (e) {
      print('❌ Error fetching buildings: $e');
      return [];
    }
  }

  /// Stream buildings (real-time updates)
  Stream<List<BuildingModel>> streamBuildings() {
    return _firestore
        .collection(collectionName)
        .orderBy('name')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => BuildingModel.fromSnapshot(doc))
          .toList();
    });
  }

  /// Get single building
  Future<BuildingModel?> getBuilding(String buildingId) async {
    try {
      final doc = await _firestore
          .collection(collectionName)
          .doc(buildingId)
          .get();

      if (doc.exists) {
        return BuildingModel.fromSnapshot(doc);
      }
      return null;
    } catch (e) {
      print('❌ Error fetching building: $e');
      return null;
    }
  }

  /// Update building
  Future<bool> updateBuilding(BuildingModel building) async {
    try {
      await _firestore.collection(collectionName).doc(building.id).update({
        'name': building.name,
        'address': building.address,
        'description': building.description,
        'totalFloors': building.totalFloors,
        'totalFlats': building.totalFlats,
        'amenities': building.amenities,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      print('✅ Building updated: ${building.id}');
      return true;
    } catch (e) {
      print('❌ Error updating building: $e');
      return false;
    }
  }

  /// Delete building
  Future<bool> deleteBuilding(String buildingId) async {
    try {
      await _firestore.collection(collectionName).doc(buildingId).delete();

      print('✅ Building deleted: $buildingId');
      return true;
    } catch (e) {
      print('❌ Error deleting building: $e');
      return false;
    }
  }

  /// Get building count
  Future<int> getBuildingCount() async {
    try {
      final snapshot = await _firestore.collection(collectionName).get();
      return snapshot.docs.length;
    } catch (e) {
      print('❌ Error getting building count: $e');
      return 0;
    }
  }
}
