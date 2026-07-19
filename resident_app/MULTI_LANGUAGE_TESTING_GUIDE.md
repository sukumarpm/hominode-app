# Multi-Language Testing Guide

## Pre-Testing Checklist

- [ ] All translation JSON files exist in `lib/l10n/`
- [ ] All translation keys are present in all language files
- [ ] LanguageProvider is properly initialized in main.dart
- [ ] User is logged in to Firebase
- [ ] Firestore users collection has write permissions
- [ ] App builds without errors

## Manual Testing

### Test 1: Language Switching

**Steps:**
1. Open app and navigate to Settings
2. Click on Language section
3. Select Tamil (TA)
4. Verify:
   - [ ] All UI text changes to Tamil
   - [ ] App doesn't crash
   - [ ] Language preference saves to Firestore
   - [ ] RTL is not applied (Tamil is LTR)

5. Select Arabic (AR)
6. Verify:
   - [ ] All UI text changes to Arabic
   - [ ] Layout switches to RTL
   - [ ] Text direction is right-to-left
   - [ ] Language preference saves to Firestore

7. Select English (EN)
8. Verify:
   - [ ] All UI text changes back to English
   - [ ] Layout switches back to LTR
   - [ ] Language preference saves to Firestore

### Test 2: App Restart with Saved Language

**Steps:**
1. Change language to Tamil
2. Close app completely
3. Reopen app
4. Verify:
   - [ ] App opens in Tamil
   - [ ] Language preference was loaded from Firestore
   - [ ] All text is in Tamil

### Test 3: All Languages

**For each language (EN, TA, HI, ES, AR):**

1. Select language
2. Verify:
   - [ ] All visible text is translated
   - [ ] No English text remains
   - [ ] No placeholder keys visible (e.g., "home" instead of "Home")
   - [ ] Numbers and special characters display correctly
   - [ ] Long text doesn't overflow

### Test 4: RTL Support (Arabic)

**Steps:**
1. Select Arabic
2. Verify:
   - [ ] Text direction is RTL
   - [ ] Buttons align to right
   - [ ] Icons align correctly
   - [ ] Navigation drawer opens from right
   - [ ] Back button is on right side
   - [ ] Text alignment is right-aligned

### Test 5: Language Persistence

**Steps:**
1. Change language to Hindi
2. Navigate to different screens
3. Verify:
   - [ ] Language remains Hindi on all screens
   - [ ] No screen reverts to English

4. Close and reopen app
5. Verify:
   - [ ] Language is still Hindi
   - [ ] Firestore has saved preference

### Test 6: Logout and Login

**Steps:**
1. Set language to Spanish
2. Logout
3. Login with different user
4. Verify:
   - [ ] New user's saved language is loaded
   - [ ] Or defaults to English if no preference

### Test 7: Missing Translations

**Steps:**
1. Add a new key to English translation only
2. Use it in code: `LocalizedText('new_key')`
3. Switch to Tamil
4. Verify:
   - [ ] Key name is displayed (fallback behavior)
   - [ ] App doesn't crash

### Test 8: Parameter Substitution

**Steps:**
1. Use translation with parameters:
   ```dart
   LocalizedText('welcome_user', params: {'name': 'John'})
   ```
2. Switch languages
3. Verify:
   - [ ] Parameter is correctly substituted in all languages
   - [ ] Text displays correctly

### Test 9: Buttons and Dialogs

**Steps:**
1. Test all button types:
   - [ ] LocalizedButton
   - [ ] LocalizedTextButton
   - [ ] LocalizedOutlinedButton

2. Test dialogs:
   - [ ] Alert dialogs with localized text
   - [ ] Confirmation dialogs
   - [ ] Bottom sheets

3. Switch language
4. Verify:
   - [ ] All button text updates
   - [ ] Dialog text updates

### Test 10: Performance

**Steps:**
1. Change language multiple times rapidly
2. Verify:
   - [ ] No lag or stuttering
   - [ ] App remains responsive
   - [ ] No memory leaks

3. Navigate between screens while changing language
4. Verify:
   - [ ] Smooth transitions
   - [ ] No crashes

## Automated Testing

### Unit Tests

```dart
// test/localization_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:resident_app/src/services/localization_service.dart';

void main() {
  group('LocalizationService', () {
    late LocalizationService localizationService;

    setUp(() {
      localizationService = LocalizationService();
    });

    test('Initialize with English', () async {
      await localizationService.initialize('en');
      expect(localizationService.currentLanguage, 'en');
    });

    test('Change to Tamil', () async {
      await localizationService.initialize('en');
      await localizationService.changeLanguage('ta');
      expect(localizationService.currentLanguage, 'ta');
    });

    test('Translate key', () async {
      await localizationService.initialize('en');
      final translation = localizationService.translate('home');
      expect(translation, isNotEmpty);
      expect(translation, isNot('home')); // Should not be the key itself
    });

    test('RTL for Arabic', () async {
      await localizationService.initialize('ar');
      expect(localizationService.isRTL(), true);
    });

    test('LTR for English', () async {
      await localizationService.initialize('en');
      expect(localizationService.isRTL(), false);
    });

    test('Parameter substitution', () async {
      await localizationService.initialize('en');
      final translation = localizationService.translate(
        'welcome_user',
        params: {'name': 'John'},
      );
      expect(translation.contains('John'), true);
    });
  });
}
```

### Widget Tests

```dart
// test/language_selector_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:resident_app/src/providers/language_provider.dart';
import 'package:resident_app/src/widgets/language_selector.dart';

void main() {
  group('LanguageSelector', () {
    testWidgets('Displays all languages', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider(
            create: (_) => LanguageProvider(),
            child: Scaffold(
              body: LanguageSelector(),
            ),
          ),
        ),
      );

      expect(find.text('English'), findsOneWidget);
      expect(find.text('Tamil'), findsOneWidget);
      expect(find.text('Hindi'), findsOneWidget);
      expect(find.text('Spanish'), findsOneWidget);
      expect(find.text('العربية'), findsOneWidget);
    });

    testWidgets('Language selection works', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider(
            create: (_) => LanguageProvider(),
            child: Scaffold(
              body: LanguageSelector(),
            ),
          ),
        ),
      );

      // Tap Tamil
      await tester.tap(find.text('Tamil'));
      await tester.pumpAndSettle();

      // Verify selection
      final provider = tester.widget<LanguageSelector>(
        find.byType(LanguageSelector),
      );
      expect(provider, isNotNull);
    });
  });
}
```

### Integration Tests

```dart
// test_driver/app_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:resident_app/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Multi-Language Integration Tests', () {
    testWidgets('Language switching flow', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Navigate to settings
      await tester.tap(find.byIcon(Icons.settings));
      await tester.pumpAndSettle();

      // Select Tamil
      await tester.tap(find.text('Tamil'));
      await tester.pumpAndSettle();

      // Verify language changed
      expect(find.text('முகப்பு'), findsWidgets); // "Home" in Tamil

      // Select Arabic
      await tester.tap(find.text('العربية'));
      await tester.pumpAndSettle();

      // Verify RTL
      final directionality = find.byType(Directionality);
      expect(directionality, findsWidgets);
    });

    testWidgets('Language persistence', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Set language to Spanish
      await tester.tap(find.byIcon(Icons.settings));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Español'));
      await tester.pumpAndSettle();

      // Close and reopen app
      await tester.binding.window.physicalSizeTestValue = Size(540, 1080);
      addTearDown(tester.binding.window.clearPhysicalSizeTestValue);

      // Verify language persisted
      expect(find.text('Inicio'), findsWidgets); // "Home" in Spanish
    });
  });
}
```

## Firestore Testing

### Verify Language Saved

```dart
// In Firebase Console
1. Go to Firestore Database
2. Navigate to users collection
3. Find your user document
4. Verify 'language' field exists
5. Check value matches selected language
```

### Test Firestore Rules

```dart
// Ensure these rules allow language updates
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId} {
      allow read: if request.auth.uid == userId;
      allow update: if request.auth.uid == userId;
    }
  }
}
```

## Device Testing

### Test on Different Screen Sizes

- [ ] Phone (small)
- [ ] Tablet (large)
- [ ] Landscape orientation
- [ ] Portrait orientation

### Test on Different Devices

- [ ] Android phone
- [ ] iOS phone
- [ ] Android tablet
- [ ] iOS iPad

### Test with Different System Languages

- [ ] System language: English
- [ ] System language: Tamil
- [ ] System language: Arabic

## Accessibility Testing

### Screen Reader Testing

1. Enable screen reader (TalkBack on Android, VoiceOver on iOS)
2. Navigate through app
3. Verify:
   - [ ] All text is readable
   - [ ] Buttons are accessible
   - [ ] Language changes are announced

### Text Size Testing

1. Increase system text size to maximum
2. Verify:
   - [ ] Text doesn't overflow
   - [ ] Layout remains usable
   - [ ] All text is readable

## Performance Testing

### Memory Usage

```dart
// Monitor memory while changing languages
1. Open DevTools
2. Go to Memory tab
3. Change language multiple times
4. Verify no memory leaks
```

### Frame Rate

```dart
// Monitor frame rate during language changes
1. Open DevTools
2. Go to Performance tab
3. Change language
4. Verify smooth 60 FPS
```

## Regression Testing

After each update, test:

- [ ] All languages still work
- [ ] Language switching is smooth
- [ ] Firestore persistence works
- [ ] RTL layout is correct
- [ ] No new crashes
- [ ] Performance is acceptable

## Test Report Template

```markdown
# Multi-Language Testing Report

**Date:** [Date]
**Tester:** [Name]
**App Version:** [Version]
**Build:** [Build Number]

## Test Results

### Language Switching
- [ ] English: PASS / FAIL
- [ ] Tamil: PASS / FAIL
- [ ] Hindi: PASS / FAIL
- [ ] Spanish: PASS / FAIL
- [ ] Arabic: PASS / FAIL

### RTL Support
- [ ] Arabic RTL: PASS / FAIL
- [ ] Other languages LTR: PASS / FAIL

### Persistence
- [ ] Language saved to Firestore: PASS / FAIL
- [ ] Language restored on restart: PASS / FAIL

### Performance
- [ ] No lag during switching: PASS / FAIL
- [ ] No crashes: PASS / FAIL
- [ ] Memory usage acceptable: PASS / FAIL

## Issues Found

[List any issues]

## Notes

[Any additional notes]
```

## Continuous Testing

### Pre-Release Checklist

- [ ] All manual tests passed
- [ ] All unit tests passed
- [ ] All widget tests passed
- [ ] All integration tests passed
- [ ] No crashes reported
- [ ] Performance acceptable
- [ ] Firestore persistence verified
- [ ] RTL layout verified
- [ ] Accessibility verified

### Post-Release Monitoring

- [ ] Monitor crash reports
- [ ] Monitor user feedback
- [ ] Monitor language preference distribution
- [ ] Monitor performance metrics
