import 'package:cloud_firestore/cloud_firestore.dart';
import 'admin_service.dart';
import 'notification_firestore_service.dart';
import '../models/notification_models.dart';

class BillingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'bills';
  final AdminService _adminService = AdminService();
  final NotificationFirestoreService _notificationService =
      NotificationFirestoreService();

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

  // Add new bill with charge breakdown and admin details
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
    try {
      print('🔍 Starting bill generation for admin: $adminId');
      print('📅 Month: $month, Year: $year');
      print('💰 Total Amount: ₹$totalAmount');
      print('📊 Charge Breakdown: $chargeBreakdown');

      // Query users collection for residents filtered by adminId
      Query query = _firestore
          .collection('users')
          .where('role', isEqualTo: 'resident')
          .where(
            'communityId',
            isEqualTo: _adminService.requireCurrentCommunityId(),
          )
          .where('flatId', isNotEqualTo: null);

      // If specific flat IDs are provided, filter by them
      if (specificFlatIds != null && specificFlatIds.isNotEmpty) {
        print('🏢 Filtering by specific flats: $specificFlatIds');
        query = query.where('flatId', whereIn: specificFlatIds);
      } else {
        print('🏢 Generating bills for ALL residents of admin $adminId');
      }

      final usersSnapshot = await query.get();
      print(
        '👥 Found ${usersSnapshot.docs.length} residents in users collection',
      );

      int count = 0;
      int skipped = 0;

      for (var doc in usersSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;

        print('\n📄 Processing document: ${doc.id}');
        print('   Data: $data');

        // Extract resident data from Firestore
        final storedResidentId = (data['residentId'] as String?)?.trim();
        final residentUid = (data['uid'] as String?)?.trim();
        final residentId = storedResidentId?.isNotEmpty == true
            ? storedResidentId!
            : residentUid?.isNotEmpty == true
            ? residentUid!
            : doc.id;
        final residentName = data['name'] as String?;
        final flatId = data['flatId'] as String?;
        final flatLabel = data['flatLabel'] as String?;

        print('   residentId: $residentId');
        print('   residentName: $residentName');
        print('   flatId: $flatId');
        print('   flatLabel: $flatLabel');

        // Validate required fields - skip if any are missing
        if (residentId.isEmpty) {
          print('   ⚠️ SKIPPED: Unable to resolve resident identifier');
          skipped++;
          continue;
        }

        if (residentName == null || residentName.isEmpty) {
          print('   ⚠️ SKIPPED: Missing name field for resident $residentId');
          skipped++;
          continue;
        }

        if (flatId == null || flatId.isEmpty) {
          print('   ⚠️ SKIPPED: Missing flatId for resident $residentId');
          skipped++;
          continue;
        }

        if (flatLabel == null || flatLabel.isEmpty) {
          print('   ⚠️ SKIPPED: Missing flatLabel for resident $residentId');
          skipped++;
          continue;
        }

        // All required data present - create bill with adminId
        await addBill(
          adminId: adminId,
          flatId: flatId,
          flatLabel: flatLabel,
          residentId: residentId,
          residentName: residentName,
          totalAmount: totalAmount,
          chargeBreakdown: chargeBreakdown,
          month: month,
          year: year,
          dueDate: dueDate,
        );
        count++;

        print(
          '   ✅ SUCCESS: Bill created for $residentName ($residentId) - Flat $flatLabel',
        );
      }

      print('\n📊 SUMMARY:');
      print('   Total residents found: ${usersSnapshot.docs.length}');
      print('   Bills created: $count');
      print('   Residents skipped: $skipped');

      return count;
    } catch (e) {
      print('❌ Error generating bills: $e');
      throw Exception('Failed to generate monthly bills: $e');
    }
  }

  // Mark bill as paid (with optional payment method for manual payments)
  Future<void> markBillAsPaid(
    String billId, {
    String paymentMethod = 'online',
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
      await _firestore.collection(_collection).doc(billId).update({
        'status': 'paid',
        'paymentMethod': paymentMethod,
        'paymentReference': paymentReference,
        'paidAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
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
    };
  }
}
