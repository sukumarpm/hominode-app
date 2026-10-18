import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('existing transparent Admin artwork has transparent corners', () async {
    final data = await rootBundle.load('assets/Admin_New1.png');
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    final frame = await codec.getNextFrame();
    final bytes = await frame.image.toByteData(
      format: ui.ImageByteFormat.rawRgba,
    );
    expect(bytes!.getUint8(3), 0);
    frame.image.dispose();
    codec.dispose();
  });
}
