# Resident Management - Testing Guide

## Quick Test Checklist

Use this guide to verify all resident management features are working correctly.

## Prerequisites

1. ✅ Firebase project configured
2. ✅ Firestore database created
3. ✅ Admin user logged in
4. ✅ At least one building created
5. ✅ At least one resident in Firestore

## Test Scenarios

### 1. View Residents List

**Steps:**
1. Open the app and login as admin
2. Navigate to Residents screen (bottom nav or dashboard)
3. Verify residents list loads

**Expected Results:**
- ✅ Loading indicator appears briefly
- ✅ Residents list displays
- ✅ Each card shows: name, flat, resident ID, phone, status
- ✅ Action buttons visible (View, Edit, More)

**Test Data:**
```javascript
// Create test resident in Firestore console
Collection: users
Document ID: auto
Data:
{
  "name": "Test User",
  "phone": "+91 9876543210",
  "email": "test@example.com",
  "residentId": "RES1001",
  "role": "resident",
  "flatId": "flat_123",
  "flatLabel": "A-101",
  "ownershipType": "owner",
  "familyMembers": 4,
  "status": "active",
  "password": "Test@123",
  "authEmail": "test@example.com",
  "authUid": "test_auth_uid",
  "createdAt": [current timestamp],
  "updatedAt": [current timestamp]
}
```

---

### 2. Search Functionality

**Steps:**
1. In Residents screen, locate search bar
2. Type "Test" in search field
3. Verify filtering works

**Expected Results:**
- ✅ List filters in real-time
- ✅ Only matching residents shown
- ✅ Search works for: name, flat label, resident ID
- ✅ Clear search shows all residents again

**Test Cases:**
- Search by name: "Test User"
- Search by flat: "A-101"
- Search by ID: "RES1001"
- Search partial: "Test"

---

### 3. Filter by Building

**Steps:**
1. Click building filter dropdown
2. Select a building (e.g., "Building A")
3. Verify filtering works

**Expected Results:**
- ✅ Dropdown shows all buildings
- ✅ List filters to show only residents in selected building
- ✅ "All Buildings" option shows all residents

---

### 4. Filter by Status

**Steps:**
1. Click status filter dropdown
2. Select "Active"
3. Verify only active residents shown
4. Select "Inactive"
5. Verify only inactive residents shown

**Expected Results:**
- ✅ Dropdown shows: All Status, Active, Inactive
- ✅ List filters correctly
- ✅ Status badges match filter

---

### 5. Edit Resident - Basic Info

**Steps:**
1. Click edit icon (✏️) on a resident card
2. Edit dialog opens
3. Change name to "Updated Test User"
4. Change phone to "+91 9999999999"
5. Click "Save Changes"

**Expected Results:**
- ✅ Dialog opens with current data
- ✅ All fields editable
- ✅ Save button works
- ✅ Success notification appears
- ✅ List updates automatically
- ✅ Changes saved in Firestore

**Verification:**
```
Check Firestore console:
users/{userId}
- name should be "Updated Test User"
- phone should be "+91 9999999999"
- updatedAt timestamp should be recent
```

---

### 6. Edit Resident - Email

**Steps:**
1. Click edit icon on resident
2. Change email to "newemail@example.com"
3. Click "Save Changes"

**Expected Results:**
- ✅ Email field accepts input
- ✅ Email validation works (if invalid format entered)
- ✅ Changes save successfully
- ✅ Firestore updated

---

### 7. Edit Resident - Family Members

**Steps:**
1. Click edit icon on resident
2. Change family members to "5"
3. Click "Save Changes"

**Expected Results:**
- ✅ Number field accepts only numbers
- ✅ Validation prevents values < 1
- ✅ Changes save successfully
- ✅ Card shows updated count

---

### 8. Edit Resident - Password

**Steps:**
1. Click edit icon on resident
2. Locate password field (shows ••••••••)
3. Click eye icon to show password
4. Change password to "NewPass@456"
5. Click eye icon to hide password
6. Click "Save Changes"

**Expected Results:**
- ✅ Password field shows masked by default
- ✅ Eye icon toggles visibility
- ✅ Password shows/hides correctly
- ✅ Changes save to Firestore
- ✅ New password visible in profile view

**Verification:**
```
Check Firestore console:
users/{userId}
- password should be "NewPass@456"
```

---

### 9. Edit Resident - Validation

**Steps:**
1. Click edit icon on resident
2. Clear the name field
3. Try to save
4. Clear phone field
5. Try to save
6. Enter invalid family members (0 or negative)
7. Try to save

**Expected Results:**
- ✅ "Please enter name" error appears
- ✅ "Please enter phone number" error appears
- ✅ "Please enter a valid number" error appears
- ✅ Save button disabled or validation prevents save
- ✅ Error messages clear when fields corrected

---

### 10. Edit Resident - Cancel

**Steps:**
1. Click edit icon on resident
2. Make some changes
3. Click "Cancel" button

**Expected Results:**
- ✅ Dialog closes
- ✅ No changes saved
- ✅ Original data remains in list
- ✅ Firestore unchanged

---

### 11. View Full Profile

**Steps:**
1. Click view icon (👁️) on resident card
2. Profile page opens

**Expected Results:**
- ✅ Profile page opens with gradient header
- ✅ Personal Information card displays
- ✅ Login Credentials card displays
- ✅ Flat Information card displays
- ✅ Billing & Payments card displays
- ✅ All data accurate

**Verify Each Section:**

**Personal Information:**
- ✅ Resident ID shown
- ✅ Full name shown
- ✅ Phone shown
- ✅ Email shown (if exists)
- ✅ Family members count shown
- ✅ Status shown with correct badge

**Login Credentials:**
- ✅ Confidential badge visible
- ✅ Auth email shown with copy button
- ✅ Password shown as ••••••••
- ✅ Password has copy and view buttons
- ✅ Auth UID shown with copy button

**Flat Information:**
- ✅ Flat label shown
- ✅ Ownership type shown
- ✅ Flat ID shown

---

### 12. Copy Auth Email

**Steps:**
1. Open resident profile
2. Navigate to Login Credentials section
3. Click copy icon next to Auth Email
4. Paste in a text editor

**Expected Results:**
- ✅ Copy icon clickable
- ✅ "Auth Email copied to clipboard" notification appears
- ✅ Correct email in clipboard
- ✅ Can paste successfully

---

### 13. Copy Password

**Steps:**
1. Open resident profile
2. Navigate to Login Credentials section
3. Click copy icon next to Password
4. Paste in a text editor

**Expected Results:**
- ✅ Copy icon clickable
- ✅ "Password copied to clipboard" notification appears
- ✅ Actual password copied (not ••••••••)
- ✅ Can paste successfully

---

### 14. View Password

**Steps:**
1. Open resident profile
2. Navigate to Login Credentials section
3. Click view icon (👁️) next to Password
4. Dialog opens showing password
5. Click "Close"

**Expected Results:**
- ✅ View icon clickable
- ✅ Dialog opens with "Password" title
- ✅ Actual password shown (not masked)
- ✅ Password is selectable
- ✅ Close button works
- ✅ Dialog dismisses

---

### 15. Copy Auth UID

**Steps:**
1. Open resident profile
2. Navigate to Login Credentials section
3. Click copy icon next to Auth UID
4. Paste in a text editor

**Expected Results:**
- ✅ Copy icon clickable
- ✅ "Auth UID copied to clipboard" notification appears
- ✅ Correct UID in clipboard

---

### 16. Activate Resident

**Steps:**
1. Find an inactive resident (or deactivate one first)
2. Click more icon (⋮)
3. Select "Activate"

**Expected Results:**
- ✅ "Activate" option visible for inactive residents
- ✅ Confirmation or immediate activation
- ✅ Status badge changes to "Active" (green)
- ✅ Success notification appears
- ✅ Firestore status updated to "active"

---

### 17. Deactivate Resident

**Steps:**
1. Find an active resident
2. Click more icon (⋮)
3. Select "Deactivate"

**Expected Results:**
- ✅ "Deactivate" option visible for active residents
- ✅ Confirmation or immediate deactivation
- ✅ Status badge changes to "Inactive" (red)
- ✅ Success notification appears
- ✅ Firestore status updated to "inactive"

---

### 18. Delete Resident

**Steps:**
1. Click more icon (⋮) on a test resident
2. Select "Delete"
3. Confirmation dialog appears
4. Click "Delete" to confirm

**Expected Results:**
- ✅ "Delete" option visible
- ✅ Confirmation dialog appears
- ✅ Dialog shows resident name
- ✅ "Cancel" and "Delete" buttons present
- ✅ Cancel button closes dialog without deleting
- ✅ Delete button removes resident
- ✅ Success notification appears
- ✅ Resident removed from list
- ✅ Firestore document deleted

**Warning:** Only test with test data!

---

### 19. Real-Time Updates

**Steps:**
1. Open Residents screen in app
2. Open Firestore console in browser
3. Edit a resident document in Firestore
4. Change name or status
5. Save in Firestore
6. Check app

**Expected Results:**
- ✅ App updates automatically (within 1-2 seconds)
- ✅ No manual refresh needed
- ✅ Changes reflect immediately
- ✅ StreamBuilder working correctly

---

### 20. Empty State

**Steps:**
1. Delete all residents (or use empty database)
2. Navigate to Residents screen

**Expected Results:**
- ✅ Empty state message appears
- ✅ Icon shown (people outline)
- ✅ Message: "No residents yet"
- ✅ No error shown

---

### 21. Error Handling

**Steps:**
1. Disconnect internet
2. Try to edit a resident
3. Try to save changes

**Expected Results:**
- ✅ Error notification appears
- ✅ Clear error message shown
- ✅ App doesn't crash
- ✅ Can retry after reconnecting

---

### 22. Navigation

**Steps:**
1. From Dashboard, click Residents quick access
2. Verify navigation works
3. Use bottom navigation to go to Residents
4. Verify navigation works
5. From profile view, click back
6. Verify returns to list

**Expected Results:**
- ✅ All navigation paths work
- ✅ Back button works correctly
- ✅ Bottom nav highlights correct tab
- ✅ No navigation errors

---

## Performance Tests

### Load Time
- ✅ Residents list loads in < 2 seconds
- ✅ Profile view opens instantly
- ✅ Edit dialog opens instantly
- ✅ Search filters in real-time

### Responsiveness
- ✅ Smooth scrolling
- ✅ No lag when typing in search
- ✅ Buttons respond immediately
- ✅ Animations smooth

### Memory
- ✅ No memory leaks
- ✅ App stable after multiple operations
- ✅ Can navigate back and forth without issues

---

## Edge Cases

### 1. Resident with No Email
**Test:** View profile of resident without email
**Expected:** Email field not shown or shows "Not provided"

### 2. Resident with No Flat
**Test:** View profile of unassigned resident
**Expected:** Flat shows "Not assigned"

### 3. Resident with No Password
**Test:** View profile of resident without password
**Expected:** Shows "No credentials available" message

### 4. Very Long Name
**Test:** Edit resident with 50+ character name
**Expected:** Name displays correctly, no overflow

### 5. Special Characters in Name
**Test:** Edit resident with name "O'Brien-Smith"
**Expected:** Saves and displays correctly

### 6. Multiple Rapid Edits
**Test:** Edit same resident multiple times quickly
**Expected:** All changes save correctly, no conflicts

---

## Mobile Testing

### Small Screens
- ✅ Edit dialog scrollable
- ✅ Profile view scrollable
- ✅ All buttons accessible
- ✅ Text readable

### Landscape Mode
- ✅ Layout adapts correctly
- ✅ Dialogs centered
- ✅ No content cut off

### Touch Targets
- ✅ All buttons easily tappable
- ✅ Minimum 44x44 touch targets
- ✅ No accidental taps

---

## Security Tests

### 1. Password Visibility
**Test:** Verify password masked by default
**Expected:** Shows ••••••••, not actual password

### 2. Clipboard Security
**Test:** Copy password, check clipboard
**Expected:** Actual password in clipboard (expected behavior)

### 3. Confidential Badge
**Test:** Check credentials section
**Expected:** Confidential badge visible and clear

---

## Firestore Rules Testing

### Read Access
```
Test: Try to read users collection
Expected: Only authenticated admins can read
```

### Write Access
```
Test: Try to update user document
Expected: Only authenticated admins can write
```

### Delete Access
```
Test: Try to delete user document
Expected: Only authenticated admins can delete
```

---

## Regression Tests

After any code changes, verify:
- ✅ List still loads
- ✅ Search still works
- ✅ Edit still saves
- ✅ Profile still displays
- ✅ Copy still works
- ✅ Navigation still works

---

## Bug Report Template

If you find issues, report using this format:

```
**Bug Title:** [Brief description]

**Steps to Reproduce:**
1. 
2. 
3. 

**Expected Result:**
[What should happen]

**Actual Result:**
[What actually happened]

**Screenshots:**
[If applicable]

**Device/Browser:**
[Device and OS version]

**Firestore Data:**
[Relevant document structure]

**Console Errors:**
[Any error messages]
```

---

## Test Results Log

Use this template to track testing:

```
Date: [Date]
Tester: [Name]
Version: [App version]

| Test # | Test Name | Status | Notes |
|--------|-----------|--------|-------|
| 1 | View Residents List | ✅ | |
| 2 | Search Functionality | ✅ | |
| 3 | Filter by Building | ✅ | |
| 4 | Filter by Status | ✅ | |
| 5 | Edit Basic Info | ✅ | |
| 6 | Edit Email | ✅ | |
| 7 | Edit Family Members | ✅ | |
| 8 | Edit Password | ✅ | |
| 9 | Validation | ✅ | |
| 10 | Cancel Edit | ✅ | |
| 11 | View Profile | ✅ | |
| 12 | Copy Auth Email | ✅ | |
| 13 | Copy Password | ✅ | |
| 14 | View Password | ✅ | |
| 15 | Copy Auth UID | ✅ | |
| 16 | Activate Resident | ✅ | |
| 17 | Deactivate Resident | ✅ | |
| 18 | Delete Resident | ✅ | |
| 19 | Real-Time Updates | ✅ | |
| 20 | Empty State | ✅ | |
| 21 | Error Handling | ✅ | |
| 22 | Navigation | ✅ | |

Overall Status: [PASS/FAIL]
Issues Found: [Number]
Critical Issues: [Number]
```

---

## Automated Testing (Future)

Consider adding these automated tests:

```dart
// Unit Tests
- UserService.getUsers()
- UserService.updateUser()
- UserModel validation

// Widget Tests
- ResidentCard rendering
- EditResidentDialog validation
- ProfilePage display

// Integration Tests
- Full edit flow
- Full view flow
- Navigation flow
```

---

## Sign-Off Checklist

Before marking as complete:

- [ ] All 22 test scenarios passed
- [ ] No critical bugs found
- [ ] Performance acceptable
- [ ] Mobile responsive
- [ ] Security verified
- [ ] Documentation complete
- [ ] Code reviewed
- [ ] Firestore rules configured
- [ ] Ready for production

---

## Support

For issues during testing:
- Check console logs
- Verify Firestore rules
- Check network connectivity
- Review documentation files
- Check Firebase console for errors

## Conclusion

This testing guide ensures all resident management features work correctly. Complete all tests before deploying to production.
