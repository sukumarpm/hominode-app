import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/parcel_entry.dart';
import 'admin_tenant_context.dart';

class ParcelResident {
  final String id;
  final String communityId;
  final String name;
  final String flatId;
  final String flatLabel;
  final String buildingId;

  const ParcelResident({
    required this.id,
    required this.communityId,
    required this.name,
    required this.flatId,
    required this.flatLabel,
    required this.buildingId,
  });

  static ParcelResident? fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
    String communityId,
  ) {
    final data = doc.data();
    if (data == null) return null;
    String text(String key) =>
        data[key] is String ? (data[key] as String).trim() : '';

    final occupancyStatus = text('occupancyStatus');

    if (data['communityId'] != communityId ||
        data['role'] != 'resident' ||
        data['isActive'] != true ||
        data['approvalStatus'] != 'approved' ||
        (data['status'] != null && data['status'] != 'active') ||
        (occupancyStatus.isNotEmpty && occupancyStatus != 'current') ||
        text('flatId').isEmpty ||
        text('buildingId').isEmpty) {
      return null;
    }
    final name = [
      text('name'),
      text('fullName'),
      text('displayName'),
      doc.id,
    ].firstWhere((value) => value.isNotEmpty);
    final label = [
      text('flatLabel'),
      text('flatNumber'),
      text('flatId'),
    ].firstWhere((value) => value.isNotEmpty);
    return ParcelResident(
      id: doc.id,
      communityId: communityId,
      name: name,
      flatId: text('flatId'),
      flatLabel: label,
      buildingId: text('buildingId'),
    );
  }
}

class ParcelFirestoreService {
  final FirebaseFirestore _firestore;
  final AdminTenantContext _tenant;

  ParcelFirestoreService({
    FirebaseFirestore? firestore,
    AdminTenantContext? tenant,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _tenant = tenant ?? AdminTenantContext.instance;

  void _requireCommunity(String expected) {
    if (_tenant.requireCommunityId() != expected) {
      throw StateError('The selected community changed. Please try again.');
    }
  }

  Stream<List<ParcelEntry>> watchParcels() {
    final communityId = _tenant.requireCommunityId();
    return _firestore
        .collection('parcels')
        .where('communityId', isEqualTo: communityId)
        .snapshots()
        .map((snapshot) {
          _requireCommunity(communityId);
          final parcels = snapshot.docs.map(ParcelEntry.fromFirestore).toList();
          parcels.sort((a, b) => b.receivedTime.compareTo(a.receivedTime));
          return parcels;
        });
  }

  Future<List<ParcelResident>> loadEligibleResidents() async {
    final communityId = _tenant.requireCommunityId();
    final snapshot = await _firestore
        .collection('users')
        .where('communityId', isEqualTo: communityId)
        .get();
    _requireCommunity(communityId);
    final residents = snapshot.docs
        .map((doc) => ParcelResident.fromFirestore(doc, communityId))
        .whereType<ParcelResident>()
        .toList();
    residents.sort(
      (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );
    return residents;
  }

  Future<ParcelEntry> addParcel({
    required ParcelResident resident,
    required String courier,
    String trackingId = '',
    String notes = '',
  }) async {
    final communityId = _tenant.requireCommunityId();
    if (resident.communityId != communityId || courier.trim().isEmpty) {
      throw StateError('Select a current resident and enter a courier.');
    }
    final ref = _firestore.collection('parcels').doc();
    return _firestore.runTransaction((transaction) async {
      _requireCommunity(communityId);
      final snapshot = await transaction.get(
        _firestore.collection('users').doc(resident.id),
      );
      final current = ParcelResident.fromFirestore(snapshot, communityId);
      _requireCommunity(communityId);
      if (current == null ||
          current.flatId != resident.flatId ||
          current.buildingId != resident.buildingId) {
        throw StateError(
          'The resident assignment changed. Reload the residents.',
        );
      }
      final receivedAt = DateTime.now();
      transaction.set(ref, {
        'communityId': communityId,
        'residentId': current.id,
        'residentName': current.name,
        'flatId': current.flatId,
        'flatLabel': current.flatLabel,
        'buildingId': current.buildingId,
        'courier': courier.trim(),
        'trackingId': trackingId.trim(),
        'receivedAt': Timestamp.fromDate(receivedAt),
        'collectedAt': null,
        'status': 'pending',
        'isResidentNotified': false,
        'notes': notes.trim(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return ParcelEntry(
        id: ref.id,
        communityId: communityId,
        residentId: current.id,
        residentName: current.name,
        unit: current.flatLabel,
        flatId: current.flatId,
        buildingId: current.buildingId,
        courier: courier.trim(),
        trackingId: trackingId.trim(),
        receivedTime: receivedAt,
        status: ParcelStatus.pending,
        isResidentNotified: false,
        notes: notes.trim().isEmpty ? null : notes.trim(),
      );
    });
  }

  Future<void> markCollected(ParcelEntry parcel) async {
    final communityId = _tenant.requireCommunityId();
    if (parcel.communityId != communityId) {
      throw StateError('This parcel belongs to another community.');
    }
    final ref = _firestore.collection('parcels').doc(parcel.id);
    await _firestore.runTransaction((transaction) async {
      _requireCommunity(communityId);
      final snapshot = await transaction.get(ref);
      final data = snapshot.data();
      _requireCommunity(communityId);
      if (data == null || data['communityId'] != communityId) {
        throw StateError('Parcel is unavailable in this community.');
      }
      if (data['status'] == 'collected') return;
      if (data['status'] != 'pending') {
        throw StateError('Parcel cannot be collected.');
      }
      transaction.update(ref, {
        'status': 'collected',
        'collectedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }
}
