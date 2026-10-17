import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:security_app/widgets/standard_header.dart';

void main() {
  testWidgets(
    'Visitor Management header renders and returns to Security home',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          initialRoute: '/visitors',
          routes: {
            '/': (_) => const Scaffold(body: Text('Security home')),
            '/visitors': (_) => const Scaffold(
              appBar: StandardHeader(
                title: 'Visitor Management',
                showBackButton: true,
              ),
            ),
          },
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Visitor Management'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
      expect(find.text('Security home'), findsNothing);

      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      expect(find.text('Security home'), findsOneWidget);
      expect(find.text('Visitor Management'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
