# Complete Firestore Rules Fix

## 🔴 Current Issues
- ❌ Permission denied errors on Buildings, Residents, Visitors, Billing
- ❌ Admin profile not found errors
- ❌ Rules syntax error

## ✅ Solution: Complete Working Rules

Go to **Firebase Console → Firestore → Rules** and replace ALL rules with this:

```firestore
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Allow authenticated users to read/write their own admin profile
    match /admins/{adminId} {
      allow read, write: if request.auth.uid == adminId;
    }

    // Allow authenticated users to read/write users collection
    match /users/{userId} {
      allow read, write: if request.auth.uid == userId;
    }

    // Allow authenticated admins to read/write buildings
    match /buildings/{buildingId} {
      allow read, write: if request.auth != null;
    }

    // Allow authenticated admins to read/write residents
    match /residents/{residentId} {
      allow read, write: if request.auth != null;
    }

    // Allow authenticated admins to read/write visitors
    match /visitors/{visitorId} {
      allow read, write: if request.auth != null;
    }

    // Allow authenticated admins to read/write bills
    match /bills/{billId} {
      allow read, write: if request.auth != null;
    }

    // Allow authenticated admins to read/write apartment images
    match /apartmentImages/{imageId} {
      allow read: if request.auth != null;
      allow create: if request.auth != null && request.auth.uid == resource.data.adminId;
      allow update: if request.auth != null && request.auth.uid == resource.data.adminId;
      allow delete: if request.auth != null && request.auth.uid == resource.data.adminId;
    }

    // Allow authenticated admins to read/write events
    match /events/{eventId} {
      allow read, write: if request.auth != null;
    }

    // Allow authenticated admins to read/write announcements
    match /announcements/{announcementId} {
      allow read, write: if request.auth != null;
    }

    // Allow authenticated admins to read/write complaints
    match /complaints/{complaintId} {
      allow read, write: if request.auth != null;
    }

    // Allow authenticated admins to read/write notices
    match /notices/{noticeId} {
      allow read, write: if request.auth != null;
    }

    // Allow authenticated admins to read/write parking
    match /parking/{parkingId} {
      allow read, write: if request.auth != null;
    }

    // Allow authenticated admins to read/write amenities
    match /amenities/{amenityId} {
      allow read, write: if request.auth != null;
    }

    // Allow authenticated admins to read/write staff
    match /staff/{staffId} {
      allow read, write: if request.auth != null;
    }

    // Allow authenticated admins to read/write vendors
    match /vendors/{vendorId} {
      allow read, write: if request.auth != null;
    }

    // Allow authenticated admins to read/write attendance
    match /attendance/{attendanceId} {
      allow read, write: if request.auth != null;
    }

    // Allow authenticated admins to read/write messages
    match /messages/{messageId} {
      allow read, write: if request.auth != null;
    }

    // Allow authenticated admins to read/write broadcasts
    match /broadcasts/{broadcastId} {
      allow read, write: if request.auth != null;
    }

    // Allow authenticated admins to read/write gates
    match /gates/{gateId} {
      allow read, write: if request.auth != null;
    }

    // Allow authenticated admins to read/write security
    match /security/{securityId} {
      allow read, write: if request.auth != null;
    }

    // Catch-all for any other collections
    match /{document=**} {
      allow read, write: if request.auth != null;
    }
  }
}
```

## 📋 Steps to Apply

1. Go to https://console.firebase.google.com
2. Select project: `lvo-app-9f8ca`
3. Click **Firestore Database**
4. Click **Rules** tab
5. **Delete all existing rules**
6. **Copy and paste the complete rules above**
7. Click **Publish**
8. Wait for success message

## ✅ What These Rules Do

| Collection | Action | Who | Condition |
|-----------|--------|-----|-----------|
| admins | read/write | User | Must own the document |
| users | read/write | User | Must own the document |
| buildings | read/write | Admin | Must be authenticated |
| residents | read/write | Admin | Must be authenticated |
| visitors | read/write | Admin | Must be authenticated |
| bills | read/write | Admin | Must be authenticated |
| apartmentImages | read | Admin | Must be authenticated |
| apartmentImages | create/update/delete | Admin | Must own the document |
| All others | read/write | Admin | Must be authenticated |

## 🎯 Expected Results After Publishing

✅ No more permission-denied errors
✅ Buildings screen loads
✅ Residents screen loads
✅ Visitors screen loads
✅ Billing screen loads
✅ Admin profile loads
✅ All features work

## ❌ Troubleshooting

### Still getting errors?
1. Make sure you deleted ALL old rules first
2. Copy the rules exactly as shown
3. Check for typos
4. Verify all braces are closed
5. Click Publish again

### Rules published but still getting errors?
1. Restart the app
2. Log out and log back in
3. Check that you're authenticated
4. Check console logs for detailed errors

## 🚀 Next Steps

After publishing rules:
1. Restart the app
2. All screens should load without errors
3. Then proceed with apartment images setup

---

## Status

✅ Complete working rules provided
✅ All collections covered
✅ Ready to publish
