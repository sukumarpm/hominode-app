// lib/src/services/billing_flow_function.dart
// Complete Billing & Maintenance Flow Function with proper Firestore integration

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class BillingFlowFunction {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// STEP 1: Validate Authentication
  /// Check if user is authenticated and get their UID
  Future<String?> _validateAuthentication() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        debugPrint('❌ BillingFlow: User not authenticated');
        return null;
      }
      debugPrint('✅ BillingFlow STEP 1: Authentication validated - UID: ${user.uid}');
      return user.uid;
    } catch (e) {
      debugPrint('❌ BillingFlow STEP 1 Error: $e');
      return null;
    }
  }

  /// STEP 2: Get User's FlatId
  /// Fetch user document to get their flatId
  Future<String?> _getUserFlatId(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      
      if (!userDoc.exists) {
        debugPrint('❌ BillingFlow STEP 2: User document not found');
        return null;
      }

      final flatId = userDoc.data()?['flatId'] as String?;
      if (flatId == null || flatId.isEmpty) {
        debugPrint('❌ BillingFlow STEP 2: No flatId found for user');
        return null;
      }

      debugPrint('✅ BillingFlow STEP 2: FlatId retrieved - $flatId');
      return flatId;
    } catch (e) {
      debugPrint('❌ BillingFlow STEP 2 Error: $e');
      return null;
    }
  }

  /// STEP 3: Fetch Bills by FlatId
  /// Query bills collection filtered by flatId
  Future<List<Map<String, dynamic>>> _fetchBillsByFlatId(String flatId) async {
    try {
      debugPrint('📋 BillingFlow STEP 3: Fetching bills for flatId: $flatId');

      final snapshot = await _firestore
          .collection('bills')
          .where('flatId', isEqualTo: flatId)
          .get();

      debugPrint('✅ BillingFlow STEP 3: Found ${snapshot.docs.length} bills');

      final bills = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();

      return bills;
    } catch (e) {
      debugPrint('❌ BillingFlow STEP 3 Error: $e');
      return [];
    }
  }

  /// STEP 4: Process Bills Data
  /// Sort, filter, and format bills for display
  List<Map<String, dynamic>> _processBillsData(List<Map<String, dynamic>> bills) {
    try {
      debugPrint('🔄 BillingFlow STEP 4: Processing ${bills.length} bills');

      // Sort by due date (newest first)
      bills.sort((a, b) {
        final aDate = (a['dueDate'] as Timestamp?)?.toDate() ?? DateTime.now();
        final bDate = (b['dueDate'] as Timestamp?)?.toDate() ?? DateTime.now();
        return bDate.compareTo(aDate);
      });

      // Add calculated fields
      for (var bill in bills) {
        bill['formattedAmount'] = '₹${bill['amount'] ?? 0}';
        bill['formattedDueDate'] = _formatDate(bill['dueDate']);
        bill['isPending'] = bill['status'] == 'pending';
        bill['isOverdue'] = _isOverdue(bill['dueDate']);
      }

      debugPrint('✅ BillingFlow STEP 4: Bills processed and formatted');
      return bills;
    } catch (e) {
      debugPrint('❌ BillingFlow STEP 4 Error: $e');
      return bills;
    }
  }

  /// STEP 5: Return Processed Bills
  /// Complete flow function - returns bills ready for display
  Future<List<Map<String, dynamic>>> getBillingData() async {
    try {
      debugPrint('🚀 BillingFlow: Starting complete flow function');

      // STEP 1: Validate Authentication
      final userId = await _validateAuthentication();
      if (userId == null) return [];

      // STEP 2: Get User's FlatId
      final flatId = await _getUserFlatId(userId);
      if (flatId == null) return [];

      // STEP 3: Fetch Bills by FlatId
      final bills = await _fetchBillsByFlatId(flatId);
      if (bills.isEmpty) {
        debugPrint('⚠️ BillingFlow: No bills found');
        return [];
      }

      // STEP 4: Process Bills Data
      final processedBills = _processBillsData(bills);

      debugPrint('✅ BillingFlow: Complete - Returning ${processedBills.length} bills');
      return processedBills;
    } catch (e) {
      debugPrint('❌ BillingFlow: Fatal error - $e');
      return [];
    }
  }

  /// Stream Bills in Real-time
  /// Returns a stream of bills that updates automatically
  Stream<List<Map<String, dynamic>>> streamBillingData() async* {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        debugPrint('❌ BillingFlow Stream: User not authenticated');
        yield [];
        return;
      }

      // Get user's flatId
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final flatId = userDoc.data()?['flatId'] as String?;
      
      if (flatId == null) {
        debugPrint('❌ BillingFlow Stream: No flatId found');
        yield [];
        return;
      }

      // Stream bills
      yield* _firestore
          .collection('bills')
          .where('flatId', isEqualTo: flatId)
          .snapshots()
          .map((snapshot) {
        final bills = snapshot.docs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id;
          return data;
        }).toList();

        return _processBillsData(bills);
      });
    } catch (e) {
      debugPrint('❌ BillingFlow Stream Error: $e');
      yield [];
    }
  }

  /// Get Total Pending Amount
  /// Calculate sum of all pending bills
  Future<double> getTotalPendingAmount() async {
    try {
      final bills = await getBillingData();
      double total = 0;

      for (var bill in bills) {
        if (bill['status'] == 'pending') {
          total += (bill['amount'] as num?)?.toDouble() ?? 0;
        }
      }

      debugPrint('💰 BillingFlow: Total pending amount: ₹$total');
      return total;
    } catch (e) {
      debugPrint('❌ BillingFlow: Error calculating total - $e');
      return 0;
    }
  }

  /// Helper: Format date
  String _formatDate(dynamic date) {
    try {
      if (date is Timestamp) {
        final dateTime = date.toDate();
        return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
      }
      return 'N/A';
    } catch (e) {
      return 'N/A';
    }
  }

  /// Helper: Check if bill is overdue
  bool _isOverdue(dynamic dueDate) {
    try {
      if (dueDate is Timestamp) {
        return dueDate.toDate().isBefore(DateTime.now());
      }
      return false;
    } catch (e) {
      return false;
    }
  }
}
