import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('approved transparent Admin artwork has transparent corners', () async {
    final data = await rootBundle.load('assets/branding/admin_transparent.png');
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    final frame = await codec.getNextFrame();
    final bytes = await frame.image.toByteData(
      format: ui.ImageByteFormat.rawRgba,
    );
    final width = frame.image.width;
    final height = frame.image.height;
    expect(width, 1254);
    expect(height, 1254);
    for (final pixel in [0, width - 1, (height - 1) * width, width * height - 1]) {
      expect(bytes!.getUint8(pixel * 4 + 3), 0);
    }
    frame.image.dispose();
    codec.dispose();
  });
}
