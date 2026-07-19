# Firestore Security Rules Deployment Guide

## 📋 OVERVIEW

This guide provides step-by-step instructions for deploying Firestore security rules for all three apps:
- **Resident App** - User data, bookings, complaints, messages
- **Admin App** - Building management, amenities, complaints
- **Security App** - Visitor management, access logs

---

## 🚀 DEPLOYMENT STEPS

### STEP 1: Access Firebase Console

1. Open [Firebase Console](https://console.firebase.google.com)
2. Select your project from the list
3. Click on **Firestore Database** in the left sidebar
4. Click on the **Rules** tab at the top

---

### STEP 2: Deploy Resident App Rules

**File:** `RESIDENT_APP_FIRESTORE_RULES.txt`

1. In Firebase Console, go to **Firestore Database** → **Rules**
2. Clear the existing rules (select all and delete)
3. Copy the entire content from `RESIDENT_APP_FIRESTORE_RULES.txt`
4. Paste into the Firebase Rules editor
5. Click **Publish** button
6. Wait for confirmation message: "Rules updated successfully"

**What these rules allow:**
- ✅ Residents read/write their own user data
- ✅ Residents read bills for their flat
- ✅ Residents read announcements and events
- ✅ Residents read amenities for their building
- ✅ Residents create/manage their own bookings
- ✅ Residents create/manage their own complaints
- ✅ Residents create/manage their own visitors
- ✅ Residents read/write community wall posts
- ✅ Residents read/write marketplace listings

---

### STEP 3: Deploy Admin App Rules

**File:** `ADMIN_APP_FIRESTORE_RULES.txt`

1. In Firebase Console, go to **Firestore Database** → **Rules**
2. Clear the existing rules (select all and delete)
3. Copy the entire content from `ADMIN_APP_FIRESTORE_RULES.txt`
4. Paste into the Firebase Rules editor
5. Click **Publish** button
6. Wait for confirmation message: "Rules updated successfully"

**What these rules allow:**
- ✅ Admins read all users in their building
- ✅ Admins read/write their building data
- ✅ Admins read/write flats in their building
- ✅ Admins read/write amenities
- ✅ Admins read bookings
- ✅ Admins read/write complaints
- ✅ Admins create/manage announcements
- ✅ Admins create/manage events
- ✅ Admins read/write bills
- ✅ Admins read visitors
- ✅ Admins moderate community wall posts
- ✅ Admins manage staff

---

### STEP 4: Deploy Security App Rules

**File:** `SECURITY_APP_FIRESTORE_RULES.txt`

1. In Firebase Console, go to **Firestore Database** → **Rules**
2. Clear the existing rules (select all and delete)
3. Copy the entire content from `SECURITY_APP_FIRESTORE_RULES.txt`
4. Paste into the Firebase Rules editor
5. Click **Publish** button
6. Wait for confirmation message: "Rules updated successfully"

**What these rules allow:**
- ✅ Security staff read users in their building
- ✅ Security staff read/write/update visitors
- ✅ Security staff read their building data
- ✅ Security staff read flats in their building
- ✅ Security staff create/read access logs
- ✅ Security staff read complaints
- ✅ Security staff read notifications

---

## ⚠️ IMPORTANT NOTES

### Before Deploying

1. **Backup Current Rules**
   - Screenshot or copy your current rules before deploying
   - This helps if you need to rollback

2. **Test in Staging First**
   - If possible, test rules in a staging Firebase project first
   - This prevents breaking production access

3. **Verify User Roles**
   - Ensure all users have correct `role` field in their user document:
     - `role: 'resident'` for residents
     - `role: 'admin'` for admins
     - `role: 'security'` for security staff

4. **Check Building IDs**
   - All users must have `buildingId` field set
   - All resources must have `buildingId` field set
   - Building IDs must match for access to work

### After Deploying

1. **Verify Deployment**
   - Check that rules show "Published" status
   - Rules should appear in the Rules editor

2. **Test Each App**
   - Test Resident App: Can read bills, announcements, events?
   - Test Admin App: Can read all building data?
   - Test Security App: Can read visitors?

3. **Monitor Errors**
   - Check Firebase Console → Firestore → Usage
   - Look for "Permission denied" errors
   - Check app logs for any access issues

---

## 🔍 VERIFICATION CHECKLIST

### Resident App Verification

- [ ] User can login successfully
- [ ] User can read their own profile
- [ ] User can read bills for their flat
- [ ] User can read announcements
- [ ] User can read events
- [ ] User can read amenities for their building
- [ ] User can create a booking
- [ ] User can read their bookings
- [ ] User can create a complaint
- [ ] User can read their complaints
- [ ] User can create a visitor
- [ ] User can read their visitors
- [ ] User can create a community wall post
- [ ] User can read community wall posts
- [ ] User can create a marketplace listing
- [ ] User cannot read other users' bills
- [ ] User cannot read other users' complaints

### Admin App Verification

- [ ] Admin can login successfully
- [ ] Admin can read all users in their building
- [ ] Admin can read building data
- [ ] Admin can read all flats
- [ ] Admin can read all amenities
- [ ] Admin can read all bookings
- [ ] Admin can read all complaints
- [ ] Admin can create an announcement
- [ ] Admin can create an event
- [ ] Admin can read all bills
- [ ] Admin can read all visitors
- [ ] Admin can delete community wall posts
- [ ] Admin can manage staff
- [ ] Admin cannot access other buildings' data

### Security App Verification

- [ ] Security staff can login successfully
- [ ] Security staff can read users in their building
- [ ] Security staff can read all visitors
- [ ] Security staff can update visitor status
- [ ] Security staff can create access logs
- [ ] Security staff can read access logs
- [ ] Security staff can read building data
- [ ] Security staff can read flats
- [ ] Security staff can read complaints
- [ ] Security staff can read notifications
- [ ] Security staff cannot modify complaints
- [ ] Security staff cannot access other buildings' data

---

## 🐛 TROUBLESHOOTING

### "Permission denied" Error

**Problem:** Users cannot read/write data

**Solutions:**
1. Check user has correct `role` in users collection
2. Verify `buildingId` is set in user document
3. Verify `buildingId` matches in resource document
4. Check collection names are spelled correctly (case-sensitive)
5. Ensure user is authenticated (Firebase Auth)

**Debug Steps:**
```
1. Go to Firebase Console → Firestore → Data
2. Find the user document in /users/{userId}
3. Check that 'role' field exists and has correct value
4. Check that 'buildingId' field exists and matches resource buildingId
```

### Cannot Read Bills

**Problem:** Residents cannot see their bills

**Solutions:**
1. Verify bill document has `flatId` field
2. Verify bill document has `userId` field
3. Verify user document has `flatId` field
4. Check that flatId in bill matches flatId in user document

### Cannot Create Bookings

**Problem:** Residents cannot create bookings

**Solutions:**
1. Verify booking document has `userId` field
2. Verify `userId` matches authenticated user ID
3. Verify booking document has `buildingId` field
4. Check that buildingId matches user's buildingId

### Admin Cannot Access Data

**Problem:** Admin cannot read building data

**Solutions:**
1. Verify admin user has `role: 'admin'`
2. Verify admin user has `buildingId` field
3. Verify resource documents have `buildingId` field
4. Check that buildingIds match exactly

### Security Staff Cannot Read Visitors

**Problem:** Security staff cannot see visitors

**Solutions:**
1. Verify security user has `role: 'security'`
2. Verify security user has `buildingId` field
3. Verify visitor documents have `buildingId` field
4. Check that buildingIds match exactly

---

## 📊 MONITORING

### Check Rule Usage

1. Go to Firebase Console → Firestore → Usage
2. Look for:
   - Read operations
   - Write operations
   - Delete operations
   - Permission denied errors

### View Error Logs

1. Go to Firebase Console → Firestore → Logs
2. Filter by:
   - Collection name
   - Operation type (read/write/delete)
   - Error type

### Performance Monitoring

1. Go to Firebase Console → Performance
2. Monitor:
   - Firestore read latency
   - Firestore write latency
   - Error rates

---

## 🔄 ROLLBACK PROCEDURE

If something goes wrong:

1. Go to Firebase Console → Firestore → Rules
2. Click **Revert** button (if available)
3. Or manually paste previous rules and click **Publish**

---

## 📝 RULE STRUCTURE EXPLANATION

### Helper Functions

```javascript
function isAdmin() {
  return get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'admin';
}

function isSecurity() {
  return get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'security';
}
```

These functions check if the current user has the specified role.

### Building Isolation

```javascript
resource.data.buildingId == get(/databases/$(database)/documents/users/$(request.auth.uid)).data.buildingId
```

This ensures users can only access data from their building.

### Data Ownership

```javascript
resource.data.userId == request.auth.uid
```

This ensures users can only modify their own data.

---

## ✅ DEPLOYMENT CHECKLIST

- [ ] Backup current rules
- [ ] Verify all users have correct role field
- [ ] Verify all users have buildingId field
- [ ] Deploy Resident App rules
- [ ] Deploy Admin App rules
- [ ] Deploy Security App rules
- [ ] Test Resident App access
- [ ] Test Admin App access
- [ ] Test Security App access
- [ ] Monitor error logs
- [ ] Verify all features working

---

## 📞 SUPPORT

If you encounter issues:

1. Check the **Troubleshooting** section above
2. Review the **Verification Checklist**
3. Check Firebase Console logs
4. Verify user documents have required fields
5. Test with a simple read operation first

---

**Status:** ✅ READY FOR DEPLOYMENT

**Last Updated:** June 1, 2026

