# Firestore Security Rules - Simple Working Version

Copy and paste these rules directly into Firebase Console → Firestore Database → Rules

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // Allow all authenticated users to read and write
    // This is a permissive rule for development
    match /{document=**} {
      allow read, write: if request.auth != null;
    }
  }
}
```

## How to Deploy

1. Go to Firebase Console: https://console.firebase.google.com
2. Select your project
3. Click "Firestore Database"
4. Click "Rules" tab
5. Delete all existing rules
6. Copy and paste the rules above
7. Click "Publish"

## Status

✅ **Simple and Working**
✅ **Allows all authenticated users**
✅ **No complex logic**
✅ **No syntax errors**

---

**After this works, you can add more specific rules later.**
