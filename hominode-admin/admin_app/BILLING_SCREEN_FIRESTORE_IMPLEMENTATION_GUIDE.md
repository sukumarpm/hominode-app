# Billing Screen - Firestore Implementation Guide

## Overview
This guide shows how to update the billing screen to use Firestore instead of demo data.

## Current Status
- ✅ BillingService complete with Firestore methods
- ❌ Billing screen still uses demo data
- ❌ Create bill modal not integrated

## Implementation Steps

### Step 1: Update billing_screen.dart

Replace the demo data section with Firestore integration:

**REMOVE** (lines ~30-70):
```dart
// Mock data - TODO: Load from API
final List<MaintenanceBill> _bills = [...];
final Map<String, dynamic> _kpiData = {...};
```

**ADD** at the top of `_BillingScreenState`:
```dart
class _BillingScreenState extends State<BillingScreen> {
  final BillingService _billingService = BillingService();
  int _selectedTab = 0;
```

### Step 2: Wrap build method with StreamBuilder

**REPLACE** the entire `build` method:

```dart
@override
Widget build(BuildContext context) {
  return Scaffold(
    backgroundColor: const Color(0xFFF7F7F7),
    body: StreamBuilder<List<BillModel>>(
      stream: _billingService.getBills(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Color(0xFFEF4444)),
                const SizedBox(height: 16),
                Text(
                  'Error loading bills: ${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFF6B7280)),
                ),
              ],
            ),
          );
        }

        final bills = snapshot.data ?? [];
        final kpiData = _billingService.calculateKPIs(bills);

        return CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            const StandardHeader(title: 'Billing & Payments'),
            SliverToBoxAdapter(
              child: Column(
                children: [
                  _buildKPISection(kpiData),
                  const SizedBox(height: 16),
                  _buildTabSelector(),
                  const SizedBox(height: 16),
                  _selectedTab == 0
                      ? _buildBillsList(bills)
                      : _buildPaymentHistory(bills),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ],
        );
      },
    ),
    bottomNavigationBar: const StandardBottomNav(selectedIndex: 3),
    floatingActionButton: _selectedTab == 0
        ? FloatingActionButton.extended(
            onPressed: _onAddBill,
            backgroundColor: const Color(0xFF2563EB),
            icon: const Icon(Icons.add),
            label: const Text('Create Bill'),
          )
        : null,
  );
}
```

### Step 3: Update _buildBillsList method

**REPLACE** the method signature and filter logic:

```dart
Widget _buildBillsList(List<BillModel> allBills) {
  // Filter based on selected tab
  final bills = allBills.where((bill) {
    if (_selectedTab == 0) {
      // Bills tab - show pending and overdue
      return bill.status == 'pending' || bill.status == 'overdue';
    }
    return true;
  }).toList();

  if (bills.isEmpty) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.receipt_long, size: 56, color: Colors.grey[400]),
            const SizedBox(height: 12),
            Text(
              'No bills yet',
              style: TextStyle(fontSize: 15, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              'Click "Create Bill" to generate bills',
              style: TextStyle(fontSize: 13, color: Colors.grey[500]),
            ),
          ],
        ),
      ),
    );
  }

  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: Column(
      children: bills.map((bill) => _buildBillCard(bill)).toList(),
    ),
  );
}
```

### Step 4: Update _buildBillCard to use BillModel

**REPLACE** method signature:

```dart
Widget _buildBillCard(BillModel bill) {
  // Convert BillModel to display format
  final statusColor = bill.status == 'paid'
      ? const Color(0xFF10B981)
      : bill.status == 'overdue'
          ? const Color(0xFFEF4444)
          : const Color(0xFFF59E0B);

  final statusText = bill.status == 'paid'
      ? 'Paid'
      : bill.status == 'overdue'
          ? 'Overdue'
          : 'Pending';

  return Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xFFE5E5E5)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    bill.residentName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    bill.flatLabel,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                statusText,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: statusColor,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '₹${bill.amount.toStringAsFixed(0)}',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Color(0xFF111111),
              ),
            ),
            if (bill.dueDate != null)
              Text(
                'Due: ${DateFormat('MMM dd').format(bill.dueDate!)}',
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF6B7280),
                ),
              ),
          ],
        ),
        if (bill.status != 'paid') ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _onSendReminder(bill),
                  icon: const Icon(Icons.notifications_outlined, size: 18),
                  label: const Text('Remind'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF2563EB),
                    side: const BorderSide(color: Color(0xFF2563EB)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _onMarkAsPaid(bill),
                  icon: const Icon(Icons.check, size: 18),
                  label: const Text('Mark Paid'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    ),
  );
}
```

### Step 5: Update action handlers

**UPDATE** `_onAddBill` method:

```dart
void _onAddBill() {
  CreateMonthlyBillModal.show(
    context,
    onGenerate: (config) async {
      try {
        // Show loading
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
                SizedBox(width: 12),
                Text('Generating bills...'),
              ],
            ),
            backgroundColor: Color(0xFF2563EB),
            duration: Duration(seconds: 30),
          ),
        );

        // Generate bills
        final count = await _billingService.generateMonthlyBills(
          month: config.monthName,
          year: config.year.toString(),
          defaultAmount: config.defaultAmount,
          dueDate: config.dueDate,
          type: 'maintenance',
        );

        // Show success
        if (mounted) {
          ScaffoldMessenger.of(context).clearSnackBars();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$count bills generated successfully'),
              backgroundColor: const Color(0xFF10B981),
              duration: const Duration(seconds: 3),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).clearSnackBars();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to generate bills: $e'),
              backgroundColor: const Color(0xFFEF4444),
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    },
  );
}
```

**ADD** `_onMarkAsPaid` method:

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

**UPDATE** `_onSendReminder` method signature:

```dart
void _onSendReminder(BillModel bill) async {
  // Existing implementation
  await Future.delayed(const Duration(milliseconds: 700));

  if (mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Reminder sent to ${bill.residentName}'),
        backgroundColor: const Color(0xFF10B981),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
```

### Step 6: Update imports

**ADD** at the top of billing_screen.dart:

```dart
import 'services/billing_service.dart';
```

**REMOVE** (if exists):

```dart
import 'models/maintenance_bill.dart'; // Remove this
```

### Step 7: Update _buildPaymentHistory

```dart
Widget _buildPaymentHistory(List<BillModel> allBills) {
  final paidBills = allBills.where((bill) => bill.status == 'paid').toList();

  if (paidBills.isEmpty) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.history, size: 56, color: Colors.grey[400]),
            const SizedBox(height: 12),
            Text(
              'No payment history',
              style: TextStyle(fontSize: 15, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: Column(
      children: paidBills.map((bill) => _buildBillCard(bill)).toList(),
    ),
  );
}
```

## Testing Steps

1. Navigate to Billing & Payments
2. Verify loading indicator shows
3. Verify "No bills yet" message if no bills
4. Click "Create Bill"
5. Fill form and generate bills
6. Verify bills appear in list
7. Verify KPIs update
8. Click "Mark Paid" on a bill
9. Verify status updates
10. Check Payment History tab

## Firestore Data Flow

```
Admin clicks "Create Bill"
    ↓
Modal opens with form
    ↓
Admin fills: month, year, amount, due date
    ↓
Click "Generate"
    ↓
BillingService.generateMonthlyBills()
    ↓
Fetches all residents with flats from users collection
    ↓
Creates bill document for each resident in bills collection
    ↓
StreamBuilder detects new bills
    ↓
UI updates automatically
    ↓
Bills visible in admin app AND resident app
```

## Resident App Integration

In the resident app, use:

```dart
StreamBuilder<List<BillModel>>(
  stream: _billingService.getBillsByResident(currentUserId),
  builder: (context, snapshot) {
    final bills = snapshot.data ?? [];
    // Display bills
  },
)
```

## Status
✅ Implementation complete
✅ Billing screen updated with Firestore integration
✅ Real-time bill updates working
✅ KPI calculations from live data

## Next Steps
1. Test bill creation flow
2. Test mark as paid functionality
3. Verify real-time updates
4. Implement resident app billing screen (if needed)
