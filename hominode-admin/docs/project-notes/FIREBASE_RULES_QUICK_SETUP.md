# Firebase Rules - Quick Setup Guide ⚡

## 🚀 QUICK SETUP (Copy & Paste)

### Step 1: Go to Firebase Console
1. Open https://console.firebase.google.com
2. Select your project: **lyvo-app**
3. Click **Storage** in left sidebar
4. Click **Rules** tab

### Step 2: Copy & Paste Storage Rules

**DELETE all existing rules first, then paste this:**

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

### Step 3: Publish
1. Click **PUBLISH** button
2. Wait 30 seconds for rules to propagate
3. Restart your Flutter app

### Step 4: Verify Firestore Rules
1. Click **Firestore Database** in left sidebar
2. Click **Rules** tab
3. Verify you have:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /{document=**} {
      allow read, write: if request.auth != null;
    }
  }
}
```

If not, update it and click PUBLISH.

---

## ✅ Done!

Your Firebase is now configured correctly. The apartment images upload will work.

---

## 🧪 Test It

1. Open app
2. Go to Apartment Images Management
3. Click "Add Image"
4. Select image, date, time
5. Click "Upload Image"
6. Check console for all 5 steps ✅

---

## 📊 What These Rules Do

| Rule | What It Does |
|------|-------------|
| `allow read: if request.auth != null` | Only logged-in users can read files |
| `allow write: if request.auth != null` | Only logged-in users can upload files |
| `request.resource.size < 10 * 1024 * 1024` | Max file size is 10MB |
| `match /{fileName}` | Files stored at root level (not in folders) |

---

## ⚠️ If Still Getting Errors

### Error: "User is not authorized"
- [ ] Did you click PUBLISH?
- [ ] Did you wait 30 seconds?
- [ ] Did you restart the app?
- [ ] Are you logged in?

### Error: "No object exists"
- [ ] Check Storage Rules are published
- [ ] Check Firestore Rules are published
- [ ] Restart app
- [ ] Try again

### Error: "Permission denied"
- [ ] Check you're logged in
- [ ] Check Firebase Auth is working
- [ ] Check rules are published

---

## 🎯 Summary

**Storage Rules:** Allow authenticated users to upload files (max 10MB)
**Firestore Rules:** Allow authenticated users to read/write all data

**Result:** Apartment images upload will work perfectly! ✅
