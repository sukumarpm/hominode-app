import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:resident_app/src/services/cloudinary_service.dart';

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
  const url =
      'https://res.cloudinary.com/test-cloud/image/upload/test-image.jpg';
  final imageBytes = [0xff, 0xd8, 0xff, 0xd9];

  setUp(() async {
    directory = await Directory.systemTemp.createTemp(
      'resident-upload-contract-',
    );
    image = await File('${directory.path}/image.jpg').writeAsBytes(imageBytes);
  });
  tearDown(() async => directory.delete(recursive: true));

  // These are the folder/public-ID contracts used by the current callers.
  for (final entry in <String?, String?>{
    null: null,
    'profile_pictures': 'user_resident-test',
    'community_wall': 'post_test',
    'complaints': null,
    'marketplace': 'marketplace_test_0',
  }.entries) {
    test(
      'unsigned upload preserves ${entry.key ?? 'default profile'} contract',
      () async {
        var requests = 0;
        final client = _UploadClient((request) async {
          requests++;
          expect(request.method, 'POST');
          expect(request.url.toString(), CloudinaryService.uploadUrl);
          expect(request.url.scheme, 'https');
          expect(
            request.url.path,
            '/v1_1/${CloudinaryService.cloudName}/image/upload',
          );
          final multipart = request as http.MultipartRequest;
          expect(multipart.fields, {
            'upload_preset': CloudinaryService.uploadPreset,
            'api_key': CloudinaryService.apiKey,
            'folder': entry.key ?? CloudinaryService.profilePicturesFolder,
            'resource_type': 'auto',
            if (entry.value != null) 'public_id': entry.value!,
          });
          expect(multipart.fields, isNot(contains('api_secret')));
          expect(multipart.fields, isNot(contains('signature')));
          expect(multipart.files.single.field, 'file');
          expect(multipart.files.single.filename, 'image.jpg');
          expect(await multipart.files.single.finalize().toBytes(), imageBytes);
          return _response(jsonEncode({'secure_url': url}));
        });
        final result = await http.runWithClient(
          () => CloudinaryService.uploadImage(
            imagePath: image.path,
            folder: entry.key,
            publicId: entry.value,
          ),
          () => client,
        );
        expect(result, url);
        expect(requests, 1);
      },
    );
  }

  for (final metadata in [false, true]) {
    Future<Object?> upload(String path) => metadata
        ? CloudinaryService.uploadImageWithMetadata(imagePath: path)
        : CloudinaryService.uploadImage(imagePath: path);

    test('missing file fails before HTTP (metadata: $metadata)', () async {
      var requests = 0;
      final client = _UploadClient((_) async {
        requests++;
        return _response('{}');
      });
      await http.runWithClient(
        () => expectLater(
          upload('${directory.path}/missing.jpg'),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('not found'),
            ),
          ),
        ),
        () => client,
      );
      expect(requests, 0);
    });

    for (final failure in ['invalid JSON', 'denied', 'network']) {
      test('$failure propagates without a URL (metadata: $metadata)', () async {
        final client = _UploadClient((_) async {
          if (failure == 'network') throw http.ClientException('offline');
          return failure == 'denied'
              ? _response('{"error":{"message":"denied"}}', 403)
              : _response('not JSON');
        });
        await http.runWithClient(
          () => expectLater(
            upload(image.path),
            throwsA(
              isA<Exception>().having(
                (e) => e.toString(),
                'message',
                contains(
                  failure == 'invalid JSON'
                      ? 'FormatException'
                      : failure == 'denied'
                      ? 'Upload failed: 403'
                      : 'offline',
                ),
              ),
            ),
          ),
          () => client,
        );
      });
    }

    test('60-second upload timeout is handled (metadata: $metadata)', () async {
      var deadlines = 0;
      final client = _UploadClient(
        (_) => Completer<http.StreamedResponse>().future,
      );
      await runZoned(
        () => http.runWithClient(
          () => expectLater(
            upload(image.path),
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
            // Exercise the real timeout callback without a 60-second wall-clock wait.
            if (duration == const Duration(seconds: 60)) {
              deadlines++;
              return parent.createTimer(zone, Duration.zero, callback);
            }
            return parent.createTimer(zone, duration, callback);
          },
        ),
      );
      expect(deadlines, 1);
    });
  }

  test('successful response without a URL is rejected', () async {
    await http.runWithClient(
      () => expectLater(
        CloudinaryService.uploadImage(imagePath: image.path),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('missing URL'),
          ),
        ),
      ),
      () => _UploadClient((_) async => _response('{}')),
    );
  });

  for (final useSecureUrl in [true, false]) {
    test(
      'metadata parsing preserves ${useSecureUrl ? 'secure_url' : 'url fallback'}',
      () async {
        final client = _UploadClient((request) async {
          expect((request as http.MultipartRequest).fields, {
            'upload_preset': CloudinaryService.uploadPreset,
            'api_key': CloudinaryService.apiKey,
            'folder': 'marketplace',
            'public_id': 'marketplace_test_0',
            'resource_type': 'auto',
          });
          return _response(
            jsonEncode({
              useSecureUrl ? 'secure_url' : 'url': url,
              'public_id': 'marketplace_test_0',
              'width': 640,
              'height': 480,
              'bytes': 4,
              'format': 'jpg',
              'folder': 'marketplace',
            }),
          );
        });
        final result = await http.runWithClient(
          () => CloudinaryService.uploadImageWithMetadata(
            imagePath: image.path,
            folder: 'marketplace',
            publicId: 'marketplace_test_0',
          ),
          () => client,
        );
        expect(result['url'], url);
        expect(result['publicId'], 'marketplace_test_0');
        expect(result['width'], 640);
        expect(result['height'], 480);
        expect(result['size'], 4);
        expect(result['format'], 'jpg');
        expect(result['folder'], 'marketplace');
        expect(DateTime.tryParse(result['uploadedAt'] as String), isNotNull);
      },
    );
  }
}
