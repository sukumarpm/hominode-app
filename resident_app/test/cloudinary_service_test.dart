import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:resident_app/src/services/cloudinary_service.dart';

class _NoNetwork extends http.BaseClient {
  int requests = 0;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    requests++;
    throw StateError('External storage requests are forbidden.');
  }
}

void main() {
  for (final folder in [
    'profile_pictures',
    'community_wall',
    'complaints',
    'marketplace',
  ]) {
    test(
      '$folder legacy upload fails closed without contacting the provider',
      () async {
        final network = _NoNetwork();
        await http.runWithClient(
          () => expectLater(
            CloudinaryService.uploadImage(
              imagePath: 'unused.jpg',
              folder: folder,
            ),
            throwsStateError,
          ),
          () => network,
        );
        expect(network.requests, 0);
      },
    );
  }
  test(
    'legacy metadata upload and deletion cannot make provider requests',
    () async {
      final network = _NoNetwork();
      await http.runWithClient(() async {
        await expectLater(
          CloudinaryService.uploadImageWithMetadata(imagePath: 'unused.jpg'),
          throwsStateError,
        );
        await expectLater(
          CloudinaryService.deleteImage('synthetic-image'),
          throwsStateError,
        );
      }, () => network);
      expect(network.requests, 0);
    },
  );
}
