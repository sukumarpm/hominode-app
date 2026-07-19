# Profile Screen - Firestore Setup Guide

## Required Firestore Structure

The profile screen requires user data to be stored in Firestore with the following structure:

### Collection: `users`

```
Firestore
└── users (collection)
    └── {authUid} (document)
        ├── id: string
        ├── authUid: string
        ├── email: string
        ├── name: string
        ├── phone: string
        ├── buildingId: string ⭐ REQUIRED
        ├── flatId: string ⭐ REQUIRED
        ├── flatLabel: string
        ├── role: string ⭐ REQUIRED
        ├── profileImage: string (optional)
        ├── photoURL: string (optional)
        ├── language: string (optional)
        ├── residentId: string (optional)
        ├── ownershipType: string (optional)
        └── updatedAt: timestamp
```

## Setup Steps

### Step 1: Create Users Collection

1. Go to Firebase Console
2. Open Firestore Database
3. Click "Create collection"
4. Name it: `users`
5. Click "Next"

### Step 2: Create User Document

1. Click "Add document"
2. Set Document ID to: **{Firebase Auth UID}**
   - This is the UID from Firebase Authentication
   - Example: `abc123def456ghi789`
3. Click "Save"

### Step 3: Add Required Fields

Add these fields to the document:

| Field | Type | Value | Required |
|-------|------|-------|----------|
| id | string | {authUid} | ✅ Yes |
| authUid | string | {authUid} | ✅ Yes |
| email | string | user@example.com | ✅ Yes |
| name | string | John Doe | ✅ Yes |
| phone | string | +1234567890 | ✅ Yes |
| buildingId | string | building1 | ✅ **REQUIRED** |
| flatId | string | flat101 | ✅ **REQUIRED** |
| flatLabel | string | A-101 | ❌ No |
| role | string | resident | ✅ **REQUIRED** |
| profileImage | string | https://... | ❌ No |
| photoURL | string | https://... | ❌ No |
| language | string | en | ❌ No |
| residentId | string | RES001 | ❌ No |
| ownershipType | string | Owner | ❌ No |

### Step 4: Example Document

```json
{
  "id": "abc123def456ghi789",
  "authUid": "abc123def456ghi789",
  "email": "preetham@example.com",
  "name": "Preetham",
  "phone": "+919876543210",
  "buildingId": "building1",
  "flatId": "flat101",
  "flatLabel": "A-101",
  "role": "resident",
  "profileImage": "https://res.cloudinary.com/...",
  "photoURL": "https://res.cloudinary.com/...",
  "language": "en",
  "residentId": "RES001",
  "ownershipType": "Owner",
  "updatedAt": "2024-04-02T10:30:00Z"
}
```

## Firestore Security Rules

Ensure your Firestore security rules allow users to read their own data:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Users can read their own user document
    match /users/{userId} {
      allow read: if request.auth.uid == userId;
      allow write: if request.auth.uid == userId;
    }
  }
}
```

## Verification

### Check if Setup is Correct

1. Open the app and login
2. Navigate to Profile tab
3. Check if user data displays correctly
4. Open browser console (F12)
5. Look for these logs:

```
✅ USER DATA FETCH FLOW: COMPLETE
   ID: [user_id]
   Name: [user_name]
   Email: [user_email]
   Phone: [user_phone]
   Flat: [flat_number]
   Building ID: [building_id]
   Role: [user_role]
```

### If You See Errors

**Error: "User document not found"**
- Solution: Create user document in Firestore with correct document ID

**Error: "Permission denied"**
- Solution: Deploy Firestore security rules

**Error: "Missing required fields"**
- Solution: Add buildingId, flatId, and role fields

## Bulk Setup (Multiple Users)

If you need to create multiple user documents, you can use Firebase Admin SDK:

```javascript
// Firebase Admin SDK (Node.js)
const admin = require('firebase-admin');
const db = admin.firestore();

const users = [
  {
    uid: 'user1_uid',
    email: 'user1@example.com',
    name: 'User One',
    phone: '+1234567890',
    buildingId: 'building1',
    flatId: 'flat101',
    flatLabel: 'A-101',
    role: 'resident'
  },
  {
    uid: 'user2_uid',
    email: 'user2@example.com',
    name: 'User Two',
    phone: '+0987654321',
    buildingId: 'building1',
    flatId: 'flat102',
    flatLabel: 'A-102',
    role: 'resident'
  }
];

async function setupUsers() {
  for (const user of users) {
    await db.collection('users').doc(user.uid).set({
      id: user.uid,
      authUid: user.uid,
      email: user.email,
      name: user.name,
      phone: user.phone,
      buildingId: user.buildingId,
      flatId: user.flatId,
      flatLabel: user.flatLabel,
      role: user.role,
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    });
  }
  console.log('Users created successfully');
}

setupUsers();
```

## Important Notes

⚠️ **Document ID Must Match Firebase Auth UID**
- The document ID in Firestore must be the same as the Firebase Auth UID
- This is how the app identifies which user document to fetch

⚠️ **Required Fields for Permissions**
- `buildingId` - Required for Firestore security rules
- `flatId` - Required for Firestore security rules
- `role` - Required for Firestore security rules

⚠️ **Profile Image URLs**
- Should be HTTPS URLs
- Can be from Cloudinary or any image hosting service
- Will be displayed in profile header

## Testing

### Test 1: Profile Screen Load
1. Login to app
2. Navigate to Profile tab
3. Verify user data displays
4. Check console for flow logs

### Test 2: Edit Profile
1. Tap "Edit Profile"
2. Verify form fields are populated
3. Edit name and phone
4. Tap "Save Changes"
5. Verify data updates in Firestore

### Test 3: Profile Image
1. In Edit Profile, tap profile photo
2. Select image from gallery
3. Tap "Save Changes"
4. Verify image displays in profile header

## Status

✅ **SETUP COMPLETE** - Follow these steps to set up Firestore for the profile screen.

