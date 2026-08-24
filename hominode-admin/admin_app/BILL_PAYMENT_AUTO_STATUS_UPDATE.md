# Bill Payment - Automatic Status Update System

## Overview
The billing system automatically updates bill status to "paid" when payment is made, with real-time UI updates and color changes.

## How It Works

### 1. Real-Time Data Flow
```
Resident makes payment (or Admin marks as paid)
    ↓
BillingService.markBillAsPaid(billId) called
    ↓
Firestore 'bills' collection updated:
  - status: 'pending' → 'paid'
  - paidAt: current timestamp
  - updatedAt: current timestamp
    ↓
StreamBuilder detects Firestore change
    ↓
UI automatically rebuilds with new data
    ↓
Bill card shows "Paid" status with green color
    ↓
Bill moves to "Payment History" tab
```

### 2. Status Colors

The system uses distinct colors for each bill status:

```dart
// Status color mapping
final statusColor = bill.status == 'paid'
    ? const Color(0xFF10B981)  // Green - Paid
    : bill.status == 'overdue'
        ? const Color(0xFFEF4444)  // Red - Overdue
        : const Color(0xFFF59E0B);  // Amber - Pending
```

**Color Codes:**
- **Paid**: `#10B981` (Green) - Success color
- **Overdue**: `#EF4444` (Red) - Error/urgent color
- **Pending**: `#F59E0B` (Amber) - Warning color

### 3. Status Badge Display

```dart
Container(
  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
  decoration: BoxDecoration(
    color: statusColor.withOpacity(0.1),  // Light background
    borderRadius: BorderRadius.circular(12),
  ),
  child: Text(
    statusText,  // "Paid", "Overdue", or "Pending"
    style: TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      color: statusColor,  // Solid color for text
    ),
  ),
)
```

### 4. Mark as Paid Function

**In BillingService:**
```dart
Future<void> markBillAsPaid(String billId) async {
  try {
    await _firestore.collection('bills').doc(billId).update({
      'status': 'paid',
      'paidAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  } catch (e) {
    throw Exception('Failed to mark bill as paid: $e');
  }
}
```

**In Billing Screen:**
```dart
Future<void> _onMarkAsPaid(BillModel bill) async {
  try {
    await _billingService.markBillAsPaid(bill.id);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Bill marked as paid for ${bill.residentName}'),
          backgroundColor: const Color(0xFF10B981),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to mark as paid: $e'),
          backgroundColor: const Color(0xFFEF4444),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }
}
```

### 5. UI Changes After Payment

**Before Payment (Pending/Overdue):**
- Status badge: Amber/Red background with matching text
- Action buttons: "Remind" + "Mark Paid"
- Visible in "Bills" tab

**After Payment (Paid):**
- Status badge: Green background with "Paid" text
- Shows "Paid on [date]" with green checkmark icon
- Action button: Only "Download" button
- Moves to "Payment History" tab
- KPI metrics automatically update

### 6. Tab Filtering

**Bills Tab:**
```dart
final bills = allBills.where((bill) {
  return bill.status == 'pending' || bill.status == 'overdue';
}).toList();
```

**Payment History Tab:**
```dart
final paidBills = allBills.where((bill) => bill.status == 'paid').toList();
```

### 7. KPI Auto-Update

When a bill is marked as paid, KPIs automatically recalculate:

```dart
Map<String, dynamic> calculateKPIs(List<BillModel> bills) {
  double totalRevenue = 0;
  double pendingAmount = 0;
  double overdueAmount = 0;
  int paidCount = 0;
  int totalCount = bills.length;

  for (var bill in bills) {
    if (bill.status == 'paid') {
      totalRevenue += bill.amount;
      paidCount++;
    } else if (bill.status == 'pending') {
      pendingAmount += bill.amount;
    } else if (bill.status == 'overdue') {
      overdueAmount += bill.amount;
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
```

## Visual States

### Pending Bill Card
```
┌─────────────────────────────────────┐
│ John Doe                    [Pending]│ ← Amber badge
│ A-101                                │
│                                      │
│ ┌──────────────────────────────────┐│
│ │ Amount        Due Date           ││
│ │ ₹5,500        15-03-2025         ││
│ └──────────────────────────────────┘│
│                                      │
│ [Remind]  [Mark Paid]               │ ← Both buttons
└─────────────────────────────────────┘
```

### Paid Bill Card
```
┌─────────────────────────────────────┐
│ John Doe                       [Paid]│ ← Green badge
│ A-101                                │
│                                      │
│ ┌──────────────────────────────────┐│
│ │ Amount        Due Date           ││
│ │ ₹5,500        15-03-2025         ││
│ └──────────────────────────────────┘│
│                                      │
│ ✓ Paid on 12-03-2025                │ ← Green checkmark
│                                      │
│ [Download]                           │ ← Only download
└─────────────────────────────────────┘
```

## Integration Points

### Admin App
1. Admin clicks "Mark Paid" button
2. Confirmation (optional)
3. Status updates in Firestore
4. UI updates automatically via StreamBuilder

### Resident App (Future)
1. Resident makes payment via payment gateway
2. Payment gateway webhook calls backend
3. Backend calls `markBillAsPaid(billId)`
4. Status updates in Firestore
5. Both admin and resident apps update automatically

### Payment Gateway Integration (Future)
```dart
// Example webhook handler
Future<void> handlePaymentWebhook(Map<String, dynamic> paymentData) async {
  final billId = paymentData['billId'];
  final status = paymentData['status'];
  
  if (status == 'success') {
    await billingService.markBillAsPaid(billId);
    
    // Optional: Send notification to admin
    await notificationService.notifyAdmin(
      'Payment received for bill $billId'
    );
  }
}
```

## Testing Steps

### Test Manual Payment
1. Open Billing & Payments screen
2. Find a pending bill
3. Click "Mark Paid" button
4. Verify:
   - ✅ Status badge changes to green "Paid"
   - ✅ "Paid on [date]" appears with checkmark
   - ✅ Action buttons change to only "Download"
   - ✅ Bill disappears from "Bills" tab
   - ✅ Bill appears in "Payment History" tab
   - ✅ KPI metrics update (Total Revenue, Collected %, Pending amount)
   - ✅ Success snackbar appears

### Test Real-Time Updates
1. Open billing screen on two devices/windows
2. Mark bill as paid on device 1
3. Verify device 2 updates automatically within 1-2 seconds

### Test Error Handling
1. Disconnect internet
2. Try to mark bill as paid
3. Verify error message appears
4. Reconnect internet
5. Try again and verify success

## Firestore Structure

### Bill Document (Before Payment)
```json
{
  "id": "bill_123",
  "flatId": "A101",
  "flatLabel": "A-101",
  "residentId": "user_123",
  "residentName": "John Doe",
  "amount": 5500,
  "month": "March",
  "year": "2025",
  "type": "maintenance",
  "status": "pending",
  "dueDate": "2025-03-15T00:00:00Z",
  "paidAt": null,
  "createdAt": "2025-02-20T10:00:00Z",
  "updatedAt": "2025-02-20T10:00:00Z"
}
```

### Bill Document (After Payment)
```json
{
  "id": "bill_123",
  "flatId": "A101",
  "flatLabel": "A-101",
  "residentId": "user_123",
  "residentName": "John Doe",
  "amount": 5500,
  "month": "March",
  "year": "2025",
  "type": "maintenance",
  "status": "paid",                          ← Changed
  "dueDate": "2025-03-15T00:00:00Z",
  "paidAt": "2025-03-12T14:30:00Z",         ← Added
  "createdAt": "2025-02-20T10:00:00Z",
  "updatedAt": "2025-03-12T14:30:00Z"       ← Updated
}
```

## Features

✅ Automatic status update to "paid"
✅ Real-time UI updates via StreamBuilder
✅ Color-coded status badges (Green/Amber/Red)
✅ Automatic tab filtering (Bills vs Payment History)
✅ KPI metrics auto-recalculation
✅ Timestamp tracking (paidAt, updatedAt)
✅ Success/error feedback to user
✅ Action buttons change based on status
✅ Visual indicators (checkmark for paid bills)
✅ No page refresh needed

## Status
✅ Automatic payment status update implemented
✅ Real-time color changes working
✅ StreamBuilder integration complete
✅ Tab filtering functional
✅ KPI auto-update working
✅ Error handling in place

## Future Enhancements
- Payment gateway integration (Razorpay, Stripe, etc.)
- Webhook handlers for automatic payment detection
- Payment receipt generation
- Email/SMS notifications on payment
- Payment history export
- Refund functionality
- Partial payment support
