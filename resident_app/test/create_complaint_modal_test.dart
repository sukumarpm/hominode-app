import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resident_app/src/modals/create_complaint_modal.dart';
import 'package:resident_app/src/models/complaint.dart';
import 'package:resident_app/src/services/complaint_firestore_service.dart';
import 'package:resident_app/src/services/complaint_image_service.dart';
import 'package:resident_app/src/services/complaints_service.dart';

class _FirestoreComplaintCreator extends Fake
    implements ComplaintFirestoreService {
  int calls = 0;
  ComplaintResult result = ComplaintResult.success(complaintId: 'complaint-1');
  Completer<ComplaintResult>? pending;

  @override
  Future<ComplaintResult> createComplaint({
    required String title,
    required String description,
    required ComplaintCategory category,
  }) {
    calls++;
    return pending?.future ?? Future.value(result);
  }
}

class _ComplaintImages extends Fake implements ComplaintImageService {
  int calls = 0;
  String? complaintId;
  ComplaintImageResult result = ComplaintImageResult.success();

  @override
  Future<ComplaintImageResult> uploadComplaintImage({
    required String imagePath,
    required String complaintId,
  }) async {
    calls++;
    this.complaintId = complaintId;
    return result;
  }
}

void main() {
  late Directory tempDirectory;
  late File imageFile;

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp('complaint-modal-');
    imageFile = await File('${tempDirectory.path}/photo.png').writeAsBytes(
      base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAIAAAACCAYAAABytg0kAAAAEUlEQVR4nGP4z8DwH4QZYAwAR8oH+WdZbrcAAAAASUVORK5CYII=',
      ),
    );
  });

  tearDown(() async {
    await tempDirectory.delete(recursive: true);
  });

  Future<void> openModal(
    WidgetTester tester, {
    required ComplaintsService complaints,
    required ComplaintImageService images,
    Future<File?> Function()? pickImage,
    void Function(Complaint)? onCreated,
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(390, 844),
        minTextAdapt: true,
        builder: (context, child) => MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                key: const ValueKey('open-create-complaint'),
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => CreateComplaintModal(
                    complaints: complaints,
                    images: images,
                    pickImage: pickImage,
                    onCreated: onCreated,
                  ),
                ),
                child: const Text('Open complaint form'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('open-create-complaint')));
    await tester.pumpAndSettle();
  }

  Future<void> enterValidComplaint(WidgetTester tester) async {
    await tester.ensureVisible(find.text('Select Category'));
    await tester.tap(find.text('Select Category'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Security'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), 'Broken gate');
    await tester.enterText(
      find.byType(TextField).at(1),
      'The entrance gate will not close.',
    );
    await tester.pumpAndSettle();
  }

  Future<(_FirestoreComplaintCreator, ComplaintsService)> buildComplaints({
    Completer<ComplaintResult>? pending,
  }) async {
    final creator = _FirestoreComplaintCreator()..pending = pending;
    return (creator, ComplaintsService.withFirestoreService(creator));
  }

  testWidgets('submits a complaint without selecting a photo', (tester) async {
    final (creator, complaints) = await buildComplaints();
    final images = _ComplaintImages();
    var createdCount = 0;
    await openModal(
      tester,
      complaints: complaints,
      images: images,
      onCreated: (_) => createdCount++,
    );
    await enterValidComplaint(tester);

    expect(
      tester
          .widget<ElevatedButton>(
            find.byKey(const ValueKey('submit-complaint-button')),
          )
          .onPressed,
      isNotNull,
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey('submit-complaint-button')),
    );
    await tester.tap(find.byKey(const ValueKey('submit-complaint-button')));
    await tester.pumpAndSettle();

    expect(creator.calls, 1);
    expect(images.calls, 0);
    expect(createdCount, 1);
    expect(find.byType(CreateComplaintModal), findsNothing);
    expect(find.text('Complaint submitted successfully!'), findsOneWidget);
  });

  testWidgets('uploads a selected photo after creating the complaint', (
    tester,
  ) async {
    final (creator, complaints) = await buildComplaints();
    final images = _ComplaintImages();
    await openModal(
      tester,
      complaints: complaints,
      images: images,
      pickImage: () async => imageFile,
    );
    await enterValidComplaint(tester);
    await tester.ensureVisible(find.text('Upload photo'));
    await tester.tap(find.text('Upload photo'));
    await tester.pumpAndSettle();
    expect(find.text('Photo attached'), findsOneWidget);

    await tester.ensureVisible(
      find.byKey(const ValueKey('submit-complaint-button')),
    );
    await tester.tap(find.byKey(const ValueKey('submit-complaint-button')));
    await tester.pumpAndSettle();

    expect(creator.calls, 1);
    expect(images.calls, 1);
    expect(images.complaintId, 'complaint-1');
    expect(find.byType(CreateComplaintModal), findsNothing);
  });

  testWidgets('removing a selected photo submits without uploading it', (
    tester,
  ) async {
    final (creator, complaints) = await buildComplaints();
    final images = _ComplaintImages();
    await openModal(
      tester,
      complaints: complaints,
      images: images,
      pickImage: () async => imageFile,
    );
    await enterValidComplaint(tester);
    await tester.ensureVisible(find.text('Upload photo'));
    await tester.tap(find.text('Upload photo'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('remove-complaint-photo')));
    await tester.pumpAndSettle();
    expect(find.text('Upload photo'), findsOneWidget);

    await tester.ensureVisible(
      find.byKey(const ValueKey('submit-complaint-button')),
    );
    await tester.tap(find.byKey(const ValueKey('submit-complaint-button')));
    await tester.pumpAndSettle();
    expect(creator.calls, 1);
    expect(images.calls, 0);
  });

  testWidgets(
    'shows title and description validation errors and disables submit',
    (tester) async {
      final (creator, complaints) = await buildComplaints();
      await openModal(
        tester,
        complaints: complaints,
        images: _ComplaintImages(),
      );
      await tester.ensureVisible(find.text('Select Category'));
      await tester.tap(find.text('Select Category'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Security'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).at(0), 'Bad');
      await tester.enterText(find.byType(TextField).at(1), 'Too short');
      await tester.pumpAndSettle();

      expect(find.text('Title must be at least 5 characters'), findsOneWidget);
      expect(
        find.text('Description must be at least 10 characters'),
        findsOneWidget,
      );
      expect(
        tester
            .widget<ElevatedButton>(
              find.byKey(const ValueKey('submit-complaint-button')),
            )
            .onPressed,
        isNull,
      );
      expect(creator.calls, 0);
    },
  );

  testWidgets(
    'photo failure keeps complaint and can continue after photo removal',
    (tester) async {
      final (creator, complaints) = await buildComplaints();
      final images = _ComplaintImages()
        ..result = ComplaintImageResult.failure(message: 'upload failed');
      var createdCount = 0;
      await openModal(
        tester,
        complaints: complaints,
        images: images,
        pickImage: () async => imageFile,
        onCreated: (_) => createdCount++,
      );
      await enterValidComplaint(tester);
      await tester.ensureVisible(find.text('Upload photo'));
      await tester.tap(find.text('Upload photo'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const ValueKey('submit-complaint-button')),
      );
      await tester.tap(find.byKey(const ValueKey('submit-complaint-button')));
      await tester.pumpAndSettle();

      expect(creator.calls, 1);
      expect(images.calls, 1);
      expect(createdCount, 1);
      expect(find.byType(CreateComplaintModal), findsOneWidget);
      expect(
        find.text(
          'Your complaint is saved. Retry its photo, or remove the photo to continue.',
        ),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const ValueKey('remove-complaint-photo')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const ValueKey('submit-complaint-button')),
      );
      await tester.tap(find.byKey(const ValueKey('submit-complaint-button')));
      await tester.pumpAndSettle();
      expect(creator.calls, 1);
      expect(images.calls, 1);
      expect(createdCount, 1);
      expect(find.byType(CreateComplaintModal), findsNothing);
    },
  );

  testWidgets(
    'Firestore create failure shows failure without photo or success',
    (tester) async {
      final creator = _FirestoreComplaintCreator()
        ..result = ComplaintResult.failure(message: 'write denied');
      final complaints = ComplaintsService.withFirestoreService(creator);
      final images = _ComplaintImages();
      var createdCount = 0;
      await openModal(
        tester,
        complaints: complaints,
        images: images,
        pickImage: () async => imageFile,
        onCreated: (_) => createdCount++,
      );
      await enterValidComplaint(tester);
      await tester.ensureVisible(find.text('Upload photo'));
      await tester.tap(find.text('Upload photo'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const ValueKey('submit-complaint-button')),
      );
      await tester.tap(find.byKey(const ValueKey('submit-complaint-button')));
      await tester.pumpAndSettle();

      expect(creator.calls, 1);
      expect(images.calls, 0);
      expect(createdCount, 0);
      expect(find.byType(CreateComplaintModal), findsOneWidget);
      expect(
        find.textContaining('Failed to submit complaint:'),
        findsOneWidget,
      );
      expect(find.text('Complaint submitted successfully!'), findsNothing);
    },
  );

  testWidgets('repeated taps while creating produce one complaint', (
    tester,
  ) async {
    final pending = Completer<ComplaintResult>();
    final (creator, complaints) = await buildComplaints(pending: pending);
    final images = _ComplaintImages();
    await openModal(tester, complaints: complaints, images: images);
    await enterValidComplaint(tester);
    await tester.ensureVisible(
      find.byKey(const ValueKey('submit-complaint-button')),
    );
    final submit = find.byKey(const ValueKey('submit-complaint-button'));
    await tester.tap(submit);
    await tester.pump();
    await tester.tap(submit, warnIfMissed: false);
    await tester.pump();
    expect(creator.calls, 1);

    pending.complete(ComplaintResult.success(complaintId: 'complaint-1'));
    await tester.pumpAndSettle();
    expect(creator.calls, 1);
    expect(find.byType(CreateComplaintModal), findsNothing);
  });
}
