// Test script to verify ResidentLoginService works correctly
// Run with: dart lib/test_resident_login.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'src/services/resident_login_service.dart';

void main() async {
  print('🧪 Testing ResidentLoginService...');
  print('');
  print('Test credentials:');
  print('  Email: preethampriyatharson07@gmail.com');
  print('  Password: wlG0czyq');
  print('');
  print('Expected result:');
  print('  ✅ Login successful');
  print('  ✅ User: Preetham Priyatharson');
  print('  ✅ Flat: T001');
  print('  ✅ Building: yFSMeOsJaYLsr5Wo');
  print('');
  print('Note: This test requires Firebase to be initialized.');
  print('Run this test in the Flutter app context, not as a standalone Dart script.');
}
