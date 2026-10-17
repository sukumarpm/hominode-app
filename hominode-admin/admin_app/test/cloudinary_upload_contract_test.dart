import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:admin_app/config/cloudinary_config.dart';
import 'package:admin_app/services/admin_service.dart';
import 'package:admin_app/services/cloudinary_apartment_images_service.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

class _Admin extends Fake implements AdminService {
  String? uid = 'admin-test';
  @override
  String? getCurrentAdminId() => uid;
  @override
  String requireCurrentCommunityId() => 'community-test';
  @override
  Future<Map<String, dynamic>?> getAdminProfile() async => {
    'name': 'Test Admin',
  };
}

class _UploadClient extends http.BaseClient {
  _UploadClient(this.handle);
  final Future<http.StreamedResponse> Function(http.BaseRequest) handle;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      handle(request);
}

http.StreamedResponse _response(String body, [int status = 200]) =>
    http.StreamedResponse(Stream.value(utf8.encode(body)), status);

void main() {
  late Directory directory;
  late File image;
  late FakeFirebaseFirestore firestore;
  late _Admin admin;
  late CloudinaryApartmentImagesService service;
  const url =
      'https://res.cloudinary.com/test-cloud/image/upload/apartment.jpg';
  final imageBytes = [0xff, 0xd8, 0xff, 0xd9];

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('admin-upload-contract-');
    image = await File('${directory.path}/image.jpg').writeAsBytes(imageBytes);
    firestore = FakeFirebaseFirestore();
    admin = _Admin();
    service = CloudinaryApartmentImagesService(
      firestore: firestore,
      adminService: admin,
    );
  });
  tearDown(() async => directory.delete(recursive: true));

  Future<String> upload() => service.uploadImage(
    title: 'Courtyard',
    description: 'Shared space',
    type: 'Common Area',
    imageFile: image,
    buildingId: 'building-test',
    uploadDate: '17-10-2026',
    uploadTime: '12:30',
  );

  Future<void> expectNoMetadata() async => expect(
    (await firestore.collection('apartmentImages').get()).docs,
    isEmpty,
  );

  test(
    'unsigned apartment upload preserves request, URL and scoped metadata',
    () async {
      var requests = 0;
      final client = _UploadClient((request) async {
        requests++;
        expect(request.method, 'POST');
        expect(
          request.url.toString(),
          CloudinaryApartmentImagesService.CLOUDINARY_API_URL,
        );
        expect(request.url.scheme, 'https');
        expect(request.url.toString(), CloudinaryConfig.uploadUrl);
        final multipart = request as http.MultipartRequest;
        expect(multipart.fields.keys.toSet(), {
          'upload_preset',
          'folder',
          'tags',
          'public_id',
        });
        expect(
          multipart.fields['upload_preset'],
          CloudinaryConfig.uploadPreset,
        );
        expect(multipart.fields['folder'], 'apartment_images');
        expect(multipart.fields['tags'], 'apartment,admin,admin-test');
        expect(multipart.fields['public_id'], matches(r'^apartment_\d+$'));
        expect(multipart.fields, isNot(contains('api_key')));
        expect(multipart.fields, isNot(contains('api_secret')));
        expect(multipart.fields, isNot(contains('signature')));
        expect(multipart.files.single.field, 'file');
        expect(await multipart.files.single.finalize().toBytes(), imageBytes);
        return _response(jsonEncode({'secure_url': url}));
      });
      final id = await http.runWithClient(upload, () => client);
      final saved =
          (await firestore.collection('apartmentImages').doc(id).get()).data()!;
      expect(requests, 1);
      expect(saved, containsPair('imageUrl', url));
      expect(saved, containsPair('communityId', 'community-test'));
      expect(saved, containsPair('buildingId', 'building-test'));
      expect(saved, containsPair('adminId', 'admin-test'));
      expect(saved, containsPair('adminName', 'Test Admin'));
      expect(saved, containsPair('title', 'Courtyard'));
      expect(saved, containsPair('description', 'Shared space'));
      expect(saved, containsPair('type', 'Common Area'));
      expect(saved, containsPair('uploadDate', '17-10-2026'));
      expect(saved, containsPair('uploadTime', '12:30'));
      expect(saved['createdAt'], isNotNull);
      expect(saved['updatedAt'], isNotNull);
    },
  );

  for (final failure in [
    'invalid JSON',
    'missing URL',
    'denied',
    'provider error',
    'network',
  ]) {
    test('$failure does not save apartment metadata', () async {
      final client = _UploadClient((_) async {
        switch (failure) {
          case 'invalid JSON':
            return _response('not JSON');
          case 'missing URL':
            return _response('{}');
          case 'denied':
            return _response('{"error":{"message":"denied"}}', 401);
          case 'provider error':
            return _response('{"error":{"message":"invalid image"}}', 400);
          default:
            throw http.ClientException('offline');
        }
      });
      await http.runWithClient(
        () => expectLater(
          upload(),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains(
                {
                  'invalid JSON': 'FormatException',
                  'missing URL': 'Failed to get image URL',
                  'denied': 'Upload preset not configured',
                  'provider error': 'invalid image',
                  'network': 'offline',
                }[failure]!,
              ),
            ),
          ),
        ),
        () => client,
      );
      await expectNoMetadata();
    });
  }

  test('60-second timeout fails without saving apartment metadata', () async {
    var deadlines = 0;
    final client = _UploadClient(
      (_) => Completer<http.StreamedResponse>().future,
    );
    await runZoned(
      () => http.runWithClient(
        () => expectLater(
          upload(),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('Upload timeout'),
            ),
          ),
        ),
        () => client,
      ),
      zoneSpecification: ZoneSpecification(
        createTimer: (self, parent, zone, duration, callback) {
          if (duration == const Duration(seconds: 60)) {
            deadlines++;
            return parent.createTimer(zone, Duration.zero, callback);
          }
          return parent.createTimer(zone, duration, callback);
        },
      ),
    );
    expect(deadlines, 1);
    await expectNoMetadata();
  });

  for (final failure in ['unauthenticated', 'empty', 'oversized', 'missing']) {
    test('$failure fails before making an HTTP request', () async {
      switch (failure) {
        case 'unauthenticated':
          admin.uid = null;
        case 'empty':
          image.writeAsBytesSync([]);
        case 'oversized':
          final file = image.openSync(mode: FileMode.write);
          file.truncateSync(10 * 1024 * 1024 + 1);
          file.closeSync();
        case 'missing':
          image.deleteSync();
      }
      var requests = 0;
      await http.runWithClient(
        () => expectLater(upload(), throwsA(isA<Exception>())),
        () => _UploadClient((_) async {
          requests++;
          return _response('{}');
        }),
      );
      expect(requests, 0);
      await expectNoMetadata();
    });
  }
}
