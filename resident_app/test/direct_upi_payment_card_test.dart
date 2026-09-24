import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resident_app/src/screens/submit_payment_proof_screen.dart';
import 'package:resident_app/src/services/resident_direct_upi_service.dart';
import 'package:resident_app/src/widgets/direct_upi_payment_card.dart';

final _preparation = DirectUpiPaymentPreparation(
  billId: 'bill-123',
  communityId: 'community-123',
  amount: 850.5,
  vpa: 'association@upi',
  payeeName: 'Green Community',
  paymentUri: Uri(
    scheme: 'upi',
    host: 'pay',
    queryParameters: {
      'pa': 'association@upi',
      'pn': 'Green Community',
      'am': '850.50',
      'cu': 'INR',
    },
  ),
);

Widget _app({
  required Future<DirectUpiPaymentPreparation> Function(String billId)
  preparePayment,
  required Future<bool> Function(Uri uri) launchPayment,
  required Future<void> Function() onSubmitProof,
}) => MaterialApp(
  home: Scaffold(
    body: DirectUpiPaymentCard(
      billId: 'bill-123',
      preparePayment: preparePayment,
      launchPayment: launchPayment,
      onSubmitProof: onSubmitProof,
    ),
  ),
);

void main() {
  testWidgets('renders Pay via UPI and the already paid proof action', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        preparePayment: (_) async => _preparation,
        launchPayment: (_) async => true,
        onSubmitProof: () async {},
      ),
    );

    expect(find.text('Pay via UPI'), findsOneWidget);
    expect(find.text('Already paid? Submit payment proof'), findsOneWidget);
  });

  testWidgets('prepares once with bill ID and launches exact prepared URI', (
    tester,
  ) async {
    var prepareCalls = 0;
    var launchCalls = 0;
    var proofCalls = 0;
    Uri? launchedUri;

    await tester.pumpWidget(
      _app(
        preparePayment: (billId) async {
          prepareCalls++;
          expect(billId, 'bill-123');
          return _preparation;
        },
        launchPayment: (uri) async {
          launchCalls++;
          launchedUri = uri;
          return true;
        },
        onSubmitProof: () async => proofCalls++,
      ),
    );

    await tester.tap(find.text('Pay via UPI'));
    await tester.pumpAndSettle();

    expect(prepareCalls, 1);
    expect(launchCalls, 1);
    expect(launchedUri, same(_preparation.paymentUri));
    expect(launchedUri.toString(), _preparation.paymentUri.toString());
    expect(proofCalls, 1);
    expect(find.text('Payment successful'), findsNothing);
    expect(find.text('Payment paid'), findsNothing);
  });

  testWidgets('disables duplicate Pay taps while preparing', (tester) async {
    final preparation = Completer<DirectUpiPaymentPreparation>();
    var prepareCalls = 0;
    var launchCalls = 0;

    await tester.pumpWidget(
      _app(
        preparePayment: (_) {
          prepareCalls++;
          return preparation.future;
        },
        launchPayment: (_) async {
          launchCalls++;
          return true;
        },
        onSubmitProof: () async {},
      ),
    );

    await tester.tap(find.text('Pay via UPI'));
    await tester.pump();
    expect(find.text('Preparing payment…'), findsOneWidget);
    expect(
      tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
      isNull,
    );
    expect(prepareCalls, 1);

    preparation.complete(_preparation);
    await tester.pumpAndSettle();
    expect(prepareCalls, 1);
    expect(launchCalls, 1);
  });

  testWidgets('does not launch if disposed during preparation', (tester) async {
    final preparation = Completer<DirectUpiPaymentPreparation>();
    var launchCalls = 0;
    await tester.pumpWidget(
      _app(
        preparePayment: (_) => preparation.future,
        launchPayment: (_) async {
          launchCalls++;
          return true;
        },
        onSubmitProof: () async {},
      ),
    );

    await tester.tap(find.text('Pay via UPI'));
    await tester.pump();
    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    preparation.complete(_preparation);
    await tester.pump();

    expect(launchCalls, 0);
  });

  testWidgets('does not navigate if disposed during launch', (tester) async {
    final launch = Completer<bool>();
    var proofCalls = 0;
    await tester.pumpWidget(
      _app(
        preparePayment: (_) async => _preparation,
        launchPayment: (_) => launch.future,
        onSubmitProof: () async => proofCalls++,
      ),
    );

    await tester.tap(find.text('Pay via UPI'));
    await tester.pump();
    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    launch.complete(true);
    await tester.pump();

    expect(proofCalls, 0);
  });

  testWidgets('shows safe service message and does not launch', (tester) async {
    var launchCalls = 0;
    await tester.pumpWidget(
      _app(
        preparePayment: (_) async => throw const ResidentDirectUpiException(
          ResidentDirectUpiFailure.directUpiDisabled,
        ),
        launchPayment: (_) async {
          launchCalls++;
          return true;
        },
        onSubmitProof: () async {},
      ),
    );

    await tester.tap(find.text('Pay via UPI'));
    await tester.pumpAndSettle();

    expect(find.text('Direct UPI is currently disabled.'), findsOneWidget);
    expect(launchCalls, 0);
  });

  testWidgets('shows a safe generic error for unexpected preparation failure', (
    tester,
  ) async {
    var launchCalls = 0;
    await tester.pumpWidget(
      _app(
        preparePayment: (_) async => throw StateError('internal detail'),
        launchPayment: (_) async {
          launchCalls++;
          return true;
        },
        onSubmitProof: () async {},
      ),
    );

    await tester.tap(find.text('Pay via UPI'));
    await tester.pumpAndSettle();

    expect(
      find.text('UPI payment could not be started. Please try again.'),
      findsOneWidget,
    );
    expect(find.textContaining('internal detail'), findsNothing);
    expect(launchCalls, 0);
  });

  for (final launchCase in <({String name, Future<bool> Function(Uri) run})>[
    (name: 'returns false', run: (_) async => false),
    (name: 'throws', run: (_) async => throw StateError('platform detail')),
  ]) {
    testWidgets('shows manual fallback when launch ${launchCase.name}', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          preparePayment: (_) async => _preparation,
          launchPayment: launchCase.run,
          onSubmitProof: () async {},
        ),
      );

      await tester.tap(find.text('Pay via UPI'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(
        find.text('Unable to open a UPI app automatically.'),
        findsOneWidget,
      );
      expect(
        find.text(
          'Open your preferred UPI app and pay the exact amount using these details.',
        ),
        findsOneWidget,
      );
      expect(find.text('Green Community'), findsOneWidget);
      expect(find.text('association@upi'), findsOneWidget);
      expect(find.text('₹850.50'), findsOneWidget);
      expect(find.textContaining('platform detail'), findsNothing);
    });
  }

  testWidgets('fallback proof action does not retry launch', (tester) async {
    var prepareCalls = 0;
    var launchCalls = 0;
    var proofCalls = 0;
    await tester.pumpWidget(
      _app(
        preparePayment: (_) async {
          prepareCalls++;
          return _preparation;
        },
        launchPayment: (_) async {
          launchCalls++;
          return false;
        },
        onSubmitProof: () async => proofCalls++,
      ),
    );

    await tester.tap(find.text('Pay via UPI'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text('Submit payment proof'));
    await tester.pumpAndSettle();

    expect(prepareCalls, 1);
    expect(launchCalls, 1);
    expect(proofCalls, 1);
  });

  testWidgets('already paid proof action skips preparation and launch', (
    tester,
  ) async {
    var prepareCalls = 0;
    var launchCalls = 0;
    var proofCalls = 0;
    await tester.pumpWidget(
      _app(
        preparePayment: (_) async {
          prepareCalls++;
          return _preparation;
        },
        launchPayment: (_) async {
          launchCalls++;
          return true;
        },
        onSubmitProof: () async => proofCalls++,
      ),
    );

    await tester.tap(find.text('Already paid? Submit payment proof'));
    await tester.pumpAndSettle();

    expect(prepareCalls, 0);
    expect(launchCalls, 0);
    expect(proofCalls, 1);
  });

  testWidgets('keeps payment copy provider neutral', (tester) async {
    await tester.pumpWidget(
      _app(
        preparePayment: (_) async => _preparation,
        launchPayment: (_) async => true,
        onSubmitProof: () async {},
      ),
    );

    expect(find.text('Google Pay'), findsNothing);
    expect(find.text('PhonePe'), findsNothing);
    expect(find.text('Paytm'), findsNothing);
    expect(find.text('BHIM'), findsNothing);
  });

  testWidgets('proof screen displays amount with two decimals', (tester) async {
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(375, 812),
        builder: (_, _) => const MaterialApp(
          home: SubmitPaymentProofScreen(
            bill: {
              'id': 'bill-123',
              'communityId': 'community-123',
              'flatId': 'flat-123',
              'amount': 42.5,
            },
          ),
        ),
      ),
    );

    expect(find.text('₹42.50'), findsOneWidget);
  });
}
