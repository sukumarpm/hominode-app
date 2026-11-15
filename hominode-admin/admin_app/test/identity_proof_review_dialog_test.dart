import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:admin_app/pending_residents_screen.dart';

import 'helpers/admin_test_localization.dart';

void main() {
  setUpAll(initializeAdminTestLocalization);

  Widget subject(ImageProvider image) => localizedAdminTestApp(
    Scaffold(
      body: IdentityProofReviewDialog(
        proofImage: image,
        onReview: (_) async {},
      ),
    ),
  );

  FilledButton verifyButton(WidgetTester tester) => tester.widget<FilledButton>(
    find.ancestor(of: find.text('Verify'), matching: find.byType(FilledButton)),
  );

  testWidgets('Verify remains disabled until the proof preview loads', (
    tester,
  ) async {
    final provider = _ControlledImageProvider();

    await _mount(tester, subject(provider));
    await tester.pump();
    expect(verifyButton(tester).onPressed, isNull);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Loading identity proof...'), findsOneWidget);
    expect(
      tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
      isNull,
    );

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, 1, 1),
      Paint()..color = Colors.blue,
    );
    final picture = recorder.endRecording();
    final image = await tester.runAsync(() => picture.toImage(1, 1));
    picture.dispose();
    provider.complete(ImageInfo(image: image!));
    await tester.pumpAndSettle();
    expect(verifyButton(tester).onPressed, isNotNull);
    expect(find.byType(RawImage), findsOneWidget);
    expect(
      tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
      isNotNull,
    );
  });

  testWidgets(
    'approval waits for backend, blocks duplicates and retains errors for retry',
    (tester) async {
      final provider = _ControlledImageProvider();
      var pending = Completer<void>();
      var calls = 0;
      bool? result;
      await _mount(
        tester,
        localizedAdminTestApp(
          Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  result = await showDialog<bool>(
                    context: context,
                    barrierDismissible: false,
                    builder: (_) => IdentityProofReviewDialog(
                      proofImage: provider,
                      onReview: (_) {
                        calls++;
                        return pending.future;
                      },
                    ),
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open'));
      await tester.pump(const Duration(milliseconds: 300));
      final recorder = ui.PictureRecorder();
      Canvas(recorder).drawRect(const Rect.fromLTWH(0, 0, 1, 1), Paint());
      final picture = recorder.endRecording();
      final image = await tester.runAsync(() => picture.toImage(1, 1));
      picture.dispose();
      provider.complete(ImageInfo(image: image!));
      await tester.pumpAndSettle();
      final submit = verifyButton(tester).onPressed!;
      submit();
      submit();
      await tester.pump();
      expect(calls, 1);
      expect(result, isNull);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      pending.completeError(StateError('Approval failed'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Approval failed'), findsOneWidget);
      expect(result, isNull);
      pending = Completer<void>();
      await tester.tap(find.text('Verify'));
      await tester.pump();
      expect(calls, 2);
      pending.complete();
      await tester.pumpAndSettle();
      expect(result, true);
      expect(find.byType(IdentityProofReviewDialog), findsNothing);
    },
  );

  testWidgets('preview failure cannot enable verification', (tester) async {
    final provider = _ControlledImageProvider();
    await _mount(tester, subject(provider));
    await tester.pump();
    expect(verifyButton(tester).onPressed, isNull);
    provider.fail(StateError('preview failed'));
    await tester.pumpAndSettle();

    expect(find.text('Unable to load identity proof'), findsOneWidget);
    expect(verifyButton(tester).onPressed, isNull);
    expect(find.text('Reject Identity Proof'), findsOneWidget);
    expect(
      tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
      isNull,
    );
    expect(find.text('Retry'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    expect(verifyButton(tester).onPressed, isNull);
    expect(tester.takeException(), isNull);
  });

  Widget loadingSubject(
    Future<ImageProvider?> Function() load, {
    String residentId = 'a',
    Duration timeout = const Duration(seconds: 30),
    Future<void> Function(bool)? onReview,
  }) => localizedAdminTestApp(
    Scaffold(
      body: IdentityProofReviewDialog(
        residentId: residentId,
        loadProof: load,
        loadTimeout: timeout,
        onReview: onReview ?? (_) async {},
      ),
    ),
  );

  testWidgets(
    'delayed retrieval shows loading and disables both review actions without duplicate fetches',
    (tester) async {
      final pending = Completer<ImageProvider?>();
      var calls = 0;
      Future<ImageProvider?> load() {
        calls++;
        return pending.future;
      }

      await _mount(tester, loadingSubject(load));
      await tester.pump(const Duration(seconds: 2));
      expect(find.text('Loading identity proof...'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(verifyButton(tester).onPressed, isNull);
      expect(
        tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
        isNull,
      );
      expect(
        tester
            .widget<TextButton>(
              find.ancestor(
                of: find.text('Cancel'),
                matching: find.byType(TextButton),
              ),
            )
            .onPressed,
        isNotNull,
      );
      await _mount(tester, loadingSubject(load));
      expect(calls, 1);
      pending.complete(null);
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'retrieval failure shows a safe error and Retry can load the proof',
    (tester) async {
      final pending = Completer<ImageProvider?>();
      final provider = _ControlledImageProvider();
      var calls = 0;
      Future<ImageProvider?> load() {
        calls++;
        return calls == 1 ? pending.future : Future.value(provider);
      }

      await _mount(tester, loadingSubject(load));
      pending.completeError(StateError('sensitive signed URL must not appear'));
      await tester.pumpAndSettle();
      expect(find.text('Unable to load identity proof'), findsOneWidget);
      expect(find.textContaining('sensitive signed URL'), findsNothing);
      expect(verifyButton(tester).onPressed, isNull);
      final retry = tester
          .widget<TextButton>(
            find.ancestor(
              of: find.text('Retry'),
              matching: find.byType(TextButton),
            ),
          )
          .onPressed!;
      retry();
      retry();
      await tester.pump();
      expect(calls, 2);
      expect(find.text('Loading identity proof...'), findsOneWidget);
      final image = await _image(tester);
      provider.complete(ImageInfo(image: image));
      await tester.pumpAndSettle();
      expect(verifyButton(tester).onPressed, isNotNull);
      expect(find.byType(RawImage), findsOneWidget);
    },
  );

  testWidgets(
    'confirmed missing upload has a distinct message and disabled review buttons',
    (tester) async {
      await _mount(tester, loadingSubject(() async => null));
      await tester.pumpAndSettle();
      expect(
        find.text('No uploaded identity proof was found for this Resident.'),
        findsOneWidget,
      );
      expect(find.text('Unable to load identity proof'), findsNothing);
      expect(verifyButton(tester).onPressed, isNull);
      expect(
        tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
        isNull,
      );
    },
  );

  testWidgets('timeout ends loading and ignores late retrieval completion', (
    tester,
  ) async {
    final pending = Completer<ImageProvider?>();
    await _mount(
      tester,
      loadingSubject(() => pending.future, timeout: const Duration(seconds: 3)),
    );
    await tester.pump(const Duration(seconds: 4));
    expect(find.text('Unable to load identity proof'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    pending.complete(_ControlledImageProvider());
    await tester.pump();
    expect(find.text('Unable to load identity proof'), findsOneWidget);
    expect(verifyButton(tester).onPressed, isNull);
  });

  testWidgets(
    'Cancel during retrieval dismisses safely and late failure is ignored',
    (tester) async {
      final pending = Completer<ImageProvider?>();
      await _mount(
        tester,
        localizedAdminTestApp(
          Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => IdentityProofReviewDialog(
                    loadProof: () => pending.future,
                    onReview: (_) async {},
                  ),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.byType(IdentityProofReviewDialog), findsNothing);
      pending.completeError(StateError('late fetch failure'));
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('changing Resident ignores the previous retrieval', (
    tester,
  ) async {
    final first = Completer<ImageProvider?>();
    final second = Completer<ImageProvider?>();
    await _mount(tester, loadingSubject(() => first.future));
    await _mount(tester, loadingSubject(() => second.future, residentId: 'b'));
    first.complete(null);
    await tester.pump();
    expect(find.text('Loading identity proof...'), findsOneWidget);
    expect(
      find.text('No uploaded identity proof was found for this Resident.'),
      findsNothing,
    );
    second.complete(null);
    await tester.pumpAndSettle();
    expect(
      find.text('No uploaded identity proof was found for this Resident.'),
      findsOneWidget,
    );
  });

  testWidgets('preview timeout cannot be revived by a late decoded image', (
    tester,
  ) async {
    final provider = _ControlledImageProvider();
    await _mount(
      tester,
      loadingSubject(() async => provider, timeout: const Duration(seconds: 2)),
    );
    await tester.pump(const Duration(seconds: 3));
    expect(find.text('Unable to load identity proof'), findsOneWidget);
    provider.complete(ImageInfo(image: await _image(tester)));
    await tester.pumpAndSettle();
    expect(verifyButton(tester).onPressed, isNull);
    expect(find.byType(RawImage), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('dismissal during image decoding ignores late completion', (
    tester,
  ) async {
    final provider = _ControlledImageProvider();
    await _mount(tester, loadingSubject(() async => provider));
    await _mount(tester, const MaterialApp(home: Text('Closed')));
    provider.complete(ImageInfo(image: await _image(tester)));
    await tester.pumpAndSettle();
    expect(find.text('Closed'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Reject waits for backend and returns the existing false decision',
    (tester) async {
      final provider = _ControlledImageProvider();
      final pending = Completer<void>();
      final decisions = <bool>[];
      bool? result;
      await _mount(
        tester,
        localizedAdminTestApp(
          Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  result = await showDialog<bool>(
                    context: context,
                    builder: (_) => IdentityProofReviewDialog(
                      proofImage: provider,
                      onReview: (value) {
                        decisions.add(value);
                        return pending.future;
                      },
                    ),
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pump(const Duration(milliseconds: 300));
      provider.complete(ImageInfo(image: await _image(tester)));
      await tester.pumpAndSettle();
      final reject = tester
          .widget<OutlinedButton>(find.byType(OutlinedButton))
          .onPressed!;
      reject();
      reject();
      await tester.pump();
      expect(decisions, [false]);
      expect(result, isNull);
      pending.complete();
      await tester.pumpAndSettle();
      expect(result, false);
      expect(find.byType(IdentityProofReviewDialog), findsNothing);
    },
  );
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

Future<ui.Image> _image(WidgetTester tester) async {
  final recorder = ui.PictureRecorder();
  Canvas(recorder).drawRect(const Rect.fromLTWH(0, 0, 2, 2), Paint());
  final picture = recorder.endRecording();
  final image = await tester.runAsync(() => picture.toImage(2, 2));
  picture.dispose();
  return image!;
}

Future<void> _mount(WidgetTester tester, Widget widget) async {
  await tester.pumpWidget(widget);
  // The localization wrapper resolves before its child is mounted.
  await tester.pump();
  await tester.pump();
}
