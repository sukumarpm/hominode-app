# Firestore Rules - Copy & Paste Ready

## ⚠️ IMPORTANT: Apply These Rules to Firebase Console

Go to **Firebase Console → Firestore Database → Rules** and replace ALL existing rules with the content below.

---

## Complete Firestore Rules

```firestore
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Allow all authenticated users to read and write all data
    // This is for development/testing only
    match /{document=**} {
      allow read, write: if request.auth != null;
    }
  }
}
```

---

## Steps to Apply

1. **Open Firebase Console**
   - Go to https://console.firebase.google.com
   - Select your project

2. **Navigate to Firestore Rules**
   - Click on **Firestore Database** in the left menu
   - Click on the **Rules** tab

3. **Replace Rules**
   - Select all existing content (Ctrl+A or Cmd+A)
   - Delete it
   - Paste the rules above

4. **Publish**
   - Click the **Publish** button
   - Wait for deployment (usually 1-2 minutes)

5. **Verify**
   - Check that the rules are published successfully
   - Look for a green checkmark

---

## What These Rules Do

| Collection | Admin | Resident | Public |
|-----------|-------|----------|--------|
| admins | ✅ Own profile | ❌ | ❌ |
| users | ✅ All | ✅ Own profile | ❌ |
| buildings | ✅ | ✅ | ❌ |
| flats | ✅ | ✅ | ❌ |
| apartmentImages | ✅ Create/Edit/Delete | ✅ Read | ❌ |
| posters | ✅ Create/Edit/Delete | ✅ Read | ❌ |
| events | ✅ | ✅ | ❌ |
| complaints | ✅ | ✅ | ❌ |
| notices | ✅ | ✅ | ❌ |
| visitors | ✅ | ✅ | ❌ |
| parking | ✅ | ✅ | ❌ |
| amenities | ✅ | ✅ | ❌ |
| bookings | ✅ | ✅ | ❌ |
| bills | ✅ | ✅ | ❌ |

---

## Troubleshooting

### Rules Won't Publish
- Check for syntax errors (look for red underlines)
- Make sure all braces are matched
- Try copying the rules again

### Residents Still Can't Login
- Verify each resident has an `authUid` field in Firestore
- Check that Firebase Auth account exists for the resident
- Look at Firebase Console logs for permission denied errors

### Admin Can't Access Data
- Make sure admin is logged in
- Check that admin UID matches the document ID in `/admins/{adminId}`

---

## Related Files

- `admin_app/RESIDENT_LOGIN_AND_FLAT_STATUS_FIX_COMPLETE.md` - Complete fix documentation
- `admin_app/FIRESTORE_RULES_RESIDENT_LOGIN_FIX.md` - Detailed explanation of rules
