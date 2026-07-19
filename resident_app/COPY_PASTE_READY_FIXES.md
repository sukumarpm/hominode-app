# Copy-Paste Ready Fixes

## Firestore Rules (Copy-Paste Ready)

### Step 1: Go to Firebase Console
```
https://console.firebase.google.com
```

### Step 2: Navigate to Firestore Rules
1. Select your project
2. Click **Firestore Database** (left sidebar)
3. Click **Rules** tab

### Step 3: Delete Everything and Paste This

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // Allow unauthenticated read to users collection for login
    match /users/{userId} {
      allow read: if true;
      allow write: if request.auth != null;
    }
    
    // Allow all authenticated users to read and write everything else
    match /{document=**} {
      allow read, write: if request.auth != null;
    }
  }
}
```

### Step 4: Click Publish

---

## Firestore Indexes (Manual Creation)

### Index 1: Bills Collection

**Collection**: `bills`

**Fields**:
- Field 1: `status` (Ascending)
- Field 2: `flatId` (Ascending)

**Steps**:
1. Go to Firebase Console → Firestore Database → Indexes
2. Click "Create Index"
3. Collection ID: `bills`
4. Add Field: `status` (Ascending)
5. Add Field: `flatId` (Ascending)
6. Click "Create Index"

---

### Index 2: Marketplace Requests (2-field)

**Collection**: `marketplaceRequests`

**Fields**:
- Field 1: `productId` (Ascending)
- Field 2: `requestUserId` (Ascending)

**Steps**:
1. Go to Firebase Console → Firestore Database → Indexes
2. Click "Create Index"
3. Collection ID: `marketplaceRequests`
4. Add Field: `productId` (Ascending)
5. Add Field: `requestUserId` (Ascending)
6. Click "Create Index"

---

### Index 3: Marketplace Requests (4-field)

**Collection**: `marketplaceRequests`

**Fields**:
- Field 1: `productId` (Ascending)
- Field 2: `productOwnerId` (Ascending)
- Field 3: `requestUserId` (Ascending)
- Field 4: `status` (Ascending)

**Steps**:
1. Go to Firebase Console → Firestore Database → Indexes
2. Click "Create Index"
3. Collection ID: `marketplaceRequests`
4. Add Field: `productId` (Ascending)
5. Add Field: `productOwnerId` (Ascending)
6. Add Field: `requestUserId` (Ascending)
7. Add Field: `status` (Ascending)
8. Click "Create Index"

---

### Index 4: Marketplace Listings

**Collection**: `marketplaces`

**Fields**:
- Field 1: `buildingId` (Ascending)
- Field 2: `status` (Ascending)
- Field 3: `category` (Ascending)

**Steps**:
1. Go to Firebase Console → Firestore Database → Indexes
2. Click "Create Index"
3. Collection ID: `marketplaces`
4. Add Field: `buildingId` (Ascending)
5. Add Field: `status` (Ascending)
6. Add Field: `category` (Ascending)
7. Click "Create Index"

---

### Index 5: Users Collection

**Collection**: `users`

**Fields**:
- Field 1: `buildingId` (Ascending)
- Field 2: `role` (Ascending)

**Steps**:
1. Go to Firebase Console → Firestore Database → Indexes
2. Click "Create Index"
3. Collection ID: `users`
4. Add Field: `buildingId` (Ascending)
5. Add Field: `role` (Ascending)
6. Click "Create Index"

---

## Test Credentials

```
Email: preethampriyatharson07@gmail.com
Password: wlG0czyq
Flat: T001
Building: yFSMeOsJaYLsr5Wo
```

---

## Verification Checklist

### After Deploying Rules

- [ ] Go to Firebase Console → Firestore Database → Rules
- [ ] Verify rules are deployed (should show green checkmark)
- [ ] Try login with test credentials
- [ ] Should see console output starting with "🔐 Starting login..."

### After Creating Indexes

- [ ] Go to Firebase Console → Firestore Database → Indexes
- [ ] Verify all 5 indexes are created
- [ ] All indexes should have green checkmark (status: "Enabled")
- [ ] Try fetching data from different screens
- [ ] Should not see "requires an index" errors

### After All Fixes

- [ ] Login works ✅
- [ ] Home screen loads ✅
- [ ] Billing screen loads ✅
- [ ] Marketplace loads ✅
- [ ] Messages load ✅
- [ ] Amenities load ✅

---

## Troubleshooting

### Rules Deployment Failed

**Error**: "Rules update failed"

**Solution**:
1. Check syntax (copy-paste from above)
2. Make sure you're in the correct project
3. Try again

### Index Creation Failed

**Error**: "Index creation failed"

**Solution**:
1. Check collection name (case-sensitive)
2. Check field names (case-sensitive)
3. Try creating index again

### Login Still Fails After Rules Deployed

**Error**: "permission-denied"

**Solution**:
1. Verify rules are deployed (check Firebase Console)
2. Refresh the app
3. Try login again
4. Check console output for detailed error

### Queries Still Fail After Indexes Created

**Error**: "requires an index"

**Solution**:
1. Verify index was created (check Firebase Console)
2. Verify index status is "Enabled" (green checkmark)
3. Wait 1-2 minutes for index to fully build
4. Refresh the app
5. Try again

---

## Quick Reference

| Task | Time | Status |
|------|------|--------|
| Deploy Rules | 1 min | ⏳ |
| Create Indexes | 5 min | ⏳ |
| Test Login | 2 min | ⏳ |
| Fix Code | 65 min | ⏳ |
| **Total** | **~70 min** | **⏳** |

---

## Next Steps

1. ✅ Deploy Firestore Rules (1 minute)
2. ✅ Create Firestore Indexes (5 minutes)
3. ✅ Test Login (2 minutes)
4. ⏳ Fix Code Issues (65 minutes)

---

**Ready? Start with the Firestore Rules above! 🚀**
