import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:admin_app/pending_residents_screen.dart';

void main() {
  Widget subject(ImageProvider image) => ScreenUtilInit(
    designSize: const Size(390, 844),
    builder: (_, __) => MaterialApp(
      home: Scaffold(body: IdentityProofReviewDialog(proofImage: image)),
    ),
  );

  FilledButton verifyButton(WidgetTester tester) => tester.widget<FilledButton>(
    find.ancestor(of: find.text('Verify'), matching: find.byType(FilledButton)),
  );

  testWidgets('Verify remains disabled until the proof preview loads', (
    tester,
  ) async {
    final provider = _ControlledImageProvider();

    await tester.pumpWidget(subject(provider));
    expect(verifyButton(tester).onPressed, isNull);

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, 1, 1),
      Paint()..color = Colors.blue,
    );
    final image = await recorder.endRecording().toImage(1, 1);
    provider.complete(ImageInfo(image: image));
    await tester.pump();
    expect(verifyButton(tester).onPressed, isNotNull);
  });

  testWidgets('preview failure cannot enable verification', (tester) async {
    final provider = _ControlledImageProvider();
    await tester.pumpWidget(subject(provider));
    provider.fail(StateError('preview failed'));
    await tester.pump();

    expect(
      find.text('The proof preview could not be loaded. Do not verify it.'),
      findsOneWidget,
    );
    expect(verifyButton(tester).onPressed, isNull);
    expect(find.text('Reject'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
  });
}

class _ControlledImageProvider extends ImageProvider<_ControlledImageProvider> {
  final Completer<ImageInfo> _result = Completer<ImageInfo>();

  void complete(ImageInfo image) => _result.complete(image);

  void fail(Object error) => _result.completeError(error);

  @override
  Future<_ControlledImageProvider> obtainKey(
    ImageConfiguration configuration,
  ) => SynchronousFuture<_ControlledImageProvider>(this);

  @override
  ImageStreamCompleter loadImage(
    _ControlledImageProvider key,
    ImageDecoderCallback decode,
  ) => OneFrameImageStreamCompleter(_result.future);
}
