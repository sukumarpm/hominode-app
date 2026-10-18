import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:admin_app/services/firebase_image_upload_service.dart';

class _Snapshot extends Fake implements TaskSnapshot {}

class _Task extends Fake implements UploadTask {
  _Task(this.result, this.onCancel);
  final Future<TaskSnapshot> result;
  final void Function() onCancel;
  @override
  Future<R> then<R>(
    FutureOr<R> Function(TaskSnapshot) onValue, {
    Function? onError,
  }) => result.then(onValue, onError: onError);
  @override
  Future<bool> cancel() async {
    onCancel();
    return true;
  }
}

class _Reference extends Fake implements Reference {
  _Reference(this.storage, this.path);
  @override
  final _Storage storage;
  final String path;
  @override
  UploadTask putData(Uint8List bytes, [SettableMetadata? metadata]) {
    storage.events.add('write');
    storage.paths.add(path);
    storage.bytes = bytes;
    storage.metadata = metadata;
    storage.onWrite?.call();
    return _Task(storage.result ?? Future.value(_Snapshot()), () {
      storage.cancelled++;
    });
  }

  @override
  Future<String> getDownloadURL() async =>
      throw StateError('Public URLs are forbidden.');
  @override
  Future<void> delete() async =>
      throw StateError('Client deletion is forbidden.');
}

class _Storage extends Fake implements FirebaseStorage {
  @override
  String bucket = 'demo-images.appspot.com';
  final events = <String>[];
  final paths = <String>[];
  Uint8List? bytes;
  SettableMetadata? metadata;
  Future<TaskSnapshot>? result;
  void Function()? onWrite;
  int cancelled = 0;
  @override
  Reference ref([String? path]) => _Reference(this, path!);
}

void main() {
  const id = 'a1111111-1111-4111-8111-111111111111';
  const allowed = {'apartment'};
  const owner = 'a';
  final bytes = Uint8List.fromList([255, 216, 255, 217]);
  late _Storage storage;
  String? uid;
  String? failureStage;
  String? hangingStage;
  Map<String, dynamic> Function(Map<String, dynamic>)? changeTicket;
  Map<String, dynamic> Function(Map<String, dynamic>)? changeReady;
  void Function()? afterPrepare;
  late FirebaseImageUploadService service;
  late Map<String, dynamic> pending;

  setUp(() {
    storage = _Storage();
    uid = owner;
    failureStage = null;
    hangingStage = null;
    changeTicket = null;
    changeReady = null;
    afterPrepare = null;
    pending = {};
    service = FirebaseImageUploadService(
      storage: storage,
      currentUid: () => uid,
      timeout: const Duration(milliseconds: 40),
      call: (name, data) async {
        storage.events.add(name);
        if (failureStage == name) throw StateError('Verification denied.');
        if (hangingStage == name) {
          return Completer<Map<String, dynamic>>().future;
        }
        if (name == 'prepareStorageImageUpload') {
          expect(data.keys.toSet(), {
            'feature',
            'resourceId',
            'contentType',
            'size',
          });
          final feature = data['feature'];
          final path = feature == 'apartment'
              ? 'apartment_images/A/$owner/$id.jpg'
              : 'resident_images/A/$owner/$feature/$id.jpg';
          pending = {
            'assetId': id,
            'provider': 'firebase',
            'bucket': storage.bucket,
            'communityId': 'A',
            'ownerId': owner,
            'feature': feature,
            'resourceId': data['resourceId'],
            'contentType': 'image/jpeg',
            'size': 4,
            'storagePath': path,
            'state': 'pending',
            'expiresAtMs': 1900000000000,
          };
          afterPrepare?.call();
          return changeTicket?.call(pending) ?? pending;
        }
        if (name == 'readStorageImage') {
          if (uid == 'other') throw StateError('Permission denied.');
          return {
            'assetId': id,
            'contentType': 'image/jpeg',
            'size': bytes.length,
            'generation': '7',
            if (data.containsKey('knownGeneration'))
              'notModified': true
            else
              'base64': base64Encode(bytes),
          };
        }
        expect(name, 'completeStorageImageUpload');
        expect(data, {'assetId': id});
        final ready = {
          ...pending,
          'state': 'ready',
          'storagePath':
              'private_images/A/$owner/${pending['feature']}/$id.jpg',
          'generation': '7',
          'sha256': List.filled(64, 'a').join(),
        };
        return changeReady?.call(ready) ?? ready;
      },
    );
  });
  Future<dynamic> upload([String? feature, String? type]) => service.upload(
    feature: feature ?? allowed.first,
    resourceId: (feature ?? allowed.first) == 'profile' ? owner : 'target',
    contentType: type ?? 'image/jpeg',
    bytes: bytes,
  );

  for (final feature in allowed) {
    test(
      '$feature uses mocked Firebase Storage and returns a private verified reference',
      () async {
        final asset = await upload(feature);
        expect(asset.state, 'ready');
        expect(asset.generation, '7');
        expect(asset.storageUri, startsWith('gs://demo-images.appspot.com/'));
        expect(asset.toMap(), isNot(contains('imageUrl')));
        expect(storage.events, [
          'prepareStorageImageUpload',
          'write',
          'completeStorageImageUpload',
        ]);
        expect(storage.paths, [pending['storagePath']]);
        expect(asset.storagePath, startsWith('private_images/'));
        expect(storage.bytes, bytes);
        expect(storage.metadata!.contentType, 'image/jpeg');
        expect(storage.metadata!.cacheControl, 'private, no-store');
        expect(storage.metadata!.customMetadata, {
          'assetId': id,
          'ownerId': owner,
          'communityId': 'A',
          'feature': feature,
          'resourceId': feature == 'profile' ? owner : 'target',
        });
      },
    );
  }
  test('no identity cannot prepare or upload a file', () async {
    uid = null;
    await expectLater(upload(), throwsStateError);
    expect(storage.events, isEmpty);
  });
  test('empty, oversized and unsupported files cannot call Firebase', () async {
    for (final invalid in [Uint8List(0), Uint8List(10 * 1024 * 1024 + 1)]) {
      await expectLater(
        service.upload(
          feature: allowed.first,
          resourceId: 'target',
          contentType: 'image/jpeg',
          bytes: invalid,
        ),
        throwsArgumentError,
      );
    }
    await expectLater(upload(null, 'image/svg+xml'), throwsArgumentError);
    expect(storage.events, isEmpty);
  });
  test('this app cannot request the other role upload contract', () {
    expect(
      () => service.upload(
        feature: allowed.contains('apartment') ? 'profile' : 'apartment',
        resourceId: owner,
        contentType: 'image/jpeg',
        bytes: bytes,
      ),
      throwsArgumentError,
    );
    expect(storage.events, isEmpty);
  });
  for (final field in [
    'ownerId',
    'storagePath',
    'bucket',
    'resourceId',
    'imageUrl',
  ]) {
    test(
      'a mismatched server $field cannot upload or return a public fallback',
      () async {
        changeTicket = (ticket) => {
          ...ticket,
          field: field == 'imageUrl'
              ? 'https://example.invalid/public.jpg'
              : 'forged',
        };
        await expectLater(
          upload(),
          throwsA(anyOf(isA<StateError>(), isA<FormatException>())),
        );
        expect(storage.paths, isEmpty);
      },
    );
  }
  for (final stage in [
    'prepareStorageImageUpload',
    'completeStorageImageUpload',
  ]) {
    test('$stage errors propagate without external fallback', () async {
      failureStage = stage;
      await expectLater(upload(), throwsStateError);
      expect(storage.paths.length, stage.startsWith('prepare') ? 0 : 1);
    });
    test('$stage times out without returning an unverified asset', () async {
      hangingStage = stage;
      await expectLater(upload(), throwsA(isA<TimeoutException>()));
    });
  }
  test('Storage failure does not finalize', () async {
    storage.result = Future<TaskSnapshot>.delayed(
      Duration.zero,
      () => throw StateError('Upload failed.'),
    );
    await expectLater(upload(), throwsStateError);
    expect(storage.events, ['prepareStorageImageUpload', 'write']);
  });
  test('Storage timeout cancels the task and does not finalize', () async {
    storage.result = Completer<TaskSnapshot>().future;
    await expectLater(upload(), throwsA(isA<TimeoutException>()));
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(storage.cancelled, 1);
    expect(storage.events, ['prepareStorageImageUpload', 'write']);
  });
  test('session change during reservation prevents Storage upload', () async {
    afterPrepare = () {
      uid = 'other';
    };
    await expectLater(upload(), throwsStateError);
    expect(storage.paths, isEmpty);
  });
  test('session change after upload prevents finalization', () async {
    storage.onWrite = () {
      uid = 'other';
    };
    await expectLater(upload(), throwsStateError);
    expect(storage.events, ['prepareStorageImageUpload', 'write']);
  });
  test('a malformed final response never becomes a successful asset', () async {
    changeReady = (ready) => {...ready, 'generation': null};
    await expectLater(upload(), throwsFormatException);
  });
  test(
    'private download uses an authenticated callable, not a bearer URL',
    () async {
      final asset = await upload();
      expect(await service.read(asset), bytes);
      await service.authorizeRead(asset);
      expect(storage.events.last, 'readStorageImage');
      uid = 'peer-admin';
      expect(await service.read(asset), bytes);
      uid = 'other';
      await expectLater(service.read(asset), throwsStateError);
    },
  );
}
