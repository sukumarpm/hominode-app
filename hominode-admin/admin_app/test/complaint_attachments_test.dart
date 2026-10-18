import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hominode_storage/hominode_storage.dart';
import 'package:admin_app/services/firebase_image_upload_service.dart';
import 'package:admin_app/widgets/complaint_attachments.dart';

final png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGP4z8DwHwAFAAH/iZk9HQAAAABJRU5ErkJggg==',
);
const id = 'a1111111-1111-4111-8111-111111111111';
StorageImageAsset asset() => StorageImageAsset.fromMap({
  'assetId': id,
  'provider': 'firebase',
  'bucket': 'demo-images.appspot.com',
  'ownerId': 'resident',
  'communityId': 'A',
  'feature': 'complaints',
  'resourceId': 'complaint',
  'contentType': 'image/png',
  'size': png.length,
  'state': 'ready',
  'storagePath': 'private_images/A/resident/complaints/$id.png',
  'generation': '7',
  'sha256': 'a' * 64,
});
Map<String, dynamic> record() => {
  'communityId': 'A',
  'imageUrl': 'hominode-image:$id',
  'managedImageAssets': [asset().toMap()],
};

class _Transport extends Fake implements FirebaseImageUploadService {
  int reads = 0;
  bool denied = false;
  @override
  Future<Uint8List> read(StorageImageAsset asset) async {
    reads++;
    if (denied) throw StateError('denied');
    return png;
  }

  @override
  Future<void> authorizeRead(StorageImageAsset asset) async {
    if (denied) throw StateError('denied');
  }
}

void main() {
  test(
    'assigned Admin read uses server authorization for a Resident-owned asset',
    () async {
      var calls = 0;
      String? uid = 'admin';
      final service = FirebaseImageUploadService(
        currentUid: () => uid,
        call: (name, data) async {
          calls++;
          expect(name, 'readStorageImage');
          expect(data, {'assetId': id});
          return {
            'assetId': id,
            'generation': '7',
            'contentType': 'image/png',
            'size': png.length,
            'base64': base64Encode(png),
          };
        },
      );
      expect(await service.read(asset()), png);
      uid = null;
      await expectLater(service.read(asset()), throwsStateError);
      expect(calls, 1);
    },
  );
  testWidgets(
    'private complaint bytes render once; session errors immediately remove them',
    (tester) async {
      final tokens = StreamController<Object?>.broadcast(sync: true);
      final session = ValueNotifier(0);
      final transport = _Transport();
      await tester.pumpWidget(
        MaterialApp(
          home: SizedBox(
            width: 390,
            height: 400,
            child: ComplaintAttachments(
              complaintId: 'complaint',
              records: Stream.value(record()),
              transport: transport,
              scope: () => 'admin/A',
              sessionChanges: session,
              tokenChanges: tokens.stream,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(Image), findsOneWidget);
      expect(transport.reads, 1);
      await tester.pump();
      expect(transport.reads, 1);
      tokens.addError(StateError('expired session'));
      await tester.pumpAndSettle();
      expect(find.byType(Image), findsNothing);
      expect(find.text('Sign in to view attachments.'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tokens.close();
      session.dispose();
    },
  );
  testWidgets(
    'denied image retries without falling back to a historical URL; tenant switch clears it',
    (tester) async {
      final tokens = StreamController<Object?>.broadcast();
      final session = ValueNotifier(0);
      var scope = 'admin/A';
      final transport = _Transport()..denied = true;
      await tester.pumpWidget(
        MaterialApp(
          home: SizedBox(
            width: 390,
            height: 400,
            child: ComplaintAttachments(
              complaintId: 'complaint',
              records: Stream.value(record()),
              transport: transport,
              scope: () => scope,
              sessionChanges: session,
              tokenChanges: tokens.stream,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byTooltip('Retry image'), findsOneWidget);
      transport.denied = false;
      await tester.tap(find.byTooltip('Retry image'));
      await tester.pumpAndSettle();
      expect(find.byType(Image), findsOneWidget);
      scope = 'admin/B';
      session.value++;
      await tester.pumpAndSettle();
      expect(find.byType(Image), findsNothing);
      expect(find.text('Attachments are unavailable.'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tokens.close();
      session.dispose();
    },
  );
  testWidgets(
    'missing private metadata is rejected and cannot become a network URL',
    (tester) async {
      final session = ValueNotifier(0);
      final transport = _Transport();
      await tester.pumpWidget(
        MaterialApp(
          home: SizedBox(
            width: 390,
            height: 400,
            child: ComplaintAttachments(
              complaintId: 'complaint',
              records: Stream.value({
                'communityId': 'A',
                'imageUrl': 'hominode-image:$id',
              }),
              transport: transport,
              scope: () => 'admin/A',
              sessionChanges: session,
              tokenChanges: const Stream.empty(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Photo unavailable.'), findsOneWidget);
      expect(transport.reads, 0);
      expect(find.byType(Image), findsNothing);
      await tester.pumpWidget(const SizedBox());
      session.dispose();
    },
  );
}
