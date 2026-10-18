import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resident_app/src/modals/add_post_modal.dart';
import 'package:resident_app/src/modals/create_complaint_modal.dart';
import 'package:resident_app/src/models/complaint.dart';
import 'package:resident_app/src/services/complaints_service.dart';
import 'package:resident_app/src/services/complaint_image_service.dart';
import 'package:resident_app/src/services/resident_image_operations.dart';
import 'package:resident_app/src/services/resident_private_images.dart';

class _Images extends Fake implements ResidentImageOperations {
  int uploads = 0;
  bool fail = false;
  @override
  Future<String> createDraft(String feature) async => 'owned-draft';
  @override
  Future<String> upload({
    required String feature,
    required String resourceId,
    required String imagePath,
  }) async {
    uploads++;
    expect(feature, 'community_wall');
    expect(resourceId, 'owned-draft');
    if (fail) {
      throw StateError('Synthetic upload failure');
    }
    return 'hominode-image:a1111111-1111-4111-8111-111111111111';
  }
}

class _Complaints extends Fake implements ComplaintsService {
  int creates = 0;
  @override
  Future<Complaint> createComplaint({
    required String title,
    required String description,
    required ComplaintCategory category,
  }) async {
    creates++;
    return Complaint(
      id: 'saved-complaint',
      title: title,
      description: description,
      category: category,
      status: ComplaintStatus.pending,
      createdDate: DateTime(2026),
    );
  }
}

class _ComplaintPhotos extends Fake implements ComplaintImageService {
  bool fail = true;
  final ids = <String>[];
  @override
  Future<ComplaintImageResult> uploadComplaintImage({
    required String imagePath,
    required String complaintId,
  }) async {
    ids.add(complaintId);
    return fail
        ? ComplaintImageResult.failure(message: 'Synthetic failure')
        : ComplaintImageResult.success(imageUrl: 'private');
  }
}

void main() {
  late Directory directory;
  late File file;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('resident-image-modal-');
    file = await File('${directory.path}/photo.png').writeAsBytes(
      base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAIAAAACCAYAAABytg0kAAAAEUlEQVR4nGP4z8DwH4QZYAwAR8oH+WdZbrcAAAAASUVORK5CYII=',
      ),
    );
  });
  tearDown(() async {
    ResidentPrivateImages.install(null);
    await directory.delete(recursive: true);
  });
  Future<void> open(WidgetTester tester, Widget modal) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (context, child) => MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (context) => modal,
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'Wall draft upload failure stays retryable and failed publication keeps the form',
    (tester) async {
      final images = _Images()..fail = true;
      var publish = false;
      final submissions = <(String, String?, String?)>[];
      ResidentPrivateImages.install(
        ResidentPrivateImageStore(
          scope: () => null,
          call: (_, __) async =>
              throw StateError('No bytes in this UI fixture'),
        ),
      );
      await open(
        tester,
        AddPostModal(
          images: images,
          pickImage: (_) async => file,
          onSubmit: (text, ref, draft) async {
            submissions.add((text, ref, draft));
            return publish;
          },
        ),
      );
      await tester.enterText(find.byType(TextField), 'Garden update');
      await tester.tap(find.text('Gallery'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Upload Image'));
      await tester.tap(find.text('Upload Image'));
      await tester.pumpAndSettle();
      expect(find.byType(AddPostModal), findsOneWidget);
      expect(submissions, isEmpty);
      images.fail = false;
      await tester.tap(find.text('Upload Image'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Post'));
      await tester.tap(find.text('Post'));
      await tester.pumpAndSettle();
      expect(find.byType(AddPostModal), findsOneWidget);
      publish = true;
      await tester.tap(find.text('Post'));
      await tester.pumpAndSettle();
      expect(find.byType(AddPostModal), findsNothing);
      expect(submissions[0], submissions[1]);
      expect(submissions[0].$3, 'owned-draft');
      expect(submissions[0].$2, startsWith('hominode-image:'));
      expect(images.uploads, 2);
    },
  );
  testWidgets(
    'complaint photo retry keeps the created complaint and notifies its parent once',
    (tester) async {
      final complaints = _Complaints(), photos = _ComplaintPhotos();
      var notified = 0;
      await open(
        tester,
        CreateComplaintModal(
          complaints: complaints,
          images: photos,
          pickImage: () async => file,
          onCreated: (_) => notified++,
        ),
      );
      await tester.tap(find.text('Select Category'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Maintenance').last);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'Leaking water');
      await tester.enterText(
        find.byType(TextField).last,
        'Water is leaking in the common area',
      );
      await tester.ensureVisible(find.text('Upload photo'));
      await tester.tap(find.text('Upload photo'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Submit Complaint'));
      await tester.tap(find.text('Submit Complaint'));
      await tester.pumpAndSettle();
      expect(complaints.creates, 1);
      expect(notified, 1);
      expect(find.byType(CreateComplaintModal), findsOneWidget);
      photos.fail = false;
      await tester.tap(find.text('Submit Complaint'));
      await tester.pumpAndSettle();
      expect(complaints.creates, 1);
      expect(photos.ids, ['saved-complaint', 'saved-complaint']);
      expect(notified, 1);
      expect(find.byType(CreateComplaintModal), findsNothing);
    },
  );
}
