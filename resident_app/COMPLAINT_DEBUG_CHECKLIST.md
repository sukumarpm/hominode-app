# Complaint Debug Checklist

## Quick Diagnosis

### What You See vs What It Means

#### Scenario 1: Shows "Assigned to: preetham" (Text Only)
```
┌─────────────────────────────┐
│ 🔧 work work    [Pending] 🔴│
│ qqqqqqqqqqqq                │
│                             │
│ Assigned to: preetham       │ ← Just text, no card
└─────────────────────────────┘
```

**Problem**: `assignedStaffId` is NULL in Firestore

**Fix**: Add to Firestore:
```json
{
  "assignedStaffId": "staff123"
}
```

#### Scenario 2: Shows Staff Card (Correct!)
```
┌─────────────────────────────┐
│ 🔧 work work [In Progress]🟠│
│ qqqqqqqqqqqq                │
│                             │
│ ┌─────────────────────────┐│
│ │ 👤 preetham             ││ ← Full card with buttons
│ │    Electrician          ││
│ │ 📞 +91 123... [Call] →  ││
│ │ 💬 Chat [Chat] →        ││
│ └─────────────────────────┘│
└─────────────────────────────┘
```

**Status**: Everything working correctly!

#### Scenario 3: Shows Nothing (No Assignment)
```
┌─────────────────────────────┐
│ 🔧 work work    [Pending] 🔴│
│ qqqqqqqqqqqq                │
│                             │
│ (No staff info)             │
└─────────────────────────────┘
```

**Status**: Complaint not assigned yet (correct for pending)

## Step-by-Step Debug

### Step 1: Open App and Check Console

Look for these specific logs:

```
🔍 Parsing complaint: dAONdk0i0cHokqz8w3ma
📊 Raw status from Firestore: ___________
📊 Assigned to: ___________
📊 Staff ID: ___________
```

Fill in the blanks from your console.

### Step 2: Match Your Scenario

#### If Console Shows:
```
📊 Raw status from Firestore: pending
📊 Assigned to: preetham
📊 Staff ID: null
```

**Diagnosis**: Staff assigned but `assignedStaffId` missing

**What You'll See**: "Assigned to: preetham" text only

**Fix**: 
1. Open Firebase Console
2. Find complaint document
3. Add field: `assignedStaffId` = `"staff123"`
4. Add field: `status` = `"inProgress"`
5. Save

#### If Console Shows:
```
📊 Raw status from Firestore: inProgress
📊 Assigned to: preetham
📊 Staff ID: staff123
📥 Fetching staff: staff123
✅ Staff cached: preetham
```

**Diagnosis**: Everything correct!

**What You'll See**: Full staff card with call/chat buttons

**Status**: Working perfectly ✅

#### If Console Shows:
```
📊 Raw status from Firestore: inProgress
📊 Assigned to: preetham
📊 Staff ID: staff123
📥 Fetching staff: staff123
⚠️ Staff not found: staff123
```

**Diagnosis**: Staff document doesn't exist

**What You'll See**: "Assigned to: preetham" text only

**Fix**:
1. Open Firebase Console
2. Go to `staff` collection
3. Create document with ID: `staff123`
4. Add fields:
   ```json
   {
     "name": "preetham",
     "phone": "+91 1234567890",
     "role": "electrician",
     "email": "preetham@example.com",
     "isActive": true
   }
   ```
5. Save
6. Pull to refresh in app

#### If Console Shows:
```
📊 Raw status from Firestore: completed
📊 Assigned to: preetham
📊 Staff ID: staff123
```

**Diagnosis**: Complaint resolved

**What You'll See**: 
- Green "Completed" badge
- In History tab
- Staff details (read-only)

**Status**: Working correctly ✅

## Firestore Data Checklist

### Required Fields for Staff Display

Check your Firestore complaint document has ALL these:

```json
{
  "assignedTo": "preetham",           // ✅ Staff name
  "technicianPhone": "+91 123...",    // ✅ Staff phone
  "assignedStaffId": "staff123",      // ✅ Staff ID (CRITICAL!)
  "assignedStaffRole": "electrician", // ✅ Staff role
  "status": "inProgress"              // ✅ Correct status
}
```

### Staff Document Must Exist

Check `staff/staff123` exists with:

```json
{
  "name": "preetham",
  "phone": "+91 1234567890",
  "role": "electrician",
  "isActive": true
}
```

## Visual Flow Chart

```
Open Complaint
      ↓
Check Console Logs
      ↓
┌─────────────────────────────┐
│ Is assignedStaffId null?    │
└─────────┬───────────────────┘
          ↓
    YES   │   NO
          ↓
┌─────────────────────────────┐
│ Shows "Assigned to:" text   │
│ Fix: Add assignedStaffId    │
└─────────────────────────────┘
          
          ↓ NO
          
┌─────────────────────────────┐
│ Does staff document exist?  │
└─────────┬───────────────────┘
          ↓
    YES   │   NO
          ↓
┌─────────────────────────────┐
│ Staff not found error       │
│ Fix: Create staff document  │
└─────────────────────────────┘
          
          ↓ YES
          
┌─────────────────────────────┐
│ ✅ Shows full staff card    │
│ with call/chat buttons      │
└─────────────────────────────┘
```

## Quick Reference Table

| Console Log | What You See | Problem | Fix |
|-------------|--------------|---------|-----|
| `Staff ID: null` | "Assigned to:" text | Missing field | Add `assignedStaffId` |
| `Staff not found` | "Assigned to:" text | No staff doc | Create staff document |
| `Staff cached` | Full staff card | None | ✅ Working! |
| `status: pending` | Red badge | Wrong status | Update to "inProgress" |
| `status: completed` | Green badge, History | None | ✅ Working! |

## Admin Panel Requirements

### When Assigning Staff

Must update ALL these fields:

```dart
{
  'assignedTo': staffName,        // ✅
  'technicianPhone': staffPhone,  // ✅
  'assignedStaffId': staffId,     // ✅ CRITICAL
  'assignedStaffRole': staffRole, // ✅
  'status': 'inProgress',         // ✅ CRITICAL
}
```

### When Marking Resolved

Must update:

```dart
{
  'status': 'completed',  // ✅ CRITICAL
  'resolvedAt': timestamp,
}
```

## Summary

**For staff card to show:**
1. ✅ `assignedStaffId` must exist in complaint
2. ✅ Staff document must exist in `staff` collection
3. ✅ Status should be "inProgress"

**For resolution to work:**
1. ✅ Status must be "completed" in Firestore
2. ✅ App will automatically move to History tab

**Check console logs to see exactly what's happening!**
