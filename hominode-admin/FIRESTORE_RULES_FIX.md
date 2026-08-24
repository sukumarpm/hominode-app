# Firestore Rules - Fix

## Error Found
**Line 9**: Syntax error with `match` statement

## Correct Rules

Replace ALL your Firestore rules with this:

```firestore
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Apartment Images Collection
    match /apartmentImages/{document=**} {
      allow read: if request.auth != null;
      allow create: if request.auth != null && request.auth.uid == resource.data.adminId;
      allow update: if request.auth != null && request.auth.uid == resource.data.adminId;
      allow delete: if request.auth != null && request.auth.uid == resource.data.adminId;
    }

    // Add your other collections here
    // Example:
    // match /users/{userId} {
    //   allow read, write: if request.auth.uid == userId;
    // }
  }
}
```

## Steps to Fix

1. Go to Firebase Console
2. Select your project: `lvo-app-9f8ca`
3. Go to Firestore Database → Rules
4. Delete all existing rules
5. Copy and paste the correct rules above
6. Click **Publish**

## Key Points

✅ `rules_version = '2';` - Must be at the top
✅ `service cloud.firestore {` - Service declaration
✅ `match /databases/{database}/documents {` - Database match
✅ `match /apartmentImages/{document=**} {` - Collection match (correct syntax)
✅ Proper indentation
✅ All braces closed

## Common Errors to Avoid

❌ Missing `rules_version = '2';`
❌ Wrong match syntax: `match /apartmentImages/{document=**}` (missing closing brace)
❌ Incorrect indentation
❌ Missing semicolons
❌ Typos in field names

---

## Status

After applying these rules:
- ✅ Syntax error fixed
- ✅ Apartment images collection secured
- ✅ Ready for image uploads
