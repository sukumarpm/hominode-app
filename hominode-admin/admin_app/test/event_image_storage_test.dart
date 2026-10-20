import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:admin_app/services/admin_service.dart';
import 'package:admin_app/services/event_announcement_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_test/flutter_test.dart';

class _Admin extends Fake implements AdminService {
  String? uid = 'admin';
  String community = 'A';
  Map<String, dynamic> profile = {
    'uid': 'admin',
    'role': 'admin',
    'isActive': true,
    'authorizedCommunityIds': ['A'],
  };
  @override
  String? getCurrentAdminId() => uid;
  @override
  String requireCurrentCommunityId() => community;
  @override
  Future<Map<String, dynamic>?> getAdminProfile() async => profile;
}

class _Snapshot extends Fake implements TaskSnapshot {}

class _Task extends Fake implements UploadTask {
  _Task(this.storage);
  @override
  final _Storage storage;
  @override
  Future<R> then<R>(
    FutureOr<R> Function(TaskSnapshot) onValue, {
    Function? onError,
  }) =>
      (storage.wait?.future ??
              (storage.failUpload
                  ? Future<TaskSnapshot>.error(
                      FirebaseException(
                        plugin: 'storage',
                        code: 'permission-denied',
                      ),
                    )
                  : Future.value(_Snapshot())))
          .then(onValue, onError: onError);
  @override
  Future<bool> cancel() async {
    storage.cancelled++;
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
    storage.uploads.add(path);
    storage.metadata = metadata;
    storage.onUpload?.call();
    return _Task(storage);
  }

  @override
  Future<String> getDownloadURL() async {
    storage.urls++;
    if (storage.failUrl) {
      throw FirebaseException(plugin: 'storage', code: 'unknown');
    }
    return 'https://firebasestorage.googleapis.com/v0/b/demo-images/o/${Uri.encodeComponent(path)}?alt=media&token=synthetic';
  }

  @override
  Future<void> delete() async {
    if (storage.failDelete) {
      throw FirebaseException(plugin: 'storage', code: 'unauthorized');
    }
    storage.deletes.add(path);
  }
}

class _Storage extends Fake implements FirebaseStorage {
  final uploads = <String>[], deletes = <String>[];
  bool failUpload = false, failUrl = false, failDelete = false;
  int urls = 0, cancelled = 0;
  SettableMetadata? metadata;
  Completer<TaskSnapshot>? wait;
  void Function()? onUpload;
  @override
  Reference ref([String? path]) => _Reference(this, path!);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeFirebaseFirestore db;
  late _Storage storage;
  late _Admin admin;
  late EventAnnouncementService service;
  late Directory dir;
  late File photo;
  setUp(() async {
    db = FakeFirebaseFirestore(
      securityRules: '''service cloud.firestore {
      match /databases/{database}/documents/{document=**} {
        allow read: if true;
        allow write: if request.auth.uid == 'allowed';
      }
    }''',
    );
    db.authObject.add({'uid': 'allowed'});
    storage = _Storage();
    admin = _Admin();
    service = EventAnnouncementService(
      firestore: db,
      adminService: admin,
      storage: storage,
    );
    dir = await Directory.systemTemp.createTemp('admin-event-image-');
    photo = await File(
      '${dir.path}/photo.jpg',
    ).writeAsBytes([255, 216, 255, 217]);
  });
  tearDown(() async {
    await dir.delete(recursive: true);
  });
  Future<String> create({File? file, String id = 'event'}) =>
      service.createEvent(
        title: 'Gathering',
        category: 'Community',
        description: 'Join us',
        date: DateTime(2026, 11, 1),
        time: '18:00',
        location: 'Hall',
        eventId: id,
        imageFile: file,
      );
  Future<Map<String, dynamic>?> record() async =>
      (await db.doc('events_announcements/event').get()).data();

  test(
    'uploads to the existing event contract before publishing cross-device metadata',
    () async {
      expect(await create(file: photo), 'event');
      final data = (await record())!;
      expect(
        storage.uploads.single,
        matches(r'^event_images/A/event/[A-Za-z0-9]+\.jpg$'),
      );
      expect(storage.metadata!.contentType, 'image/jpeg');
      expect(data.containsKey('localImagePath'), isFalse);
      expect(data['images'], [
        {
          'url': data['imageUrl'],
          'storagePath': storage.uploads.single,
          'name': 'photo.jpg',
        },
      ]);
      expect(data['imageUrls'], [data['imageUrl']]);
      expect(Uri.parse(data['imageUrl']).scheme, 'https');
      expect(data['communityId'], 'A');
      expect(data['date'], Timestamp.fromDate(DateTime(2026, 11, 1)));
      expect(data['totalCapacity'], 248);
      expect(
        EventModel.fromFirestore('event', data).imageUrl,
        data['imageUrl'],
      );
    },
  );
  test(
    'upload denial leaves no event or local image reference; same ID can retry',
    () async {
      storage.failUpload = true;
      await expectLater(create(file: photo), throwsA(isA<FirebaseException>()));
      expect(await record(), isNull);
      storage.failUpload = false;
      await create(file: photo);
      expect(storage.uploads.toSet(), hasLength(1));
      expect(
        (await db.collection('events_announcements').get()).docs,
        hasLength(1),
      );
    },
  );
  test(
    'URL failure retries the stored object without uploading again',
    () async {
      storage.failUrl = true;
      await expectLater(create(file: photo), throwsA(isA<FirebaseException>()));
      expect(await record(), isNull);
      storage.failUrl = false;
      await create(file: photo);
      expect(storage.uploads, hasLength(1));
      expect(storage.urls, 2);
    },
  );
  test(
    'metadata denial retains upload for retry without creating a duplicate',
    () async {
      db.authObject.add({'uid': 'denied'});
      await expectLater(
        create(file: photo),
        throwsA(
          predicate(
            (error) =>
                error is Exception &&
                error.toString().contains('Method.write') &&
                error.toString().contains('not allowed'),
          ),
        ),
      );
      expect(await record(), isNull);
      db.authObject.add({'uid': 'allowed'});
      await create(file: photo);
      expect(storage.uploads, hasLength(1));
      expect(
        (await db.collection('events_announcements').get()).docs,
        hasLength(1),
      );
    },
  );
  test(
    'retry after successful save preserves RSVP and does not upload or overwrite',
    () async {
      await create(file: photo);
      await db.doc('events_announcements/event').update({'rsvpCount': 9});
      await create(file: photo);
      expect(storage.uploads, hasLength(1));
      expect((await record())!['rsvpCount'], 9);
    },
  );
  test('cancel removes only an unpublished uploaded object', () async {
    storage.failUrl = true;
    await expectLater(create(file: photo), throwsA(isA<FirebaseException>()));
    await service.discardEventAttempt('event');
    expect(storage.deletes, storage.uploads);
    expect(await record(), isNull);
  });
  test(
    'cancel does not remove an image after a successful publication',
    () async {
      await create(file: photo);
      await service.discardEventAttempt('event');
      expect(storage.deletes, isEmpty);
      expect(await record(), isNotNull);
    },
  );
  test(
    'session/community change during upload cannot publish image metadata',
    () async {
      storage.onUpload = () => admin.community = 'B';
      await expectLater(create(file: photo), throwsStateError);
      expect(await record(), isNull);
      expect(storage.urls, 0);
      expect(storage.deletes, isEmpty);
    },
  );
  for (final boundary in [
    'signed out',
    'foreign community',
    'inactive',
    'resident role',
  ]) {
    test('$boundary cannot start an Admin event image upload', () async {
      if (boundary == 'signed out') admin.uid = null;
      if (boundary == 'foreign community') admin.community = 'B';
      if (boundary == 'inactive') admin.profile['isActive'] = false;
      if (boundary == 'resident role') admin.profile['role'] = 'resident';
      await expectLater(create(file: photo), throwsStateError);
      expect(storage.uploads, isEmpty);
      expect(await record(), isNull);
    });
  }
  test(
    'invalid bytes and oversize files are rejected before uploading or publishing',
    () async {
      final invalid = await File(
        '${dir.path}/invalid.jpg',
      ).writeAsString('not an image');
      await expectLater(create(file: invalid), throwsArgumentError);
      final oversized = await File(
        '${dir.path}/large.jpg',
      ).writeAsBytes(Uint8List(5 * 1024 * 1024 + 1));
      await expectLater(create(file: oversized), throwsArgumentError);
      expect(storage.uploads, isEmpty);
      expect(await record(), isNull);
    },
  );
  test('timeout cancels upload and leaves no event to display', () async {
    service = EventAnnouncementService(
      firestore: db,
      adminService: admin,
      storage: storage,
      uploadTimeout: const Duration(milliseconds: 20),
    );
    storage.wait = Completer<TaskSnapshot>();
    await expectLater(create(file: photo), throwsA(isA<TimeoutException>()));
    expect(storage.cancelled, 1);
    expect(await record(), isNull);
    storage.wait!.complete(_Snapshot());
  });
  test(
    'text-only creation preserves existing event fields without image or local paths',
    () async {
      await create();
      expect(storage.uploads, isEmpty);
      final data = (await record())!;
      expect(data['type'], 'event');
      expect(data['imageUrl'], isNull);
      expect(data.containsKey('localImagePath'), isFalse);
    },
  );
  test(
    'legacy local paths are ignored while ordered network fields remain compatible',
    () {
      final data = {
        'localImagePath': '/device-only/photo.jpg',
        'imageUrl': 'https://example.invalid/one.jpg',
        'imageUrls': [
          'https://example.invalid/one.jpg',
          'https://example.invalid/two.jpg',
        ],
        'images': [
          {'url': 'https://example.invalid/two.jpg'},
          {'url': 'https://example.invalid/three.jpg'},
        ],
      };
      final model = EventModel.fromFirestore('event', data);
      expect(model.imageUrls, [
        'https://example.invalid/one.jpg',
        'https://example.invalid/two.jpg',
        'https://example.invalid/three.jpg',
      ]);
      expect(model.localImagePath, isNull);
      expect(model.toMap().containsKey('localImagePath'), isFalse);
      expect(
        EventModel.fromFirestore('event', {
          'localImagePath': '/device.jpg',
        }).hasImage,
        isFalse,
      );
    },
  );
  test(
    'metadata-only edit retains image order and removes historical local path',
    () async {
      await create(file: photo);
      await db.doc('events_announcements/event').update({
        'localImagePath': '/old/file.jpg',
        'imageUrls': [
          'https://example.invalid/one.jpg',
          'https://example.invalid/two.jpg',
        ],
      });
      await service.updateEvent(eventId: 'event', title: 'Changed');
      final data = (await record())!;
      expect(data['imageUrls'], [
        'https://example.invalid/one.jpg',
        'https://example.invalid/two.jpg',
      ]);
      expect(data.containsKey('localImagePath'), isFalse);
    },
  );
  test(
    'event deletion detaches metadata before deleting only scoped Firebase objects',
    () async {
      await create(file: photo);
      final storedPath = storage.uploads.single;
      await db.doc('events_announcements/event').update({
        'images': [
          {'storagePath': storedPath},
          {'storagePath': 'event_images/B/event/foreign.jpg'},
          {'storagePath': 'event_images/A/other/foreign.jpg'},
          {'url': 'https://res.cloudinary.com/example/legacy.jpg'},
        ],
      });
      await service.deleteEvent('event');
      expect(await record(), isNull);
      expect(storage.deletes, [storedPath]);
    },
  );
  test('metadata deletion denial preserves referenced event bytes', () async {
    await create(file: photo);
    db.authObject.add({'uid': 'denied'});
    await expectLater(service.deleteEvent('event'), throwsException);
    expect(await record(), isNotNull);
    expect(storage.deletes, isEmpty);
  });
  test(
    'failed byte deletion can retry without recreating event metadata',
    () async {
      await create(file: photo);
      storage.failDelete = true;
      await expectLater(
        service.deleteEvent('event'),
        throwsA(isA<FirebaseException>()),
      );
      expect(await record(), isNull);
      storage.failDelete = false;
      await service.deleteEvent('event');
      expect(storage.deletes, storage.uploads);
      expect(await record(), isNull);
    },
  );
  test('a different community cannot delete an event or its bytes', () async {
    await create(file: photo);
    admin.community = 'B';
    await expectLater(service.deleteEvent('event'), throwsStateError);
    expect(await record(), isNotNull);
    expect(storage.deletes, isEmpty);
  });
  test(
    'explicit primary-image edits preserve the order of the remaining gallery',
    () async {
      await create();
      await db.doc('events_announcements/event').update({
        'imageUrls': [
          'https://example.invalid/one.jpg',
          'https://example.invalid/two.jpg',
        ],
        'images': [
          {
            'url': 'https://example.invalid/one.jpg',
            'storagePath': 'event_images/A/event/one.jpg',
          },
          {
            'url': 'https://example.invalid/two.jpg',
            'storagePath': 'event_images/A/event/two.jpg',
          },
        ],
      });
      await service.updateEvent(
        eventId: 'event',
        imageUrl: 'https://example.invalid/two.jpg',
      );
      final data = (await record())!;
      expect(data['imageUrls'], [
        'https://example.invalid/two.jpg',
        'https://example.invalid/one.jpg',
      ]);
      expect(data['imageUrl'], 'https://example.invalid/two.jpg');
      expect((data['images'] as List).map((image) => image['storagePath']), [
        'event_images/A/event/two.jpg',
        'event_images/A/event/one.jpg',
      ]);
    },
  );
  test('local-file URLs cannot be supplied as stored event images', () async {
    await expectLater(
      service.createEvent(
        title: 'Event',
        category: '',
        description: '',
        date: DateTime(2026),
        time: '',
        location: '',
        imageUrl: 'file:///device.jpg',
      ),
      throwsArgumentError,
    );
    await expectLater(
      service.updateEvent(eventId: 'event', imageUrl: '/device.jpg'),
      throwsException,
    );
    expect(storage.uploads, isEmpty);
  });
}
