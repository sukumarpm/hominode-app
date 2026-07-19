# Required Firestore Structure

## Complaint Document Structure

### Collection: `complaints`
### Document ID: `dAONdk0i0cHokqz8w3ma` (example)

## Status: Pending (Not Assigned)

```json
{
  "id": "dAONdk0i0cHokqz8w3ma",
  "userId": "user123",
  "userName": "John Doe",
  "userEmail": "john@example.com",
  "title": "work work",
  "description": "qqqqqqqqqqqq",
  "category": "plumbing",
  "status": "pending",
  "assignedTo": null,
  "technicianPhone": null,
  "assignedStaffId": null,
  "assignedStaffRole": null,
  "createdAt": "2024-02-20T07:23:00Z",
  "updatedAt": "2024-02-20T07:23:00Z"
}
```

**App Shows:**
- Red "Pending" badge
- No staff details
- Info box: "Waiting for staff assignment"

---

## Status: In Progress (Staff Assigned)

```json
{
  "id": "dAONdk0i0cHokqz8w3ma",
  "userId": "user123",
  "userName": "John Doe",
  "userEmail": "john@example.com",
  "title": "work work",
  "description": "qqqqqqqqqqqq",
  "category": "plumbing",
  "status": "inProgress",                    ← MUST BE THIS
  "assignedTo": "preetham",                  ← Staff name
  "technicianPhone": "+91 1234567890",       ← Staff phone
  "assignedStaffId": "staff_preetham_001",   ← CRITICAL: Staff document ID
  "assignedStaffRole": "electrician",        ← Staff role
  "createdAt": "2024-02-20T07:23:00Z",
  "updatedAt": "2024-02-20T07:24:00Z"
}
```

**App Shows:**
- Orange "In Progress" badge
- Full staff card with:
  - Avatar
  - Name: "preetham"
  - Role: "Electrician"
  - Phone: "+91 1234567890"
  - Call button (tappable)
  - Chat button (tappable)
- Timeline showing progress
- "Chat With Technician" button

---

## Status: Completed (Work Done)

```json
{
  "id": "dAONdk0i0cHokqz8w3ma",
  "userId": "user123",
  "userName": "John Doe",
  "userEmail": "john@example.com",
  "title": "work work",
  "description": "qqqqqqqqqqqq",
  "category": "plumbing",
  "status": "completed",                     ← MUST BE THIS
  "assignedTo": "preetham",
  "technicianPhone": "+91 1234567890",
  "assignedStaffId": "staff_preetham_001",
  "assignedStaffRole": "electrician",
  "resolvedAt": "2024-02-20T12:00:00Z",      ← Resolution timestamp
  "createdAt": "2024-02-20T07:23:00Z",
  "updatedAt": "2024-02-20T12:00:00Z"
}
```

**App Shows:**
- Green "Completed" badge
- In History tab (not Active tab)
- Staff details (read-only)
- Timeline showing all steps complete
- Success message: "Work completed successfully"

---

## Staff Document Structure

### Collection: `staff`
### Document ID: `staff_preetham_001` (example)

```json
{
  "name": "preetham",
  "phone": "+91 1234567890",
  "role": "electrician",
  "email": "preetham@example.com",
  "avatarUrl": null,
  "isActive": true,
  "createdAt": "2024-01-15T10:00:00Z",
  "updatedAt": null
}
```

**Role Values:**
- `"plumber"` → Displays as "Plumber"
- `"electrician"` → Displays as "Electrician"
- `"maintenance"` → Displays as "Maintenance Technician"
- `"cleaner"` → Displays as "Cleaning Staff"
- `"security"` → Displays as "Security Personnel"
- `"general"` → Displays as "Support Staff"

---

## Field Mapping

### Complaint Fields

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `id` | string | Yes | Auto-generated document ID |
| `userId` | string | Yes | User who created complaint |
| `userName` | string | Yes | User's display name |
| `userEmail` | string | Yes | User's email |
| `title` | string | Yes | Complaint title |
| `description` | string | Yes | Complaint description |
| `category` | string | Yes | One of: plumbing, electrical, maintenance, cleaning, security, other |
| `status` | string | Yes | One of: pending, inProgress, completed |
| `assignedTo` | string | No | Staff member's name |
| `technicianPhone` | string | No | Staff member's phone |
| `assignedStaffId` | string | No | **CRITICAL:** Staff document ID for fetching full details |
| `assignedStaffRole` | string | No | Staff member's role |
| `createdAt` | timestamp | Yes | When complaint was created |
| `updatedAt` | timestamp | Yes | Last update time |
| `resolvedAt` | timestamp | No | When complaint was resolved |

### Staff Fields

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `name` | string | Yes | Staff member's name |
| `phone` | string | Yes | Staff member's phone |
| `role` | string | Yes | Staff role (plumber, electrician, etc.) |
| `email` | string | No | Staff member's email |
| `avatarUrl` | string | No | Profile picture URL |
| `isActive` | boolean | Yes | Whether staff is active |
| `createdAt` | timestamp | Yes | When staff was added |
| `updatedAt` | timestamp | No | Last update time |

---

## Status Values (MUST BE EXACT)

### ✅ Correct Values:
- `"pending"` (lowercase, no spaces)
- `"inProgress"` (camelCase, no spaces)
- `"completed"` (lowercase, no spaces)

### ❌ Wrong Values:
- `"Pending"` (wrong case)
- `"in_progress"` (underscore)
- `"in-progress"` (hyphen)
- `"In Progress"` (spaces)
- `"COMPLETED"` (uppercase)

---

## Category Values (MUST BE EXACT)

### ✅ Correct Values:
- `"plumbing"`
- `"electrical"`
- `"maintenance"`
- `"cleaning"`
- `"security"`
- `"other"`

### ❌ Wrong Values:
- `"Plumbing"` (wrong case)
- `"ELECTRICAL"` (uppercase)
- `"Maintenance"` (wrong case)

---

## Admin Panel Update Examples

### When Assigning Staff

```dart
// Firestore update
await FirebaseFirestore.instance
    .collection('complaints')
    .doc(complaintId)
    .update({
  'assignedTo': 'preetham',
  'technicianPhone': '+91 1234567890',
  'assignedStaffId': 'staff_preetham_001',  // ← Staff document ID
  'assignedStaffRole': 'electrician',
  'status': 'inProgress',                    // ← Update status
  'updatedAt': FieldValue.serverTimestamp(),
});
```

### When Marking as Resolved

```dart
// Firestore update
await FirebaseFirestore.instance
    .collection('complaints')
    .doc(complaintId)
    .update({
  'status': 'completed',                     // ← Change status
  'resolvedAt': FieldValue.serverTimestamp(),
  'updatedAt': FieldValue.serverTimestamp(),
});
```

---

## Verification Checklist

### For Staff Assignment:

- [ ] `assignedTo` has staff name
- [ ] `technicianPhone` has staff phone
- [ ] `assignedStaffId` has staff document ID (NOT NULL)
- [ ] `assignedStaffRole` has staff role
- [ ] `status` is "inProgress" (NOT "pending")
- [ ] Staff document exists at `staff/{assignedStaffId}`
- [ ] Staff document has `isActive: true`

### For Complaint Resolution:

- [ ] `status` is "completed" (NOT "inProgress")
- [ ] `resolvedAt` has timestamp
- [ ] `updatedAt` has timestamp

### For App Display:

- [ ] Console shows "Staff cached: [name]"
- [ ] App shows full staff card
- [ ] Call button is tappable
- [ ] Chat button is tappable
- [ ] Status badge shows correct color
- [ ] Completed complaints are in History tab

---

## Common Issues and Fixes

### Issue: Shows "Assigned to: preetham" (text only)

**Cause:** `assignedStaffId` is null

**Fix:**
```json
{
  "assignedStaffId": "staff_preetham_001"  // Add this field
}
```

### Issue: Status stays "pending" after assignment

**Cause:** Status not updated

**Fix:**
```json
{
  "status": "inProgress"  // Change to this
}
```

### Issue: Complaint doesn't move to History

**Cause:** Status not "completed"

**Fix:**
```json
{
  "status": "completed"  // Change to this
}
```

### Issue: Staff fetch fails

**Cause:** Staff document doesn't exist

**Fix:** Create staff document at `staff/{assignedStaffId}` with required fields

---

## Summary

**For staff card with call/chat buttons to show:**
1. Complaint must have `assignedStaffId` (NOT NULL)
2. Staff document must exist at `staff/{assignedStaffId}`
3. Status should be "inProgress"

**For complaint to move to History:**
1. Status must be "completed"

**The app code is correct. Just ensure Firestore has the right data structure!**
