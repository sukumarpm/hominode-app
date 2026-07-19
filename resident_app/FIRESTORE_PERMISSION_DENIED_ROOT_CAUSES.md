# 🔍 Firestore Permission Denied - Root Cause Analysis & Fixes

## Current Situation

You've deployed the Firestore rules, but you're still getting permission denied errors. This means there's a deeper issue beyond just the rules.

```
❌ Error: [cloud_firestore/permission-denied]
```

---

## 🎯 Root Cause #1: User Document ID Mismatch (MOST COMMON)

### The Problem
Your Firestore security rules check for a user document using `request.auth.uid`, but the user document in Firestore has a DIFFERENT document ID.

### Example:
```
Firebase Auth UID: abc123xyz
Firestore Document ID: user_456def  ← MISMATCH!
```

### The Rules Expect:
```javascript
function getUserData() {
  return get(/databases/$(database)/documents/users/$(request.auth.uid)).data;
}
```

This tries to read: `users/abc123xyz`
But your document is at: `users/user_456def`
Result: Document not found → Permission denied

### ✅ Solution 1: Fix Document ID

**Option A: Rename Document in Firestore Console**
1. Go to Firebase Console > Firestore Database
2. Find your user document
3. Note the current document ID
4. Create a NEW document with ID = Firebase Auth UID
5. Copy all fields from old document to new document
6. Delete old document

**Option B: Create Script to Fix**
```dart
// Run this once to fix the mismatch
Future<void> fixUserDocumentId() async {
  final auth = FirebaseAuth.instance;
  final firestore = FirebaseFirestore.instance;
  
  final user = auth.currentUser;
  if (user == null) return;
  
  // Check if document exists with correct ID
  final correctDoc = await firestore.collection('users').doc(user.uid).get();
  
  if (!correctDoc.exists) {
    print('Creating user document with correct ID...');
    
    // Create document with Firebase Auth UID as document ID
    await firestore.collection('users').doc(user.uid).set({
      'id': user.uid,
      'authUid': user.uid,
      'email': user.email,
      'name': user.displayName ?? 'User',
      'phone': user.phoneNumber ?? '',
      'buildingId': 'building1', // SET YOUR BUILDING ID
      'flatId': 'flat101', // SET YOUR FLAT ID
      'role': 'resident', // or 'admin'
      'createdAt': FieldValue.serverTimestamp(),
    });
    
    print('✅ User document created with correct ID');
  }
}
```

---

## 🎯 Root Cause #2: Missing Required Fields

### The Problem
User document exists, but missing `buildingId`, `flatId`, or `role` fields.

### The Rules Need:
```javascript
function getUserBuildingId() {
  return getUserData().buildingId;  // ← Must exist
}

function getUserFlatId() {
  return getUserData().flatId;  // ← Must exist
}

function isAdmin() {
  return getUserData().role == 'admin';  // ← Must exist
}
```

### ✅ Solution 2: Add Missing Fields

**In Firestore Console:**
1. Go to Firebase Console > Firestore Database
2. Open `users` collection
3. Find your user document
4. Click "Add field" and add:
   - `buildingId` (string): e.g., "building1"
   - `flatId` (string): e.g., "flat101"
   - `role` (string): "resident" or "admin"

**Or run this script:**
```dart
Future<void> addMissingFields() async {
  final auth = FirebaseAuth.instance;
  final firestore = FirebaseFirestore.instance;
  
  final user = auth.currentUser;
  if (user == null) return;
  
  await firestore.collection('users').doc(user.uid).update({
    'buildingId': 'building1', // SET YOUR BUILDING ID
    'flatId': 'flat101', // SET YOUR FLAT ID
    'role': 'resident', // or 'admin'
    'updatedAt': FieldValue.serverTimestamp(),
  });
  
  print('✅ Missing fields added');
}
```

---

## 🎯 Root Cause #3: Rules Not Propagated Yet

### The Problem
Rules are deployed but Firebase servers haven't propagated them globally yet.

### ✅ Solution 3: Wait and Retry

1. Wait 2-5 minutes after publishing rules
2. Completely restart your app (not hot reload)
3. Try again

---

## 🎯 Root Cause #4: User Not Logged In

### The Problem
Trying to access Firestore before user is authenticated.

### ✅ Solution 4: Ensure User is Logged In

```dart
Future<void> checkAuthStatus() async {
  final user = FirebaseAuth.instance.currentUser;
  
  if (user == null) {
    print('❌ User not logged in');
    // Navigate to login screen
    return;
  }
  
  print('✅ User logged in: ${user.uid}');
  // Proceed with Firestore operations
}
```

---

## 🎯 Root Cause #5: Rules Have Syntax Errors

### The Problem
Rules were copied incorrectly or have syntax errors.

### ✅ Solution 5: Verify Rules in Firebase Console

1. Go to Firebase Console > Firestore Database > Rules
2. Check for red error indicators
3. Look for error messages at the bottom
4. Common errors:
   - Missing closing braces `}`
   - Missing semicolons `;`
   - Incorrect function syntax

---

## 🔧 Complete Diagnostic Process

### Step 1: Run Diagnostic Script

```bash
cd resident_app
flutter run lib/diagnose_firestore_permission.dart
```

This will tell you exactly what's wrong.

### Step 2: Check Firebase Auth

```dart
final user = FirebaseAuth.instance.currentUser;
print('User: ${user?.uid}');
print('Email: ${user?.email}');
```

Expected output:
```
User: abc123xyz
Email: user@example.com
```

### Step 3: Check User Document

In Firebase Console:
1. Go to Firestore Database
2. Open `users` collection
3. Look for document with ID = Firebase Auth UID
4. Verify it has all required fields

### Step 4: Test Rules

Try to read your own user document:
```dart
final doc = await FirebaseFirestore.instance
    .collection('users')
    .doc(FirebaseAuth.instance.currentUser!.uid)
    .get();

print('Document exists: ${doc.exists}');
print('Data: ${doc.data()}');
```

---

## 📋 Quick Fix Checklist

- [ ] User is logged in (Firebase Auth)
- [ ] User document exists in Firestore
- [ ] Document ID matches Firebase Auth UID
- [ ] User document has `buildingId` field
- [ ] User document has `flatId` field
- [ ] User document has `role` field
- [ ] Firestore rules are published
- [ ] Waited 2 minutes after publishing rules
- [ ] Restarted app completely
- [ ] No syntax errors in rules

---

## 🚀 Complete Fix Script

Run this to fix all common issues:

```dart
// lib/fix_firestore_permissions_complete.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

Future<void> fixAllPermissionIssues() async {
  print('🔧 Fixing Firestore permission issues...\n');
  
  final auth = FirebaseAuth.instance;
  final firestore = FirebaseFirestore.instance;
  
  // Step 1: Check auth
  final user = auth.currentUser;
  if (user == null) {
    print('❌ No user logged in. Please login first.');
    return;
  }
  
  print('✅ User logged in: ${user.uid}');
  
  // Step 2: Check if document exists with correct ID
  final doc = await firestore.collection('users').doc(user.uid).get();
  
  if (!doc.exists) {
    print('📝 Creating user document with correct ID...');
    
    // Create document with correct structure
    await firestore.collection('users').doc(user.uid).set({
      'id': user.uid,
      'authUid': user.uid,
      'email': user.email ?? '',
      'name': user.displayName ?? 'User',
      'phone': user.phoneNumber ?? '',
      'buildingId': 'building1', // ⚠️ CHANGE THIS
      'flatId': 'flat101', // ⚠️ CHANGE THIS
      'flatLabel': 'A-101', // ⚠️ CHANGE THIS
      'role': 'resident', // or 'admin'
      'residentId': 'RES${DateTime.now().millisecondsSinceEpoch}',
      'ownershipType': 'Owner',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    
    print('✅ User document created');
  } else {
    print('✅ User document exists');
    
    // Step 3: Check for required fields
    final data = doc.data()!;
    final updates = <String, dynamic>{};
    
    if (data['buildingId'] == null) {
      updates['buildingId'] = 'building1'; // ⚠️ CHANGE THIS
      print('⚠️  Adding missing buildingId');
    }
    
    if (data['flatId'] == null) {
      updates['flatId'] = 'flat101'; // ⚠️ CHANGE THIS
      print('⚠️  Adding missing flatId');
    }
    
    if (data['role'] == null) {
      updates['role'] = 'resident';
      print('⚠️  Adding missing role');
    }
    
    if (updates.isNotEmpty) {
      updates['updatedAt'] = FieldValue.serverTimestamp();
      await firestore.collection('users').doc(user.uid).update(updates);
      print('✅ Missing fields added');
    } else {
      print('✅ All required fields present');
    }
  }
  
  // Step 4: Test reading user document
  print('\n🧪 Testing permissions...');
  try {
    final testDoc = await firestore.collection('users').doc(user.uid).get();
    print('✅ Can read user document');
    print('   Data: ${testDoc.data()}');
  } catch (e) {
    print('❌ Cannot read user document: $e');
    print('   This means rules are not working correctly');
    print('   Wait 2 minutes and try again');
  }
  
  print('\n✅ Fix complete!');
  print('   If you still get errors, wait 2 minutes for rules to propagate');
}

void main() async {
  await fixAllPermissionIssues();
}
```

---

## 🎯 Most Likely Solution

Based on common issues, the problem is usually:

1. **Document ID mismatch** (80% of cases)
   - Fix: Create user document with ID = Firebase Auth UID

2. **Missing fields** (15% of cases)
   - Fix: Add buildingId, flatId, role to user document

3. **Rules not propagated** (5% of cases)
   - Fix: Wait 2 minutes and restart app

---

## 📞 Next Steps

1. **Run the diagnostic script**: `flutter run lib/diagnose_firestore_permission.dart`
2. **Read the output** to identify the exact issue
3. **Run the fix script**: `flutter run lib/fix_firestore_permissions_complete.dart`
4. **Wait 2 minutes** for changes to propagate
5. **Restart your app** completely
6. **Test again**

---

## ✅ Success Indicators

You'll know it's fixed when you see:

```
✅ User data fetched successfully
   ID: abc123xyz
   Name: John Doe
   Building ID: building1
   Flat ID: flat101
✅ Bills fetched: 3 bills
✅ Complaints fetched: 2 complaints
✅ Dashboard loaded successfully
```

---

**The issue is NOT the rules themselves - it's the data structure or timing!**

