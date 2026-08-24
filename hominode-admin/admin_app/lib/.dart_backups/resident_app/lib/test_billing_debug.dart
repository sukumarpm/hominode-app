// Test script to debug billing data fetch
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';

Future<void> testBillingFetch() async {
  print('═══════════════════════════════════════════════════════');
  print('🔍 BILLING DATA FETCH DEBUG');
  print('═══════════════════════════════════════════════════════');
  
  try {
    final auth = FirebaseAuth.instance;
    final firestore = FirebaseFirestore.instance;
    
    // 1. Check current user
    final user = auth.currentUser;
    if (user == null) {
      print('❌ No user logged in');
      return;
    }
    
    print('\n📱 CURRENT USER:');
    print('   UID: ${user.uid}');
    print('   Email: ${user.email}');
    
    // 2. Get user document
    print('\n📄 FETCHING USER DOCUMENT...');
    final userDoc = await firestore.collection('users').doc(user.uid).get();
    
    if (!userDoc.exists) {
      print('❌ User document not found');
      return;
    }
    
    final userData = userDoc.data()!;
    print('✅ User document found');
    print('   Name: ${userData['name']}');
    print('   FlatId: ${userData['flatId']}');
    print('   FlatLabel: ${userData['flatLabel']}');
    print('   ResidentId: ${userData['residentId']}');
    
    final flatId = userData['flatId'] as String?;
    
    if (flatId == null || flatId.isEmpty) {
      print('❌ No flatId assigned to user');
      return;
    }
    
    // 3. Query bills collection
    print('\n📋 QUERYING BILLS COLLECTION...');
    print('   Query: WHERE flatId == "$flatId"');
    
    final billsSnapshot = await firestore
        .collection('bills')
        .where('flatId', isEqualTo: flatId)
        .get();
    
    print('✅ Query completed');
    print('   Bills found: ${billsSnapshot.docs.length}');
    
    if (billsSnapshot.docs.isEmpty) {
      print('\n⚠️  NO BILLS FOUND');
      print('   Possible reasons:');
      print('   1. No bills exist for flatId: $flatId');
      print('   2. FlatId mismatch in bills collection');
      print('   3. Firestore rules blocking access');
      return;
    }
    
    // 4. Display each bill
    print('\n📊 BILLS DETAILS:');
    for (var doc in billsSnapshot.docs) {
      final bill = doc.data();
      print('\n   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      print('   Bill ID: ${doc.id}');
      print('   FlatId: ${bill['flatId']}');
      print('   FlatLabel: ${bill['flatLabel']}');
      print('   Amount: ${bill['amount']}');
      print('   Status: ${bill['status']}');
      print('   Month: ${bill['month']}');
      print('   Year: ${bill['year']}');
      print('   Type: ${bill['type']}');
      print('   ResidentName: ${bill['residentName']}');
      
      // Check for chargeBreakdown
      if (bill.containsKey('chargeBreakdown')) {
        print('   ChargeBreakdown:');
        final breakdown = bill['chargeBreakdown'] as Map<String, dynamic>;
        breakdown.forEach((key, value) {
          print('      $key: $value');
        });
      } else {
        print('   ⚠️  No chargeBreakdown field');
      }
      
      // Check due date
      if (bill.containsKey('dueDate')) {
        final dueDate = bill['dueDate'];
        if (dueDate is Timestamp) {
          print('   DueDate: ${dueDate.toDate()}');
        } else {
          print('   DueDate: $dueDate (not a Timestamp)');
        }
      }
    }
    
    // 5. Check pending bills
    print('\n📌 PENDING BILLS:');
    final pendingBills = billsSnapshot.docs
        .where((doc) => doc.data()['status'] == 'pending')
        .toList();
    
    print('   Pending bills count: ${pendingBills.length}');
    
    if (pendingBills.isNotEmpty) {
      final bill = pendingBills.first.data();
      print('   Current pending bill:');
      print('      Amount: ${bill['amount']}');
      print('      Month: ${bill['month']}');
      print('      Status: ${bill['status']}');
    }
    
    // 6. Check paid bills
    print('\n💰 PAID BILLS (Payment History):');
    final paidBills = billsSnapshot.docs
        .where((doc) => doc.data()['status'] == 'paid')
        .toList();
    
    print('   Paid bills count: ${paidBills.length}');
    
    for (var doc in paidBills) {
      final bill = doc.data();
      print('   - ${bill['month']} ${bill['year']}: ₹${bill['amount']} (${bill['paymentMethod'] ?? 'N/A'})');
    }
    
    print('\n═══════════════════════════════════════════════════════');
    print('✅ DEBUG COMPLETE');
    print('═══════════════════════════════════════════════════════');
    
  } catch (e, stackTrace) {
    print('\n❌ ERROR: $e');
    print('Stack trace: $stackTrace');
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  await testBillingFetch();
}
