import 'package:admin_app/admin_login_desktop.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('desktop login is selected at and above 1024 pixels', () {
    expect(adminLoginLayoutForWidth(1024), AdminLoginLayout.desktop);
    expect(adminLoginLayoutForWidth(1366), AdminLoginLayout.desktop);
  });

  test('existing mobile login remains selected below 1024 pixels', () {
    expect(adminLoginLayoutForWidth(1023.99), AdminLoginLayout.mobile);
    expect(adminLoginLayoutForWidth(390), AdminLoginLayout.mobile);
  });
}
