import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resident_app/src/services/profile_image_service.dart';
import 'package:resident_app/src/services/resident_image_operations.dart';
import 'package:resident_app/src/services/user_data_service.dart';

class _User extends Fake implements User {
  bool syncFails = false;
  @override
  String get uid => 'resident';
  @override
  Future<void> updateDisplayName(String? name) async {
    if (syncFails) throw FirebaseAuthException(code: 'network-request-failed');
  }
}

class _Auth extends Fake implements FirebaseAuth {
  _Auth(this.currentUser);
  @override
  User? currentUser;
}

class _Writes {
  Map<String, dynamic>? fields;
  bool deny = false;
  Future<void> write(String uid, Map<String, dynamic> data) async {
    expect(uid, 'resident');
    if (deny)
      throw FirebaseException(
        plugin: 'cloud_firestore',
        code: 'permission-denied',
      );
    fields = data;
  }
}

class _Images extends Fake implements ResidentImageOperations {
  final stages = <String>[];
  bool fail = false;
  @override
  Future<Map<String, dynamic>> record(String feature, String id) async {
    expect(feature, 'profile');
    expect(id, 'resident');
    stages.add('record');
    return {'imageRevision': 2};
  }

  @override
  Future<String> upload({
    required String feature,
    required String resourceId,
    required String imagePath,
  }) async {
    stages.add('upload');
    if (fail)
      throw FirebaseException(
        plugin: 'firebase_storage',
        code: 'unauthorized',
        message: 'private-token-and-phone-must-not-be-logged',
      );
    return 'hominode-image:synthetic-reference';
  }

  @override
  Future<Map<String, dynamic>> save({
    required String feature,
    required String resourceId,
    required int revision,
    required List<String> references,
    Map<String, dynamic>? content,
    bool deleteResource = false,
  }) async {
    expect(revision, 2);
    expect(resourceId, 'resident');
    expect(references, ['hominode-image:synthetic-reference']);
    stages.add('attach');
    return {};
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'invalid App Check fails closed before profile lookup, staging or metadata',
    () async {
      final images = _Images();
      final service = ProfileImageService.forTesting(
        operations: images,
        currentUid: () => 'resident',
        verifyDevice: () async {
          throw FirebaseException(
            plugin: 'firebase_app_check',
            code: 'invalid-argument',
          );
        },
      );
      final result = await service.uploadProfileImage(
        imagePath: 'synthetic.jpg',
      );
      expect(result.success, false);
      expect(result.errorCode, 'APP_CHECK_UNAVAILABLE');
      expect(images.stages, isEmpty);
    },
  );
  test(
    'verified device uploads then attaches the owned profile revision; retry succeeds',
    () async {
      final images = _Images()..fail = true;
      final logs = <String>[];
      final prior = debugPrint;
      debugPrint = (String? message, {int? wrapWidth}) {
        if (message != null) logs.add(message);
      };
      addTearDown(() => debugPrint = prior);
      final service = ProfileImageService.forTesting(
        operations: images,
        currentUid: () => 'resident',
        verifyDevice: () async {},
      );
      expect(
        (await service.uploadProfileImage(imagePath: 'synthetic.jpg')).success,
        false,
      );
      expect(images.stages, ['record', 'upload']);
      expect(logs.join(), contains('stage=image-upload code=unauthorized'));
      expect(logs.join(), isNot(contains('private-token')));
      images.fail = false;
      final result = await service.uploadProfileImage(
        imagePath: 'synthetic.jpg',
      );
      expect(result.success, true);
      expect(result.imageUrl, 'hominode-image:synthetic-reference');
      expect(images.stages.last, 'attach');
    },
  );
  test(
    'ordinary save updates display fields and timestamp, preserving identity',
    () async {
      final db = _Writes();
      final service = UserDataService.forTesting(
        writeUser: db.write,
        auth: _Auth(_User()),
      );
      final input = {
        'name': 'Synthetic Resident',
        'email': 'test@example.invalid',
      };
      expect(await service.updateUserData(input), true);
      expect(db.fields!.keys, unorderedEquals(['name', 'email', 'updatedAt']));
      expect(input.keys, unorderedEquals(['name', 'email']));
      expect(db.fields, isNot(contains('phoneNumber')));
      expect(db.fields, isNot(contains('phone')));
    },
  );
  test(
    'optional Auth sync failure does not misreport a committed Firestore save',
    () async {
      final db = _Writes();
      final user = _User()..syncFails = true;
      expect(
        await UserDataService.forTesting(
          writeUser: db.write,
          auth: _Auth(user),
        ).updateUserData({'name': 'Synthetic'}),
        true,
      );
      expect(db.fields!['name'], 'Synthetic');
    },
  );
  test(
    'Firestore rejection and expired authentication cannot report success',
    () async {
      final db = _Writes();
      db.deny = true;
      expect(
        await UserDataService.forTesting(
          writeUser: db.write,
          auth: _Auth(_User()),
        ).updateUserData({'name': 'Synthetic'}),
        false,
      );
      expect(
        await UserDataService.forTesting(
          writeUser: db.write,
          auth: _Auth(null),
        ).updateUserData({'name': 'Synthetic'}),
        false,
      );
      expect(db.fields, isNull);
    },
  );
}
