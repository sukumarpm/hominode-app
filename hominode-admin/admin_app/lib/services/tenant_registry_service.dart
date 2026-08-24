import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../models/tenant_config.dart';

class TenantNotFoundException implements Exception {
  const TenantNotFoundException(this.identifier);

  final String identifier;

  @override
  String toString() => 'Tenant $identifier does not exist.';
}

class InactiveTenantException implements Exception {
  const InactiveTenantException(this.communityId);

  final String communityId;

  @override
  String toString() => 'Tenant $communityId is inactive.';
}

class TenantRegistryService {
  TenantRegistryService({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _functions =
           functions ??
           FirebaseFunctions.instanceFor(region: 'asia-southeast1');

  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  CollectionReference<Map<String, dynamic>> get _communities =>
      _firestore.collection('communities');

  Future<TenantConfig> getTenantById(String communityId) async {
    final id = communityId.trim();
    if (id.isEmpty) throw const TenantNotFoundException('');
    final document = await _communities.doc(id).get();
    final data = document.data();
    if (!document.exists || data == null) {
      throw TenantNotFoundException(id);
    }
    return TenantConfig.fromMap(document.id, data);
  }

  Future<TenantConfig> getTenantByIdFromServer(String communityId) async {
    final id = communityId.trim();
    if (id.isEmpty) throw const TenantNotFoundException('');
    final document = await _communities
        .doc(id)
        .get(const GetOptions(source: Source.server));
    final data = document.data();
    if (!document.exists || data == null) throw TenantNotFoundException(id);
    return TenantConfig.fromMap(document.id, data);
  }

  Future<TenantConfig> getTenantBySlug(String slug) async {
    final normalized = TenantConfig.slugify(slug);
    if (normalized.isEmpty) throw TenantNotFoundException(slug);

    final exact = await _communities
        .where('slug', isEqualTo: normalized)
        .limit(1)
        .get();
    if (exact.docs.isNotEmpty) {
      return TenantConfig.fromMap(exact.docs.first.id, exact.docs.first.data());
    }

    // Legacy documents may not persist slug yet. Super Admin registry reads can
    // derive and compare it in memory without writing a migration.
    final tenants = (await _communities.get()).docs.map(
      (document) => TenantConfig.fromMap(document.id, document.data()),
    );
    return findTenantBySlug(tenants, normalized) ??
        (throw TenantNotFoundException(normalized));
  }

  Future<List<TenantConfig>> getActiveTenants() async {
    return (await getTenants()).where((tenant) => tenant.isActive).toList();
  }

  Future<List<TenantConfig>> getTenants() async {
    final tenants = (await _communities.get()).docs
        .map((document) => TenantConfig.fromMap(document.id, document.data()))
        .toList();
    tenants.sort((a, b) => a.name.compareTo(b.name));
    return tenants;
  }

  Future<String> createTenant(Map<String, dynamic> values) async {
    final payload = mutationPayload(values);
    final response = await _functions
        .httpsCallable('createCommunity')
        .call(payload);
    final data = response.data;
    if (data is! Map || data['communityId'] is! String) {
      throw StateError('Community service returned an invalid response.');
    }
    return data['communityId'] as String;
  }

  Future<void> updateTenant(
    String communityId,
    Map<String, dynamic> values,
  ) async {
    await _functions.httpsCallable('updateCommunity').call({
      ...mutationPayload(values),
      'communityId': communityId,
    });
  }

  Future<void> setTenantActive(String communityId, bool isActive) async {
    await _functions.httpsCallable('setCommunityActive').call({
      'communityId': communityId,
      'isActive': isActive,
    });
  }

  static Map<String, dynamic> mutationPayload(Map<String, dynamic> values) {
    String value(String key) => (values[key] ?? '').toString().trim();
    final name = value('name');
    final slug = TenantConfig.slugify(
      value('slug').isEmpty ? name : value('slug'),
    );
    final websitePath = TenantConfig.slugify(
      value('websitePath').isEmpty ? slug : value('websitePath'),
    );
    if (name.isEmpty) throw ArgumentError('Community name is required.');
    if (slug.isEmpty) throw ArgumentError('Enter a valid slug.');
    if (websitePath.isEmpty) {
      throw ArgumentError('Enter a valid website path.');
    }
    return {
      'name': name,
      'slug': slug,
      'websitePath': websitePath,
      'databaseId': value('databaseId').isEmpty
          ? TenantConfig.defaultDatabaseId
          : value('databaseId'),
      'brandName': value('brandName').isEmpty ? name : value('brandName'),
      'logoUrl': value('logoUrl'),
      'primaryColor': value('primaryColor'),
    };
  }

  Future<TenantConfig> requireActiveTenant(String communityId) async {
    final tenant = await getTenantById(communityId);
    validateActiveState(tenant);
    return tenant;
  }

  static void validateActiveState(TenantConfig tenant) {
    if (!tenant.isActive) throw InactiveTenantException(tenant.communityId);
  }

  static TenantConfig? findTenantBySlug(
    Iterable<TenantConfig> tenants,
    String slug,
  ) {
    final normalized = TenantConfig.slugify(slug);
    for (final tenant in tenants) {
      if (tenant.slug == normalized) return tenant;
    }
    return null;
  }
}
