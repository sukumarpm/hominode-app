# 🎯 Visitor Management - Resident & Admin Flow

## Updated Implementation: Resident Can Only Cancel, Admin Approves

---

## 👥 User Roles

### 1. Resident (User)
**Can:**
- ✅ Add expected visitors
- ✅ View pending visitors (awaiting admin approval)
- ✅ Cancel their own pending visitor requests
- ✅ View approved visitors
- ✅ View QR pass for approved visitors

**Cannot:**
- ❌ Approve visitors (only admin can approve)

### 2. Admin
**Can:**
- ✅ View all pending visitor requests
- ✅ Approve visitor requests
- ✅ Reject visitor requests
- ✅ View all approved visitors

---

## 🔄 Complete Flow

### Step 1: Resident Adds Visitor
```
Resident opens app
    ↓
Navigate to Visitor Management
    ↓
Click FAB (+) button
    ↓
Fill visitor details:
  - Visitor Name
  - Purpose
  - Phone Number (optional)
  - Vehicle Number (optional)
  - Date
  - Time
    ↓
Click "Add Visitor"
    ↓
Saved to Firestore:
{
  "visitorName": "John Doe",
  "purpose": "Personal visit",
  "expectedArrival": "2026-02-16T14:30:00Z",
  "phoneNumber": "+91 98765 43210",
  "vehicleNumber": "MH 01 AB 1234",
  "status": "expected",
  "isApproved": false,  ← Waiting for admin
  "hostUserId": "resident123",
  "createdAt": "2026-02-15T10:00:00Z"
}
    ↓
Appears in Pending Tab
```

---

### Step 2: Resident Views Pending Request

**Pending Tab Display:**
```
┌─────────────────────────────────────────────┐
│ 👤 John Doe      [Awaiting Approval]       │
│    Personal visit                           │
│    ⏰ 2:30 PM Tomorrow                     │
│    📞 +91 98765 43210                      │
│    🚗 MH 01 AB 1234                        │
│                                             │
│ [Cancel Request]                            │
└─────────────────────────────────────────────┘
```

**What Resident Sees:**
- ✅ Visitor name and details
- ✅ Purpose of visit
- ✅ Expected arrival date and time
- ✅ Phone number (if provided)
- ✅ Vehicle number (if provided)
- ✅ Red "Awaiting Approval" badge
- ✅ "Cancel Request" button (red outline)
- ❌ NO "Approve" button (only admin can approve)

---

### Step 3: Resident Can Cancel Request

**If resident wants to cancel:**
```
Click "Cancel Request" button
    ↓
Confirmation dialog appears:
"Cancel Visitor Request"
"Are you sure you want to cancel the visitor request for John Doe?"
    ↓
Click "Yes, Cancel"
    ↓
Visitor deleted from Firestore
    ↓
Disappears from Pending tab
    ↓
Success message: "Visitor request for John Doe cancelled"
```

---

### Step 4: Admin Approves Request

**Admin Process (separate admin app/panel):**
```
Admin views pending requests
    ↓
Reviews visitor details
    ↓
Clicks "Approve"
    ↓
Firestore updated:
{
  "isApproved": true,  ← Changed by admin
  "approvedBy": "admin123",
  "approvedAt": "2026-02-15T11:00:00Z",
  "updatedAt": "2026-02-15T11:00:00Z"
}
    ↓
Visitor moves to Approved status
```

---

### Step 5: Resident Views Approved Visitor

**Approved Tab Display:**
```
┌─────────────────────────────────────────────┐
│ 👤 John Doe           [Approved]           │
│    Personal visit                           │
│    ⏰ 2:30 PM Tomorrow                     │
│    📞 +91 98765 43210                      │
│    🚗 MH 01 AB 1234                        │
│                                             │
│ [🔲 View QR Pass]                          │
└─────────────────────────────────────────────┘
```

**What Resident Sees:**
- ✅ Visitor name and details
- ✅ Green "Approved" badge
- ✅ "View QR Pass" button
- ❌ NO "Cancel Request" button (already approved)
- ❌ NO "Approve" button

---

## 📊 Tab Structure

### Pending Tab (Awaiting Admin Approval)

**Filter:**
```dart
filteredVisitors = allVisitors
    .where((v) => v['isApproved'] == false && v['status'] == 'expected')
    .toList();
```

**Shows:**
- Visitors added by resident
- Waiting for admin approval
- `isApproved: false`
- `status: expected`

**Actions Available:**
- ✅ Cancel Request (delete from Firestore)
- ❌ Approve (only admin can do this)

**Empty State:**
```
┌─────────────────────────────────────────────┐
│                                             │
│              ⏱️                             │
│         No pending visitors                 │
│   Add expected visitors using the + button. │
│     Admin will approve your requests.       │
│                                             │
└─────────────────────────────────────────────┘
```

---

### Approved Tab (Admin Approved)

**Filter:**
```dart
filteredVisitors = allVisitors
    .where((v) => v['isApproved'] == true)
    .toList();
```

**Shows:**
- Visitors approved by admin
- `isApproved: true`

**Actions Available:**
- ✅ View QR Pass
- ❌ Cancel (cannot cancel approved visitors)

**Empty State:**
```
┌─────────────────────────────────────────────┐
│                                             │
│              ✅                             │
│        No approved visitors                 │
│   Admin-approved visitors will appear here  │
│                                             │
└─────────────────────────────────────────────┘
```

---

## 🎨 UI Components

### Status Badges

**Awaiting Approval (Pending):**
```dart
Container(
  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
  decoration: BoxDecoration(
    color: Color(0xFFFFE6EB),  // Light red
    borderRadius: BorderRadius.circular(8),
  ),
  child: Text(
    'Awaiting Approval',
    style: TextStyle(
      color: Color(0xFFE11D48),  // Dark red
      fontSize: 12,
      fontWeight: FontWeight.w600,
    ),
  ),
)
```

**Approved:**
```dart
Container(
  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
  decoration: BoxDecoration(
    color: Color(0xFFD1FAE5),  // Light green
    borderRadius: BorderRadius.circular(8),
  ),
  child: Text(
    'Approved',
    style: TextStyle(
      color: Color(0xFF10B981),  // Dark green
      fontSize: 12,
      fontWeight: FontWeight.w600,
    ),
  ),
)
```

---

### Action Buttons

**Cancel Request Button (Pending Tab):**
```dart
SizedBox(
  width: double.infinity,
  height: 48,
  child: OutlinedButton(
    onPressed: () => _rejectVisitor(visitorId, visitorName),
    style: OutlinedButton.styleFrom(
      foregroundColor: Color(0xFFDC2626),
      side: BorderSide(color: Color(0xFFDC2626), width: 1.5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),
    child: Text(
      'Cancel Request',
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
    ),
  ),
)
```

**View QR Pass Button (Approved Tab):**
```dart
SizedBox(
  width: double.infinity,
  height: 48,
  child: OutlinedButton.icon(
    onPressed: () => Navigator.push(...),
    icon: Icon(Icons.qr_code_2, size: 20),
    label: Text(
      'View QR Pass',
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
    ),
    style: OutlinedButton.styleFrom(
      foregroundColor: Color(0xFF2563EB),
      side: BorderSide(color: Color(0xFF2563EB), width: 1.5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),
  ),
)
```

---

## 🧪 Testing Scenarios

### Test 1: Add Visitor Request

**Steps:**
1. Open Visitor Management screen
2. Click FAB (+) button
3. Fill details:
   - Name: Test Visitor
   - Purpose: Personal visit
   - Phone: +91 98765 43210
   - Vehicle: MH 01 AB 1234
   - Date: Tomorrow
   - Time: 2:00 PM
4. Click "Add Visitor"

**Expected Result:**
- ✅ Success message appears
- ✅ Modal closes
- ✅ Visitor appears in Pending tab
- ✅ Shows "Awaiting Approval" badge (red)
- ✅ Shows "Cancel Request" button
- ✅ Does NOT show "Approve" button
- ✅ Shows date: "2:00 PM Tomorrow"
- ✅ Shows phone: "+91 98765 43210"
- ✅ Shows vehicle: "MH 01 AB 1234"

**Firestore Verification:**
```javascript
visitors/{visitorId}
  visitorName: "Test Visitor"
  purpose: "Personal visit"
  phoneNumber: "+91 98765 43210"
  vehicleNumber: "MH 01 AB 1234"
  expectedArrival: Timestamp (tomorrow 2:00 PM)
  isApproved: false  ← Must be false
  status: "expected"
```

---

### Test 2: Cancel Visitor Request

**Steps:**
1. Go to Pending tab
2. Find visitor
3. Click "Cancel Request" button
4. Confirmation dialog appears
5. Click "Yes, Cancel"

**Expected Result:**
- ✅ Confirmation dialog: "Cancel Visitor Request"
- ✅ Dialog message: "Are you sure you want to cancel the visitor request for Test Visitor?"
- ✅ Loading spinner appears
- ✅ Success message: "Visitor request for Test Visitor cancelled"
- ✅ Visitor disappears from Pending tab
- ✅ Visitor NOT in Approved tab
- ✅ Firestore document deleted

**Firestore Verification:**
```javascript
visitors/{visitorId}  ← Document deleted
```

---

### Test 3: Admin Approves (Simulated)

**Steps:**
1. Go to Firebase Console
2. Find visitor document in Firestore
3. Manually update:
   - `isApproved: true`
   - `approvedBy: "admin123"`
   - `approvedAt: [current timestamp]`
4. Go back to app

**Expected Result:**
- ✅ Visitor automatically disappears from Pending tab
- ✅ Visitor automatically appears in Approved tab
- ✅ Shows "Approved" badge (green)
- ✅ Shows "View QR Pass" button
- ✅ Does NOT show "Cancel Request" button
- ✅ Real-time update (no manual refresh needed)

---

### Test 4: View QR Pass

**Steps:**
1. Go to Approved tab
2. Find approved visitor
3. Click "View QR Pass" button

**Expected Result:**
- ✅ Navigates to QR screen
- ✅ Shows visitor name
- ✅ Shows purpose
- ✅ Shows time
- ✅ Shows QR code

---

## 📱 Screen States

### Pending Tab - With Visitors
```
┌─────────────────────────────────────────────┐
│ Visitor Management                    [×]   │
├─────────────────────────────────────────────┤
│                                             │
│ [Pending] [Approved] [Deliveries]           │
│                                             │
│ ┌─────────────────────────────────────────┐ │
│ │ 👤 John Doe    [Awaiting Approval]     │ │
│ │    Personal visit                       │ │
│ │    ⏰ 2:30 PM Tomorrow                 │ │
│ │    📞 +91 98765 43210                  │ │
│ │    🚗 MH 01 AB 1234                    │ │
│ │                                         │ │
│ │ [Cancel Request]                        │ │
│ └─────────────────────────────────────────┘ │
│                                             │
│ ┌─────────────────────────────────────────┐ │
│ │ 👤 Jane Smith  [Awaiting Approval]     │ │
│ │    Delivery                             │ │
│ │    ⏰ 4:00 PM Today                    │ │
│ │                                         │ │
│ │ [Cancel Request]                        │ │
│ └─────────────────────────────────────────┘ │
│                                             │
└─────────────────────────────────────────────┘
                    [+]
```

---

### Approved Tab - With Visitors
```
┌─────────────────────────────────────────────┐
│ Visitor Management                    [×]   │
├─────────────────────────────────────────────┤
│                                             │
│ [Pending] [Approved] [Deliveries]           │
│                                             │
│ ┌─────────────────────────────────────────┐ │
│ │ 👤 John Doe         [Approved]         │ │
│ │    Personal visit                       │ │
│ │    ⏰ 2:30 PM Tomorrow                 │ │
│ │    📞 +91 98765 43210                  │ │
│ │    🚗 MH 01 AB 1234                    │ │
│ │                                         │ │
│ │ [🔲 View QR Pass]                      │ │
│ └─────────────────────────────────────────┘ │
│                                             │
│ ┌─────────────────────────────────────────┐ │
│ │ 👤 Jane Smith       [Approved]         │ │
│ │    Delivery                             │ │
│ │    ⏰ 4:00 PM Today                    │ │
│ │                                         │ │
│ │ [🔲 View QR Pass]                      │ │
│ └─────────────────────────────────────────┘ │
│                                             │
└─────────────────────────────────────────────┘
                    [+]
```

---

## 🔥 Firestore Data Structure

### Pending Visitor (Awaiting Approval)
```json
{
  "id": "visitor123",
  "hostUserId": "resident123",
  "hostName": "Amit Kumar",
  "hostEmail": "amit@example.com",
  "visitorName": "John Doe",
  "purpose": "Personal visit",
  "expectedArrival": "2026-02-16T14:30:00Z",
  "phoneNumber": "+91 98765 43210",
  "vehicleNumber": "MH 01 AB 1234",
  "status": "expected",
  "isApproved": false,
  "approvedBy": null,
  "approvedAt": null,
  "createdAt": "2026-02-15T10:00:00Z",
  "updatedAt": "2026-02-15T10:00:00Z"
}
```

### Approved Visitor (Admin Approved)
```json
{
  "id": "visitor123",
  "hostUserId": "resident123",
  "hostName": "Amit Kumar",
  "hostEmail": "amit@example.com",
  "visitorName": "John Doe",
  "purpose": "Personal visit",
  "expectedArrival": "2026-02-16T14:30:00Z",
  "phoneNumber": "+91 98765 43210",
  "vehicleNumber": "MH 01 AB 1234",
  "status": "expected",
  "isApproved": true,
  "approvedBy": "admin123",
  "approvedAt": "2026-02-15T11:00:00Z",
  "createdAt": "2026-02-15T10:00:00Z",
  "updatedAt": "2026-02-15T11:00:00Z"
}
```

---

## ✅ Summary of Changes

### What Changed:
1. ✅ Removed "Approve" button from Pending tab
2. ✅ Changed "Reject" button to "Cancel Request"
3. ✅ Updated button to full width (no longer in row)
4. ✅ Changed status badge from "Pending" to "Awaiting Approval"
5. ✅ Updated empty state messages to mention admin approval
6. ✅ Updated confirmation dialog text
7. ✅ Updated success message text

### What Stayed the Same:
- ✅ Real-time data streaming
- ✅ Firestore integration
- ✅ Status filtering (Pending/Approved)
- ✅ Date and time display
- ✅ Phone and vehicle number display
- ✅ QR pass functionality
- ✅ Loading and error states

---

## 🎯 Key Points

1. **Resident Role:**
   - Can add visitors
   - Can cancel their own pending requests
   - Cannot approve visitors
   - Can view approved visitors
   - Can view QR pass for approved visitors

2. **Admin Role:**
   - Approves visitor requests (via admin panel/app)
   - Can reject visitor requests
   - Has full control over visitor approval

3. **Status Flow:**
   - Add Visitor → Pending (Awaiting Approval) → Admin Approves → Approved
   - Resident can cancel at Pending stage only

4. **UI Clarity:**
   - "Awaiting Approval" badge clearly indicates admin action needed
   - "Cancel Request" button clearly indicates resident can only cancel
   - Empty states explain admin approval process

---

## 🚀 Ready to Test!

The visitor management screen now correctly implements the resident/admin flow:
- Residents add visitors and wait for admin approval
- Residents can only cancel their pending requests
- Only admin can approve visitors
- Approved visitors show QR pass option

**The implementation is complete and ready to use! 🎉**
