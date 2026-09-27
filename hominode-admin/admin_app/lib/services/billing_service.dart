import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../models/notification_models.dart';
import 'admin_service.dart';
import 'notification_firestore_service.dart';

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
    final date = '${dueDate.year.toString().padLeft(4, '0')}-'
        '${dueDate.month.toString().padLeft(2, '0')}-'
        '${dueDate.day.toString().padLeft(2, '0')}';
    final selected = specificFlatIds != null && specificFlatIds.isNotEmpty;
    final response = await _functions.httpsCallable('createMaintenanceBills').call({
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
          message: 'Your bill of ₹${amount.toStringAsFixed(2)} for ${bill['month']} ${bill['year']} has been created. Due date: ${dueDate.day}/${dueDate.month}/${dueDate.year}',
          type: NotificationType.payment,
          priority: NotificationPriority.high,
          recipientId: bill['residentId'] as String,
          metadata: {
            'billId': bill['billId'], 'amount': amount,
            'month': bill['month'], 'year': bill['year'],
            'dueDate': dueDate.toIso8601String(),
          },
        );
      } catch (error) {
        print('Failed to send bill notification: $error');
      }
    }
    final conflicts = result['conflicts'] as List? ?? const [];
    if (conflicts.isNotEmpty) {
      throw StateError('${result['created']} bills created; ${conflicts.length} existing bills have different terms and were left unchanged.');
    }
    return (result['created'] as num).toInt();
  }

  // Mark bill as paid (with optional payment method for manual payments)
  Future<void> markBillAsPaid(
    String billId, {
    String paymentMethod = 'manual',
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
      final residentId = billData?['residentId'];
      final residentName = billData?['residentName'] ?? 'Unknown';
      final amount = billData?['amount'] ?? 0.0;
      print('✅ STEP 2 PASSED');

      // STEP 3: Update Bill Status
      print('📝 STEP 3: Marking bill as paid...');
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
      throw Exception('Failed to mark bill as paid: $e');
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
  final DateTime? createdAt;
  final DateTime? updatedAt;

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
    this.createdAt,
    this.updatedAt,
  });

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
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
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
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : null,
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }
}
