# Resident App Billing Integration Guide

## Overview

When the admin creates bills in the admin app, each resident should be able to see ONLY their own bills in the resident app. This guide explains the complete data flow and implementation.

## Data Flow

```
┌─────────────────────────────────────────────────────────────┐
│ ADMIN APP                                                   │
│ Admin creates monthly bill                                  │
│ - Month: January 2024                                       │
│ - Charges: Maintenance ₹5000, Water ₹500, etc.            │
│ - Apply to: All Residents                                   │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│ FIRESTORE bills Collection                                  │
│ Creates bill for each resident:                             │
│                                                             │
│ bills/bill_001 {                                            │
│   residentId: "RES%16",      ← Matches user's residentId  │
│   residentName: "sukumar",                                  │
│   flatId: "t401",                                           │
│   flatLabel: "t401",                                        │
│   amount: 6800,                                             │
│   chargeBreakdown: {...},                                   │
│   status: "pending",                                        │
│   month: "January",                                         │
│   year: "2024",                                             │
│   dueDate: Timestamp                                        │
│ }                                                           │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│ RESIDENT APP                                                │
│ Resident logs in with their credentials                     │
│ - Email: sukumar@gmail.com                                  │
│ - Password: 123456                                          │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│ AUTHENTICATION                                              │
│ Firebase Auth returns user                                  │
│ - authUid: "firebase_uid_123"                              │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│ FETCH USER DATA                                             │
│ Query users collection by authUid                           │
│                                                             │
│ users/0oLNbxo8GrFzyMCQlo4 {                                │
│   residentId: "RES%16",      ← User's resident ID          │
│   name: "sukumar",                                          │
│   authUid: "firebase_uid_123",                             │
│   flatId: "t401",                                           │
│   role: "resident"                                          │
│ }                                                           │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│ FETCH BILLS FOR THIS RESIDENT                               │
│ Query bills collection:                                     │
│ WHERE residentId = "RES%16"                                │
│                                                             │
│ Returns ONLY bills for this resident:                       │
│ - bill_001 (January 2024 - ₹6800)                         │
│ - bill_002 (December 2023 - ₹6500)                        │
│ - bill_003 (November 2023 - ₹6500)                        │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│ DISPLAY IN RESIDENT APP                                     │
│ Show bills in UI:                                           │
│                                                             │
│ ┌─────────────────────────────────────┐                   │
│ │ January 2024            [Pending]   │                   │
│ │ Flat: t401                          │                   │
│ │ Amount: ₹6,800                      │                   │
│ │ Due: 31 Jan 2024                    │                   │
│ │                                     │                   │
│ │ Breakdown:                          │                   │
│ │ • Maintenance: ₹5,000               │                   │
│ │ • Water: ₹500                       │                   │
│ │ • Parking: ₹1,000                   │                   │
│ │ • Service: ₹300                     │                   │
│ │                                     │                   │
│ │ [Pay Now]                           │                   │
│ └─────────────────────────────────────┘                   │
└─────────────────────────────────────────────────────────────┘
```

## Resident App Implementation

### 1. BillingService for Resident App

Create a billing service in the resident app:

**File**: `resident_app/lib/services/billing_service.dart`

```dart
import 'package:cloud_firestore/cloud_firestore.dart';

class ResidentBillingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'bills';

  /// Get bills for a specific resident by their residentId
  /// This ensures each resident sees ONLY their own bills
  Stream<List<BillModel>> getBillsForResident(String residentId) {
    print('\n🔵 Fetching bills for resident: $residentId');
    
    return _firestore
        .collection(_collection)
        .where('residentId', isEqualTo: residentId)  // ✅ Filter by residentId
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      print('📊 Found ${snapshot.docs.length} bills for resident $residentId');
      
      return snapshot.docs.map((doc) {
        final data = doc.data();
        print('  - ${data['month']} ${data['year']}: ₹${data['amount']} (${data['status']})');
        
        return BillModel.fromMap(doc.id, data);
      }).toList();
    });
  }

  /// Get pending bills only
  Stream<List<BillModel>> getPendingBills(String residentId) {
    return _firestore
        .collection(_collection)
        .where('residentId', isEqualTo: residentId)
        .where('status', isEqualTo: 'pending')
        .orderBy('dueDate', descending: false)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return BillModel.fromMap(doc.id, doc.data());
      }).toList();
    });
  }

  /// Get paid bills only
  Stream<List<BillModel>> getPaidBills(String residentId) {
    return _firestore
        .collection(_collection)
        .where('residentId', isEqualTo: residentId)
        .where('status', isEqualTo: 'paid')
        .orderBy('paidAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return BillModel.fromMap(doc.id, doc.data());
      }).toList();
    });
  }

  /// Pay a bill (update status to paid)
  Future<void> payBill(String billId, String paymentMethod) async {
    try {
      await _firestore.collection(_collection).doc(billId).update({
        'status': 'paid',
        'paymentMethod': paymentMethod,
        'paidAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      print('✅ Bill $billId marked as paid');
    } catch (e) {
      print('❌ Error paying bill: $e');
      throw Exception('Failed to pay bill: $e');
    }
  }
}

/// Bill Model (same as admin app)
class BillModel {
  final String id;
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

  BillModel({
    required this.id,
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
  });

  factory BillModel.fromMap(String id, Map<String, dynamic> data) {
    Map<String, double>? breakdown;
    if (data['chargeBreakdown'] != null) {
      final breakdownData = data['chargeBreakdown'] as Map<String, dynamic>;
      breakdown = breakdownData.map((key, value) => 
        MapEntry(key, (value as num).toDouble())
      );
    }
    
    return BillModel(
      id: id,
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
    );
  }
}
```

### 2. Resident Billing Screen

**File**: `resident_app/lib/screens/billing_screen.dart`

```dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/billing_service.dart';

class ResidentBillingScreen extends StatefulWidget {
  const ResidentBillingScreen({super.key});

  @override
  State<ResidentBillingScreen> createState() => _ResidentBillingScreenState();
}

class _ResidentBillingScreenState extends State<ResidentBillingScreen> {
  final ResidentBillingService _billingService = ResidentBillingService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  String? _residentId;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadResidentData();
  }

  /// Load current user's resident data
  Future<void> _loadResidentData() async {
    try {
      // Get current authenticated user
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('❌ No authenticated user');
        return;
      }

      print('🔵 Loading resident data for authUid: ${user.uid}');

      // Query users collection to get resident data
      final userDoc = await _firestore
          .collection('users')
          .where('authUid', isEqualTo: user.uid)
          .where('role', isEqualTo: 'resident')
          .limit(1)
          .get();

      if (userDoc.docs.isEmpty) {
        print('❌ No resident found for authUid: ${user.uid}');
        return;
      }

      final userData = userDoc.docs.first.data();
      final residentId = userData['residentId'] as String?;

      print('✅ Resident data loaded:');
      print('   residentId: $residentId');
      print('   name: ${userData['name']}');
      print('   flatId: ${userData['flatId']}');

      setState(() {
        _residentId = residentId;
        _isLoading = false;
      });
    } catch (e) {
      print('❌ Error loading resident data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_residentId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('My Bills')),
        body: const Center(
          child: Text('Unable to load resident data'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Bills'),
        backgroundColor: const Color(0xFF2563EB),
      ),
      body: StreamBuilder<List<BillModel>>(
        stream: _billingService.getBillsForResident(_residentId!),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('Error: ${snapshot.error}'),
            );
          }

          final bills = snapshot.data ?? [];

          if (bills.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.receipt_long_outlined,
                    size: 64,
                    color: Colors.grey,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'No bills found',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: bills.length,
            itemBuilder: (context, index) {
              final bill = bills[index];
              return _buildBillCard(bill);
            },
          );
        },
      ),
    );
  }

  Widget _buildBillCard(BillModel bill) {
    final isPending = bill.status == 'pending';
    final isOverdue = isPending && 
        bill.dueDate != null && 
        bill.dueDate!.isBefore(DateTime.now());

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${bill.month} ${bill.year}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: isOverdue
                        ? const Color(0xFFDC2626)
                        : isPending
                            ? const Color(0xFFF59E0B)
                            : const Color(0xFF10B981),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    isOverdue ? 'Overdue' : bill.status.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Flat info
            Text(
              'Flat: ${bill.flatLabel}',
              style: const TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 16),

            // Amount
            Row(
              children: [
                const Icon(
                  Icons.currency_rupee,
                  size: 24,
                  color: Color(0xFF2563EB),
                ),
                Text(
                  bill.amount.toStringAsFixed(0).replaceAllMapped(
                    RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
                    (Match m) => '${m[1]},',
                  ),
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF2563EB),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Charge breakdown
            if (bill.chargeBreakdown != null && bill.chargeBreakdown!.isNotEmpty) ...[
              const Text(
                'Breakdown:',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              ...bill.chargeBreakdown!.entries.map((entry) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '• ${entry.key}',
                        style: const TextStyle(fontSize: 14),
                      ),
                      Text(
                        '₹${entry.value.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
              const SizedBox(height: 16),
            ],

            // Due date
            if (bill.dueDate != null)
              Text(
                'Due: ${DateFormat('dd MMM yyyy').format(bill.dueDate!)}',
                style: TextStyle(
                  fontSize: 14,
                  color: isOverdue ? const Color(0xFFDC2626) : Colors.grey,
                  fontWeight: isOverdue ? FontWeight.w600 : FontWeight.normal,
                ),
              ),

            // Pay button
            if (isPending) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => _handlePayBill(bill),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Pay Now',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _handlePayBill(BillModel bill) async {
    // TODO: Integrate with payment gateway
    // For now, just mark as paid
    try {
      await _billingService.payBill(bill.id, 'online');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment successful!'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Payment failed: $e'),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    }
  }
}
```

## Key Points for Resident App

### 1. Authentication Flow ✅

```dart
// 1. Resident logs in
FirebaseAuth.instance.signInWithEmailAndPassword(
  email: "sukumar@gmail.com",
  password: "123456",
);

// 2. Get authUid from Firebase Auth
final user = FirebaseAuth.instance.currentUser;
final authUid = user.uid; // e.g., "firebase_uid_123"

// 3. Query users collection to get residentId
final userDoc = await FirebaseFirestore.instance
    .collection('users')
    .where('authUid', isEqualTo: authUid)
    .where('role', isEqualTo: 'resident')
    .limit(1)
    .get();

final residentId = userDoc.docs.first.data()['residentId']; // "RES%16"

// 4. Fetch bills using residentId
final bills = await FirebaseFirestore.instance
    .collection('bills')
    .where('residentId', isEqualTo: residentId)
    .get();
```

### 2. Security Rules ✅

Update Firestore security rules to ensure residents can only see their own bills:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // Bills collection
    match /bills/{billId} {
      // Allow read if the bill belongs to the authenticated user
      allow read: if request.auth != null && 
                     resource.data.residentId == getUserResidentId(request.auth.uid);
      
      // Only admins can write
      allow write: if request.auth != null && 
                      getUserRole(request.auth.uid) == 'admin';
    }
    
    // Helper function to get user's residentId
    function getUserResidentId(authUid) {
      return get(/databases/$(database)/documents/users/$(authUid)).data.residentId;
    }
    
    // Helper function to get user's role
    function getUserRole(authUid) {
      return get(/databases/$(database)/documents/users/$(authUid)).data.role;
    }
  }
}
```

### 3. Data Filtering ✅

**IMPORTANT**: Always filter bills by `residentId`:

```dart
// ✅ CORRECT - Filters by residentId
_firestore
    .collection('bills')
    .where('residentId', isEqualTo: currentUserResidentId)
    .get();

// ❌ WRONG - Would return all bills
_firestore
    .collection('bills')
    .get();
```

## Testing Checklist

### Admin App Testing

1. ✅ Create bills in admin app
2. ✅ Verify bills stored in Firestore with correct `residentId`
3. ✅ Check console logs show correct resident data

### Resident App Testing

1. ✅ Login as resident (sukumar@gmail.com)
2. ✅ Navigate to billing screen
3. ✅ Verify ONLY bills for this resident appear
4. ✅ Check bill details are correct
5. ✅ Test payment functionality

### Firestore Verification

```javascript
// Check bills collection
bills/bill_001 {
  residentId: "RES%16",        // ✅ Must match user's residentId
  residentName: "sukumar",
  amount: 6800,
  status: "pending",
  // ...
}

// Check users collection
users/0oLNbxo8GrFzyMCQlo4 {
  residentId: "RES%16",        // ✅ Same as in bills
  authUid: "firebase_uid_123", // ✅ Links to Firebase Auth
  email: "sukumar@gmail.com",
  role: "resident",
  // ...
}
```

## Summary

✅ **Admin App**: Creates bills with `residentId` field
✅ **Firestore**: Stores bills with correct `residentId`
✅ **Resident App**: Fetches bills filtered by `residentId`
✅ **Security**: Firestore rules ensure data privacy
✅ **Authentication**: Links Firebase Auth → users → bills

Each resident sees ONLY their own bills based on their `residentId`!

