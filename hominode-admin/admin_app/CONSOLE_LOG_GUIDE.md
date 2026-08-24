# Console Log Guide - What to Look For

## When You Click "Assign Resident"

You should see this sequence of logs in your console:

### Step 1: Button Click
```
🟡 _handleAssign() called
Mode: AssignMode.addNew
Form valid: true
✅ Form validation passed
🟡 Mode: Add New
🟡 Request created:
  - Name: booio
  - Phone: 1234567890
  - Email: test@gmail.com
  - Password: y3xk8wUi
🟡 Calling widget.onAssignNew...
```

**If you DON'T see this:** The button click is not working or form validation is failing.

### Step 2: Callback Triggered
```
🔵 onAssignNew callback triggered!
Request data:
  - Name: booio
  - Phone: 1234567890
  - Email: test@gmail.com
  - Password: y3xk8wUi
  - FlatId: b102

🔵 Calling UserService.createUser()...
```

**If you DON'T see this:** The callback is not connected properly.

### Step 3: User Service Called
```
╔════════════════════════════════════════════════════════╗
║         CREATE USER - START                            ║
╚════════════════════════════════════════════════════════╝
Input parameters:
  - Name: booio
  - Phone: 1234567890
  - Email: test@gmail.com
  - Password: y3xk8wUi
  - Family Members: 1

[Step 1] Auth email determined: test@gmail.com
[Step 2] Creating Firebase Auth account...
```

**If you DON'T see this:** UserService.createUser() is not being called.

### Step 4: Firebase Auth (May Fail - That's OK!)
```
✅ Firebase Auth account created
   Auth UID: abc123xyz
✅ Display name updated
```

OR

```
❌ Firebase Auth creation failed: [firebase_auth/email-already-in-use]
⚠️  Continuing with Firestore creation anyway...
```

**Note:** Auth failure is OK! The system continues to create the Firestore document.

### Step 5: Firestore Document Creation
```
[Step 3] Generating resident ID...
✅ Resident ID generated: RES5326

[Step 4] Creating Firestore document...
Collection: users
Data to store:
  {name: booio, phone: 1234567890, email: test@gmail.com, ...}
✅ Firestore document created successfully!
   Document ID: abc123xyz

[Step 5] Verifying document...
✅ Document verified in Firestore
   Data: {name: booio, ...}

╔════════════════════════════════════════════════════════╗
║         CREATE USER - SUCCESS                          ║
╚════════════════════════════════════════════════════════╝
```

**If you DON'T see this:** Firestore write is failing. Check Firestore rules!

### Step 6: Flat Assignment
```
🔵 User created with ID: abc123xyz
🔵 Now assigning to flat...
🔵 User assigned to flat
🔵 Now updating flat status...
🔵 Flat status updated
🔵 Now syncing building occupancy...
🔵 Building occupancy synced
✅ ALL OPERATIONS COMPLETED SUCCESSFULLY!
```

**If you DON'T see this:** One of the follow-up operations failed.

## Common Issues

### Issue 1: No Logs at All
**Problem:** Button click not working
**Check:**
- Is the button enabled? (blue, not grey)
- Are all required fields filled?
- Check form validation

### Issue 2: Stops at "Calling widget.onAssignNew..."
**Problem:** Callback not connected
**Check:**
- Is `onAssignNew` parameter passed to `AssignResidentModal.show()`?
- Check `manage_buildings_page.dart` line ~520

### Issue 3: Stops at "Creating Firebase Auth account..."
**Problem:** Firebase Auth issue
**Check:**
- Is Firebase initialized?
- Check `main.dart` for `Firebase.initializeApp()`
- This is OK if it fails - Firestore should still work

### Issue 4: Stops at "Creating Firestore document..."
**Problem:** Firestore write blocked
**Check:**
- Firestore Security Rules
- Go to Firebase Console → Firestore → Rules
- Set to: `allow read, write: if true;` (for development)

### Issue 5: Document Created but Not Visible
**Problem:** Firestore rules blocking read
**Check:**
- Same as Issue 4
- Also check if document actually exists in Firebase Console

## What to Do

1. **Run the app**
2. **Fill the form** with test data
3. **Click "Assign Resident"**
4. **Watch the console** carefully
5. **Note where it stops** (if it stops)
6. **Check Firebase Console** to see if document was created

## Expected Result

If everything works:
- ✅ All logs appear in sequence
- ✅ Document appears in Firebase Console under `users` collection
- ✅ Success message shown in app
- ✅ Modal closes

## Debugging Steps

### If logs stop at Step 1:
- Form validation issue
- Check all required fields are filled
- Check email format is valid

### If logs stop at Step 2:
- Callback not connected
- Check `manage_buildings_page.dart`
- Verify `onAssignNew` is passed to modal

### If logs stop at Step 3:
- UserService not initialized
- Check `_userService = UserService()` in manage_buildings_page

### If logs stop at Step 5:
- **MOST COMMON ISSUE**
- Firestore rules blocking write
- Go to Firebase Console → Firestore → Rules
- Change to: `allow read, write: if true;`
- Click Publish

## Quick Test

Fill form with:
- Name: Test User
- Phone: 9999999999
- Email: test@test.com
- Family Members: 1
- Ownership: Owner

Click "Assign Resident"

Watch console for the sequence above.

If you see "✅ ALL OPERATIONS COMPLETED SUCCESSFULLY!" - it worked!

If not, note where it stopped and check that section above.
