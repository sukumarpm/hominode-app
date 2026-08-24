// lib/src/services/bill_firestore_service.dart
// Firestore service for bills and payments - Optimized for fast fetching

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'user_data_service.dart';

class BillFirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final UserDataService _userDataService = UserDataService();

  static const String billsCollection = 'bills';
  static const String paymentsCollection = 'payments';
  static const String flatsCollection = 'flats';
  static const String usersCollection = 'users';

  // Cache for faster subsequent fetches
  Map<String, dynamic>? _cachedCurrentBill;
  List<Map<String, dynamic>>? _cachedPaymentHistory;
  DateTime? _lastFetchTime;

  // Cache duration: 30 seconds
  static const Duration _cacheDuration = Duration(seconds: 30);

  /// Clear cache (call when data changes)
  void clearCache() {
    _cachedCurrentBill = null;
    _cachedPaymentHistory = null;
    _lastFetchTime = null;
  }

  /// Check if cache is valid
  bool get _isCacheValid {
    if (_lastFetchTime == null) return false;
    return DateTime.now().difference(_lastFetchTime!) < _cacheDuration;
  }

  /// Resolve tenant authority plus the resident's secondary flat scope.
  Future<({String communityId, String flatId})?> _getResidentScope() async {
    try {
      final userData = await _userDataService.getCurrentUserData();

      if (userData == null) {
        print('❌ BillService: User data not found');
        return null;
      }

      final flatId = userData['flatId'] as String?;
      final communityId = userData['communityId'] as String?;

      if (flatId == null ||
          flatId.isEmpty ||
          communityId == null ||
          communityId.isEmpty) {
        print('⚠️ BillService: Community or flat not assigned to user');
        return null;
      }

      print('✅ BillService: Found flatId: $flatId');
      return (communityId: communityId, flatId: flatId);
    } catch (e) {
      print('❌ BillService: Error fetching flatId: $e');
      return null;
    }
  }

  /// Get all bills for current user by flatId with Firestore .where() filtering
  Future<List<Map<String, dynamic>>> getBills() async {
    try {
      final scope = await _getResidentScope();

      if (scope == null) {
        print('❌ BillService: Cannot fetch bills - No flatId');
        return [];
      }

      print('📋 BillService: Fetching bills by flatId');
      print('   flatId: ${scope.flatId}');

      // Use Firestore .where() for server-side filtering by flatId
      final snapshot = await _firestore
          .collection(billsCollection)
          .where('communityId', isEqualTo: scope.communityId)
          .where('flatId', isEqualTo: scope.flatId)
          .get();

      print('   ✓ Applied communityId and flatId tenant filters');

      final bills = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();

      // Sort by due date (newest first)
      bills.sort((a, b) {
        final aDate = (a['dueDate'] as Timestamp?)?.toDate() ?? DateTime.now();
        final bDate = (b['dueDate'] as Timestamp?)?.toDate() ?? DateTime.now();
        return bDate.compareTo(aDate);
      });

      print('✅ BillService: Fetched ${bills.length} bills by flatId');
      return bills;
    } catch (e, stackTrace) {
      print('❌ BillService: Error fetching bills: $e');
      print('   Stack trace: $stackTrace');
      return [];
    }
  }

  /// Get current pending bill by flatId with Firestore .where() filtering
  Future<Map<String, dynamic>?> getCurrentBill({
    bool forceRefresh = false,
  }) async {
    try {
      // Return cached bill if valid and not forcing refresh
      if (!forceRefresh && _isCacheValid && _cachedCurrentBill != null) {
        print('⚡ BillService: Returning cached current bill');
        return _cachedCurrentBill;
      }

      final scope = await _getResidentScope();

      if (scope == null) {
        print('❌ BillService: Cannot fetch current bill - No flatId');
        return null;
      }

      print('📋 BillService: Fetching pending bill by flatId');
      print('   flatId: ${scope.flatId}');

      // Use Firestore .where() for server-side filtering by flatId
      final snapshot = await _firestore
          .collection(billsCollection)
          .where('communityId', isEqualTo: scope.communityId)
          .where('status', isEqualTo: 'pending')
          .where('flatId', isEqualTo: scope.flatId)
          .get();

      print('   ✓ Applied communityId and flatId tenant filters');

      if (snapshot.docs.isEmpty) {
        print('ℹ️ BillService: No pending bills found');
        _cachedCurrentBill = null;
        _lastFetchTime = DateTime.now();
        return null;
      }

      // Get the most recent bill
      final matchingBills = snapshot.docs.toList();
      matchingBills.sort((a, b) {
        final aDate =
            (a.data()['dueDate'] as Timestamp?)?.toDate() ?? DateTime.now();
        final bDate =
            (b.data()['dueDate'] as Timestamp?)?.toDate() ?? DateTime.now();
        return bDate.compareTo(aDate);
      });

      final data = matchingBills.first.data();
      data['id'] = matchingBills.first.id;

      // Cache the result
      _cachedCurrentBill = data;
      _lastFetchTime = DateTime.now();

      print('✅ BillService: Found current bill (cached)');
      print('   Amount: ${data['amount']}');
      print('   Month: ${data['month']}');
      return data;
    } catch (e, stackTrace) {
      print('❌ BillService: Error fetching current bill: $e');
      print('   Stack trace: $stackTrace');
      return null;
    }
  }

  /// Get payment history (paid bills) by flatId with Firestore .where() filtering
  Future<List<Map<String, dynamic>>> getPaymentHistory({
    bool forceRefresh = false,
  }) async {
    try {
      // Return cached history if valid and not forcing refresh
      if (!forceRefresh && _isCacheValid && _cachedPaymentHistory != null) {
        print('⚡ BillService: Returning cached payment history');
        return _cachedPaymentHistory!;
      }

      final scope = await _getResidentScope();

      if (scope == null) {
        print('❌ Cannot fetch payment history: No flatId');
        return [];
      }

      print('📋 Fetching payment history by flatId');
      print('   flatId: ${scope.flatId}');

      // Use Firestore .where() for server-side filtering by flatId
      final snapshot = await _firestore
          .collection(billsCollection)
          .where('communityId', isEqualTo: scope.communityId)
          .where('status', isEqualTo: 'paid')
          .where('flatId', isEqualTo: scope.flatId)
          .get();

      print('   ✓ Applied communityId and flatId tenant filters');

      final payments = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();

      // Sort by paid date (newest first)
      payments.sort((a, b) {
        final aDate = (a['paidAt'] as Timestamp?)?.toDate() ?? DateTime.now();
        final bDate = (b['paidAt'] as Timestamp?)?.toDate() ?? DateTime.now();
        return bDate.compareTo(aDate);
      });

      // Limit to 10 most recent
      final limitedPayments = payments.take(10).toList();

      // Cache the result
      _cachedPaymentHistory = limitedPayments;
      _lastFetchTime = DateTime.now();

      print(
        '✅ Fetched ${limitedPayments.length} payment history records by flatId',
      );
      return limitedPayments;
    } catch (e) {
      print('❌ Error fetching payment history: $e');
      return [];
    }
  }

  /// Pay a bill (clears cache after payment)
  Future<bool> payBill({
    required String billId,
    required String paymentMethod,
    required String transactionId,
    required String paymentMode,
  }) async {
    try {
      // Try Firebase Auth first
      String? userId;

      final firebaseUser = _auth.currentUser;
      if (firebaseUser != null) {
        userId = firebaseUser.uid;
      } else {
        // Fallback to Firestore-only authentication
        final prefs = await SharedPreferences.getInstance();
        userId = prefs.getString('user_id');
      }

      if (userId == null) {
        print('❌ No user logged in');
        return false;
      }

      // Update bill status to paid
      await _firestore.collection(billsCollection).doc(billId).update({
        'status': 'paid',
        'paidAt': FieldValue.serverTimestamp(),
        'paymentMethod': paymentMethod,
        'transactionId': transactionId,
        'paymentMode': paymentMode,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Clear cache to force refresh
      clearCache();

      print('✅ Bill paid successfully: $billId (cache cleared)');
      return true;
    } catch (e) {
      print('❌ Error paying bill: $e');
      return false;
    }
  }

  /// Stream bills (real-time updates) by flatId with Firestore .where() filtering
  Stream<List<Map<String, dynamic>>> streamBills() async* {
    final scope = await _getResidentScope();

    if (scope == null) {
      print('❌ Cannot stream bills: No flatId');
      yield [];
      return;
    }

    print('📡 Streaming bills by flatId');
    print('   flatId: ${scope.flatId}');
    print('   ✓ Applied communityId and flatId tenant filters');

    // Use Firestore .where() for server-side filtering by flatId
    yield* _firestore
        .collection(billsCollection)
        .where('communityId', isEqualTo: scope.communityId)
        .where('flatId', isEqualTo: scope.flatId)
        .snapshots()
        .map((snapshot) {
          final bills = snapshot.docs.map((doc) {
            final data = doc.data();
            data['id'] = doc.id;
            return data;
          }).toList();

          // Sort by due date (newest first)
          bills.sort((a, b) {
            final aDate =
                (a['dueDate'] as Timestamp?)?.toDate() ?? DateTime.now();
            final bDate =
                (b['dueDate'] as Timestamp?)?.toDate() ?? DateTime.now();
            return bDate.compareTo(aDate);
          });

          print('📡 Streamed ${bills.length} bills by flatId');
          return bills;
        });
  }

  /// Get bill breakdown
  Map<String, double> getBillBreakdown(Map<String, dynamic> bill) {
    // Check if chargeBreakdown exists (nested structure)
    if (bill.containsKey('chargeBreakdown')) {
      final breakdown = bill['chargeBreakdown'] as Map<String, dynamic>?;
      if (breakdown != null) {
        return {
          'Electricity': (breakdown['Electricity'] as num?)?.toDouble() ?? 0,
          'Maintenance': (breakdown['Maintenance'] as num?)?.toDouble() ?? 0,
          'Parking': (breakdown['Parking'] as num?)?.toDouble() ?? 0,
          'Security': (breakdown['Security'] as num?)?.toDouble() ?? 0,
          'Service': (breakdown['Service'] as num?)?.toDouble() ?? 0,
          'Water': (breakdown['Water'] as num?)?.toDouble() ?? 0,
        };
      }
    }

    // Fallback to direct fields (old structure)
    return {
      'Maintenance': (bill['Maintenance'] as num?)?.toDouble() ?? 0,
      'Water': (bill['Water'] as num?)?.toDouble() ?? 0,
      'Parking': (bill['Parking'] as num?)?.toDouble() ?? 0,
      'Service': (bill['Service'] as num?)?.toDouble() ?? 0,
      'Security': (bill['Security'] as num?)?.toDouble() ?? 0,
      'Electricity': (bill['Electricity'] as num?)?.toDouble() ?? 0,
    };
  }

  /// Calculate total from breakdown
  double calculateTotal(Map<String, double> breakdown) {
    return breakdown.values.fold(0, (sum, value) => sum + value);
  }
}
