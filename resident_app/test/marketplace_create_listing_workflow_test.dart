import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hominode_entitlements/hominode_entitlements.dart';
import 'package:image_picker/image_picker.dart';
import 'package:resident_app/src/screens/marketplace_create_listing_screen.dart';
import 'package:resident_app/src/services/listing_firestore_service.dart';

import 'marketplace_access_gate_test.dart' show entitlement;

class _Picker extends Fake implements ImagePicker {
  Future<List<XFile>> Function() gallery = () async => [];
  Future<XFile?> Function() camera = () async => null;
  int calls = 0;

  @override
  Future<List<XFile>> pickMultiImage({
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    int? limit,
    bool requestFullMetadata = true,
  }) {
    calls++;
    return gallery();
  }

  @override
  Future<XFile?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    bool requestFullMetadata = true,
  }) {
    calls++;
    expect(source, ImageSource.camera);
    return camera();
  }
}

class _Listings extends Fake implements ListingFirestoreService {
  final paths = <List<String>>[];
  Future<ServiceResult> Function() submit = () async =>
      ServiceResult(success: true);

  @override
  Future<ServiceResult> createListing({
    required String title,
    required int price,
    required String category,
    required String condition,
    required String description,
    List<String> images = const [],
    List<String> imagePaths = const [],
    String? imageDraftId,
  }) {
    paths.add(List.of(imagePaths));
    return submit();
  }
}

void main() {
  late Directory directory;
  late List<XFile> photos;
  late _Picker picker;
  late _Listings listings;
  setUp(() {
    directory = Directory.systemTemp.createTempSync('marketplace-picker-');
    final bytes = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAIAAAACCAYAAABytg0kAAAAEUlEQVR4nGP4z8DwH4QZYAwAR8oH+WdZbrcAAAAASUVORK5CYII=',
    );
    photos = List.generate(6, (i) {
      final file = File('${directory.path}/$i.png')..writeAsBytesSync(bytes);
      return XFile(file.path);
    });
    picker = _Picker();
    listings = _Listings();
  });
  tearDown(() => directory.deleteSync(recursive: true));

  Future<void> open(
    WidgetTester tester, {
    Future<HominodeEntitlement?> Function()? loader,
  }) async {
    tester.view.physicalSize = const Size(390, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (_, _) => MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => MarketplaceCreateListingScreen(
                      listingService: listings,
                      imagePicker: picker,
                      accessLoader: loader ?? () async => entitlement('plus'),
                    ),
                  ),
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

  Future<void> decodePreviews(WidgetTester tester) async {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 30)),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'multiple gallery selections append previews, camera appends, removal works',
    (tester) async {
      picker.gallery = () async => photos.take(2).toList();
      await open(tester);
      await tester.tap(find.text('Gallery'));
      await tester.pumpAndSettle();
      expect(find.byType(Image), findsNWidgets(2));
      picker.gallery = () async => [photos[2]];
      await tester.tap(find.text('Gallery'));
      await tester.pumpAndSettle();
      expect(find.byType(Image), findsNWidgets(3));
      final previewPaths = tester
          .widgetList<Image>(find.byType(Image))
          .map((image) => (image.image as FileImage).file.path);
      expect(previewPaths, photos.take(3).map((file) => file.path));
      await tester.tap(find.byIcon(Icons.close).first);
      await tester.pumpAndSettle();
      expect(find.byType(Image), findsNWidgets(2));
      picker.camera = () async => photos[3];
      await tester.tap(find.text('Camera'));
      await decodePreviews(tester);
      expect(find.byType(Image), findsNWidgets(3));
      expect(tester.takeException(), isNull);
    },
  );

  for (final camera in [false, true]) {
    testWidgets(
      '${camera ? 'camera' : 'gallery'} cancellation and exception restore controls and preserve previews',
      (tester) async {
        picker.gallery = () async => [photos.first];
        await open(tester);
        await tester.tap(find.text('Gallery'));
        await tester.pumpAndSettle();
        final label = camera ? 'Camera' : 'Gallery';
        picker.gallery = () async => [];
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();
        expect(find.byType(Image), findsOneWidget);
        picker.gallery = () async =>
            throw PlatformException(code: 'photo_access_denied');
        picker.camera = () async =>
            throw PlatformException(code: 'camera_access_denied');
        await tester.tap(find.text(label));
        await decodePreviews(tester);
        expect(find.textContaining('permission and try again'), findsOneWidget);
        expect(find.byType(Image), findsOneWidget);
        expect(
          tester
              .widget<OutlinedButton>(
                find.widgetWithText(OutlinedButton, label),
              )
              .onPressed,
          isNotNull,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final fail in [false, true]) {
    for (final camera in [false, true]) {
      testWidgets(
        'disposed ${camera ? 'camera' : 'gallery'} ignores ${fail ? 'error' : 'selection'}',
        (tester) async {
          final pending = Completer<List<XFile>>();
          picker.gallery = () => pending.future;
          picker.camera = () async => (await pending.future).first;
          await open(tester);
          await tester.tap(find.text(camera ? 'Camera' : 'Gallery'));
          await tester.pump();
          await tester.pumpWidget(const SizedBox());
          if (fail) {
            pending.completeError(PlatformException(code: 'picker_failed'));
          } else {
            pending.complete([photos.first]);
          }
          await tester.pump();
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets(
    'native picker lifecycle retains form and selected images behind fresh access verification',
    (tester) async {
      final selected = Completer<List<XFile>>();
      final verification = Completer<HominodeEntitlement?>();
      var calls = 0;
      picker.gallery = () => selected.future;
      await open(
        tester,
        loader: () => ++calls == 1
            ? Future.value(entitlement('plus'))
            : verification.future,
      );
      await tester.enterText(find.byType(TextFormField).first, 'Saved chair');
      await tester.tap(find.text('Gallery'));
      // A second invocation before the next frame must not launch another picker.
      await tester.tap(find.text('Gallery'));
      expect(picker.calls, 1);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      expect(find.byType(TextFormField, skipOffstage: false), findsNWidgets(3));
      selected.complete(photos.take(2).toList());
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(find.byType(TextFormField), findsNothing);
      verification.complete(entitlement('plus'));
      await decodePreviews(tester);
      expect(find.text('Saved chair'), findsOneWidget);
      expect(find.byType(Image), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('selection caps at backend five-image limit', (tester) async {
    picker.gallery = () async => photos;
    await open(tester);
    await tester.tap(find.text('Gallery'));
    await decodePreviews(tester);
    expect(find.text('You can add up to 5 images.'), findsOneWidget);
    await tester.tap(find.text('Camera'));
    await tester.pump();
    expect(picker.calls, 1);
    await tester.tap(find.byIcon(Icons.close).first);
    await tester.pumpAndSettle();
    picker.gallery = () async => [photos.last];
    await tester.tap(find.text('Gallery'));
    await decodePreviews(tester);
    expect(picker.calls, 2);
  });

  testWidgets(
    'publication awaits service, prevents duplicate submission and restores retry after failure',
    (tester) async {
      final pending = Completer<ServiceResult>();
      listings.submit = () => pending.future;
      picker.gallery = () async => [photos.first];
      await open(tester);
      await tester.tap(find.text('Gallery'));
      await decodePreviews(tester);
      await tester.enterText(find.byType(TextFormField).at(0), 'Chair');
      await tester.enterText(find.byType(TextFormField).at(1), '500');
      await tester.enterText(
        find.byType(TextFormField).at(2),
        'Good condition',
      );
      final create = find.widgetWithText(ElevatedButton, 'Create Listing');
      await tester.ensureVisible(create);
      await tester.tap(create);
      await tester.tap(create);
      await tester.pump();
      expect(listings.paths, [
        [photos.first.path],
      ]);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(
        tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
        isNull,
      );
      expect(
        tester
            .widget<OutlinedButton>(
              find.widgetWithText(OutlinedButton, 'Gallery'),
            )
            .onPressed,
        isNull,
      );
      pending.complete(
        ServiceResult(success: false, message: 'Upload failed. Please retry.'),
      );
      await tester.pumpAndSettle();
      expect(find.text('Upload failed. Please retry.'), findsOneWidget);
      expect(find.text('Listing created successfully'), findsNothing);
      expect(find.text('Chair'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      listings.submit = () async => ServiceResult(success: true);
      ScaffoldMessenger.of(tester.element(create)).removeCurrentSnackBar();
      await tester.pumpAndSettle();
      await tester.tap(create);
      await tester.pumpAndSettle();
      expect(listings.paths, [
        [photos.first.path],
        [photos.first.path],
      ]);
      expect(find.byType(MarketplaceCreateListingScreen), findsNothing);
      expect(find.text('Listing created successfully'), findsOneWidget);
    },
  );

  testWidgets('publication completion after screen disposal is safe', (
    tester,
  ) async {
    final pending = Completer<ServiceResult>();
    listings.submit = () => pending.future;
    await open(tester);
    await tester.enterText(find.byType(TextFormField).at(0), 'Chair');
    await tester.enterText(find.byType(TextFormField).at(1), '500');
    await tester.enterText(find.byType(TextFormField).at(2), 'Good condition');
    await tester.ensureVisible(
      find.widgetWithText(ElevatedButton, 'Create Listing'),
    );
    await tester.tap(find.widgetWithText(ElevatedButton, 'Create Listing'));
    await tester.pump();
    await tester.pumpWidget(const SizedBox());
    pending.complete(ServiceResult(success: true));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
