# Admin App - Testing Quick Start Guide

## Overview

This guide provides step-by-step instructions for testing the completed features:
1. Flat ID Generation with Sequential Numbering
2. Flow Function Pattern Implementation
3. Multi-Tenancy Enforcement

---

## Test 1: Flat ID Generation

### Objective
Verify that when a new building is created, all flats are automatically generated with sequential IDs in format A001, A002, A003, etc.

### Steps

1. **Login to Admin App**
   - Open the admin app
   - Login with admin credentials

2. **Create a New Building**
   - Navigate to "Manage Buildings" or "Building Management"
   - Click "Add New Building"
   - Fill in the form:
     - Building Name: "Ashoka Towers"
     - Floors: 2
     - Flats per Floor: 3
     - BHK Type: 2BHK (or mix of types)
   - Click "Create Building"

3. **Verify Flat Generation**
   - Check the console logs for:
     ```
     🔵 FLAT GENERATION FLOW: Starting...
     📋 STEP 1: Validating input parameters...
     ✅ STEP 1 PASSED: Input parameters validated
     📋 STEP 2: Fetching admin details...
     ✅ STEP 2 PASSED: Admin details retrieved
     📝 STEP 3: Generating flat IDs and creating batch...
        - Flat ID prefix: A
        - Total flats to create: 6
     ✅ STEP 3 PASSED: Flat IDs generated and batch prepared
     💾 STEP 4: Committing batch to Firestore...
     ✅ STEP 4 PASSED: Batch committed successfully
     🔍 STEP 5: Verifying flat creation...
        - Flats created: 6
        - Expected: 6
     ✅ STEP 5 PASSED: All flats verified
     ✅ FLAT GENERATION FLOW: COMPLETE
     ```

4. **Check Firestore**
   - Open Firebase Console
   - Navigate to Firestore Database
   - Go to `flats` collection
   - Filter by `buildingId` = the building you just created
   - Verify 6 flats exist with IDs:
     - A001 (Floor 1, Flat 1)
     - A002 (Floor 1, Flat 2)
     - A003 (Floor 1, Flat 3)
     - A004 (Floor 2, Flat 1)
     - A005 (Floor 2, Flat 2)
     - A006 (Floor 2, Flat 3)

5. **Verify Flat Data**
   - Click on flat A001
   - Verify the following fields:
     - `flatId`: "A001"
     - `flatLabel`: "A001"
     - `buildingId`: matches the building ID
     - `buildingName`: "Ashoka Towers"
     - `floor`: 1
     - `flatNumber`: 1
     - `type`: "2BHK"
     - `area`: "1200 Sqft"
     - `status`: "vacant"
     - `adminId`: your admin ID
     - `adminName`: your admin name
     - `adminEmail`: your admin email
     - `adminPhone`: your admin phone
     - `organization`: your organization

### Expected Results

✅ All 6 flats created with correct sequential IDs (A001-A006)
✅ Each flat has correct floor and flatNumber
✅ Admin details stored with each flat
✅ All flats have status "vacant"
✅ Console logs show all 5 flow function steps

---

## Test 2: Flow Function Pattern - Visitor Approval

### Objective
Verify that visitor approval follows the 5-step flow function pattern and sends notifications to residents.

### Steps

1. **Create a Visitor Request** (from Resident App)
   - Open Resident App
   - Navigate to "Visitor Management"
   - Click "Request Visitor"
   - Fill in:
     - Visitor Name: "John Smith"
     - Phone: "+91-9876543210"
     - Purpose: "Meeting"
     - Expected Time: Tomorrow at 2 PM
   - Submit request

2. **Approve Visitor** (from Admin App)
   - Open Admin App
   - Navigate to "Visitor Management"
   - Find the pending visitor request for "John Smith"
   - Click "Approve"

3. **Check Console Logs**
   - Verify the following logs appear:
     ```
     🔵 VISITOR APPROVAL FLOW: Starting...
     🔐 STEP 1: Validating admin authentication...
     ✅ STEP 1 PASSED: Admin authenticated
     📋 STEP 2: Validating visitor request...
     ✅ STEP 2 PASSED: Visitor request validated
     ✅ STEP 3: Approving visitor...
     ✅ STEP 3 PASSED: Visitor approved
     🔔 STEP 4: Notifying resident...
     ✅ STEP 4 PASSED: Resident notified
     ✅ VISITOR APPROVAL FLOW: COMPLETE
     ```

4. **Verify Notification in Resident App**
   - Open Resident App
   - Navigate to "Notifications"
   - Verify notification appears:
     - Title: "Visitor Approved"
     - Message: "John Smith has been approved to visit"
     - Type: "visitor_approved"

5. **Check Firestore**
   - Open Firebase Console
   - Go to `visitors` collection
   - Find the visitor record
   - Verify:
     - `isApproved`: true
     - `approvedAt`: timestamp of approval
     - `updatedAt`: timestamp of approval

### Expected Results

✅ All 5 flow function steps logged
✅ Visitor status updated to approved
✅ Notification sent to resident
✅ Notification appears in Resident App
✅ Firestore data updated correctly

---

## Test 3: Flow Function Pattern - Complaint Status Update

### Objective
Verify that complaint status updates follow the 5-step flow function pattern and send notifications.

### Steps

1. **Create a Complaint** (from Resident App)
   - Open Resident App
   - Navigate to "Complaint Management"
   - Click "Create Complaint"
   - Fill in:
     - Title: "Water Leakage"
     - Description: "Water leaking from ceiling"
     - Category: "Maintenance"
   - Submit complaint

2. **Update Complaint Status** (from Admin App)
   - Open Admin App
   - Navigate to "Complaint Management"
   - Find the complaint "Water Leakage"
   - Click "Edit" or "Update Status"
   - Change status to "In Progress"
   - Click "Update"

3. **Check Console Logs**
   - Verify logs appear for complaint status update flow

4. **Verify Notification in Resident App**
   - Open Resident App
   - Navigate to "Notifications"
   - Verify notification appears about complaint status change

5. **Check Firestore**
   - Open Firebase Console
   - Go to `complaints` collection
   - Find the complaint
   - Verify status updated to "In Progress"

### Expected Results

✅ Complaint status updated
✅ Notification sent to resident
✅ Notification appears in Resident App
✅ Firestore data updated correctly

---

## Test 4: Multi-Tenancy Enforcement

### Objective
Verify that Admin A cannot see Admin B's data and vice versa.

### Steps

1. **Setup Two Admin Accounts**
   - Create Admin A with building "Ashoka Towers"
   - Create Admin B with building "Breeze Heights"

2. **Login as Admin A**
   - Open Admin App
   - Login with Admin A credentials

3. **Verify Admin A Only Sees Their Data**
   - Navigate to "Manage Buildings"
   - Verify only "Ashoka Towers" appears
   - Verify "Breeze Heights" does NOT appear
   - Navigate to "Flat Management"
   - Verify only flats from "Ashoka Towers" appear (A001-A006)
   - Navigate to "Visitor Management"
   - Verify only visitors for Admin A's building appear

4. **Login as Admin B**
   - Logout from Admin A
   - Login with Admin B credentials

5. **Verify Admin B Only Sees Their Data**
   - Navigate to "Manage Buildings"
   - Verify only "Breeze Heights" appears
   - Verify "Ashoka Towers" does NOT appear
   - Navigate to "Flat Management"
   - Verify only flats from "Breeze Heights" appear
   - Navigate to "Visitor Management"
   - Verify only visitors for Admin B's building appear

### Expected Results

✅ Admin A cannot see Admin B's buildings
✅ Admin A cannot see Admin B's flats
✅ Admin A cannot see Admin B's visitors
✅ Admin B cannot see Admin A's buildings
✅ Admin B cannot see Admin A's flats
✅ Admin B cannot see Admin A's visitors

---

## Test 5: Admin Details Storage

### Objective
Verify that admin details are stored with all data for audit trail.

### Steps

1. **Create Building as Admin A**
   - Login as Admin A
   - Create building "Ashoka Towers"

2. **Check Firestore - Buildings Collection**
   - Open Firebase Console
   - Go to `buildings` collection
   - Find "Ashoka Towers"
   - Verify fields:
     - `adminId`: Admin A's ID
     - `adminName`: Admin A's name
     - `adminEmail`: Admin A's email
     - `adminPhone`: Admin A's phone
     - `organization`: Admin A's organization

3. **Check Firestore - Flats Collection**
   - Go to `flats` collection
   - Filter by `buildingId` = "Ashoka Towers"
   - Click on flat A001
   - Verify fields:
     - `adminId`: Admin A's ID
     - `adminName`: Admin A's name
     - `adminEmail`: Admin A's email
     - `adminPhone`: Admin A's phone
     - `organization`: Admin A's organization

4. **Create Event as Admin A**
   - Login as Admin A
   - Create an event "Building Meeting"

5. **Check Firestore - Events Collection**
   - Go to `events` collection
   - Find "Building Meeting"
   - Verify fields:
     - `adminId`: Admin A's ID
     - `adminName`: Admin A's name
     - `adminEmail`: Admin A's email
     - `adminPhone`: Admin A's phone
     - `organization`: Admin A's organization

### Expected Results

✅ Admin details stored with buildings
✅ Admin details stored with flats
✅ Admin details stored with events
✅ Admin details stored with all data
✅ Audit trail preserved

---

## Troubleshooting

### Issue: Flats not created
**Solution**: Check console logs for errors. Verify:
- Building name is not empty
- Floors > 0
- FlatsPerFloor > 0
- Admin is logged in
- Firestore permissions allow write

### Issue: Notifications not appearing
**Solution**: Verify:
- Resident is logged in
- Notifications collection exists in Firestore
- Resident ID is correct
- Check Firestore for notification documents

### Issue: Multi-tenancy not working
**Solution**: Verify:
- AdminId is being set correctly
- Queries include `where('adminId', isEqualTo: adminId)`
- Admin is logged in
- Check Firestore for adminId field in documents

### Issue: Flow function logs not appearing
**Solution**: Check:
- Console is open (F12 or right-click → Inspect)
- Dart DevTools is connected
- Print statements are not being filtered

---

## Quick Checklist

### Flat ID Generation
- [ ] Building created successfully
- [ ] 6 flats generated with IDs A001-A006
- [ ] Each flat has correct floor and flatNumber
- [ ] Admin details stored with each flat
- [ ] All flats have status "vacant"
- [ ] Console logs show all 5 flow function steps

### Flow Function Pattern
- [ ] Visitor approval logs show all 5 steps
- [ ] Complaint status update logs show all 5 steps
- [ ] Notifications sent to residents
- [ ] Notifications appear in Resident App
- [ ] Firestore data updated correctly

### Multi-Tenancy
- [ ] Admin A only sees their data
- [ ] Admin B only sees their data
- [ ] Admin A cannot see Admin B's data
- [ ] Admin B cannot see Admin A's data
- [ ] All queries filtered by adminId

### Admin Details
- [ ] Admin details stored with buildings
- [ ] Admin details stored with flats
- [ ] Admin details stored with events
- [ ] Admin details stored with all data
- [ ] Audit trail preserved

---

**Last Updated**: March 25, 2026
**Version**: 1.0.0
**Status**: Ready for Testing ✅
