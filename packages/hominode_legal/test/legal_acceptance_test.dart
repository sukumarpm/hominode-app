import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hominode_legal/hominode_legal.dart';

void main() {
  test('missing and stale versions require acceptance', () {
    expect(HominodeLegalAcceptance.isCurrent(null), isFalse);
    expect(
      HominodeLegalAcceptance.isCurrent({
        'termsVersion': 'older',
        'privacyVersion': HominodeLegalAcceptance.privacyVersion,
        'acceptedAt': DateTime.now(),
      }),
      isFalse,
    );
  });

  test('both current versions and acceptedAt satisfy the gate', () {
    expect(
      HominodeLegalAcceptance.isCurrent({
        'termsVersion': HominodeLegalAcceptance.termsVersion,
        'privacyVersion': HominodeLegalAcceptance.privacyVersion,
        'acceptedAt': DateTime.now(),
      }),
      isTrue,
    );
  });

  testWidgets('acceptance screen has document buttons and no checkbox', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: LegalAcceptanceScreen(onAccept: () async {})),
    );

    expect(find.text('Read Terms & Conditions'), findsOneWidget);
    expect(find.text('Read Privacy Policy'), findsOneWidget);
    expect(find.text('Accept and continue'), findsOneWidget);
    expect(find.byType(Checkbox), findsNothing);
  });

  test('shared legal package assets contain both PDF documents', () async {
    for (final assetPath in <String>[
      HominodeLegalDocuments.termsAndConditionsAsset,
      HominodeLegalDocuments.privacyPolicyAsset,
    ]) {
      final data = await rootBundle.load(assetPath);
      expect(data.lengthInBytes, greaterThan(4));
      expect(
        data.buffer.asUint8List(data.offsetInBytes, 4),
        orderedEquals(<int>[0x25, 0x50, 0x44, 0x46]),
      );
    }
  });
}
