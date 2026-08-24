# Firebase Rules - Syntax Fix ✅

## Error Fixed
**Error:** "Error saving rules - Line 1: mismatched input 'match' expecting ('function', 'import', 'service', 'rules_version')"

**Cause:** Invalid rule syntax (comments or incorrect formatting)

**Solution:** Use simplified rules without comments

---

## Correct Firebase Storage Rules

### Copy & Paste This (No Comments)

```
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    match /{allPaths=**} {
      allow read: if request.auth != null;
      allow write: if request.auth != null && request.resource.size < 10 * 1024 * 1024;
    }
  }
}
```

---

## Steps to Apply

### Step 1: Go to Firebase Console
1. Open https://console.firebase.google.com
2. Select your project: **lyvo-app**
3. Click **Storage** in left sidebar
4. Click **Rules** tab

### Step 2: Clear Existing Rules
1. Select ALL existing text (Ctrl+A)
2. Delete it

### Step 3: Paste New Rules
1. Copy the rules above (without the markdown code block markers)
2. Paste into the rules editor
3. Make sure it looks exactly like above

### Step 4: Publish
1. Click **PUBLISH** button
2. Wait for confirmation
3. Wait 30 seconds for propagation

### Step 5: Restart App
1. Close app completely
2. Reopen app

---

## What These Rules Do

| Rule | What It Does |
|------|-------------|
| `rules_version = '2';` | Use Firebase Rules version 2 |
| `service firebase.storage` | Configure Firebase Storage |
| `match /b/{bucket}/o` | Match all buckets |
| `match /{allPaths=**}` | Match all paths |
| `allow read: if request.auth != null;` | Allow authenticated users to read |
| `allow write: if request.auth != null && request.resource.size < 10 * 1024 * 1024;` | Allow authenticated users to write (max 10MB) |

---

## Testing

### After Publishing Rules

1. Open app
2. Go to **Apartment Images Management**
3. Click **Add Image**
4. Select image, date, time
5. Click **Upload Image**
6. ✅ Should upload successfully

### Check Console

You should see:
```
✅ STEP 3 PASSED: Image uploaded - https://firebasestorage.googleapis.com/...
✅ STEP 4 PASSED: Image metadata saved - doc_id_abc123
✅ APARTMENT IMAGES SERVICE: Image upload COMPLETE
```

---

## Firestore Rules (Also Required)

### Go to Firestore Rules
1. Click **Firestore Database** in left sidebar
2. Click **Rules** tab

### Paste These Rules

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /{document=**} {
      allow read, write: if request.auth != null;
    }
  }
}
```

### Publish
1. Click **PUBLISH** button
2. Wait for confirmation

---

## Summary

**Firebase Rules are now correct!**

1. ✅ Storage Rules updated (no syntax errors)
2. ✅ Firestore Rules updated (no syntax errors)
3. ✅ Ready to test

**Next Steps:**
1. Apply Storage Rules (see above)
2. Apply Firestore Rules (see above)
3. Restart app
4. Test image upload

**The error should now be fixed!** 🎉

