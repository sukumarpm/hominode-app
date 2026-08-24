import 'package:cloud_firestore/cloud_firestore.dart';

/// Additive helpers for migrating root collections without changing paths yet.
class TenantFirestore {
  const TenantFirestore._();

  static Map<String, dynamic> stamp(
    String communityId,
    Map<String, dynamic> data,
  ) {
    if (communityId.trim().isEmpty) {
      throw ArgumentError.value(
        communityId,
        'communityId',
        'must not be empty',
      );
    }
    return {...data, 'communityId': communityId};
  }

  static Query<Map<String, dynamic>> scope(
    CollectionReference<Map<String, dynamic>> collection,
    String communityId,
  ) {
    if (communityId.trim().isEmpty) {
      throw ArgumentError.value(
        communityId,
        'communityId',
        'must not be empty',
      );
    }
    return collection.where('communityId', isEqualTo: communityId);
  }
}
