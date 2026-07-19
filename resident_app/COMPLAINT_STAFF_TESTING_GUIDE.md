# Complaint Staff Assignment - Testing Guide

## Quick Setup

### 1. Add Sample Staff to Firestore

Go to Firebase Console → Firestore Database → Create Collection `staff`

Add these documents:

**Document ID: `staff001`**
```json
{
  "name": "Ramesh Kumar",
  "phone": "+91 98765 43210",
  "role": "plumber",
  "email": "ramesh.kumar@example.com",
  "isActive": true,
  "createdAt": "2024-01-15T10:00:00Z",
  "updatedAt": "2024-01-15T10:00:00Z"
}
```

**Document ID: `staff002`**
```json
{
  "name": "Suresh Electrician",
  "phone": "+91 98765 43211",
  "role": "electrician",
  "email": "suresh@example.com",
  "isActive": true,
  "createdAt": "2024-01-15T10:00:00Z",
  "updatedAt": "2024-01-15T10:00:00Z"
}
```

**Document ID: `staff003`**
```json
{
  "name": "Vijay Maintenance",
  "phone": "+91 98765 43212",
  "role": "maintenance",
  "isActive": true,
  "createdAt": "2024-01-15T10:00:00Z",
  "updatedAt": "2024-01-15T10:00:00Z"
}
```

### 2. Assign Staff to Existing Complaint

Find a complaint document in Firestore and update it:

```json
{
  "assignedTo": "Ramesh Kumar",
  "technicianPhone": "+91 98765 43210",
  "assignedStaffId": "staff001",
  "assignedStaffRole": "plumber",
  "status": "inProgress"
}
```

## Testing Steps

### Test 1: View Complaint with Assigned Staff
1. Open app and navigate to Complaints screen
2. Look for complaint with assigned staff
3. Verify staff card shows:
   - Staff name
   - Role (e.g., "Plumber")
   - Phone number
   - Gray background card with avatar icon

### Test 2: View Staff Details in Modal
1. Tap on complaint with assigned staff
2. Modal opens with complaint details
3. Scroll to "Assigned Staff" section
4. Verify blue card shows:
   - Staff name (bold)
   - Role display name
   - Phone with icon
   - Email with icon (if available)

### Test 3: Complaint Without Staff
1. Create new complaint (no staff assigned)
2. Verify complaint shows without staff card
3. Status should be "Pending"
4. No staff information displayed

### Test 4: Staff Assignment Flow
1. Create complaint as resident
2. Admin assigns staff (via Firestore or admin panel)
3. Pull to refresh complaints list
4. Verify staff details appear
5. Status changes to "In Progress"

### Test 5: Multiple Complaints
1. Create 3 complaints
2. Assign different staff to each
3. Verify each shows correct staff
4. Verify staff details don't mix up

### Test 6: Staff Without Email
1. Create staff without email field
2. Assign to complaint
3. Verify phone shows but email row hidden
4. No errors or crashes

### Test 7: Invalid Staff ID
1. Assign complaint with invalid staffId
2. App should fallback to basic display
3. Shows "Assigned to: [name]" text
4. No crashes

## Expected Results

### Complaints List View
```
┌─────────────────────────────────────┐
│ 🔧 Leaking Pipe          [In Progress]│
│ Kitchen sink is leaking              │
│ Plumbing • Jan 20, 2024              │
│                                      │
│ ┌──────────────────────────────────┐│
│ │ 👤  Ramesh Kumar                 ││
│ │     Plumber • +91 98765 43210   ││
│ └──────────────────────────────────┘│
└─────────────────────────────────────┘
```

### Detail Modal View
```
┌─────────────────────────────────────┐
│         Complaint Details        [X] │
├─────────────────────────────────────┤
│ 🔧  Leaking Pipe                     │
│     [in-progress]                    │
│     Jan 20, 2024                     │
│                                      │
│ Description                          │
│ Kitchen sink pipe is leaking badly   │
│                                      │
│ ┌─────────────────────────────────┐ │
│ │ Assigned Staff                  │ │
│ │                                 │ │
│ │ 👤  Ramesh Kumar                │ │
│ │     Plumber                     │ │
│ │                                 │ │
│ │ 📞 +91 98765 43210              │ │
│ │ ✉️  ramesh.kumar@example.com    │ │
│ └─────────────────────────────────┘ │
│                                      │
│ Timeline                             │
│ • Complaint Submitted - Oct 28, 10AM│
│ • Assigned to Ramesh - Oct 28, 11AM │
│ • Work in Progress - Oct 29, 9AM    │
│                                      │
│ [Chat With Technician]               │
└─────────────────────────────────────┘
```

## Troubleshooting

### Staff Details Not Showing
- Check Firestore `staff` collection exists
- Verify staff document ID matches `assignedStaffId`
- Check console logs for fetch errors
- Verify internet connection

### Wrong Staff Showing
- Clear app cache
- Verify `assignedStaffId` in complaint document
- Check staff cache is updating correctly

### App Crashes
- Check all required fields in staff document
- Verify Firestore rules allow read access
- Check console for error messages

## Console Logs to Watch

```
🔵 Fetching staff with ID: staff001
✅ Staff fetched: Ramesh Kumar
```

If you see:
```
⚠️ Staff not found: staff001
```
Then the staff document doesn't exist or ID is wrong.

## Firestore Rules

Ensure your Firestore rules allow reading staff:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /staff/{staffId} {
      allow read: if request.auth != null;
      allow write: if request.auth != null && 
                      get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'admin';
    }
  }
}
```

## Success Criteria

✅ Staff details display in complaint list
✅ Staff details display in detail modal
✅ Phone and email show correctly
✅ Role displays proper name (not enum)
✅ No crashes with missing data
✅ Fallback works for invalid staff
✅ Performance is smooth (no lag)
✅ Pull to refresh updates staff info

## Next Steps

After testing, you can:
1. Build admin panel for staff assignment
2. Add staff profile photos
3. Implement chat with staff
4. Add staff ratings
5. Track staff performance
