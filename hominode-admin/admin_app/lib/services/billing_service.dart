import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../models/notification_models.dart';
import 'admin_service.dart';
import 'notification_firestore_service.dart';

String formatPaymentMethod(Object? value) {
  final method = value is String ? value.trim().toLowerCase() : '';
  return switch (method) {
    'upi' => 'UPI',
    'cash' => 'Cash',
    'bank_transfer' => 'Bank Transfer',
    'cheque' => 'Cheque',
    'manual' => 'Manual',
    'external' => 'External',
    '' => 'Not recorded',
    _ =>
      method
          .replaceAll(RegExp(r'[_-]+'), ' ')
          .split(' ')
          .map(
            (part) => part.isEmpty
                ? part
                : '${part[0].toUpperCase()}${part.substring(1)}',
          )
          .join(' '),
  };
}

const List<String> offlinePaymentMethodOptions = [
  'Cash',
  'Bank Transfer',
  'Cheque',
];

String offlinePaymentMethodValue(String label) => switch (label) {
  'Cash' => 'cash',
  'Bank Transfer' => 'bank_transfer',
  'Cheque' => 'cheque',
  _ => throw ArgumentError.value(
    label,
    'label',
    'Unsupported offline payment method',
  ),
};

const int _safePaymentMinorUnitMax = 9007199254740991;

bool _isValidFirestoreDocumentId(String value) {
  return value.isNotEmpty &&
      value == value.trim() &&
      !value.contains('/') &&
      !RegExp(r'^__.*__$').hasMatch(value) &&
      utf8.encode(value).length <= 1500;
}

/// Validates the complete callable result against the exact submitted amount.
/// Invalid responses must remain unresolved so the persisted request can retry.
Map<String, dynamic> validateOfflinePaymentResultV2(
  Object? value, {
  required int submittedAmountMinor,
}) {
  if (submittedAmountMinor <= 0 ||
      submittedAmountMinor > _safePaymentMinorUnitMax) {
    throw const FormatException('Invalid submitted offline payment amount.');
  }
  if (value is! Map) {
    throw const FormatException('Invalid offline payment response.');
  }

  final record = Map<String, dynamic>.from(value);
  final transactionId = record['transactionId'];
  final rawAllocations = record['allocations'];
  final excessCreditMinor = record['excessCreditMinor'];
  final alreadyCompleted = record['alreadyCompleted'];
  if (record['success'] != true ||
      transactionId is! String ||
      !_isValidFirestoreDocumentId(transactionId) ||
      rawAllocations is! List ||
      excessCreditMinor is! int ||
      excessCreditMinor < 0 ||
      excessCreditMinor > _safePaymentMinorUnitMax ||
      alreadyCompleted is! bool) {
    throw const FormatException('Invalid offline payment response.');
  }

  final allocations = <Map<String, dynamic>>[];
  final seenBillIds = <String>{};
  var totalMinor = BigInt.from(excessCreditMinor);
  for (final rawAllocation in rawAllocations) {
    if (rawAllocation is! Map) {
      throw const FormatException('Invalid offline payment allocation.');
    }
    final allocation = Map<String, dynamic>.from(rawAllocation);
    final billId = allocation['billId'];
    final amountMinor = allocation['amountMinor'];
    if (billId is! String ||
        !_isValidFirestoreDocumentId(billId) ||
        amountMinor is! int ||
        amountMinor <= 0 ||
        amountMinor > _safePaymentMinorUnitMax ||
        !seenBillIds.add(billId)) {
      throw const FormatException('Invalid offline payment allocation.');
    }
    totalMinor += BigInt.from(amountMinor);
    allocations.add({'billId': billId, 'amountMinor': amountMinor});
  }
  if (totalMinor != BigInt.from(submittedAmountMinor)) {
    throw const FormatException('Offline payment result amount mismatch.');
  }

  return {
    'success': true,
    'transactionId': transactionId,
    'allocations': allocations,
    'excessCreditMinor': excessCreditMinor,
    'alreadyCompleted': alreadyCompleted,
  };
}

String? formatSettlementAttribution(Object? paymentMethod) {
  final method = paymentMethod is String
      ? paymentMethod.trim().toLowerCase()
      : '';
  return switch (method) {
    'upi' => 'Verified by Admin',
    'cash' || 'bank_transfer' || 'cheque' || 'manual' => 'Recorded by Admin',
    _ => null,
  };
}

class BillingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'bills';
  final AdminService _adminService = AdminService();
  final NotificationFirestoreService _notificationService =
      NotificationFirestoreService();
  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(
    region: 'asia-southeast1',
  );

  Stream<Map<String, dynamic>?> streamPendingPaymentForBill({
    required String communityId,
    required String billId,
  }) {
    print('💳 ADMIN PAYMENT QUERY');
    print('   communityId: $communityId');
    print('   billId: $billId');

    return _firestore
        .collection('payments')
        .where('communityId', isEqualTo: communityId)
        .where('billId', isEqualTo: billId)
        .snapshots()
        .map((snapshot) {
          print(
            '💳 ADMIN PAYMENT QUERY RESULT: '
            '${snapshot.docs.length} documents',
          );

          for (final doc in snapshot.docs) {
            print(
              '   ${doc.id}: '
              'status=${doc.data()['status']}, '
              'receiptPath=${doc.data()['receiptPath']}',
            );
          }

          if (snapshot.docs.isEmpty) {
            return null;
          }

          final pending = snapshot.docs
              .where(
                (doc) =>
                    doc.data()['status']?.toString().toLowerCase() == 'pending',
              )
              .toList();

          if (pending.isEmpty) {
            print('💳 No pending payment proof found');
            return null;
          }

          pending.sort((a, b) {
            final aDate =
                (a.data()['createdAt'] as Timestamp?)?.toDate() ??
                DateTime.fromMillisecondsSinceEpoch(0);

            final bDate =
                (b.data()['createdAt'] as Timestamp?)?.toDate() ??
                DateTime.fromMillisecondsSinceEpoch(0);

            return bDate.compareTo(aDate);
          });

          final data = Map<String, dynamic>.from(pending.first.data());

          data['id'] = pending.first.id;

          print(
            '✅ Pending payment proof found: '
            '${pending.first.id}',
          );

          return data;
        });
  }

  /// Streams the newest pending V2 proof for a bill, isolated from V1 payments.
  Stream<Map<String, dynamic>?> streamPendingV2PaymentProofForBill({
    required String communityId,
    required String billId,
  }) {
    if (communityId.trim().isEmpty || billId.trim().isEmpty) {
      return Stream.value(null);
    }
    return _firestore
        .collection('paymentProofsV2')
        .where('communityId', isEqualTo: communityId)
        .where('billId', isEqualTo: billId)
        .snapshots()
        .map((snapshot) {
          final pending = snapshot.docs.where((doc) {
            final data = doc.data();
            return data['schemaVersion'] == 2 &&
                data['communityId'] == communityId &&
                data['billId'] == billId &&
                data['status'] == 'pending' &&
                data['residentId'] is String &&
                (data['residentId'] as String).trim().isNotEmpty &&
                data['userId'] == data['residentId'] &&
                data['id'] == doc.id &&
                data['currency'] == 'INR' &&
                data['submittedAmountMinor'] is int &&
                (data['submittedAmountMinor'] as int) > 0 &&
                (data['submittedAmountMinor'] as int) <= 9007199254740991 &&
                data['receiptPath'] is String &&
                (data['receiptPath'] as String).trim().isNotEmpty &&
                (data['receiptPath'] as String).startsWith(
                  'payment_receipts/$communityId/$billId/'
                  '${data['residentId']}/${doc.id}.',
                ) &&
                data['submittedAt'] is Timestamp;
          }).toList();
          if (pending.isEmpty) return null;
          pending.sort((a, b) {
            final aDate = a.data()['submittedAt'];
            final bDate = b.data()['submittedAt'];
            final aMillis = aDate is Timestamp
                ? aDate.millisecondsSinceEpoch
                : 0;
            final bMillis = bDate is Timestamp
                ? bDate.millisecondsSinceEpoch
                : 0;
            return bMillis.compareTo(aMillis);
          });
          return {...pending.first.data(), 'id': pending.first.id};
        });
  }

  Future<Uint8List> loadPaymentReceipt(String receiptPath) async {
    if (receiptPath.trim().isEmpty) {
      throw Exception('Payment receipt path is missing');
    }

    final data = await _storage
        .ref()
        .child(receiptPath)
        .getData(10 * 1024 * 1024);

    if (data == null) {
      throw Exception('Payment receipt could not be loaded');
    }

    return data;
  }

  Future<void> verifyPaymentProof(String paymentId) async {
    final callable = _functions.httpsCallable('verifyPaymentProof');

    await callable.call({'paymentId': paymentId});
  }

  Future<void> verifyPaymentProofV2(String paymentId) async {
    final id = paymentId.trim();
    if (id.isEmpty) throw ArgumentError.value(paymentId, 'paymentId');
    await _functions.httpsCallable('verifyPaymentProofV2').call({
      'paymentId': id,
    });
  }

  Future<void> rejectPaymentProof({
    required String paymentId,
    required String rejectionReason,
  }) async {
    final callable = _functions.httpsCallable('rejectPaymentProof');

    await callable.call({
      'paymentId': paymentId,
      'rejectionReason': rejectionReason.trim(),
    });
  }

  Future<void> rejectPaymentProofV2({
    required String paymentId,
    required String rejectionReason,
  }) async {
    final id = paymentId.trim();
    final reason = rejectionReason.trim();
    if (id.isEmpty) throw ArgumentError.value(paymentId, 'paymentId');
    if (reason.isEmpty || reason.length > 1000) {
      throw ArgumentError.value(rejectionReason, 'rejectionReason');
    }
    await _functions.httpsCallable('rejectPaymentProofV2').call({
      'paymentId': id,
      'rejectionReason': reason,
    });
  }

  Future<Map<String, dynamic>> recordOfflinePaymentV2({
    required String communityId,
    required String residentId,
    required int amountMinor,
    required String paymentMethod,
    String? paymentReference,
    required String idempotencyKey,
  }) async {
    const safeIntegerMax = 9007199254740991;
    final community = communityId.trim();
    final resident = residentId.trim();
    final reference = paymentReference?.trim();
    if (community.isEmpty) {
      throw ArgumentError.value(communityId, 'communityId');
    }
    if (resident.isEmpty) {
      throw ArgumentError.value(residentId, 'residentId');
    }
    if (amountMinor <= 0 || amountMinor > safeIntegerMax) {
      throw ArgumentError.value(amountMinor, 'amountMinor');
    }
    if (!const {'cash', 'bank_transfer', 'cheque'}.contains(paymentMethod)) {
      throw ArgumentError.value(paymentMethod, 'paymentMethod');
    }
    if (idempotencyKey.trim().isEmpty) {
      throw ArgumentError.value(idempotencyKey, 'idempotencyKey');
    }
    if (reference != null && reference.length > 200) {
      throw ArgumentError.value(paymentReference, 'paymentReference');
    }
    final response = await _functions
        .httpsCallable('recordOfflinePaymentV2')
        .call({
          'communityId': community,
          'residentId': resident,
          'amountMinor': amountMinor,
          'paymentMethod': paymentMethod,
          'paymentReference': reference == null || reference.isEmpty
              ? null
              : reference,
          // The UI owns attempt creation; retries must pass this same key.
          'idempotencyKey': idempotencyKey,
        });
    return validateOfflinePaymentResultV2(
      response.data,
      submittedAmountMinor: amountMinor,
    );
  }

  final FirebaseStorage _storage = FirebaseStorage.instance;
  // Get all bills filtered by adminId (multi-tenancy)
  Stream<List<BillModel>> getBills(String communityId) {
    return _firestore
        .collection(_collection)
        .where('communityId', isEqualTo: communityId)
        .snapshots()
        .map((snapshot) {
          // Sort in memory instead of using orderBy to avoid index requirement
          final bills = snapshot.docs.map((doc) {
            final data = doc.data();
            return BillModel.fromMap(doc.id, data);
          }).toList();

          // Sort by createdAt descending (newest first)
          bills.sort((a, b) {
            if (a.createdAt == null && b.createdAt == null) return 0;
            if (a.createdAt == null) return 1;
            if (b.createdAt == null) return -1;
            return b.createdAt!.compareTo(a.createdAt!);
          });

          return bills;
        });
  }

  // Get bills by resident ID (for resident app)
  Stream<List<BillModel>> getBillsByResident(String residentId) {
    return _firestore
        .collection(_collection)
        .where('residentId', isEqualTo: residentId)
        .snapshots()
        .map((snapshot) {
          // Sort in memory instead of using orderBy to avoid index requirement
          final bills = snapshot.docs.map((doc) {
            final data = doc.data();
            return BillModel.fromMap(doc.id, data);
          }).toList();

          // Sort by createdAt descending (newest first)
          bills.sort((a, b) {
            if (a.createdAt == null && b.createdAt == null) return 0;
            if (a.createdAt == null) return 1;
            if (b.createdAt == null) return -1;
            return b.createdAt!.compareTo(a.createdAt!);
          });

          return bills;
        });
  }

  // Get this month's collection (sum of paid bills) filtered by adminId
  Stream<double> getThisMonthCollection(String communityId) {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final endOfMonth = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

    return _firestore
        .collection(_collection)
        .where('communityId', isEqualTo: communityId)
        .where('status', isEqualTo: 'paid')
        .where(
          'paidAt',
          isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth),
        )
        .where('paidAt', isLessThanOrEqualTo: Timestamp.fromDate(endOfMonth))
        .snapshots()
        .map((snapshot) {
          double total = 0;
          for (var doc in snapshot.docs) {
            final data = doc.data();
            total += (data['amount'] as num?)?.toDouble() ?? 0;
          }
          return total;
        });
  }

  // Calculate KPIs from bills
  Map<String, dynamic> calculateKPIs(List<BillModel> bills) {
    double totalRevenue = 0;
    double pendingAmount = 0;
    double overdueAmount = 0;
    int paidCount = 0;
    int totalCount = bills.length;

    final now = DateTime.now();

    for (var bill in bills) {
      if (bill.status == 'paid') {
        totalRevenue += bill.amount;
        paidCount++;
      } else if (bill.status == 'pending') {
        pendingAmount += bill.amount;
      } else if (bill.status == 'overdue') {
        overdueAmount += bill.amount;
      }

      // Auto-mark as overdue if past due date
      if (bill.status == 'pending' &&
          bill.dueDate != null &&
          bill.dueDate!.isBefore(now)) {
        overdueAmount += bill.amount;
        pendingAmount -= bill.amount;
      }
    }

    final collectionRate = totalCount > 0
        ? (paidCount / totalCount * 100).round()
        : 0;

    return {
      'totalRevenue': totalRevenue,
      'collected': collectionRate,
      'pending': pendingAmount,
      'overdue': overdueAmount,
    };
  }

  // Explicit one-off bill; recurring charges use createMaintenanceBills.
  Future<String> addBill({
    required String adminId,
    required String flatId,
    required String flatLabel,
    required String residentId,
    required String residentName,
    required double totalAmount,
    required Map<String, double> chargeBreakdown,
    required String month,
    required String year,
    required DateTime dueDate,
  }) async {
    try {
      print('🔵 BILL CREATION: Starting...');

      // STEP 1: Validate Admin
      print('🔐 STEP 1: Validating admin...');
      if (adminId.isEmpty) {
        throw Exception('adminId cannot be empty');
      }
      print('✅ STEP 1 PASSED');

      // STEP 2: Validate Data
      print('📋 STEP 2: Validating bill data...');
      if (residentId.isEmpty) {
        throw Exception('residentId cannot be empty');
      }
      if (residentName.isEmpty) {
        throw Exception(
          'residentName cannot be empty for resident $residentId',
        );
      }
      if (flatId.isEmpty) {
        throw Exception('flatId cannot be empty');
      }
      if (flatLabel.isEmpty) {
        throw Exception('flatLabel cannot be empty');
      }
      print('✅ STEP 2 PASSED');

      // STEP 3: Create Bill
      print('📝 STEP 3: Creating bill document...');
      final adminProfile = await _adminService.getAdminProfile();
      if (adminProfile == null) {
        throw Exception('Admin profile not found');
      }

      final docRef = await _firestore.collection(_collection).add({
        'billingKind': 'ad_hoc',
        'adminId': adminId,
        'communityId': _adminService.requireCurrentCommunityId(),
        'adminName': adminProfile['name'] ?? '',
        'adminEmail': adminProfile['email'] ?? '',
        'adminPhone': adminProfile['phone'] ?? '',
        'organization': adminProfile['organization'] ?? '',
        'flatId': flatId,
        'flatLabel': flatLabel,
        'residentId': residentId,
        'residentName': residentName,
        'amount': totalAmount,
        'chargeBreakdown': chargeBreakdown,
        'month': month,
        'year': year,
        'type': 'combined',
        'status': 'pending',
        'dueDate': Timestamp.fromDate(dueDate),
        'paidAt': null,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      print('✅ STEP 3 PASSED');

      // STEP 4: Notify Resident
      print('🔔 STEP 4: Notifying resident...');
      try {
        await _notificationService.createNotification(
          title: 'New Bill Created',
          message:
              'Your bill of ₹${totalAmount.toStringAsFixed(2)} for $month $year has been created. Due date: ${dueDate.day}/${dueDate.month}/${dueDate.year}',
          type: NotificationType.payment,
          priority: NotificationPriority.high,
          recipientId: residentId,
          metadata: {
            'billId': docRef.id,
            'amount': totalAmount,
            'month': month,
            'year': year,
            'dueDate': dueDate.toIso8601String(),
          },
        );
        print('✅ STEP 4 PASSED: Resident notified');
      } catch (notificationError) {
        print(
          '⚠️ STEP 4 WARNING: Failed to send notification: $notificationError',
        );
      }

      print('✅ BILL CREATION: COMPLETE');
      return docRef.id;
    } catch (e) {
      print('❌ ERROR: $e');
      throw Exception('Failed to add bill: $e');
    }
  }

  // Generate monthly bills for all residents or specific units (filtered by adminId)
  Future<int> generateMonthlyBills({
    required String adminId,
    required String month,
    required String year,
    required double totalAmount,
    required Map<String, double> chargeBreakdown,
    required DateTime dueDate,
    List<String>? specificFlatIds,
  }) async {
    if (_adminService.getCurrentAdminId() != adminId) {
      throw StateError('Admin not authenticated');
    }
    final date =
        '${dueDate.year.toString().padLeft(4, '0')}-'
        '${dueDate.month.toString().padLeft(2, '0')}-'
        '${dueDate.day.toString().padLeft(2, '0')}';
    final selected = specificFlatIds != null && specificFlatIds.isNotEmpty;
    final response = await _functions
        .httpsCallable('createMaintenanceBills')
        .call({
          'communityId': _adminService.requireCurrentCommunityId(),
          'scope': selected ? 'units' : 'community',
          if (selected) 'flatIds': specificFlatIds,
          'amount': totalAmount,
          'chargeBreakdown': chargeBreakdown,
          'chargeType': 'maintenance',
          'month': month,
          'year': year,
          'dueDate': date,
        });
    final result = Map<String, dynamic>.from(response.data as Map);
    // Preserve best-effort notifications only for newly committed bills.
    for (final item in (result['createdBills'] as List? ?? const [])) {
      final bill = Map<String, dynamic>.from(item as Map);
      final amount = (bill['amount'] as num).toDouble();
      try {
        await _notificationService.createNotification(
          title: 'New Bill Created',
          message:
              'Your bill of ₹${amount.toStringAsFixed(2)} for ${bill['month']} ${bill['year']} has been created. Due date: ${dueDate.day}/${dueDate.month}/${dueDate.year}',
          type: NotificationType.payment,
          priority: NotificationPriority.high,
          recipientId: bill['residentId'] as String,
          metadata: {
            'billId': bill['billId'],
            'amount': amount,
            'month': bill['month'],
            'year': bill['year'],
            'dueDate': dueDate.toIso8601String(),
          },
        );
      } catch (error) {
        print('Failed to send bill notification: $error');
      }
    }
    final conflicts = result['conflicts'] as List? ?? const [];
    if (conflicts.isNotEmpty) {
      throw StateError(
        '${result['created']} bills created; ${conflicts.length} existing bills have different terms and were left unchanged.',
      );
    }
    return (result['created'] as num).toInt();
  }

  // Record an Admin-attested offline payment through the trusted callable.
  Future<void> recordPayment(
    String billId, {
    required String paymentMethod,
    String? paymentReference,
  }) async {
    try {
      print('🔵 BILL PAYMENT: Starting...');

      // STEP 1: Validate Admin
      print('🔐 STEP 1: Validating admin...');
      final adminId = _adminService.getCurrentAdminId();
      if (adminId == null) throw Exception('Admin not logged in');
      print('✅ STEP 1 PASSED');

      // STEP 2: Validate Bill
      print('📋 STEP 2: Validating bill...');
      final billDoc = await _firestore
          .collection(_collection)
          .doc(billId)
          .get();
      if (!billDoc.exists) throw Exception('Bill not found');

      final billData = billDoc.data();
      if (billData == null ||
          billData['status'] == 'paid' ||
          billData['paymentId'] != null ||
          billData['paidAt'] != null) {
        throw StateError('This bill is already settled.');
      }
      final residentId = billData['residentId'];
      final amount = billData['amount'] ?? 0.0;
      print('✅ STEP 2 PASSED');

      // STEP 3: Update Bill Status
      print('📝 STEP 3: Recording payment...');
      await _functions.httpsCallable('recordManualPayment').call({
        'billId': billId,
        'paymentMethod': paymentMethod,
        'paymentReference': paymentReference,
      });
      print('✅ STEP 3 PASSED');

      // STEP 4: Notify Resident
      print('🔔 STEP 4: Notifying resident...');
      if (residentId != null) {
        try {
          await _notificationService.createNotification(
            title: 'Payment Received',
            message:
                'Your payment of ₹${amount.toStringAsFixed(2)} has been received. Thank you!',
            type: NotificationType.payment,
            priority: NotificationPriority.high,
            recipientId: residentId,
            metadata: {
              'billId': billId,
              'amount': amount,
              'paymentMethod': paymentMethod,
              'paymentReference': paymentReference,
            },
          );
          print('✅ STEP 4 PASSED: Resident notified');
        } catch (notificationError) {
          print(
            '⚠️ STEP 4 WARNING: Failed to send notification: $notificationError',
          );
        }
      }

      print('✅ BILL PAYMENT: COMPLETE');
    } catch (e) {
      print('❌ ERROR: $e');
      throw Exception('Failed to record payment: $e');
    }
  }

  // Update bill status to overdue
  Future<void> markBillAsOverdue(String billId) async {
    try {
      await _firestore.collection(_collection).doc(billId).update({
        'status': 'overdue',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to mark bill as overdue: $e');
    }
  }

  // Delete bill
  Future<void> deleteBill(String billId) async {
    try {
      await _firestore.collection(_collection).doc(billId).delete();
    } catch (e) {
      throw Exception('Failed to delete bill: $e');
    }
  }
}

// Bill Model
class BillModel {
  final String id;
  final String adminId;
  final String? adminName;
  final String? adminEmail;
  final String? adminPhone;
  final String communityId;
  final String? organization;
  final String flatId;
  final String flatLabel;
  final String residentId;
  final String residentName;
  final double amount;
  final Map<String, double>? chargeBreakdown;
  final String month;
  final String year;
  final String type;
  final String status;
  final DateTime? dueDate;
  final DateTime? paidAt;
  final String? paymentMethod;
  final String? paymentReference;
  final String? paymentId;
  final String? settledBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final int? schemaVersion;
  final String? currency;
  final int? amountMinor;
  final int? paidAmountMinor;
  final int? creditAppliedMinor;
  final int? outstandingAmountMinor;
  final String? currentRevisionId;
  final String? billingPeriod;
  final List<BillChargeLine> chargeLines;

  BillModel({
    required this.id,
    required this.adminId,
    this.adminName,
    this.adminEmail,
    this.adminPhone,
    required this.communityId,
    this.organization,
    required this.flatId,
    required this.flatLabel,
    required this.residentId,
    required this.residentName,
    required this.amount,
    this.chargeBreakdown,
    required this.month,
    required this.year,
    required this.type,
    required this.status,
    this.dueDate,
    this.paidAt,
    this.paymentMethod,
    this.paymentReference,
    this.paymentId,
    this.settledBy,
    this.createdAt,
    this.updatedAt,
    this.schemaVersion,
    this.currency,
    this.amountMinor,
    this.paidAmountMinor,
    this.creditAppliedMinor,
    this.outstandingAmountMinor,
    this.currentRevisionId,
    this.billingPeriod,
    this.chargeLines = const [],
  });

  String get normalizedPaymentMethod => formatPaymentMethod(paymentMethod);
  bool get isV2 => schemaVersion == 2;

  bool get hasValidInrV2Financials =>
      isV2 &&
      currency == 'INR' &&
      _isSafeMinor(amountMinor) &&
      _isSafeMinor(paidAmountMinor) &&
      _isSafeMinor(creditAppliedMinor) &&
      _isSafeMinor(outstandingAmountMinor) &&
      amountMinor! > 0 &&
      paidAmountMinor! <= amountMinor! &&
      creditAppliedMinor! <= amountMinor! - paidAmountMinor! &&
      outstandingAmountMinor! ==
          amountMinor! - paidAmountMinor! - creditAppliedMinor! &&
      currentRevisionId?.trim().isNotEmpty == true;

  bool get isCurrentV2Liability =>
      hasValidInrV2Financials &&
      const {'pending', 'overdue', 'partially_paid'}.contains(status) &&
      outstandingAmountMinor! > 0;

  bool get isSettledV2 =>
      hasValidInrV2Financials &&
      (const {'paid', 'settled'}.contains(status) ||
          outstandingAmountMinor == 0);

  String formatV2MinorAmount(int? minorUnits) =>
      hasValidInrV2Financials && _isSafeMinor(minorUnits)
      ? formatInrMinorUnits(minorUnits!)
      : 'Unavailable';

  factory BillModel.fromMap(String id, Map<String, dynamic> data) {
    // Parse charge breakdown if it exists
    Map<String, double>? breakdown;
    if (data['chargeBreakdown'] != null) {
      final breakdownData = data['chargeBreakdown'] as Map<String, dynamic>;
      breakdown = breakdownData.map(
        (key, value) => MapEntry(key, (value as num).toDouble()),
      );
    }

    return BillModel(
      id: id,
      adminId: data['adminId'] ?? '',
      adminName: data['adminName'],
      adminEmail: data['adminEmail'],
      adminPhone: data['adminPhone'],
      communityId: data['communityId'] ?? '',
      organization: data['organization'],
      flatId: data['flatId'] ?? '',
      flatLabel: data['flatLabel'] ?? '',
      residentId: data['residentId'] ?? '',
      residentName: data['residentName'] ?? '',
      amount: (data['amount'] as num?)?.toDouble() ?? 0,
      chargeBreakdown: breakdown,
      month: data['month'] ?? '',
      year: data['year'] ?? '',
      type: data['type'] ?? '',
      status: data['status'] ?? 'pending',
      dueDate: (data['dueDate'] as Timestamp?)?.toDate(),
      paidAt: (data['paidAt'] as Timestamp?)?.toDate(),
      paymentMethod: data['paymentMethod'] is String
          ? data['paymentMethod'] as String
          : null,
      paymentReference: data['paymentReference'] is String
          ? data['paymentReference'] as String
          : null,
      paymentId: data['paymentId'] is String
          ? data['paymentId'] as String
          : null,
      settledBy: data['settledBy'] is String
          ? data['settledBy'] as String
          : null,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      schemaVersion: data['schemaVersion'] is int
          ? data['schemaVersion'] as int
          : null,
      currency: data['currency'] is String ? data['currency'] as String : null,
      amountMinor: data['amountMinor'] is int
          ? data['amountMinor'] as int
          : null,
      paidAmountMinor: data['paidAmountMinor'] is int
          ? data['paidAmountMinor'] as int
          : null,
      creditAppliedMinor: data['creditAppliedMinor'] is int
          ? data['creditAppliedMinor'] as int
          : null,
      outstandingAmountMinor: data['outstandingAmountMinor'] is int
          ? data['outstandingAmountMinor'] as int
          : null,
      currentRevisionId: data['currentRevisionId'] is String
          ? data['currentRevisionId'] as String
          : null,
      billingPeriod: data['billingPeriod'] is String
          ? data['billingPeriod'] as String
          : null,
      chargeLines: _parseChargeLines(data['chargeLines']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'adminId': adminId,
      'adminName': adminName,
      'adminEmail': adminEmail,
      'adminPhone': adminPhone,
      'communityId': communityId,
      'organization': organization,
      'flatId': flatId,
      'flatLabel': flatLabel,
      'residentId': residentId,
      'residentName': residentName,
      'amount': amount,
      'chargeBreakdown': chargeBreakdown,
      'month': month,
      'year': year,
      'type': type,
      'status': status,
      'dueDate': dueDate != null ? Timestamp.fromDate(dueDate!) : null,
      'paidAt': paidAt != null ? Timestamp.fromDate(paidAt!) : null,
      'paymentMethod': paymentMethod,
      'paymentReference': paymentReference,
      'paymentId': paymentId,
      'settledBy': settledBy,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : null,
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      if (isV2) ...{
        'schemaVersion': schemaVersion,
        'currency': currency,
        'amountMinor': amountMinor,
        'paidAmountMinor': paidAmountMinor,
        'creditAppliedMinor': creditAppliedMinor,
        'outstandingAmountMinor': outstandingAmountMinor,
        'currentRevisionId': currentRevisionId,
        'billingPeriod': billingPeriod,
        'chargeLines': chargeLines.map((line) => line.toMap()).toList(),
      },
    };
  }
}

class BillChargeLine {
  final String lineId;
  final String label;
  final int amountMinor;

  const BillChargeLine({
    required this.lineId,
    required this.label,
    required this.amountMinor,
  });

  Map<String, dynamic> toMap() => {
    'lineId': lineId,
    'label': label,
    'amountMinor': amountMinor,
  };
}

bool _isSafeMinor(Object? value) =>
    value is int && value >= 0 && value <= 9007199254740991;

String formatInrMinorUnits(int minorUnits) {
  if (!_isSafeMinor(minorUnits)) return 'Unavailable';
  final digits = minorUnits.toString().padLeft(3, '0');
  final rupees = digits.substring(0, digits.length - 2);
  final paise = digits.substring(digits.length - 2);
  var grouped = rupees;
  if (rupees.length > 3) {
    final prefix = rupees.substring(0, rupees.length - 3);
    final groups = <String>[];
    var end = prefix.length;
    while (end > 2) {
      groups.insert(0, prefix.substring(end - 2, end));
      end -= 2;
    }
    if (end > 0) groups.insert(0, prefix.substring(0, end));
    grouped = '${groups.join(',')},${rupees.substring(rupees.length - 3)}';
  }
  return '₹$grouped.$paise';
}

List<BillChargeLine> _parseChargeLines(Object? value) {
  if (value is! List) return const [];
  return value
      .whereType<Map>()
      .map((raw) {
        final line = Map<String, dynamic>.from(raw);
        final amountMinor = line['amountMinor'];
        if (!_isSafeMinor(amountMinor)) return null;
        return BillChargeLine(
          lineId: line['lineId'] is String ? line['lineId'] as String : '',
          label: line['label'] is String ? line['label'] as String : '',
          amountMinor: amountMinor as int,
        );
      })
      .whereType<BillChargeLine>()
      .toList();
}
