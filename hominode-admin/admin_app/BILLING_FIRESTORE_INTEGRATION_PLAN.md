# Billing & Payments - Firestore Integration Plan

## Current Status
- ✅ BillingService exists with Firestore methods
- ✅ BillModel defined
- ❌ Billing screen uses demo data
- ❌ Create bill not integrated with Firestore
- ❌ Bills not visible in resident app

## Requirements

### 1. Remove Demo Data
- Remove mock `_bills` list
- Remove mock `_kpiData`
- Fetch real data from Firestore

### 2. Firestore Integration
- Collection: `bills`
- Real-time updates via StreamBuilder
- Calculate KPIs from actual data

### 3. Create Bill Flow
- Click "Create Bill" button
- Open modal with form
- Select residents/flats
- Enter amount and details
- Save to Firestore
- Bills appear in resident app

### 4. Firestore Structure

```json
{
  "bills": {
    "billId": {
      "flatId": "flat_doc_id",
      "flatLabel": "A-101",
      "residentId": "user_doc_id",
      "residentName": "John Doe",
      "amount": 5500,
      "month": "November",
      "year": "2024",
      "type": "maintenance",
      "status": "pending",
      "dueDate": "2024-11-05T00:00:00Z",
      "paidAt": null,
      "createdAt": "timestamp",
      "updatedAt": "timestamp"
    }
  }
}
```

### 5. Bill Status Flow
- `pending` - Bill created, not paid
- `paid` - Payment received
- `overdue` - Past due date, not paid

### 6. Resident App Integration
- Residents see their bills in resident app
- Filter by `residentId`
- Show status, amount, due date
- Payment button (future feature)

## Implementation Steps

### Step 1: Update BillingService
- Add `dueDate` field
- Add method to get bills by resident
- Add method to calculate KPIs
- Add method to generate monthly bills

### Step 2: Update Billing Screen
- Remove demo data
- Use StreamBuilder for real-time data
- Fetch bills from Firestore
- Calculate KPIs from actual bills

### Step 3: Update Create Bill Modal
- Fetch residents from Firestore
- Fetch flats from Firestore
- Save bill to Firestore on submit
- Show success message

### Step 4: Add KPI Calculations
- Total Revenue: Sum of all paid bills
- Collection Rate: (Paid / Total) * 100
- Pending Amount: Sum of pending bills
- Overdue Amount: Sum of overdue bills

### Step 5: Resident App (Future)
- Create resident app billing screen
- Fetch bills by residentId
- Show payment history
- Payment gateway integration

## Files to Modify

1. `lib/services/billing_service.dart` - Add methods
2. `lib/billing_screen.dart` - Remove demo data, add Firestore
3. `lib/widgets/create_monthly_bill_modal.dart` - Firestore integration
4. `lib/models/maintenance_bill.dart` - Update model

## Data Flow

```
Admin App:
Create Bill → Save to Firestore → Real-time update

Resident App:
Fetch Bills (by residentId) → Display → Payment

Both Apps:
StreamBuilder → Real-time updates
```

## Status Tracking

Bills visible in:
- ✅ Admin App (all bills)
- ✅ Resident App (filtered by residentId)
- ✅ Real-time updates
- ✅ Status changes reflected immediately

## Next Steps

1. Update BillingService with new methods
2. Modify billing screen to use Firestore
3. Update create bill modal
4. Test with real data
5. Document for resident app team
