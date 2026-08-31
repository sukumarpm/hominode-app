# Unified Firestore Rules - Quick Guide

## 📋 OVERVIEW

**Single rule file for all 3 apps:** Resident, Admin, and Security

**File:** `FIRESTORE_RULES_UNIFIED_ALL_APPS.txt`

This unified rule uses **role-based access control** to manage permissions for all three apps in one place.

---

## 🚀 DEPLOYMENT

1. Go to **Firebase Console** → **Firestore** → **Rules**
2. Copy entire content from `FIRESTORE_RULES_UNIFIED_ALL_APPS.txt`
3. Paste into Firebase Rules editor
4. Click **Publish**

That's it! All 3 apps will work with this single rule.

---

## 🔑 KEY FEATURES

### Role-Based Access Control

The rules check user `role` field to determine permissions:

- **`role: 'resident'`** - Residents (Resident App)
- **`role: 'admin'`** - Admins (Admin App)
- **`role: 'security'`** - Security staff (Security App)

### Building Isolation

All users must have `buildingId` field. Users can only access data from their building.

### Helper Functions

```javascript
isAdmin()           // Check if user is admin
isSecurity()        // Check if user is security staff
isResident()        // Check if user is resident
userBuildingId()    // Get user's building ID
sameBuilding()      // Check if resource is in user's building
```

---

## 📊 PERMISSIONS BY ROLE

### RESIDENT APP (role: 'resident')

| Collection | Read | Write | Notes |
|-----------|------|-------|-------|
| users | Own data | Own data | Can read other users in building |
| buildings | Own building | ❌ | Read-only |
| flats | Own building | ❌ | Read-only |
| bills | Own bills | ❌ | Backend writes only |
| announcements | All active | ❌ | Backend writes only |
| events | All published | ❌ | Backend writes only |
| amenities | Own building | ❌ | Backend writes only |
| bookings | Own bookings | Own bookings | Create/update/delete own |
| messages | Own messages | Own messages | Create/update/delete own |
| complaints | Own complaints | Own complaints | Create/update/delete own |
| visitors | Own visitors | Own visitors | Create/update/delete own |
| community_wall | Own building | Own posts | Create/update/delete own |
| marketplace | Own building | Own listings | Create/update/delete own |
| notifications | Own notifications | ❌ | Backend writes only |
| staff | Own building | ❌ | Read-only |
| access_logs | ❌ | ❌ | Security staff only |

### ADMIN APP (role: 'admin')

| Collection | Read | Write | Notes |
|-----------|------|-------|-------|
| users | All in building | Own data | Manage building users |
| buildings | Own building | Own building | Manage building |
| flats | All in building | All in building | Manage flats |
| bills | All in building | All in building | Manage bills |
| announcements | All | All | Create/manage announcements |
| events | All | All | Create/manage events |
| amenities | All in building | All in building | Manage amenities |
| bookings | All in building | ❌ | Read-only |
| messages | All in building | ❌ | Read-only |
| complaints | All in building | All in building | Manage complaints |
| visitors | All in building | ❌ | Read-only |
| community_wall | All in building | Delete posts | Moderate content |
| marketplace | All in building | ❌ | Read-only |
| notifications | All in building | All in building | Manage notifications |
| staff | All in building | All in building | Manage staff |
| access_logs | All in building | ❌ | Read-only |

### SECURITY APP (role: 'security')

| Collection | Read | Write | Notes |
|-----------|------|-------|-------|
| users | All in building | Own data | View building users |
| buildings | Own building | ❌ | Read-only |
| flats | All in building | ❌ | Read-only |
| bills | ❌ | ❌ | No access |
| announcements | ❌ | ❌ | No access |
| events | ❌ | ❌ | No access |
| amenities | ❌ | ❌ | No access |
| bookings | ❌ | ❌ | No access |
| messages | ❌ | ❌ | No access |
| complaints | All in building | ❌ | Read-only |
| visitors | All in building | All in building | Manage visitors |
| community_wall | ❌ | ❌ | No access |
| marketplace | ❌ | ❌ | No access |
| notifications | All in building | ❌ | Read-only |
| staff | All in building | ❌ | Read-only |
| access_logs | All in building | Create logs | Create/read access logs |

---

## ✅ REQUIRED USER FIELDS

Every user document must have:

```json
{
  "uid": "user-id",
  "role": "resident|admin|security",
  "buildingId": "building-id",
  "flatId": "flat-id",
  "email": "user@example.com",
  "name": "User Name"
}
```

---

## 🔒 SECURITY PRINCIPLES

1. **Authentication Required** - All operations need `request.auth != null`
2. **Building Isolation** - Users only access their building's data
3. **Role-Based Access** - Different permissions per role
4. **Data Ownership** - Users manage only their own data
5. **Backend Protection** - Critical data (bills, announcements) backend-only

---

## 🧪 TESTING CHECKLIST

### Resident App
- [ ] Can read own profile
- [ ] Can read bills for own flat
- [ ] Can read announcements and events
- [ ] Can read amenities for building
- [ ] Can create/read bookings
- [ ] Can create/read complaints
- [ ] Can create/read visitors
- [ ] Can create/read community posts
- [ ] Cannot read other residents' bills

### Admin App
- [ ] Can read all users in building
- [ ] Can read all building data
- [ ] Can read all flats
- [ ] Can read all amenities
- [ ] Can read all bookings
- [ ] Can read all complaints
- [ ] Can create announcements
- [ ] Can create events
- [ ] Can manage staff
- [ ] Cannot access other buildings

### Security App
- [ ] Can read users in building
- [ ] Can read all visitors
- [ ] Can update visitor status
- [ ] Can create access logs
- [ ] Can read access logs
- [ ] Can read complaints
- [ ] Cannot modify complaints
- [ ] Cannot access other buildings

---

## 🐛 TROUBLESHOOTING

### "Permission denied" Error

**Check:**
1. User has correct `role` field (resident/admin/security)
2. User has `buildingId` field
3. Resource has `buildingId` field
4. Building IDs match exactly

### Cannot Read Data

**Check:**
1. User is authenticated (Firebase Auth)
2. User document exists in `/users/{uid}`
3. User has required fields (role, buildingId)
4. Collection names are correct (case-sensitive)

### Cannot Write Data

**Check:**
1. User has correct role for operation
2. User's buildingId matches resource buildingId
3. User is owner of data (for personal data)
4. Operation is allowed for that role

---

## 📝 COLLECTION STRUCTURE

### Users Collection
```
/users/{uid}
  - role: 'resident' | 'admin' | 'security'
  - buildingId: string
  - flatId: string (residents only)
  - email: string
  - name: string
```

### Bills Collection
```
/bills/{billId}
  - buildingId: string
  - flatId: string
  - userId: string
  - amount: number
  - status: string
```

### Visitors Collection
```
/visitors/{visitorId}
  - buildingId: string
  - flatId: string
  - residentId: string
  - visitorName: string
  - status: 'expected' | 'arrived' | 'departed'
```

### Complaints Collection
```
/complaints/{complaintId}
  - buildingId: string
  - flatId: string
  - userId: string
  - title: string
  - status: string
```

---

## 🎯 DEPLOYMENT STEPS

1. **Prepare User Data**
   - Ensure all users have `role` and `buildingId` fields
   - Verify role values are correct

2. **Deploy Rules**
   - Copy `FIRESTORE_RULES_UNIFIED_ALL_APPS.txt`
   - Paste into Firebase Console
   - Click Publish

3. **Test Each App**
   - Login as resident → test resident permissions
   - Login as admin → test admin permissions
   - Login as security → test security permissions

4. **Monitor**
   - Check Firebase Console for errors
   - Review access logs
   - Monitor performance

---

## 💡 TIPS

- Use helper functions to keep rules DRY
- Test rules in Firebase Console before deploying
- Monitor error logs for permission issues
- Keep user documents updated with correct roles
- Use building isolation to prevent cross-building access

---

**Status:** ✅ READY FOR DEPLOYMENT

**Last Updated:** June 1, 2026

