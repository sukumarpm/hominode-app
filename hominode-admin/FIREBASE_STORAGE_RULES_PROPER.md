# Firebase Storage Rules - Proper Setup ✅

## The Correct Rules (Copy & Paste Exactly)

Go to Firebase Console → Storage → Rules and paste this:

```
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    match /{allPaths=**} {
      allow read: if request.auth != null;
      allow write: if request.auth != null && request.resource.size < 10485760;
    }
  }
}
```

**That's it! No comments, no extra lines.**

---

## Step-by-Step Setup

### Step 1: Open Firebase Console
1. Go to https://console.firebase.google.com
2. Select project: **lyvo-app**
3. Click **Storage** in left sidebar
4. Click **Rules** tab

### Step 2: Clear Everything
1. Select ALL text (Ctrl+A or Cmd+A)
2. Delete it completely
3. Make sure editor is completely empty

### Step 3: Paste Rules
Copy this exactly (no markdown, no code block):

```
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    match /{allPaths=**} {
      allow read: if request.auth != null;
      allow write: if request.auth != null && request.resource.size < 10485760;
    }
  }
}
```

### Step 4: Publish
1. Click **PUBLISH** button
2. Wait for confirmation message
3. Wait 30 seconds

### Step 5: Restart App
1. Close app completely
2. Reopen app
3. Test upload

---

## Firestore Rules (Also Required)

Go to Firebase Console → Firestore Database → Rules and paste this:

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

Then click **PUBLISH**.

---

## Testing

### After Publishing Both Rules

1. Open app
2. Go to **Apartment Images Management**
3. Click **Add Image**
4. Select image, date, time
5. Click **Upload Image**

### Expected Console Output

```
🔵 APARTMENT IMAGES SERVICE: Starting image upload...
🔐 STEP 1: Validating admin authentication...
✅ STEP 1 PASSED: Admin authenticated - admin_uid_12345
📋 STEP 2: Validating input data...
✅ STEP 2 PASSED: Input data validated - File size: 2048576 bytes
📤 STEP 3: Uploading image to Firebase Storage...
📤 STEP 3.1: Uploading to path: apartment_images/admin_uid_12345/apartment_image_1711440000000.jpg
✅ STEP 3 PASSED: Image uploaded - https://firebasestorage.googleapis.com/...
💾 STEP 4: Saving image metadata to Firestore...
✅ STEP 4 PASSED: Image metadata saved - doc_id_abc123
🔔 STEP 5: Logging completion...
✅ APARTMENT IMAGES SERVICE: Image upload COMPLETE
```

---

## What These Rules Do

| Rule | Meaning |
|------|---------|
| `rules_version = '2';` | Use Firebase Rules v2 |
| `service firebase.storage` | Configure Storage |
| `match /b/{bucket}/o` | Match all buckets |
| `match /{allPaths=**}` | Match all paths |
| `allow read: if request.auth != null;` | Authenticated users can read |
| `allow write: if request.auth != null && request.resource.size < 10485760;` | Authenticated users can write (max 10MB) |

---

## Common Mistakes to Avoid

❌ **Don't use comments** - Firebase doesn't like comments in rules
❌ **Don't use markdown code blocks** - Paste plain text only
❌ **Don't add extra spaces** - Copy exactly as shown
❌ **Don't forget to PUBLISH** - Rules don't work until published
❌ **Don't forget to restart app** - App needs to reconnect after rules change

---

## If Still Getting Error

### Error: "mismatched input 'match'"
**Solution:** Make sure `rules_version = '2';` is on the FIRST line

### Error: "permission-denied"
**Solution:** 
1. Wait 30 seconds after publishing
2. Restart app completely
3. Make sure you're logged in

### Error: "object-not-found"
**Solution:** This is a code issue, not rules issue. Check storage path in code.

---

## Summary

**Firebase Storage Rules:**
```
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    match /{allPaths=**} {
      allow read: if request.auth != null;
      allow write: if request.auth != null && request.resource.size < 10485760;
    }
  }
}
```

**Firestore Rules:**
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

**Then:**
1. Publish both
2. Wait 30 seconds
3. Restart app
4. Test

**Done!** 🎉

