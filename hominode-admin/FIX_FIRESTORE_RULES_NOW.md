# Fix Firestore Rules - Step by Step

## ❌ Current Error
```
Error saving rules - Line 9: Unexpected 'match'
```

## ✅ Solution

### Step 1: Go to Firebase Console
1. Open https://console.firebase.google.com
2. Select project: `lvo-app-9f8ca`
3. Click **Firestore Database** (left sidebar)
4. Click **Rules** tab

### Step 2: Clear Existing Rules
1. Select all text in the rules editor (Ctrl+A or Cmd+A)
2. Delete it

### Step 3: Paste Correct Rules

Copy this entire block and paste it:

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
  }
}
```

### Step 4: Publish
1. Click **Publish** button (blue button)
2. Wait for confirmation
3. You should see: "Rules updated successfully"

---

## ✅ Verification

After publishing, you should see:
- ✅ No error messages
- ✅ Green checkmark or success message
- ✅ Rules are now active

---

## 🎯 What These Rules Do

| Action | Who Can Do It | Condition |
|--------|---------------|-----------|
| **Read** | Anyone | Must be authenticated |
| **Create** | Admin | Must own the document (adminId matches) |
| **Update** | Admin | Must own the document (adminId matches) |
| **Delete** | Admin | Must own the document (adminId matches) |

---

## 🚀 Next Steps

After fixing the rules:

1. Run `flutter pub get`
2. Test image upload
3. Verify image appears in Firestore
4. Check console logs

---

## ❓ Troubleshooting

### Still getting error?
- Check for typos in the rules
- Verify all braces are closed
- Make sure indentation is correct
- Try copying the rules again

### Rules published but upload fails?
- Check that admin profile has `adminId` field
- Verify user is authenticated
- Check console logs for detailed error

---

## Done!

Once published, your Firestore is ready for apartment images uploads. 🎉
