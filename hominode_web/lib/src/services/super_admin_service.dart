import 'package:cloud_functions/cloud_functions.dart';

class SuperAdminService {
  SuperAdminService._();

  static final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(
    region: 'asia-southeast1',
  );

  static Future<void> createCommunity({
    required String name,
    required String brandName,
    required String slug,
    required String websitePath,
    required String databaseId,
  }) async {
    await _functions.httpsCallable('createCommunity').call({
      'name': name.trim(),
      'brandName': brandName.trim(),
      'slug': slug.trim(),
      'websitePath': websitePath.trim(),
      'databaseId': databaseId.trim(),
      'isActive': true,
    });
  }

  static Future<void> updateCommunity({
    required String communityId,
    required String name,
    required String brandName,
    required String slug,
    required String websitePath,
    required String databaseId,
  }) async {
    await _functions.httpsCallable('updateCommunity').call({
      'communityId': communityId.trim(),
      'name': name.trim(),
      'brandName': brandName.trim(),
      'slug': slug.trim(),
      'websitePath': websitePath.trim(),
      'databaseId': databaseId.trim(),
    });
  }

  static Future<void> setCommunityActive({
    required String communityId,
    required bool isActive,
  }) async {
    await _functions.httpsCallable('setCommunityActive').call({
      'communityId': communityId.trim(),
      'isActive': isActive,
    });
  }

  static Future<void> createAdmin({
    required String phoneNumber,
    required List<String> communityIds,
  }) async {
    await _functions.httpsCallable('createAdmin').call({
      'phoneNumber': phoneNumber.trim(),
      'authorizedCommunityIds': communityIds,
      'isActive': true,
    });
  }

  static Future<void> updateAdminAssignments({
    required String adminId,
    required List<String> communityIds,
  }) async {
    await _functions.httpsCallable('updateAdminAssignments').call({
      'uid': adminId.trim(),
      'authorizedCommunityIds': communityIds,
    });
  }

  static Future<void> setAdminActive({
    required String adminId,
    required bool isActive,
  }) async {
    await _functions.httpsCallable('setAdminActive').call({
      'uid': adminId.trim(),
      'isActive': isActive,
    });
  }
}
