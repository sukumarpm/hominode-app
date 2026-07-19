# 🧪 Test Firebase Auth Auto-Create - Quick Guide

## Quick Test (2 Minutes)

### Step 1: Check Current State
1. Open Firebase Console → Authentication
2. Note how many users are there currently
3. Check if your test user exists

### Step 2: Login to App
```bash
# Run the app
flutter run -d ZA222LQT6V
```

1. Open the app
2. Login with: **7010678124** / **121456**
3. Watch the console logs

### Step 3: Verify Firebase Auth Creation

**Expected Console Logs**:
```
🔐 Starting Firestore-only authentication...
📱 Detected phone number, searching in Firestore...
✅ Found user with phone: 7010678124
✅ Password verified successfully
🔐 Creating/Signing in with Firebase Authentication...
⚠️  User not found in Firebase Auth, creating account...
✅ Firebase Auth account created
✅ Firebase Auth profile set and authUid stored in Firestore
   Auth UID: abc123xyz
✅ Login successful!
```

### Step 4: Check Firebase Console
1. Go to Firebase Console → Authentication
2. You should see a new user:
   - Email: preethampriyatharson07@gmail.com
   - Display Name: Preetham
   - UID: (some unique ID)

### Step 5: Check Firestore
1. Go to Firebase Console → Firestore
2. Open: users → ZsjxqVHSv7OQELHCFee1
3. You should see new field:
   - `authUid`: (matches Firebase Auth UID)
   - `updatedAt`: (current timestamp)

---

## Test Scenarios

### Scenario 1: First-Time Login (New Firebase Auth User)
**Setup**: User exists in Firestore but NOT in Firebase Auth

**Steps**:
1. Login with credentials
2. Check console logs
3. Check Firebase Auth

**Expected**:
- ✅ "User not found in Firebase Auth, creating account..."
- ✅ New user appears in Firebase Authentication
- ✅ `authUid` added to Firestore user document

### Scenario 2: Subsequent Login (Existing Firebase Auth User)
**Setup**: User exists in both Firestore AND Firebase Auth

**Steps**:
1. Login again with same credentials
2. Check console logs

**Expected**:
- ✅ "Firebase Authentication successful (existing user)"
- ✅ Profile data updated
- ✅ `authUid` verified in Firestore

### Scenario 3: User Without Email
**Setup**: User in Firestore has no email field

**Steps**:
1. Create user without email
2. Login with phone + password
3. Check console logs

**Expected**:
- ✅ Firestore authentication succeeds
- ⚠️  "No email found in user data, skipping Firebase Auth"
- ✅ Login successful (Firestore-only)

---

## Verification Checklist

### Firebase Authentication
- [ ] User appears in Firebase Console → Authentication
- [ ] Email matches Firestore email
- [ ] Display name matches Firestore name
- [ ] UID is generated

### Firestore User Document
- [ ] `authUid` field added
- [ ] `authUid` matches Firebase Auth UID
- [ ] `updatedAt` timestamp updated
- [ ] All other fields unchanged

### App Functionality
- [ ] Login successful
- [ ] Dashboard loads
- [ ] Marketplace works (no "User not authenticated")
- [ ] Profile displays correctly
- [ ] All features accessible

---

## Console Log Examples

### Success (New User)
```
🔐 Starting Firestore-only authentication...
   Identifier: 7010678124
📱 Detected phone number, searching in Firestore...
   Trying: 7010678124
   ✅ Found user with phone: 7010678124
   User ID: ZsjxqVHSv7OQELHCFee1
   User Name: Preetham
   Verifying password...
✅ Password verified successfully
🔐 Creating/Signing in with Firebase Authentication...
⚠️  User not found in Firebase Auth, creating account...
✅ Firebase Auth account created
✅ Firebase Auth profile set and authUid stored in Firestore
   Auth UID: abc123xyz456def
💾 Login state saved
✅ Login successful!
   Welcome: Preetham
```

### Success (Existing User)
```
🔐 Starting Firestore-only authentication...
✅ Found user with phone: 7010678124
✅ Password verified successfully
🔐 Creating/Signing in with Firebase Authentication...
✅ Firebase Authentication successful (existing user)
✅ Updated authUid in Firestore: abc123xyz456def
✅ Firebase Auth profile updated
✅ Login successful!
```

### Fallback (No Email)
```
🔐 Starting Firestore-only authentication...
✅ Found user with phone: 7010678124
✅ Password verified successfully
⚠️  No email found in user data, skipping Firebase Auth
✅ Login successful!
```

---

## Troubleshooting

### Issue: User Not Created in Firebase Auth

**Check**:
1. Does user have email field in Firestore?
2. Is email valid format?
3. Check console for error messages

**Solution**:
- Ensure user document has `email` field
- Email must be valid format
- Check Firebase Auth quota limits

### Issue: "Email already in use"

**Cause**: User already exists in Firebase Auth

**Result**: System will sign in instead of creating new user

**Action**: This is normal behavior, no action needed

### Issue: authUid Not Added to Firestore

**Check**:
1. Firestore Security Rules allow updates
2. User has write permission
3. Check console for errors

**Solution**:
- Update Firestore Security Rules
- Ensure user document is writable

---

## Quick Commands

```bash
# Run app
flutter run -d ZA222LQT6V

# Watch logs
flutter logs

# Hot reload
r

# Hot restart
R

# Quit
q
```

---

## Firebase Console Links

### Authentication
```
https://console.firebase.google.com/project/lyvo-app/authentication/users
```

### Firestore
```
https://console.firebase.google.com/project/lyvo-app/firestore/data
```

---

## Expected Results Summary

✅ **Firebase Auth User Created** - New user in Authentication
✅ **Profile Data Synced** - Display name and photo URL set
✅ **authUid Stored** - Firestore user document updated
✅ **Login Successful** - User can access app
✅ **Marketplace Works** - No authentication errors
✅ **All Features Accessible** - Full app functionality

---

## Test Credentials

**Phone**: 7010678124  
**Password**: 121456  
**Expected Email**: preethampriyatharson07@gmail.com  
**Expected Name**: Preetham

---

**Status**: Ready to test ✅  
**Time Required**: 2 minutes  
**Difficulty**: Easy

Just login and check Firebase Console!
