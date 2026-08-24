# Billing Screen - Implementation Guide

## Overview
The Billing screen allows admins to track payments, manage maintenance bills, send reminders, and export reports. It features KPI cards, bill management, and export functionality.

## Visual Design

### Screen Layout
- **Background**: Light grey (#F7F7F7)
- **Header**: Blue gradient (#2563EB → #1E40AF) with back button and "+ Add" button
- **Section Title**: "Maintenance & Billing" (bold, 20sp)
- **KPI Cards**: 2×2 grid showing Total Revenue, Collected, Pending, Overdue
- **Segmented Control**: Bills / Payment History tabs
- **Bill Cards**: List of maintenance bills with status indicators
- **Export Section**: PDF and Excel export buttons

### KPI Cards (2×2 Grid)
Four cards showing key metrics:
- **Total Revenue (Nov)**: ₹8.4L (blue)
- **Collected**: 94% (green)
- **Pending**: ₹48K (orange)
- **Overdue**: ₹48K (blue)

### Bill Card Layout
Each card displays:
- **Header**: Resident name + Status pill (Paid/Pending/Overdue)
- **Unit**: Unit number in grey
- **Info Block**: Amount and Due Date in light grey container
- **Status Line**: "Paid on [date]" with green checkmark (for paid bills)
- **Action Buttons**:
  - Paid: Single "Download" button
  - Pending/Overdue: "Send Reminder" + "Download" buttons

### Status Pills
- **Paid**: Green background (#22C55E), white text
- **Pending**: Light yellow background (#FEF3C7), orange text (#F59E0B)
- **Overdue**: Light red background (#FEE2E2), red text (#DC2626)

## Features

### 1. Tab Navigation
```dart
// Toggle between Bills and Payment History
int _selectedTab = 0; // 0 = Bills, 1 = Payment History
```

### 2. Bill Management
- View all maintenance bills
- Filter by status (Paid/Pending/Overdue)
- Send payment reminders
- Download individual bills

### 3. Export Reports
- Export all bills as PDF
- Export all bills as Excel
- Bulk download functionality

### 4. KPI Dashboard
- Real-time revenue tracking
- Collection percentage
- Pending and overdue amounts

## Data Model

```dart
enum BillStatus {
  paid,
  pending,
  overdue,
}

class MaintenanceBill {
  final String id;
  final String residentName;
  final String unit;
  final double amount;
  final DateTime dueDate;
  final DateTime? paidOn;
  final BillStatus status;
}
```

## Usage

### Accessing Billing Screen
1. Navigate from bottom navigation (Billing tab)
2. Or use route: `Navigator.pushNamed(context, '/billing')`

### Send Reminder Flow
```dart
void _onSendReminder(MaintenanceBill bill) async {
  await Future.delayed(const Duration(milliseconds: 700));
  // Show success message
  // TODO: Integrate with push/SMS/WhatsApp APIs
}
```

### Download Bill Flow
```dart
void _onDownloadBill(MaintenanceBill bill) async {
  await Future.delayed(const Duration(milliseconds: 500));
  // Show downloading message
  // TODO: Generate and download PDF
}
```

### Export Flow
```dart
void _onExportPDF() async {
  // Generate PDF report
  // TODO: POST /api/bills/export/pdf
}

void _onExportExcel() async {
  // Generate Excel report
  // TODO: POST /api/bills/export/excel
}
```

## Integration Points

### TODO: Backend Integration

1. **Fetch Bills**
   ```
   GET /api/bills?month=11&year=2025
   ```

2. **Fetch KPI Data**
   ```
   GET /api/bills/kpi?month=11&year=2025
   ```

3. **Send Reminder**
   ```
   POST /api/bills/{id}/send-reminder
   - Send via SMS/WhatsApp/Email
   ```

4. **Download Bill**
   ```
   GET /api/bills/{id}/pdf
   - Generate PDF invoice
   ```

5. **Export Reports**
   ```
   POST /api/bills/export/pdf
   POST /api/bills/export/excel
   ```

6. **Add New Bill**
   ```
   POST /api/bills
   {
     "residentId": "...",
     "amount": 5500,
     "dueDate": "2025-11-05",
     "description": "Monthly maintenance"
   }
   ```

## Accessibility

All interactive elements include semantic labels:
- Bill card: "Bill card for [name], unit [unit], status [status], amount ₹[amount]"
- Send reminder: "Send reminder button"
- Download: "Download bill button"
- Export: "Export PDF" / "Export Excel"

## Responsive Design

- Works on iPhone 13 and other devices
- Bouncing scroll physics
- Touch targets minimum 44×44
- Proper SafeArea handling
- Compact spacing matching overall UI flow

## Mock Data

The screen includes 3 sample bills:
1. **Rajesh Kumar** (A-204) - Paid - ₹5,500
2. **Priya Sharma** (B-305) - Pending - ₹5,500
3. **Sneha Reddy** (D-401) - Overdue - ₹11,000

KPI Data:
- Total Revenue: ₹8.4L
- Collected: 94%
- Pending: ₹48K
- Overdue: ₹48K

## Files Created
- `admin_app/lib/models/maintenance_bill.dart` - Bill data model
- `admin_app/lib/billing_screen.dart` - Main billing screen
- `admin_app/lib/main.dart` - Updated with billing route

## Next Steps
1. Integrate with real backend API
2. Implement Add Bill modal/form
3. Add payment history view
4. Implement PDF/Excel generation
5. Add filtering and sorting options
6. Add date range picker for reports
7. Implement bulk actions (send reminders to all pending)
8. Add payment gateway integration
