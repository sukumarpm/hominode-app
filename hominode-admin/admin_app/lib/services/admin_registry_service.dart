import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../models/admin_profile.dart';

class AdminRegistryService {
  AdminRegistryService({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _functions =
           functions ??
           FirebaseFunctions.instanceFor(region: 'asia-southeast1');
  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  Future<List<AdminProfile>> getAdmins() async {
    final snapshot = await _firestore.collection('admins').get();
    final admins = snapshot.docs
        .map((doc) => AdminProfile.fromMap(doc.id, doc.data()))
        .toList();
    admins.sort((a, b) => a.phoneNumber.compareTo(b.phoneNumber));
    return admins;
  }

  Future<String> createAdmin({
    required String phoneNumber,
    required List<String> communityIds,
    bool isActive = true,
  }) async {
    final response = await _functions.httpsCallable('createAdmin').call({
      'phoneNumber': phoneNumber.trim(),
      'authorizedCommunityIds': communityIds,
      'isActive': isActive,
    });
    final data = response.data;
    if (data is! Map || data['uid'] is! String) {
      throw StateError('Admin service returned an invalid response.');
    }
    return data['uid'] as String;
  }

  Future<void> updateAssignments(String uid, List<String> communityIds) async {
    await _functions.httpsCallable('updateAdminAssignments').call({
      'uid': uid,
      'authorizedCommunityIds': communityIds,
    });
  }

  Future<void> setAdminActive(String uid, bool isActive) async {
    await _functions.httpsCallable('setAdminActive').call({
      'uid': uid,
      'isActive': isActive,
    });
  }
}
