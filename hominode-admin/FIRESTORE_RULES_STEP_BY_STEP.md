# Firestore Rules - Step by Step Visual Guide

## Step 1: Open Firebase Console

**URL:** https://console.firebase.google.com

**What you'll see:**
```
┌─────────────────────────────────────────┐
│  Firebase Console                       │
│  ┌─────────────────────────────────────┐│
│  │ Your Projects                       ││
│  │ ┌─────────────────────────────────┐││
│  │ │ lyvo-app (or your project name) │││
│  │ └─────────────────────────────────┘││
│  └─────────────────────────────────────┘│
└─────────────────────────────────────────┘
```

**Action:** Click on your project name

---

## Step 2: Navigate to Firestore Database

**Left Sidebar Menu:**
```
┌─────────────────────────────────┐
│ Build                           │
│ ├─ Firestore Database ← CLICK   │
│ ├─ Realtime Database            │
│ ├─ Storage                      │
│ └─ ...                          │
└─────────────────────────────────┘
```

**Action:** Click on "Firestore Database"

---

## Step 3: Go to Rules Tab

**Top Navigation:**
```
┌──────────────────────────────────────────┐
│ Firestore Database                       │
│ ┌──────────────────────────────────────┐ │
│ │ Data  Rules  Indexes  Backups  ...   │ │
│ │       ↑ CLICK HERE                   │ │
│ └──────────────────────────────────────┘ │
└──────────────────────────────────────────┘
```

**Action:** Click on "Rules" tab

---

## Step 4: See Current Rules

**What you'll see:**
```
┌─────────────────────────────────────────┐
│ Cloud Firestore Security Rules          │
│ ┌─────────────────────────────────────┐ │
│ │ rules_version = '2';                │ │
│ │ service cloud.firestore {           │ │
│ │   match /databases/{database}/...   │ │
│ │   ...                               │ │
│ │ }                                   │ │
│ └─────────────────────────────────────┘ │
└─────────────────────────────────────────┘
```

**Action:** Select all text (Ctrl+A or Cmd+A)

---

## Step 5: Delete Old Rules

**After selecting all:**
```
┌─────────────────────────────────────────┐
│ Cloud Firestore Security Rules          │
│ ┌─────────────────────────────────────┐ │
│ │ [All text is highlighted in blue]   │ │
│ │                                     │ │
│ │                                     │ │
│ └─────────────────────────────────────┘ │
└─────────────────────────────────────────┘
```

**Action:** Press Delete or Backspace

---

## Step 6: Paste New Rules

**Copy this exact text:**
```firestore
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /{document=**} {
      allow read, write: if request.auth != null;
    }
  }
}
```

**Then paste it in the editor:**
```
┌─────────────────────────────────────────┐
│ Cloud Firestore Security Rules          │
│ ┌─────────────────────────────────────┐ │
│ │ rules_version = '2';                │ │
│ │ service cloud.firestore {           │ │
│ │   match /databases/{database}/...   │ │
│ │   {                                 │ │
│ │     match /{document=**} {          │ │
│ │       allow read, write: if ...     │ │
│ │     }                               │ │
│ │   }                                 │ │
│ │ }                                   │ │
│ └─────────────────────────────────────┘ │
└─────────────────────────────────────────┘
```

**Action:** Paste the rules

---

## Step 7: Click Publish

**Bottom right corner:**
```
┌─────────────────────────────────────────┐
│ Cloud Firestore Security Rules          │
│ ┌─────────────────────────────────────┐ │
│ │ [Your rules here]                   │ │
│ │                                     │ │
│ │                                     │ │
│ │                    [Publish] ← CLICK│ │
│ └─────────────────────────────────────┘ │
└─────────────────────────────────────────┘
```

**Action:** Click the "Publish" button

---

## Step 8: Wait for Deployment

**You'll see:**
```
┌─────────────────────────────────────────┐
│ Publishing rules...                     │
│ ⏳ Please wait (1-2 minutes)            │
│                                         │
│ [Loading spinner]                       │
└─────────────────────────────────────────┘
```

**Action:** Wait 1-2 minutes

---

## Step 9: Deployment Complete

**You'll see a green checkmark:**
```
┌─────────────────────────────────────────┐
│ ✅ Rules published successfully         │
│                                         │
│ Last updated: Just now                  │
│ Version: 1                              │
└─────────────────────────────────────────┘
```

**Action:** Proceed to next step

---

## Step 10: Restart Your App

**On your phone/emulator:**
1. Close the app completely
2. Go to Settings → Apps → Admin App
3. Click "Storage" → "Clear Cache"
4. Restart the app

**What happens:**
```
App closes
    ↓
Cache cleared
    ↓
App restarts
    ↓
Connects to Firebase with new rules
    ↓
Ready to test!
```

---

## Step 11: Test Resident Assignment

**In the app:**
1. Go to Buildings → Select a building
2. Click on a flat
3. Click "Assign Resident"
4. Select or create a resident
5. Click "Assign"

**Expected result:**
```
✅ Resident assigned successfully
✅ No error messages
✅ Flat status updates to "Occupied"
```

---

## Troubleshooting

### Issue: Rules won't publish
**Solution:**
1. Check for syntax errors
2. Make sure you copied exactly
3. Try again in 1 minute

### Issue: Still getting errors after publishing
**Solution:**
1. Verify green checkmark ✅ appears
2. Wait 2-3 minutes for full deployment
3. Clear app cache and restart
4. Try again

### Issue: Can't find Firestore Database
**Solution:**
1. Make sure you're in the right project
2. Check left sidebar under "Build"
3. If not there, your project might not have Firestore enabled

---

## Summary

| Step | Action | Time |
|------|--------|------|
| 1 | Open Firebase Console | 30 sec |
| 2 | Go to Firestore Database | 30 sec |
| 3 | Click Rules tab | 30 sec |
| 4-6 | Replace rules | 1 min |
| 7 | Click Publish | 30 sec |
| 8 | Wait for deployment | 2 min |
| 9 | Verify checkmark | 30 sec |
| 10 | Restart app | 1 min |
| 11 | Test | 1 min |
| **Total** | | **~7 min** |

---

**You're done! The app should now work perfectly.** ✅
