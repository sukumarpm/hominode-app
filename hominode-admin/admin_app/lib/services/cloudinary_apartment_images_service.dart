import 'dart:io';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hominode_storage/hominode_storage.dart';
import 'admin_service.dart';
import 'firebase_image_upload_service.dart';

/// Compatibility name for existing callers. All writes use private Firebase
/// assets and server-authorized gallery operations; there is no external upload.
class CloudinaryApartmentImagesService {
  final FirebaseFirestore _firestore;
  final AdminService _adminService;
  final FirebaseImageUploadService _uploads;
  StorageImageAsset? _reservation;
  StorageImageAsset? _ready;
  String? _attempt;
  bool _stored = false;

  CloudinaryApartmentImagesService({
    FirebaseFirestore? firestore,
    AdminService? adminService,
    FirebaseImageUploadService? uploads,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _adminService = adminService ?? AdminService(),
       _uploads = uploads ?? FirebaseImageUploadService();

  Future<String> uploadImage({
    required String title,
    required String description,
    required String type,
    required File imageFile,
    String? buildingId,
    String ownershipScope = 'BUILDING',
    String? uploadDate,
    String? uploadTime,
    ApartmentImageModel? replacing,
  }) async {
    final community = _adminService.requireCurrentCommunityId();
    if (!{'COMMUNITY', 'BUILDING'}.contains(ownershipScope))
      throw ArgumentError('Unsupported management scope.');
    final resource = ownershipScope == 'COMMUNITY'
        ? community
        : buildingId ?? '';
    PhotoOwnership.queryFields(community, ownershipScope, resource);
    if (replacing != null &&
        (replacing.contractVersion != 2 ||
            replacing.ownershipScope != ownershipScope ||
            replacing.resourceId != resource))
      throw StateError(
        'Legacy or differently scoped photos cannot be replaced.',
      );
    final uid = _adminService.getCurrentAdminId();
    if (uid == null) throw StateError('Sign in to upload an image.');
    final stat = await imageFile.stat();
    if (stat.size < 1 || stat.size > StorageImageAsset.maxBytes) {
      throw ArgumentError('Choose an image no larger than 10 MB.');
    }
    final attempt =
        '$uid/$community/$ownershipScope/$resource/${replacing?.id}/${replacing?.revision}/${imageFile.path}/${stat.size}/${stat.modified.millisecondsSinceEpoch}';
    if (_attempt != attempt) {
      _attempt = attempt;
      _reservation = null;
      _ready = null;
      _stored = false;
    }
    void checkScope() {
      if (_adminService.getCurrentAdminId() != uid ||
          _adminService.requireCurrentCommunityId() != community) {
        throw StateError(
          'The selected community or sign-in changed. Reopen the image form.',
        );
      }
    }

    if (_ready == null) {
      if (_stored && _reservation != null) {
        _ready = await _uploads.complete(_reservation!);
      } else {
        final builder = BytesBuilder(copy: false);
        await for (final chunk in imageFile.openRead(
          0,
          StorageImageAsset.maxBytes + 1,
        )) {
          builder.add(chunk);
        }
        final bytes = builder.takeBytes();
        if (bytes.isEmpty || bytes.length > StorageImageAsset.maxBytes) {
          throw ArgumentError('Choose an image no larger than 10 MB.');
        }
        // Match the content, not the filename or a client-supplied MIME string.
        final String mime;
        if (bytes.length >= 3 &&
            bytes[0] == 255 &&
            bytes[1] == 216 &&
            bytes[2] == 255) {
          mime = 'image/jpeg';
        } else if (bytes.length >= 8 &&
            bytes.take(8).join(',') == '137,80,78,71,13,10,26,10') {
          mime = 'image/png';
        } else if (bytes.length >= 12 &&
            String.fromCharCodes(bytes.take(4)) == 'RIFF' &&
            String.fromCharCodes(bytes.sublist(8, 12)) == 'WEBP') {
          mime = 'image/webp';
        } else {
          throw ArgumentError('Choose a JPEG, PNG or WebP image.');
        }
        checkScope();
        _ready = await _uploads.upload(
          feature: 'apartment',
          resourceId: resource,
          ownershipScope: ownershipScope,
          contentType: mime,
          bytes: bytes,
          onReserved: (asset) => _reservation = asset,
          onStored: () => _stored = true,
        );
      }
    }
    checkScope();
    if (_ready!.communityId != community ||
        !PhotoOwnership.matches(
          _ready!.toMap(),
          community,
          ownershipScope,
          resource,
        )) {
      throw StateError('The image belongs to another community or building.');
    }
    final result = await _uploads.call('saveApartmentImage', {
      'assetId': _ready!.assetId,
      if (replacing != null) ...{
        'imageId': replacing.id,
        'expectedRevision': replacing.revision,
      },
      if (replacing == null) ...{
        'title': title,
        'description': description,
        'type': type,
        'uploadDate': uploadDate ?? '',
        'uploadTime': uploadTime ?? '',
      },
    });
    checkScope();
    final id = result['imageId'];
    if (result['contractVersion'] != 2 ||
        id is! String ||
        id != (replacing?.id ?? _ready!.assetId)) {
      throw const FormatException(
        'The image save was not confirmed. Retry to check it.',
      );
    }
    // Retain the idempotent attempt until the modal closes, including on a lost
    // response. A retry must never create another gallery record.
    return id;
  }

  Stream<List<ApartmentImageModel>> getImages() => _images(scope: 'COMMUNITY');
  Stream<List<ApartmentImageModel>> getLegacyImages([String? buildingId]) =>
      _images(buildingId: buildingId, legacy: true);
  Stream<List<ApartmentImageModel>> getImagesForBuilding(String buildingId) =>
      _images(buildingId: buildingId, scope: 'BUILDING');
  Stream<List<ApartmentImageModel>> _images({
    String? buildingId,
    String scope = 'COMMUNITY',
    bool legacy = false,
  }) {
    if (_adminService.getCurrentAdminId() == null) return Stream.value([]);
    final communityId = _adminService.requireCurrentCommunityId();
    Query<Map<String, dynamic>> query = _firestore
        .collection(legacy ? 'apartmentImages' : 'apartmentImagesV2')
        .where('communityId', isEqualTo: communityId);

    final appliedFields = <String>{'communityId'};

    if (!legacy) {
      for (final entry in PhotoOwnership.queryFields(
        communityId,
        scope,
        scope == 'COMMUNITY' ? communityId : buildingId ?? '',
      ).entries) {
        if (appliedFields.add(entry.key)) {
          query = query.where(entry.key, isEqualTo: entry.value);
        }
      }
    }

    if (buildingId != null) {
      if (appliedFields.add('buildingId')) {
        query = query.where('buildingId', isEqualTo: buildingId);
      }
      if (appliedFields.add('status')) {
        query = query.where('status', isEqualTo: 'active');
      }
    }
    return query.snapshots().map((snapshot) {
      final images = snapshot.docs
          .where(
            (doc) => legacy
                ? !PhotoOwnership.isVersioned(doc.data())
                : PhotoOwnership.matches(
                    doc.data(),
                    _adminService.requireCurrentCommunityId(),
                    scope,
                    scope == 'COMMUNITY'
                        ? _adminService.requireCurrentCommunityId()
                        : buildingId,
                  ),
          )
          .map((doc) => ApartmentImageModel.fromFirestore(doc.id, doc.data()))
          .toList();
      images.sort(
        (a, b) => (b.createdAt ?? DateTime.now()).compareTo(
          a.createdAt ?? DateTime.now(),
        ),
      );
      return images;
    });
  }

  Future<void> deleteImage(
    String imageId, {
    required int expectedRevision,
  }) async {
    final result = await _uploads.call('deleteApartmentImage', {
      'contractVersion': 2,
      'imageId': imageId,
      'expectedRevision': expectedRevision,
    });
    if (result['imageId'] != imageId || result['deleted'] != true)
      throw const FormatException('Image deletion could not be confirmed.');
  }
}

class ApartmentImageModel {
  final String id,
      title,
      description,
      type,
      imageUrl,
      adminId,
      adminName,
      buildingId,
      communityId,
      status,
      uploadDate,
      uploadTime;
  final DateTime? createdAt, updatedAt;
  final StorageImageAsset? imageAsset;
  final int revision;
  final int? contractVersion;
  final String? ownershipScope, resourceId;
  ApartmentImageModel({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.imageUrl,
    required this.adminId,
    required this.adminName,
    required this.buildingId,
    this.communityId = '',
    required this.status,
    required this.uploadDate,
    required this.uploadTime,
    this.createdAt,
    this.updatedAt,
    this.imageAsset,
    this.revision = 0,
    this.contractVersion,
    this.ownershipScope,
    this.resourceId,
  });

  factory ApartmentImageModel.fromFirestore(
    String id,
    Map<String, dynamic> data,
  ) => ApartmentImageModel(
    id: id,
    contractVersion: data['contractVersion'] as int?,
    ownershipScope: data['ownershipScope'] as String?,
    resourceId: data['resourceId'] as String?,
    title: data['title'] ?? '',
    description: data['description'] ?? '',
    type: data['type'] ?? 'Common Area',
    imageUrl: data['imageUrl'] ?? '',
    adminId: data['adminId'] ?? '',
    adminName: data['adminName'] ?? 'Admin',
    buildingId: data['buildingId'] ?? '',
    communityId: data['communityId'] ?? '',
    status: data['status'] ?? 'active',
    uploadDate: data['uploadDate'] ?? '',
    uploadTime: data['uploadTime'] ?? '',
    createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    imageAsset: data['imageAsset'] == null
        ? null
        : StorageImageAsset.fromMap(
            Map<String, dynamic>.from(data['imageAsset']),
          ),
    revision: data['revision'] as int? ?? 0,
  );
}
