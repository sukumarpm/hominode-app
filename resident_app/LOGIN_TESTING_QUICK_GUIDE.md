# Login Testing Quick Guide

## What Was Fixed

The `signInWithEmail()` method in `firestore_auth_service.dart` now:
1. ✅ Detects if input is email or phone number
2. ✅ Searches Firestore first (not Firebase Auth)
3. ✅ Verifies password against Firestore
4. ✅ Syncs with Firebase Authentication
5. ✅ Assigns flatId if missing
6. ✅ Saves login state
7. ✅ Follows flow function pattern with logging

---

## How to Test

### Step 1: Run the App
```bash
flutter run
```

### Step 2: Go to Login Screen
- Tap on "Email" tab
- You should see email/password login form

### Step 3: Test Email Login
```
Email: user@example.com
Password: password123
```

**Expected Result:**
- ✅ Console shows flow function logs (🔵 🔍 ✅ ❌)
- ✅ "Login successful!" message appears
- ✅ App navigates to home screen
- ❌ NOT "Access Restricted" screen

### Step 4: Test Phone Login
```
Phone: 9876543210
Password: password123
```

**Expected Result:**
- ✅ Console shows flow function logs
- ✅ "Login successful!" message appears
- ✅ App navigates to home screen

### Step 5: Test Phone with Country Code
```
Phone: +919876543210
Password: password123
```

**Expected Result:**
- ✅ Same as Step 4 (phone number is cleaned and normalized)

### Step 6: Test Wrong Password
```
Email: user@example.com
Password: wrongpassword
```

**Expected Result:**
- ✅ Error message: "Invalid credentials. Please check and try again."
- ❌ No navigation to home screen

### Step 7: Test Non-existent User
```
Email: nonexistent@example.com
Password: password123
```

**Expected Result:**
- ✅ Error message: "No account found with this email"
- ❌ No navigation to home screen

---

## Console Log Indicators

Look for these indicators in the console:

### Success Flow
```
🔵 signInWithEmail: Starting email/password login...
📧 Identifier: user@example.com
🔍 Identifier type: Email
🔐 Step 1: Searching for user in Firestore...
✅ User found in Firestore: user_id
🔐 Step 2: Verifying password...
✅ Password verified successfully
🔐 Step 3: Syncing with Firebase Authentication...
✅ Firebase Auth sign-in successful
🔐 Step 4: Checking flat assignment...
✅ User has flatId: flat_001
🔐 Step 5: Saving login state...
✅ Login successful!
```

### Failure Flow
```
🔵 signInWithEmail: Starting email/password login...
📧 Identifier: nonexistent@example.com
🔍 Identifier type: Email
🔐 Step 1: Searching for user in Firestore...
❌ No user found with email: nonexistent@example.com
```

---

## Troubleshooting

### Issue: "Access Restricted" after login
**Cause:** User doesn't have flatId assigned
**Solution:** The code now automatically assigns `flat_001` if missing

### Issue: "User account not found in database"
**Cause:** User exists in Firestore but not in Firebase Auth, and Firebase Auth account creation failed
**Solution:** Check Firebase Auth console for errors

### Issue: "Invalid credentials"
**Cause:** Password doesn't match Firestore stored password
**Solution:** Verify password in Firestore users collection

### Issue: Phone number not recognized
**Cause:** Phone number format not matching
**Solution:** The code now tries multiple formats:
- `9876543210` (10 digits)
- `+919876543210` (with country code)
- `919876543210` (country code without +)

---

## Expected User Journey

```
1. User opens app
   ↓
2. User taps "Email" tab on login screen
   ↓
3. User enters email/phone and password
   ↓
4. User taps "Login" button
   ↓
5. App searches Firestore for user
   ↓
6. App verifies password
   ↓
7. App syncs with Firebase Auth
   ↓
8. App assigns flatId if needed
   ↓
9. App saves login state
   ↓
10. "Login successful!" message appears
   ↓
11. App navigates to home screen
   ↓
12. FlatAccessControlService grants access
   ↓
13. User sees home screen (NOT "Access Restricted")
```

---

## Key Files

- `lib/src/services/firestore_auth_service.dart` - Login service (FIXED)
- `lib/src/screens/login_screen.dart` - Login UI
- `lib/src/services/flat_access_control_service.dart` - Access control

---

## Test Credentials

Use these credentials from your Firestore database:

```
Collection: users
Documents: [user_id_1, user_id_2, ...]

Each document should have:
- email: "user@example.com"
- phone: "9876543210"
- password: "password123"
- name: "User Name"
- flatId: "flat_001" (or will be assigned automatically)
- buildingId: "building_001"
```

---

## Success Criteria

✅ All of these should be true:

1. Email login works with valid credentials
2. Phone login works with valid credentials
3. Phone with country code works
4. Wrong password shows error
5. Non-existent user shows error
6. User navigates to home screen after login
7. User does NOT see "Access Restricted" screen
8. Console shows flow function logs
9. FlatId is assigned if missing
10. Firebase Auth account is created/synced

---

## Next Steps After Testing

1. ✅ Verify login works with email
2. ✅ Verify login works with phone
3. ✅ Verify user navigates to home screen
4. ✅ Verify FlatAccessControlService grants access
5. ⏳ Apply same pattern to other screens if needed
6. ⏳ Test complete app flow end-to-end
