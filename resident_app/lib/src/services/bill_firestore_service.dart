// lib/src/services/bill_firestore_service.dart
// Firestore service for bills and payments - Optimized for fast fetching

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'user_data_service.dart';

class BillFirestoreService {
  BillFirestoreService({
    FirebaseFirestore? firestore,
    UserDataService? userDataService,
    Stream<List<Map<String, dynamic>>> Function()? billsStreamLoader,
    Stream<Map<String, dynamic>?> Function(String billId)?
    v1PaymentStreamLoader,
    Stream<Map<String, dynamic>?> Function(String billId)? v2ProofStreamLoader,
  }) : _firestore = firestore,
       _userDataService = userDataService,
       _billsStreamLoader = billsStreamLoader,
       _v1PaymentStreamLoader = v1PaymentStreamLoader,
       _v2ProofStreamLoader = v2ProofStreamLoader;

  final FirebaseFirestore? _firestore;
  final UserDataService? _userDataService;
  final Stream<List<Map<String, dynamic>>> Function()? _billsStreamLoader;
  final Stream<Map<String, dynamic>?> Function(String billId)?
  _v1PaymentStreamLoader;
  final Stream<Map<String, dynamic>?> Function(String billId)?
  _v2ProofStreamLoader;

  FirebaseFirestore get firestore => _firestore ?? FirebaseFirestore.instance;
  UserDataService get userDataService => _userDataService ?? UserDataService();

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

  Stream<Map<String, dynamic>?> streamLatestPaymentForBill(
    String billId,
  ) async* {
    final injected = _v1PaymentStreamLoader;
    if (injected != null) {
      yield* injected(billId);
      return;
    }
    final scope = await _getResidentScope();
    final user = FirebaseAuth.instance.currentUser;

    if (scope == null || user == null || billId.isEmpty) {
      yield null;
      return;
    }

    print('💳 Streaming payments for bill: $billId');
    print('   communityId: ${scope.communityId}');
    print('   flatId: ${scope.flatId}');
    print('   userId: ${user.uid}');

    yield* firestore
        .collection(paymentsCollection)
        .where('communityId', isEqualTo: scope.communityId)
        .where('flatId', isEqualTo: scope.flatId)
        .where('billId', isEqualTo: billId)
        .where('userId', isEqualTo: user.uid)
        .snapshots()
        .map((snapshot) {
          if (snapshot.docs.isEmpty) {
            print('💳 No payment submissions found');
            return null;
          }

          final docs = snapshot.docs.toList();

          docs.sort((a, b) {
            final aDate =
                (a.data()['createdAt'] as Timestamp?)?.toDate() ??
                DateTime.fromMillisecondsSinceEpoch(0);

            final bDate =
                (b.data()['createdAt'] as Timestamp?)?.toDate() ??
                DateTime.fromMillisecondsSinceEpoch(0);

            return bDate.compareTo(aDate);
          });

          final data = Map<String, dynamic>.from(docs.first.data());
          data['id'] = docs.first.id;

          print(
            '💳 Latest payment: ${docs.first.id}, '
            'status=${data['status']}',
          );

          return data;
        });
  }

  /// V2 proofs are private to their canonical resident and bill context.
  /// This stream never reads the legacy `payments` collection.
  Stream<Map<String, dynamic>?> streamLatestV2ProofForBill(
    String billId,
  ) async* {
    final injected = _v2ProofStreamLoader;
    if (injected != null) {
      yield* injected(billId);
      return;
    }
    final scope = await _getResidentScope();
    final user = FirebaseAuth.instance.currentUser;
    if (scope == null || user == null || billId.isEmpty) {
      yield null;
      return;
    }

    yield* firestore
        .collection('paymentProofsV2')
        .where('communityId', isEqualTo: scope.communityId)
        .where('residentId', isEqualTo: user.uid)
        .where('billId', isEqualTo: billId)
        .snapshots()
        .map((snapshot) {
          final proofs = snapshot.docs.map((doc) {
            return <String, dynamic>{...doc.data(), 'id': doc.id};
          }).toList();
          proofs.sort((first, second) {
            final firstAt = first['submittedAt'] as Timestamp?;
            final secondAt = second['submittedAt'] as Timestamp?;
            return (secondAt?.millisecondsSinceEpoch ?? 0).compareTo(
              firstAt?.millisecondsSinceEpoch ?? 0,
            );
          });
          return proofs.isEmpty ? null : proofs.first;
        });
  }

  /// Resolve tenant authority plus the resident's secondary flat scope.
  Future<({String communityId, String flatId})?> _getResidentScope() async {
    try {
      final userData = await userDataService.getCurrentUserData();

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
      final snapshot = await firestore
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
      final snapshot = await firestore
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
      final snapshot = await firestore
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

  /// Stream bills (real-time updates) by flatId with Firestore .where() filtering
  Stream<List<Map<String, dynamic>>> streamBills() async* {
    final injected = _billsStreamLoader;
    if (injected != null) {
      yield* injected();
      return;
    }
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
    yield* firestore
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
    if (isV2Bill(bill)) {
      return {};
    }
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

  static bool isV2Bill(Map<String, dynamic> bill) => bill['schemaVersion'] == 2;

  static bool isV2InrBill(Map<String, dynamic> bill) =>
      isV2Bill(bill) && bill['currency'] == 'INR';

  static String formatV2BillMinorUnits(
    Map<String, dynamic> bill,
    Object? value,
  ) => isV2InrBill(bill) ? formatInrMinorUnits(value) : '—';

  /// Formats V2 integer paise without converting through a floating point
  /// value. Returns an em dash for malformed data so it cannot look payable.
  static String formatInrMinorUnits(Object? value) {
    if (value is! int || value < 0 || value > 9007199254740991) return '—';
    final whole = value ~/ 100;
    final paise = (value % 100).toString().padLeft(2, '0');
    return '₹$whole.$paise';
  }

  static List<BillChargeLine> getV2ChargeLines(Map<String, dynamic> bill) {
    if (!isV2InrBill(bill) || bill['chargeLines'] is! List) return const [];
    return (bill['chargeLines'] as List).whereType<Map>().map((line) {
      final amount = line['amountMinor'];
      return BillChargeLine(
        label: line['label'] is String && (line['label'] as String).isNotEmpty
            ? line['label'] as String
            : 'Charge',
        amountMinor: amount is int && amount >= 0 ? amount : null,
      );
    }).toList();
  }
}

class BillChargeLine {
  const BillChargeLine({required this.label, required this.amountMinor});

  final String label;
  final int? amountMinor;
}
