import 'dart:io';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hominode_storage/hominode_storage.dart';
import 'firebase_image_upload_service.dart';

const privateImagePrefix = 'hominode-image:';

class _Attempt {
  StorageImageAsset? reservation, ready;
  bool stored = false;
}

/// One instance per form preserves ready assets and operation IDs across retries.
class ResidentImageOperations {
  ResidentImageOperations({
    FirebaseImageUploadService? transport,
    FirebaseFirestore? firestore,
    String? Function()? currentUid,
    String Function()? newOperationId,
  }) : transport = transport ?? FirebaseImageUploadService(),
       _firestore = firestore,
       _operationId = newOperationId,
       _uid = currentUid ?? (() => FirebaseAuth.instance.currentUser?.uid);
  final FirebaseImageUploadService transport;
  final FirebaseFirestore? _firestore;
  final String? Function() _uid;
  final String Function()? _operationId;
  FirebaseFirestore get firestore => _firestore ?? FirebaseFirestore.instance;
  final _attempts = <String, _Attempt>{};
  final _operations = <String, (String, int)>{};
  String? _draft;
  String? _draftUid, _profileCommunity;
  String? get draftId => _draft;
  Future<String> createDraft(String feature) async {
    final uid = _uid();
    if (_draft != null && _draftUid == uid && uid != null) {
      return _draft!;
    }
    if (uid == null) {
      throw StateError('Sign in to add an image.');
    }
    final response = await transport.call('createResidentImageDraft', {
      'feature': feature,
    });
    if (_uid() != uid || response['resourceId'] is! String) {
      throw StateError('The image session changed.');
    }
    _draftUid = uid;
    return _draft = response['resourceId'] as String;
  }

  Future<String> upload({
    required String feature,
    required String resourceId,
    required String imagePath,
  }) async {
    final uid = _uid();
    if (uid == null) {
      throw StateError('Sign in to add an image.');
    }
    final file = File(imagePath);
    final stat = await file.stat();
    if (stat.size < 1 || stat.size > StorageImageAsset.maxBytes) {
      throw ArgumentError('Choose an image no larger than 10 MB.');
    }
    final key =
        '$uid/$feature/$resourceId/$imagePath/${stat.size}/${stat.modified.millisecondsSinceEpoch}';
    final attempt = _attempts.putIfAbsent(key, _Attempt.new);
    if (_attempts.length > 10) {
      _attempts.remove(_attempts.keys.first);
    }
    try {
      if (attempt.ready == null) {
        if (attempt.stored && attempt.reservation != null) {
          attempt.ready = await transport.complete(attempt.reservation!);
        } else {
          final builder = BytesBuilder(copy: false);
          await for (final chunk in file.openRead(
            0,
            StorageImageAsset.maxBytes + 1,
          )) {
            builder.add(chunk);
          }
          final bytes = builder.takeBytes();
          if (bytes.isEmpty || bytes.length > StorageImageAsset.maxBytes) {
            throw ArgumentError('Choose an image no larger than 10 MB.');
          }
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
          } else if (bytes.length >= 6 &&
              [
                'GIF87a',
                'GIF89a',
              ].contains(String.fromCharCodes(bytes.take(6))) &&
              {'profile', 'community_wall'}.contains(feature)) {
            mime = 'image/gif';
          } else {
            throw ArgumentError(
              'Choose a supported JPEG, PNG, WebP or GIF image.',
            );
          }
          attempt.ready = await transport.upload(
            feature: feature,
            resourceId: resourceId,
            contentType: mime,
            bytes: bytes,
            onReserved: (asset) => attempt.reservation = asset,
            onStored: () => attempt.stored = true,
          );
        }
      }
    } on FirebaseFunctionsException catch (error) {
      if ({
        'not-found',
        'failed-precondition',
        'permission-denied',
      }.contains(error.code)) {
        _attempts.remove(key);
      }
      rethrow;
    }
    if (_uid() != uid) {
      throw StateError('The image session changed.');
    }
    return '$privateImagePrefix${attempt.ready!.assetId}';
  }

  Future<Map<String, dynamic>> save({
    required String feature,
    required String resourceId,
    required int revision,
    required List<String> references,
    Map<String, dynamic>? content,
    bool deleteResource = false,
  }) async {
    final uid = _uid();
    if (uid == null) {
      throw StateError('Sign in to save images.');
    }
    final key =
        '$uid/$feature/$resourceId/${references.join('|')}/${content.toString()}/$deleteResource';
    final operation = _operations.putIfAbsent(
      key,
      () => (
        _operationId?.call() ??
            firestore.collection('residentImageCommits').doc().id,
        revision,
      ),
    );
    if (_operations.length > 20) {
      _operations.remove(_operations.keys.first);
    }
    final result = await transport.call('commitResidentImages', {
      'feature': feature,
      'resourceId': resourceId,
      'expectedRevision': operation.$2,
      'operationId': operation.$1,
      'references': references,
      if (content != null) 'content': content,
      if (deleteResource) 'deleteResource': true,
    });
    final confirmed = result['references'];
    final expected = deleteResource ? <String>[] : references;
    if (confirmed is! List ||
        confirmed.length != expected.length ||
        List.generate(
          expected.length,
          (index) => index,
        ).any((index) => confirmed[index] != expected[index]) ||
        result['imageRevision'] != operation.$2 + 1) {
      throw const FormatException(
        'The image attachment was not confirmed. Retry to check it.',
      );
    }
    if (_uid() != uid || result['resourceId'] != resourceId) {
      throw StateError(
        'The image save could not be confirmed. Retry to check it.',
      );
    }
    _operations.remove(key);
    // A confirmed attachment may later be replaced or removed. Selecting the
    // same local file again must reserve a new asset rather than reuse it.
    _attempts.removeWhere(
      (_, attempt) =>
          attempt.ready != null &&
          references.contains('$privateImagePrefix${attempt.ready!.assetId}'),
    );
    return result;
  }

  Future<Map<String, dynamic>> record(String feature, String id) async {
    const collections = {
      'profile': 'users',
      'community_wall': 'posts',
      'complaints': 'complaints',
      'marketplace': 'marketplaces',
    };
    final record =
        (await firestore.collection(collections[feature]!).doc(id).get())
            .data() ??
        {};
    if (feature == 'profile') {
      final community = record['communityId'] as String?;
      if (_profileCommunity != null && _profileCommunity != community) {
        _attempts.clear();
        _operations.clear();
      }
      _profileCommunity = community;
    }
    return record;
  }
}
