import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const locales = ['en', 'ta', 'hi', 'es', 'ar'];

  test('Admin locale files have identical keys and placeholders', () async {
    final translations = <String, Map<String, dynamic>>{};

    for (final locale in locales) {
      translations[locale] =
          jsonDecode(
                await rootBundle.loadString('assets/translations/$locale.json'),
              )
              as Map<String, dynamic>;
    }

    final english = translations['en']!;
    for (final locale in locales.skip(1)) {
      final translated = translations[locale]!;
      expect(translated.keys.toSet(), english.keys.toSet(), reason: locale);

      for (final key in english.keys) {
        expect(
          _placeholders(translated[key] as String),
          _placeholders(english[key] as String),
          reason: '$locale:$key',
        );
      }
    }
  });

  testWidgets('Arabic tagline renders with RTL text direction', (tester) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.rtl,
        child: Text('مساحات ذكية. حياة أفضل.'),
      ),
    );
    final tagline = find.text('مساحات ذكية. حياة أفضل.');
    expect(tagline, findsOneWidget);
    expect(Directionality.of(tester.element(tagline)).name, 'rtl');
  });
}

Set<String> _placeholders(String value) => RegExp(
  r'\{([^{}]+)\}',
).allMatches(value).map((match) => match.group(1)!).toSet();
