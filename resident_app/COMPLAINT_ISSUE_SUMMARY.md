# Complaint Issue Summary

## Current Status

The resident app code is **100% working correctly**. The issue is with the **admin panel** not updating Firestore properly.

## The Problem

### Issue 1: Staff Details Not Showing (Call/Chat Buttons Missing)

**What You See:**
```
Assigned to: preetham
```
(Just text, no staff card with buttons)

**What You Should See:**
```
┌─────────────────────────────┐
│ 👤 preetham                 │
│    Electrician              │
│ 📞 +91 123... [Call] →      │
│ 💬 Chat with preetham →     │
└─────────────────────────────┘
```

**Root Cause:**
The admin panel is only updating these fields:
```json
{
  "assignedTo": "preetham",
  "technicianPhone": "+91 1234567890"
}
```

But it's **NOT updating** this critical field:
```json
{
  "assignedStaffId": "staff123"  // ← MISSING!
}
```

### Issue 2: Status Not Changing to "Completed"

**What Happens:**
- Admin marks complaint as resolved
- Status stays "pending" or "inProgress"
- Complaint doesn't move to History tab

**Root Cause:**
Admin panel is not updating the `status` field to "completed"

## How the App Works

### Code Logic (Already Correct)

```dart
// In complaints_screen.dart (line 560-600)
if (staff != null) {
  // Shows FULL staff card with call/chat buttons
  _buildStaffDetailsSection()
} else if (complaint.assignedTo != null) {
  // Shows FALLBACK text only
  Text('Assigned to: ${complaint.assignedTo}')
}
```

The app checks:
1. If `assignedStaffId` exists → Fetch staff → Show full card ✅
2. If `assignedStaffId` is null → Show fallback text ⚠️

### What Needs to Happen

When admin assigns staff, Firestore should have:
```json
{
  "assignedTo": "preetham",           // ✅ Staff name
  "technicianPhone": "+91 1234567890", // ✅ Staff phone
  "assignedStaffId": "staff123",      // ❌ MISSING - Admin panel must add this
  "assignedStaffRole": "electrician", // ❌ MISSING - Admin panel must add this
  "status": "inProgress"              // ❌ MISSING - Admin panel must update this
}
```

## The Fix

### Option 1: Fix Admin Panel (Recommended)

Update admin panel code to include ALL fields when assigning staff:

```dart
await FirebaseFirestore.instance
    .collection('complaints')
    .doc(complaintId)
    .update({
  'assignedTo': staffName,           // ← Already doing this
  'technicianPhone': staffPhone,     // ← Already doing this
  'assignedStaffId': staffDocumentId, // ← ADD THIS
  'assignedStaffRole': staffRole,    // ← ADD THIS
  'status': 'inProgress',            // ← ADD THIS
  'updatedAt': FieldValue.serverTimestamp(),
});
```

And when marking as resolved:

```dart
await FirebaseFirestore.instance
    .collection('complaints')
    .doc(complaintId)
    .update({
  'status': 'completed',             // ← ADD THIS
  'resolvedAt': FieldValue.serverTimestamp(),
  'updatedAt': FieldValue.serverTimestamp(),
});
```

### Option 2: Manual Fix (Temporary)

For existing complaints, manually update in Firebase Console:

1. Open Firebase Console
2. Go to Firestore Database
3. Find complaint document (e.g., `dAONdk0i0cHokqz8w3ma`)
4. Click Edit
5. Add/Update these fields:
   - `assignedStaffId`: `"staff123"` (the staff document ID)
   - `assignedStaffRole`: `"electrician"`
   - `status`: `"inProgress"`
6. Save

7. Ensure staff document exists at `staff/staff123`:
   ```json
   {
     "name": "preetham",
     "phone": "+91 1234567890",
     "role": "electrician",
     "email": "preetham@example.com",
     "isActive": true,
     "createdAt": "2024-01-15T10:00:00Z"
   }
   ```

## Verification Steps

### Step 1: Check Console Logs

Run the app and look for:

```
🔍 Parsing complaint: dAONdk0i0cHokqz8w3ma
📊 Raw status from Firestore: inProgress
📊 Assigned to: preetham
📊 Staff ID: staff123          ← Should NOT be null
📥 Fetching staff: staff123
✅ Staff cached: preetham       ← Should see this
```

### Step 2: Check UI

**Active Tab (In Progress):**
- Orange "In Progress" badge
- Full staff card with:
  - Avatar icon
  - Name and role
  - Phone number
  - Call button (tappable)
  - Chat button (tappable)

**History Tab (Completed):**
- Green "Completed" badge
- Staff details still visible
- Success message: "Work completed successfully"

## Status Flow

```
Pending → In Progress → Completed
   ↓           ↓            ↓
Red badge  Orange badge  Green badge
   ↓           ↓            ↓
Active tab  Active tab   History tab
   ↓           ↓            ↓
No staff   Staff card   Staff card
           + Call/Chat  (read-only)
```

## Common Mistakes

### ❌ Mistake 1: Missing assignedStaffId
```json
{
  "assignedTo": "preetham",  // Has this
  "assignedStaffId": null    // Missing this!
}
```
**Result:** Shows "Assigned to: preetham" text only

### ❌ Mistake 2: Wrong Status Format
```json
{
  "status": "in_progress"  // Wrong (underscore)
}
```
**Should be:** `"inProgress"` (camelCase)

### ❌ Mistake 3: Staff Document Missing
```json
{
  "assignedStaffId": "staff123"  // Has this
}
```
But no document at `staff/staff123`
**Result:** Staff fetch fails, shows fallback text

### ❌ Mistake 4: Status Not Updated
```json
{
  "assignedTo": "preetham",      // ✅
  "assignedStaffId": "staff123", // ✅
  "status": "pending"            // ❌ Still pending!
}
```
**Should be:** `"inProgress"`

## Summary

**The resident app is working perfectly.** It:
- ✅ Fetches staff details when `assignedStaffId` exists
- ✅ Shows full staff card with call/chat buttons
- ✅ Updates in real-time when Firestore changes
- ✅ Moves complaints to History when status is "completed"
- ✅ Has proper fallback when data is missing

**The admin panel needs to be fixed** to:
- ❌ Add `assignedStaffId` when assigning staff
- ❌ Add `assignedStaffRole` when assigning staff
- ❌ Update `status` to "inProgress" when assigning
- ❌ Update `status` to "completed" when resolving

Once the admin panel is fixed, everything will work automatically!

## Next Steps

1. **Check your console logs** to see what's actually in Firestore
2. **Verify Firestore data** matches the required format
3. **Fix admin panel** to include all required fields
4. **Test the flow** from pending → in progress → completed

The app code requires no changes. All fixes are in the admin panel or Firestore data.
