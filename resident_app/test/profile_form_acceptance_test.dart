import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resident_app/src/screens/edit_profile_screen.dart';
import 'package:resident_app/src/services/profile_image_service.dart';
import 'localization_test_app.dart';

void main() {
  setUpAll(initializeTestLocalization);
  Future<void> open(
    WidgetTester tester, {
    required Future<bool> Function(Map<String, dynamic>) save,
    String? initialEmail = 'resident@example.invalid',
    Future<String?> Function()? picker,
    Future<ProfileImageResult> Function(String)? upload,
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      withEnglishLocalization(
        (context) => ScreenUtilInit(
          designSize: const Size(390, 844),
          builder: (_, _) => localizedMaterialApp(
            context,
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  child: const Text('open'),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => EditProfileScreen(
                        profileLoader: () async => {
                          'name': 'Synthetic Resident',
                          'email': initialEmail,
                          'phoneNumber': '+639170000000',
                          'phone': 'legacy-display',
                          'flatLabel': 'A-1',
                        },
                        profileSaver: save,
                        photoPicker: picker,
                        photoUploader: upload,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'name/email-only form save preserves canonical phone and does not upload',
    (tester) async {
      Map<String, dynamic>? saved;
      var uploads = 0;
      await open(
        tester,
        save: (fields) async {
          saved = fields;
          return true;
        },
        upload: (_) async {
          uploads++;
          throw StateError('unexpected');
        },
      );
      expect(find.text('+639170000000'), findsOneWidget);
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'Updated Synthetic');
      await tester.enterText(fields.at(1), 'updated@example.invalid');
      await tester.ensureVisible(find.text('Save Changes'));
      await tester.tap(find.text('Save Changes'));
      await tester.pumpAndSettle();
      expect(saved, {
        'name': 'Updated Synthetic',
        'email': 'updated@example.invalid',
      });
      expect(uploads, 0);
      expect(find.text('open'), findsOneWidget);
    },
  );
  testWidgets(
    'pending photo verification failure preserves saved fields and offers retry',
    (tester) async {
      final dir = Directory.systemTemp.createTempSync('profile-form-');
      addTearDown(() => dir.deleteSync(recursive: true));
      final file = File('${dir.path}/synthetic.png')
        ..writeAsBytesSync(
          base64Decode(
            'iVBORw0KGgoAAAANSUhEUgAAAAIAAAACCAYAAABytg0kAAAAEUlEQVR4nGP4z8DwH4QZYAwAR8oH+WdZbrcAAAAASUVORK5CYII=',
          ),
        );
      var saves = 0;
      final order = <String>[];
      await open(
        tester,
        save: (_) async {
          saves++;
          order.add('fields');
          return true;
        },
        picker: () async => file.path,
        upload: (_) async {
          order.add('photo');
          return ProfileImageResult.failure(
            message: 'unavailable',
            errorCode: 'APP_CHECK_UNAVAILABLE',
          );
        },
      );
      await tester.tap(find.byIcon(Icons.camera_alt));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Save Changes'));
      await tester.tap(find.text('Save Changes'));
      await tester.pump();
      expect(saves, 1);
      expect(order, ['fields', 'photo']);
      expect(find.textContaining('Profile details saved.'), findsOneWidget);
      expect(find.byType(EditProfileScreen), findsOneWidget);
      expect(find.textContaining('Device verification failed'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    },
  );
  for (final email in <String?>[null, '', '   ']) {
    testWidgets('optional email $email saves without photo attestation', (
      tester,
    ) async {
      Map<String, dynamic>? saved;
      var uploads = 0;
      await open(
        tester,
        initialEmail: email,
        save: (fields) async {
          saved = fields;
          return true;
        },
        upload: (_) async {
          uploads++;
          throw StateError('Photo verification must not run');
        },
      );
      await tester.ensureVisible(find.text('Save Changes'));
      await tester.tap(find.text('Save Changes'));
      await tester.pumpAndSettle();
      expect(saved, {'name': 'Synthetic Resident', 'email': ''});
      expect(uploads, 0);
      expect(find.text('open'), findsOneWidget);
    });
  }
  testWidgets(
    'clearing an existing email persists empty; malformed nonempty email is rejected',
    (tester) async {
      Map<String, dynamic>? saved;
      await open(
        tester,
        save: (fields) async {
          saved = fields;
          return true;
        },
      );
      await tester.enterText(find.byType(TextFormField).at(1), 'invalid-email');
      await tester.ensureVisible(find.text('Save Changes'));
      await tester.tap(find.text('Save Changes'));
      await tester.pumpAndSettle();
      expect(saved, isNull);
      expect(find.text('Enter a valid email address'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField).at(1), '');
      await tester.tap(find.text('Save Changes'));
      await tester.pumpAndSettle();
      expect(saved!['email'], '');
      expect(saved!.keys, unorderedEquals(['name', 'email']));
    },
  );
  testWidgets(
    'a rejected ordinary write reports failure without entering photo verification',
    (tester) async {
      var uploads = 0;
      await open(
        tester,
        save: (_) async => false,
        upload: (_) async {
          uploads++;
          throw StateError('Unexpected upload');
        },
      );
      await tester.ensureVisible(find.text('Save Changes'));
      await tester.tap(find.text('Save Changes'));
      await tester.pumpAndSettle();
      expect(uploads, 0);
      expect(find.byType(EditProfileScreen), findsOneWidget);
      expect(
        find.text('Could not update your profile. Please try again.'),
        findsOneWidget,
      );
    },
  );
}
