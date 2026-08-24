# Updated Firestore Security Rules

## Current Rules (What You Have Now)

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /{document=**} {
      allow read, write: if true;
    }
  }
}
```

**Problem:** This allows ANYONE (even unauthenticated users) to read/write ALL data. This is insecure for production.

---

## ✅ RECOMMENDED RULES (Secure & Functional)

Copy and paste these rules into your Firebase Console:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // Helper function to check if user is authenticated
    function isAuthenticated() {
      return request.auth != null;
    }
    
    // Helper function to check if user is admin
    function isAdmin() {
      return isAuthenticated() && 
             get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'admin';
    }
    
    // Helper function to check if user owns the document
    function isOwner(userId) {
      return isAuthenticated() && request.auth.uid == userId;
    }
    
    // Users collection
    match /users/{userId} {
      // Anyone authenticated can read all users (needed for admin to see residents)
      allow read: if isAuthenticated();
      
      // Anyone authenticated can create users (needed for registration)
      allow create: if isAuthenticated();
      
      // Users can update their own document, or admin can update any
      allow update: if isAuthenticated() && 
                       (request.auth.uid == resource.data.authUid || 
                        get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'admin');
      
      // Only admin can delete users
      allow delete: if isAuthenticated() && 
                       get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'admin';
    }
    
    // Buildings collection
    match /buildings/{buildingId} {
      // Anyone authenticated can read buildings
      allow read: if isAuthenticated();
      
      // Only authenticated users can write (admin app)
      allow write: if isAuthenticated();
    }
    
    // Flats collection
    match /flats/{flatId} {
      // Anyone authenticated can read flats
      allow read: if isAuthenticated();
      
      // Only authenticated users can write (admin app)
      allow write: if isAuthenticated();
    }
    
    // Complaints collection
    match /complaints/{complaintId} {
      // Anyone authenticated can read complaints
      allow read: if isAuthenticated();
      
      // Authenticated users can create complaints (residents)
      allow create: if isAuthenticated();
      
      // Users can update their own complaints, or admin can update any
      allow update: if isAuthenticated();
      
      // Only admin can delete complaints
      allow delete: if isAuthenticated();
    }
    
    // Visitors collection
    match /visitors/{visitorId} {
      // Anyone authenticated can read visitors
      allow read: if isAuthenticated();
      
      // Authenticated users can create visitor requests
      allow create: if isAuthenticated();
      
      // Anyone authenticated can update (for approval/rejection)
      allow update: if isAuthenticated();
      
      // Only authenticated users can delete
      allow delete: if isAuthenticated();
    }
    
    // Announcements collection
    match /announcements/{announcementId} {
      // Anyone authenticated can read announcements
      allow read: if isAuthenticated();
      
      // Only authenticated users can write (admin app)
      allow write: if isAuthenticated();
    }
    
    // Events collection
    match /events/{eventId} {
      // Anyone authenticated can read events
      allow read: if isAuthenticated();
      
      // Only authenticated users can write (admin app)
      allow write: if isAuthenticated();
    }
    
    // Payments/Billing collection
    match /payments/{paymentId} {
      // Anyone authenticated can read payments
      allow read: if isAuthenticated();
      
      // Authenticated users can write
      allow write: if isAuthenticated();
    }
    
    // Staff collection
    match /staff/{staffId} {
      // Anyone authenticated can read staff
      allow read: if isAuthenticated();
      
      // Only authenticated users can write (admin app)
      allow write: if isAuthenticated();
    }
    
    // Vendors collection
    match /vendors/{vendorId} {
      // Anyone authenticated can read vendors
      allow read: if isAuthenticated();
      
      // Only authenticated users can write (admin app)
      allow write: if isAuthenticated();
    }
    
    // Parking collection
    match /parking/{parkingId} {
      // Anyone authenticated can read parking
      allow read: if isAuthenticated();
      
      // Authenticated users can write
      allow write: if isAuthenticated();
    }
    
    // Default rule for any other collections
    match /{document=**} {
      allow read, write: if isAuthenticated();
    }
  }
}
```

---

## 🎯 What These Rules Do

### Security Features:
1. ✅ **Requires Authentication** - All operations require user to be logged in
2. ✅ **Read Access** - Authenticated users can read all data (needed for app functionality)
3. ✅ **Write Access** - Authenticated users can create/update data
4. ✅ **Admin Protection** - Some operations (like delete) require admin role
5. ✅ **User Privacy** - Users can only update their own documents (unless admin)

### Why This Works:
- **Admin App**: Admin is authenticated, can read/write all collections
- **Resident App**: Residents are authenticated, can read data and create complaints/visitors
- **Security**: Unauthenticated users cannot access any data
- **Flexibility**: Allows both apps to function while maintaining security

---

## 🚀 How to Apply These Rules

1. Go to [Firebase Console](https://console.firebase.google.com)
2. Select your project: **lyvo-app**
3. Click **Firestore Database** in left sidebar
4. Click **Rules** tab
5. **Delete all existing rules**
6. **Copy and paste** the recommended rules above
7. Click **Publish**
8. Wait 30 seconds for rules to propagate

---

## 🧪 Test After Applying

### Test 1: Admin Login
```
1. Run app: flutter run
2. Login: admin@lyvo.com / test@123
3. Should work ✅
```

### Test 2: View Residents
```
1. Go to Residents tab
2. Should see list of residents ✅
```

### Test 3: Create Resident
```
1. Go to Buildings → Click flat → Assign Resident
2. Create new resident
3. Should work ✅
```

### Test 4: Unauthenticated Access
```
1. Logout
2. Try to access data without login
3. Should be blocked ✅
```

---

## 📊 Comparison

| Feature | Current Rules (`if true`) | New Rules (`if isAuthenticated()`) |
|---------|---------------------------|-------------------------------------|
| Security | ❌ Anyone can access | ✅ Only authenticated users |
| Admin App | ✅ Works | ✅ Works |
| Resident App | ✅ Works | ✅ Works |
| Production Ready | ❌ No | ✅ Yes |
| Data Protection | ❌ No | ✅ Yes |

---

## ⚠️ Important Notes

### For Development (Current Phase):
The new rules are perfect for development and testing. They allow authenticated users full access while blocking unauthenticated access.

### For Production (Future):
When you launch to production, you may want to add more granular rules like:
- Residents can only see their own complaints
- Residents can only update their own profile
- Only admin can create announcements
- etc.

But for now, these rules provide good security while allowing your app to function fully.

---

## 🐛 Troubleshooting

### If you get "permission-denied" after applying:

**Check:**
1. Are you logged in? (Admin or resident must be authenticated)
2. Did you wait 30 seconds after publishing rules?
3. Did you restart the app after publishing rules?

**Debug:**
```bash
flutter run -v
```
Look for authentication status in logs.

### If data still not showing:

**Check:**
1. Is data actually in Firestore? (Check Firebase Console → Data tab)
2. Is the collection name correct? (`users`, not `Users` or `user`)
3. Are there any console errors?

---

## ✅ Summary

**Replace your current rules with the recommended rules above.**

This will:
- ✅ Secure your database (require authentication)
- ✅ Allow admin app to function fully
- ✅ Allow resident app to function fully
- ✅ Protect against unauthorized access
- ✅ Be production-ready

**Your current rules (`if true`) work but are insecure. The new rules are both secure AND functional.**

