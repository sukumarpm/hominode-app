import 'dart:async';
import 'dart:typed_data';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:hominode_storage/hominode_storage.dart';

/// Phase 1 private upload foundation. Does not mutate existing imageUrl fields.
class FirebaseImageUploadService {
  FirebaseImageUploadService({
    FirebaseStorage? storage,
    ImageCallable? call,
    String? Function()? currentUid,
    this.timeout = const Duration(seconds: 60),
  }) : _storage = storage,
       _call = call,
       _currentUid =
           currentUid ?? (() => FirebaseAuth.instance.currentUser?.uid);

  final FirebaseStorage? _storage;
  final ImageCallable? _call;
  final String? Function() _currentUid;
  final Duration timeout;
  static const supportedFeatures = {
    'profile',
    'community_wall',
    'complaints',
    'marketplace',
  };

  late final StorageImageUploadClient _client = StorageImageUploadClient(
    currentUid: _currentUid,
    timeout: timeout,
    call:
        _call ??
        (name, data) async {
          final result =
              await FirebaseFunctions.instanceFor(region: 'asia-southeast1')
                  .httpsCallable(
                    name,
                    options: HttpsCallableOptions(timeout: timeout),
                  )
                  .call<Map<String, dynamic>>(data);
          return Map<String, dynamic>.from(result.data);
        },
    write: (asset, bytes) async {
      final storage = _storage ?? FirebaseStorage.instance;
      if (storage.bucket.replaceFirst(RegExp(r'^gs://'), '') != asset.bucket) {
        throw StateError('The image upload bucket does not match this app.');
      }
      final task = storage
          .ref(asset.storagePath)
          .putData(
            bytes,
            SettableMetadata(
              contentType: asset.contentType,
              cacheControl: 'private, no-store',
              customMetadata: {
                'assetId': asset.assetId,
                'communityId': asset.communityId,
                'ownerId': asset.ownerId,
                'feature': asset.feature,
                'resourceId': asset.resourceId,
              },
            ),
          );
      await task
          .then<void>((_) {})
          .timeout(
            timeout,
            onTimeout: () {
              unawaited(
                task.cancel().then<void>(
                  (_) {},
                  onError: (Object error, StackTrace stack) {
                    // Preserve the original timeout. A failed cancellation must not
                    // become an unhandled asynchronous error or publish an asset.
                  },
                ),
              );
              throw TimeoutException('Image upload timed out.');
            },
          );
    },
  );

  Future<StorageImageAsset> upload({
    required String feature,
    required String resourceId,
    required String contentType,
    required Uint8List bytes,
    void Function(StorageImageAsset)? onReserved,
    void Function()? onStored,
  }) {
    if (!supportedFeatures.contains(feature)) {
      throw ArgumentError('This app cannot upload that image type.');
    }
    return _client.upload(
      feature: feature,
      resourceId: resourceId,
      contentType: contentType,
      bytes: bytes,
      onReserved: onReserved,
      onStored: onStored,
    );
  }

  Future<Uint8List> read(StorageImageAsset asset) => _client.read(asset);
  Future<StorageImageAsset> complete(StorageImageAsset asset) =>
      _client.complete(asset);
  Future<Map<String, dynamic>> call(String name, Map<String, dynamic> data) =>
      _client.call(name, data).timeout(timeout);
}
