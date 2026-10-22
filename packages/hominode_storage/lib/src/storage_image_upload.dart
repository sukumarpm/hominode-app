import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

typedef ImageCallable =
    Future<Map<String, dynamic>> Function(
      String name,
      Map<String, dynamic> data,
    );
typedef PrivateImageWriter =
    Future<void> Function(StorageImageAsset reservation, Uint8List bytes);

/// A private Firebase reference, never a long-lived public download URL.
/// Existing domain imageUrl fields remain untouched until their readers support
/// this reference. Do not pass [storageUri] directly to Image.network.
class StorageImageAsset {
  StorageImageAsset._(this._data);

  final Map<String, dynamic> _data;
  static const maxBytes = 10 * 1024 * 1024;
  static const extensions = {
    'image/jpeg': 'jpg',
    'image/png': 'png',
    'image/webp': 'webp',
    'image/gif': 'gif',
  };
  static const features = {
    'apartment',
    'profile',
    'community_wall',
    'complaints',
    'marketplace',
  };

  int? get contractVersion => _data['contractVersion'] as int?;
  String? get ownershipScope => _data['ownershipScope'] as String?;
  String? get buildingId => _data['buildingId'] as String?;
  String? get unitId => _data['unitId'] as String?;

  String get assetId => _data['assetId'] as String;
  String get communityId => _data['communityId'] as String;
  String get ownerId => _data['ownerId'] as String;
  String get feature => _data['feature'] as String;
  String get resourceId => _data['resourceId'] as String;
  String get bucket => _data['bucket'] as String;
  String get storagePath => _data['storagePath'] as String;
  String get contentType => _data['contentType'] as String;
  int get size => _data['size'] as int;
  String get state => _data['state'] as String;
  String? get generation => _data['generation'] as String?;
  String get storageUri => 'gs://$bucket/$storagePath';

  Map<String, dynamic> toMap() => Map<String, dynamic>.from(_data);

  factory StorageImageAsset.fromMap(Map<String, dynamic> data) {
    const identifiers = [
      'assetId',
      'communityId',
      'ownerId',
      'resourceId',
      'bucket',
    ];
    const fields = {
      'contractVersion',
      'ownershipScope',
      'buildingId',
      'unitId',
      'assetId',
      'provider',
      'bucket',
      'storagePath',
      'communityId',
      'ownerId',
      'feature',
      'resourceId',
      'contentType',
      'size',
      'state',
      'expiresAtMs',
      'generation',
      'sha256',
    };
    if ((PhotoOwnership.isVersioned(data) &&
            (data['feature'] != 'apartment' ||
                !PhotoOwnership.matches(
                  data,
                  data['communityId'],
                  data['ownershipScope'],
                  data['resourceId'],
                  buildingId: data['buildingId'],
                ))) ||
        data.keys.any((key) => !fields.contains(key)) ||
        data['storagePath'] is! String ||
        identifiers.any(
          (key) =>
              data[key] is! String ||
              (data[key] as String).isEmpty ||
              RegExp(r'[/\s\x00-\x1f]').hasMatch(data[key] as String),
        ) ||
        !RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
        ).hasMatch(data['assetId'] as String) ||
        data['provider'] != 'firebase' ||
        !features.contains(data['feature']) ||
        !extensions.containsKey(data['contentType']) ||
        (data['contentType'] == 'image/gif' &&
            !{'profile', 'community_wall'}.contains(data['feature'])) ||
        data['size'] is! int ||
        (data['size'] as int) < 1 ||
        (data['size'] as int) > maxBytes ||
        !{'pending', 'ready'}.contains(data['state']) ||
        (data['state'] == 'ready' &&
            (data['generation'] is! String ||
                !RegExp(r'^[0-9]+$').hasMatch(data['generation'] as String) ||
                data['sha256'] is! String ||
                !RegExp(
                  r'^[0-9a-f]{64}$',
                ).hasMatch(data['sha256'] as String)))) {
      throw const FormatException('Invalid private image reference.');
    }
    final asset = StorageImageAsset._(Map<String, dynamic>.from(data));
    final file = '${asset.assetId}.${extensions[asset.contentType]}';
    final expected = asset.state == 'ready'
        ? 'private_images/${asset.communityId}/${asset.ownerId}/${asset.feature}/$file'
        : asset.feature == 'apartment'
        ? 'apartment_images/${asset.communityId}/${asset.ownerId}/$file'
        : 'resident_images/${asset.communityId}/${asset.ownerId}/${asset.feature}/$file';
    if (asset.storagePath != expected ||
        (asset.feature == 'profile' && asset.resourceId != asset.ownerId)) {
      throw const FormatException('Image reference is outside its scope.');
    }
    return asset;
  }
}

/// SDK-neutral sequencing reused by both Flutter applications.
class StorageImageUploadClient {
  StorageImageUploadClient({
    required this.currentUid,
    required this.call,
    required this.write,
    this.timeout = const Duration(seconds: 60),
  });

  final String? Function() currentUid;
  final ImageCallable call;
  final PrivateImageWriter write;
  final Duration timeout;

  Future<StorageImageAsset> upload({
    required String feature,
    required String resourceId,
    required String contentType,
    required Uint8List bytes,
    String? ownershipScope,
    void Function(StorageImageAsset)? onReserved,
    void Function()? onStored,
  }) async {
    final uid = currentUid();
    if (uid == null || uid.isEmpty) {
      throw StateError('Sign in to upload an image.');
    }
    if (!StorageImageAsset.features.contains(feature) ||
        resourceId.isEmpty ||
        resourceId.length > 128 ||
        resourceId.contains('/') ||
        !StorageImageAsset.extensions.containsKey(contentType) ||
        (contentType == 'image/gif' &&
            !{'profile', 'community_wall'}.contains(feature)) ||
        bytes.isEmpty ||
        bytes.length > StorageImageAsset.maxBytes) {
      throw ArgumentError('Choose a supported image no larger than 10 MB.');
    }
    if (ownershipScope != null &&
        (feature != 'apartment' ||
            !PhotoOwnership.scopes.contains(ownershipScope)))
      throw ArgumentError('Unsupported photo scope.');
    final request = {
      if (ownershipScope != null) ...{
        'contractVersion': 2,
        'ownershipScope': ownershipScope,
      },
      'feature': feature,
      'resourceId': resourceId,
      'contentType': contentType,
      'size': bytes.length,
    };
    final pending = StorageImageAsset.fromMap(
      await call('prepareStorageImageUpload', request).timeout(timeout),
    );
    if (pending.ownershipScope != ownershipScope ||
        (ownershipScope != null && pending.contractVersion != 2) ||
        pending.state != 'pending' ||
        pending.ownerId != uid ||
        pending.feature != feature ||
        pending.resourceId != resourceId ||
        pending.contentType != contentType ||
        pending.size != bytes.length) {
      throw StateError(
        'Image reservation does not match the requested upload.',
      );
    }
    if (currentUid() != uid) {
      throw StateError('The image upload session changed.');
    }
    onReserved?.call(pending);
    await write(pending, bytes).timeout(timeout);
    onStored?.call();
    if (currentUid() != uid) {
      throw StateError('The image upload session changed.');
    }
    return complete(pending);
  }

  Future<StorageImageAsset> complete(StorageImageAsset pending) async {
    final uid = currentUid();
    if (uid == null || uid != pending.ownerId) {
      throw StateError('The image upload session changed.');
    }
    final ready = StorageImageAsset.fromMap(
      await call('completeStorageImageUpload', {
        'assetId': pending.assetId,
      }).timeout(timeout),
    );
    if (currentUid() != uid ||
        ready.state != 'ready' ||
        [
          'contractVersion',
          'ownershipScope',
          'buildingId',
          'unitId',
          'assetId',
          'ownerId',
          'communityId',
          'feature',
          'resourceId',
          'bucket',
          'contentType',
          'size',
        ].any((key) => ready.toMap()[key] != pending.toMap()[key])) {
      throw StateError('Image verification did not match the uploaded file.');
    }
    return ready;
  }

  Future<Uint8List> read(
    StorageImageAsset asset, {
    bool allowApartmentViewer = false,
    bool allowAuthorizedViewer = false,
  }) async {
    final uid = currentUid();
    if (asset.state != 'ready' ||
        uid == null ||
        (uid != asset.ownerId &&
            !allowAuthorizedViewer &&
            !(allowApartmentViewer && asset.feature == 'apartment'))) {
      throw StateError(
        'Sign in as the image owner to read this private asset.',
      );
    }
    final result = await call('readStorageImage', {
      'assetId': asset.assetId,
    }).timeout(timeout);
    final encoded = result['base64'];
    if (currentUid() != uid ||
        result['assetId'] != asset.assetId ||
        result['generation'] != asset.generation ||
        result['contentType'] != asset.contentType ||
        result['size'] != asset.size ||
        encoded is! String ||
        encoded.length > ((StorageImageAsset.maxBytes + 2) ~/ 3) * 4) {
      throw const FormatException('Invalid private image response.');
    }
    final bytes = base64Decode(encoded);
    if (bytes.length != asset.size) {
      throw const FormatException('Invalid private image size.');
    }
    return bytes;
  }
}

/// Ownership is explicit. Legacy categories never determine permissions.
class PhotoOwnership {
  static const scopes = {'COMMUNITY', 'BUILDING', 'UNIT'};
  static bool isVersioned(Map<String, dynamic> data) =>
      data.containsKey('contractVersion') || data.containsKey('ownershipScope');
  static bool _id(dynamic value) =>
      value is String &&
      value.isNotEmpty &&
      value == value.trim() &&
      value.length <= 128 &&
      value != '.' &&
      value != '..' &&
      !RegExp(r'[/\\\s\x00-\x1f]').hasMatch(value);
  static bool matches(
    Map<String, dynamic> data,
    dynamic community,
    dynamic scope,
    dynamic resource, {
    dynamic buildingId,
  }) {
    if (!_id(community) ||
        !_id(resource) ||
        !scopes.contains(scope) ||
        data['contractVersion'] is! int ||
        data['contractVersion'] != 2 ||
        data['ownershipScope'] != scope ||
        data['communityId'] != community ||
        data['resourceId'] != resource)
      return false;
    if (scope == 'COMMUNITY')
      return resource == community &&
          !data.containsKey('buildingId') &&
          !data.containsKey('unitId');
    if (scope == 'BUILDING')
      return data['buildingId'] == resource && !data.containsKey('unitId');
    return _id(buildingId) &&
        data['buildingId'] == buildingId &&
        data['unitId'] == resource;
  }

  static Map<String, dynamic> queryFields(
    String community,
    String scope,
    String resource, {
    String? buildingId,
  }) {
    if (!_id(community) ||
        !_id(resource) ||
        !scopes.contains(scope) ||
        (scope == 'COMMUNITY' && community != resource) ||
        (scope == 'UNIT' && !_id(buildingId)))
      throw ArgumentError('A canonical photo scope is required.');
    return {
      'communityId': community,
      'status': 'active',
      'contractVersion': 2,
      'ownershipScope': scope,
      'resourceId': resource,
      if (scope == 'BUILDING') 'buildingId': resource,
      if (scope == 'UNIT') ...{'buildingId': buildingId, 'unitId': resource},
    };
  }
}
