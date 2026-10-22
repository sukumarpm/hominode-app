import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:admin_app/apartment_images_management_screen.dart';
import 'package:admin_app/services/cloudinary_apartment_images_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

class _Service extends Fake implements CloudinaryApartmentImagesService {
  final calls = <ApartmentImageModel?>[];
  final titles = <String>[];
  final dates = <String?>[];
  final times = <String?>[];
  bool fail = false;
  String expectedScope = 'BUILDING';
  String? expectedBuildingId = 'building';
  Completer<String>? pending;
  @override
  Future<String> uploadImage({
    required String title,
    required String description,
    required String type,
    required File imageFile,
    String? buildingId,
    String ownershipScope = 'BUILDING',
    String? uploadDate,
    String? uploadTime,
    ApartmentImageModel? replacing,
  }) async {
    calls.add(replacing);
    titles.add(title);
    dates.add(uploadDate);
    times.add(uploadTime);
    expect(buildingId, expectedBuildingId);
    expect(ownershipScope, expectedScope);
    if (fail) throw StateError('Synthetic failure');
    return pending?.future ?? Future.value('saved');
  }
}

void main() {
  late Directory temp;
  late File file;
  late _Service service;
  setUp(() async {
    temp = await Directory.systemTemp.createTemp('apartment-modal-test-');
    file = await File('${temp.path}/photo.png').writeAsBytes(
      base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGP4z8DwHwAFAAH/iZk9HQAAAABJRU5ErkJggg==',
      ),
    );
    service = _Service();
  });
  tearDown(() async {
    await temp.delete(recursive: true);
  });
  Future<void> open(
    WidgetTester tester,
    ApartmentImageModel? model,
    void Function(String) saved, {
    String? buildingId = 'building',
    String ownershipScope = 'BUILDING',
  }) async {
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
                  barrierDismissible: false,
                  builder: (context) => AddApartmentImageModal(
                    buildingId: buildingId,
                    ownershipScope: ownershipScope,
                    replacing: model,
                    imagesService: service,
                    pickImage: () async => file,
                    onImageAdded: saved,
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

  ApartmentImageModel model() =>
      ApartmentImageModel.fromFirestore('existing-v2', {
        'contractVersion': 2,
        'ownershipScope': 'BUILDING',
        'title': 'Lobby photo',
        'resourceId': 'building',
        'buildingId': 'building',
        'communityId': 'A',
        'imageUrl': '',
        'uploadDate': '01-02-2020',
        'uploadTime': '9:30 AM',
      });
  testWidgets(
    'existing image picker and replacement button call Firebase service and close on confirmed save',
    (tester) async {
      String? saved;
      await open(tester, model(), (id) => saved = id);
      await tester.tap(find.text('Upload image'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Replace Image'));
      await tester.pumpAndSettle();
      expect(saved, 'saved');
      expect(service.calls.single!.id, 'existing-v2');
      expect(service.dates.single, '01-02-2020');
      expect(service.times.single, '9:30 AM');
      expect(service.titles.single, 'Lobby photo');
      expect(find.byType(AddApartmentImageModal), findsNothing);
    },
  );

  testWidgets('community entry uploads with COMMUNITY scope and no building', (
    tester,
  ) async {
    service.expectedScope = 'COMMUNITY';
    service.expectedBuildingId = null;
    await open(
      tester,
      null,
      (_) {},
      buildingId: null,
      ownershipScope: 'COMMUNITY',
    );
    await tester.tap(find.text('Upload image'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Upload Image'));
    await tester.pumpAndSettle();
    expect(service.calls, [null]);
    expect(service.titles, ['Community Photo']);
  });

  testWidgets('new building upload defaults to Building Photo title', (
    tester,
  ) async {
    await open(tester, null, (_) {});
    await tester.tap(find.text('Upload image'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Upload Image'));
    await tester.pumpAndSettle();
    expect(service.titles, ['Building Photo']);
  });
  testWidgets(
    'failure keeps modal open for retry; upload disables closing and duplicate submit',
    (tester) async {
      String? saved;
      await open(tester, model(), (id) => saved = id);
      await tester.tap(find.text('Upload image'));
      await tester.pumpAndSettle();
      service.fail = true;
      await tester.tap(find.text('Replace Image'));
      await tester.pumpAndSettle();
      expect(saved, isNull);
      expect(find.byType(AddApartmentImageModal), findsOneWidget);
      expect(
        find.textContaining('The image could not be saved'),
        findsOneWidget,
      );
      service.fail = false;
      service.pending = Completer<String>();
      await tester.tap(find.text('Replace Image'));
      await tester.pump();
      final button = tester.widget<ElevatedButton>(
        find.byType(ElevatedButton).last,
      );
      expect(button.onPressed, isNull);
      service.pending!.complete('retried');
      await tester.pumpAndSettle();
      expect(saved, 'retried');
      expect(service.calls.length, 2);
    },
  );
  testWidgets(
    'Add Image fills read-only date/time automatically and submits without pickers',
    (tester) async {
      String? saved;
      final before = DateTime.now();
      await open(tester, null, (id) => saved = id);
      final after = DateTime.now();
      final fields = tester
          .widgetList<TextFormField>(find.byType(TextFormField))
          .toList();
      expect(fields, hasLength(2));
      String date(DateTime value) =>
          '${value.day.toString().padLeft(2, '0')}-${value.month.toString().padLeft(2, '0')}-${value.year}';
      expect(fields.first.controller!.text, isIn([date(before), date(after)]));
      final context = tester.element(find.byType(AddApartmentImageModal));
      expect(
        fields.last.controller!.text,
        isIn([
          TimeOfDay.fromDateTime(before).format(context),
          TimeOfDay.fromDateTime(after).format(context),
        ]),
      );
      for (final field in tester.widgetList<TextField>(
        find.byType(TextField),
      )) {
        expect(field.readOnly, isTrue);
        expect(field.onTap, isNull);
      }
      final automaticDate = fields.first.controller!.text;
      final automaticTime = fields.last.controller!.text;
      await tester.tap(find.text('Upload image'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Upload Image'));
      await tester.pumpAndSettle();
      expect(service.dates.single, automaticDate);
      expect(service.times.single, automaticTime);
      expect(service.titles.single, 'Building Photo');
      expect(saved, 'saved');
      expect(service.calls.single, isNull);
    },
  );
}
