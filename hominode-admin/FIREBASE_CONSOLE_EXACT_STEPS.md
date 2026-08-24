# Firebase Console - Exact Steps with Descriptions

## 🎯 Goal
Apply Firestore rules to fix the error

## Step-by-Step Instructions

### STEP 1: Open Firebase Console
**URL**: `https://console.firebase.google.com`

**What you'll see**:
- Firebase home page
- List of your projects

**Action**: Click on your project name

---

### STEP 2: You're Now in Your Project
**What you'll see**:
- Left sidebar with options
- "Firestore Database" option in the sidebar

**Action**: Click on "Firestore Database"

---

### STEP 3: You're in Firestore Database
**What you'll see**:
- At the top: "Data" tab (currently selected)
- Next to it: "Rules" tab
- Below: Your collections (admins, users, flats, etc.)

**Action**: Click on "Rules" tab at the top

---

### STEP 4: You're in Rules Editor
**What you'll see**:
- A text editor with current rules
- Current rules might show: `allow read, write: if true;`
- Or might be empty
- Buttons at bottom: "Publish" and "Cancel"

**Action**: 
1. Click in the editor
2. Press Ctrl+A (or Cmd+A on Mac)
3. Press Delete to clear all text

---

### STEP 5: Editor is Now Empty
**What you'll see**:
- Empty text editor
- Ready for new rules

**Action**: Copy and paste this rule:

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

**How to paste**:
1. Copy the rule above
2. Right-click in the editor
3. Click "Paste"
4. Or press Ctrl+V (or Cmd+V on Mac)

---

### STEP 6: Rules Are Now in Editor
**What you'll see**:
- The new rules in the editor
- No red underlines (syntax is correct)
- "Publish" button at bottom right

**Action**: Click the "Publish" button

---

### STEP 7: Publishing...
**What you'll see**:
- Loading message: "Publishing..."
- Wait indicator

**Action**: Wait 1-2 minutes

---

### STEP 8: Published Successfully
**What you'll see**:
- Green checkmark ✅
- Message: "Rules Published Successfully"
- Timestamp of when published

**Action**: Go back to your app

---

### STEP 9: Test Your App
**What to do**:
1. Close the app completely
2. Restart the app
3. Try the action that was failing (e.g., update flat status)
4. Should work now!

**Expected result**:
- ✅ No more errors
- ✅ All features work

---

## 📋 Checklist

- [ ] Opened Firebase Console
- [ ] Clicked on your project
- [ ] Clicked on Firestore Database
- [ ] Clicked on Rules tab
- [ ] Deleted all current rules
- [ ] Pasted new rules
- [ ] Clicked Publish
- [ ] Waited 1-2 minutes
- [ ] Saw green checkmark
- [ ] Closed and restarted app
- [ ] Tested - works now!

---

## 🆘 Troubleshooting

### Issue: Can't Find Rules Tab
**Solution**:
- Make sure you're in Firestore Database (not Realtime Database)
- Rules tab should be at the top next to "Data"
- If not visible, refresh the page

### Issue: Rules Won't Publish
**Solution**:
- Check for red underlines (syntax errors)
- Make sure all braces are matched
- Try copying the rules again
- Click Publish again

### Issue: Still Getting Errors After Publishing
**Solution**:
- Wait 1-2 minutes for deployment
- Close app completely
- Clear app cache
- Restart app
- Try again

---

## ✅ Success Indicators

After applying rules, you should see:
- ✅ Green checkmark in Firebase Console
- ✅ No more "not-found" errors in app
- ✅ Flat status updates work
- ✅ Resident assignment works
- ✅ All features work

---

## 🎯 DO THIS NOW!

**Time required**: 5 minutes

**Expected result**: All errors fixed

**Go to Firebase Console NOW!**

