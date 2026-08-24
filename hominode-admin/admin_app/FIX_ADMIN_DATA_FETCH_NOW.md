# Fix Admin Data Fetch - Simple Steps

## What I Added

I've added a "Debug Admin Data" button to your Profile screen that will:
1. Show you exactly what's happening with your admin data
2. Automatically fix the issue by creating the correct document

## How to Use

### Step 1: Open the App
Run your app on your device/emulator

### Step 2: Go to Profile
Tap on the Profile tab (bottom navigation)

### Step 3: Open Debug Tool
In the Account section, you'll see a new option:
- **"Debug Admin Data"** (with a bug icon, shown in red)
- Tap on it

### Step 4: Check the Information
The debug screen will show you:
```
=== FIREBASE AUTH ===
UID: UCkGf6KNHeQBvJZGQwZ8LF7Zgv2
Email: sukumar@gmail.com

=== ADMINS COLLECTION ===
Document DOES NOT EXIST at: admins/UCkGf6KNHeQBvJZGQwZ8LF7Zgv2

=== ALL ADMIN DOCUMENTS ===
Found 1 document(s):

Doc ID: UCkGf6KNHeQBvJZGQwZ8LF7Zgv2
  Name: lyvo home's
  Email: admin@lyvo.com
```

### Step 5: Fix the Issue
Tap the **"Create/Fix Document"** button (green button)

This will:
- Create a new document in `admins` collection
- Use your Firebase Auth UID as the document ID
- Copy data from any existing admin document
- Or use default values if no document exists

### Step 6: Verify
1. Tap "Refresh" to see the updated information
2. Go back to Profile screen
3. Open "Personal Information" (Edit Profile)
4. You should now see the correct data!

## What This Does

The debug tool:
- ✅ Shows your Firebase Auth UID
- ✅ Checks if document exists at `admins/{your_uid}`
- ✅ Lists all documents in `admins` collection
- ✅ Creates/fixes the document with correct ID
- ✅ Copies data from existing documents if available

## Expected Result

After clicking "Create/Fix Document":
- Document will exist at: `admins/{your_firebase_auth_uid}`
- Profile will show: "lyvo home's", "admin@lyvo.com", "1010678124"
- Dashboard will show: "LYVO Property Management"

## Why This Happens

The issue occurs when:
1. Document ID in Firestore doesn't match your Firebase Auth UID
2. Or document doesn't exist in `admins` collection

The fix ensures the document ID matches your Auth UID exactly.

## After Fixing

Once fixed, you can:
- Remove the debug button (optional)
- Or keep it for future troubleshooting
- Your data will fetch correctly from `admins` collection

## Quick Summary

1. Open app → Profile tab
2. Tap "Debug Admin Data"
3. Tap "Create/Fix Document"
4. Go back and check Profile
5. Data should now be correct!

That's it! The tool will automatically fix the issue for you.
