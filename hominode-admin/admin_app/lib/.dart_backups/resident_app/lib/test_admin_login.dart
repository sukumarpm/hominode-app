// lib/test_admin_login.dart
// Test admin login flow

import 'package:flutter/material.dart';
import 'src/services/admin_login_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  print('\n═══════════════════════════════════════════════════');
  print('🧪 TESTING ADMIN LOGIN FLOW');
  print('═══════════════════════════════════════════════════\n');

  final loginService = AdminLoginService.instance;

  // Test with the admin credentials from Firestore
  // Email: admin@lyvo.com
  // Password: (you need to set this in Firebase)
  
  print('Testing admin login with email and password...\n');
  
  final result = await loginService.loginAsAdmin(
    identifier: 'preethampriyatharson07@gmail.com',
    password: 'iQ2joLPr',
  );

  print('\n═══════════════════════════════════════════════════');
  print('📊 LOGIN RESULT');
  print('═══════════════════════════════════════════════════\n');
  
  print('Success: ${result.success}');
  print('Message: ${result.message}');
  print('Admin ID: ${result.adminId}');
  print('Building ID: ${result.buildingId}');
  print('Error Code: ${result.errorCode}');
  
  if (result.userData != null) {
    print('\nUser Data:');
    result.userData!.forEach((key, value) {
      print('  $key: $value');
    });
  }

  print('\n═══════════════════════════════════════════════════\n');

  // Check login state
  final isLoggedIn = await loginService.isAdminLoggedIn();
  print('Is Admin Logged In: $isLoggedIn');
  
  final adminId = await loginService.getCurrentAdminId();
  print('Current Admin ID: $adminId');
  
  final buildingId = await loginService.getCurrentBuildingId();
  print('Current Building ID: $buildingId');

  print('\n═══════════════════════════════════════════════════\n');
}
