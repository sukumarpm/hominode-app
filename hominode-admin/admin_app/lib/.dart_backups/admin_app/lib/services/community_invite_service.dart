import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../models/community_invite.dart';
import 'admin_service.dart';
import 'admin_tenant_context.dart';

class CommunityNotFoundException implements Exception {
  const CommunityNotFoundException();
  @override
  String toString() => 'Selected community does not exist.';
}

class CommunityInviteService {
  CommunityInviteService({
    FirebaseFirestore? firestore,
    AdminService? adminService,
    FirebaseFunctions? functions,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _adminService = adminService ?? AdminService(),
       _functions =
           functions ??
           FirebaseFunctions.instanceFor(region: 'asia-southeast1');

  final FirebaseFirestore _firestore;
  final AdminService _adminService;
  final FirebaseFunctions _functions;
  final _inviteRefresh = StreamController<void>.broadcast();

  // Exact resident-app contract: trim, uppercase, keep A-Z, 0-9, underscore and hyphen.
  static String normalizeInviteCode(String value) =>
      value.trim().toUpperCase().replaceAll(RegExp(r'[^A-Z0-9_-]'), '');

  static String normalizeSlug(String value) => value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');

  static String normalizeCommunityId(String value) => value
      .trim()
      .toUpperCase()
      .replaceAll(RegExp(r'[^A-Z0-9_-]+'), '-')
      .replaceAll(RegExp(r'-+'), '-')
      .replaceAll(RegExp(r'^[-_]+|[-_]+$'), '');

  static Map<String, String> communityCreationPayload({
    required String communityId,
    required String name,
    required String slug,
  }) => {
    'communityId': normalizeCommunityId(communityId),
    'name': name.trim(),
    'slug': normalizeSlug(slug),
  };

  Future<AdminCommunity> getSelectedCommunity() async {
    final communityId = _adminService.requireCurrentCommunityId();
    final doc = await _firestore
        .collection('communities')
        .doc(communityId)
        .get();
    if (!doc.exists || doc.data() == null) {
      throw const CommunityNotFoundException();
    }
    return AdminCommunity.fromMap(doc.id, doc.data()!);
  }

  Future<void> createCommunity({
    required String communityId,
    required String name,
    required String slug,
  }) async {
    final payload = communityCreationPayload(
      communityId: communityId,
      name: name,
      slug: slug,
    );
    if (payload['communityId']!.isEmpty) {
      throw ArgumentError('Community ID is required.');
    }
    if (payload['name']!.isEmpty) {
      throw ArgumentError('Community name is required.');
    }
    if (payload['slug']!.isEmpty) throw ArgumentError('Enter a valid slug.');
    try {
      final response = await _functions
          .httpsCallable('createCommunity')
          .call(payload);
      final data = response.data;
      final createdId = data is Map ? data['communityId'] as String? : null;
      if (createdId == null || createdId.isEmpty) {
        throw StateError('Community service returned an invalid response.');
      }
      AdminTenantContext.instance.addAuthorizedCommunity(createdId);
    } on FirebaseFunctionsException catch (error) {
      throw StateError(error.message ?? 'Community could not be created.');
    }
  }

  Stream<List<CommunityInvite>> watchInvites() async* {
    yield await _listInvites();
    await for (final _ in _inviteRefresh.stream) {
      yield await _listInvites();
    }
  }

  Future<List<CommunityInvite>> _listInvites() async {
    final communityId = _adminService.requireCurrentCommunityId();
    try {
      final response = await _functions
          .httpsCallable('listCommunityInvites')
          .call({'communityId': communityId});
      final data = response.data;
      final records = data is Map ? data['invites'] : null;
      if (records is! List) {
        throw StateError('Invite service returned an invalid response.');
      }
      return records
          .whereType<Map>()
          .map((record) => Map<String, dynamic>.from(record))
          .map(
            (record) =>
                CommunityInvite.fromMap(record['code'].toString(), record),
          )
          .toList();
    } on FirebaseFunctionsException catch (error) {
      throw StateError(error.message ?? 'Invites could not be loaded.');
    }
  }

  Future<String> createInvite({DateTime? expiresAt, int? maxUses}) async {
    final communityId = _adminService.requireCurrentCommunityId();
    if (expiresAt != null && !expiresAt.isAfter(DateTime.now())) {
      throw ArgumentError('Expiry must be in the future.');
    }
    if (maxUses != null && maxUses < 1) {
      throw ArgumentError('Usage limit must be at least 1.');
    }
    try {
      final response = await _functions
          .httpsCallable('createCommunityInvite')
          .call({
            'communityId': communityId,
            'expiresAt': expiresAt?.millisecondsSinceEpoch,
            'maxUses': maxUses,
          });
      final data = response.data;
      final code = data is Map ? data['code'] as String? : null;
      if (code == null || code.isEmpty) {
        throw StateError('Invite service returned an invalid response.');
      }
      _inviteRefresh.add(null);
      return code;
    } on FirebaseFunctionsException catch (error) {
      throw StateError(error.message ?? 'Invite could not be created.');
    }
  }

  Future<void> revokeInvite(String rawCode) async {
    final code = normalizeInviteCode(rawCode);
    final communityId = _adminService.requireCurrentCommunityId();
    try {
      await _functions.httpsCallable('revokeCommunityInvite').call({
        'communityId': communityId,
        'inviteCode': code,
      });
      _inviteRefresh.add(null);
    } on FirebaseFunctionsException catch (error) {
      throw StateError(error.message ?? 'Invite could not be revoked.');
    }
  }
}
