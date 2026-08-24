# Testing Guide - Updated Features

## Build Status
✅ **Build Successful** - App compiled and deployed to device

---

## Feature Testing

### 1. Persistent Login (Session Management)

**Test Steps**:
1. Launch the app
2. Login with credentials:
   - Email: `sibi@gmail.com`
   - Password: `BCDEFGHIJKLM`
3. Verify dashboard loads with staff data
4. Close the app completely
5. Reopen the app
6. **Expected Result**: Dashboard should show immediately (no login screen)

**What's Happening**:
- Firebase Auth maintains session automatically
- App checks auth state on startup
- If user is logged in, dashboard shows
- If user is logged out, login screen shows

---

### 2. Dashboard Data Loading

**Test Steps**:
1. Login successfully
2. Dashboard should display:
   - Staff name (not "Loading...")
   - Gate assignment (e.g., "Gate A")
   - Shift timing
3. Verify all data is from Firestore (real data, not demo)

**Expected Results**:
- Staff name displays immediately
- Gate assignment shows correctly
- No "Loading..." placeholder text
- All data matches Firestore staff collection

---

### 3. Attendance Toggle (On/Off)

**Test Steps**:
1. On dashboard, locate "Today's Attendance" card
2. You should see a **Switch toggle** (not a button)
3. Toggle is currently OFF (orange indicator, "Off Duty")
4. **Toggle ON**:
   - App requests GPS permission
   - Shows loading spinner
   - Records check-in with GPS location
   - Toggle turns green, shows "On Duty"
   - Displays check-in time and GPS coordinates
5. **Toggle OFF**:
   - Shows loading spinner
   - Records check-out with GPS location
   - Toggle turns orange, shows "Off Duty"
   - Clears check-in time display

**Expected Results**:
- Toggle switches smoothly between ON/OFF
- GPS location captured on both check-in and check-out
- Status text updates: "You are On Duty" / "You are Off Duty"
- Check-in time and coordinates display when checked in

---

### 4. Profile Screen Data Loading

**Test Steps**:
1. On dashboard, tap the "Profile" tab (bottom navigation)
2. Profile screen should display:
   - Staff name
   - Staff role
   - Security ID
   - Shift timing
   - Gate assignment
   - Phone number
   - Email address
3. All data should be from Firestore (real data)

**Expected Results**:
- All staff information displays correctly
- No loading spinners (data loads quickly)
- All fields populated from Firestore
- Settings section shows: Notifications, Change Password, Help & Support

---

### 5. Logout Functionality

**Test Steps**:
1. On Profile screen, scroll down
2. Tap "Logout" button
3. Confirmation dialog appears
4. Tap "Logout" to confirm
5. **Expected Result**: Redirected to login screen

**After Logout**:
1. Close and reopen app
2. **Expected Result**: Login screen shows (session cleared)

---

### 6. GPS Location Capture

**Test Steps**:
1. Ensure GPS is enabled on device
2. On dashboard, toggle attendance ON
3. App requests GPS permission
4. Grant permission
5. Check-in recorded with GPS coordinates
6. Verify coordinates display in attendance card
7. Toggle OFF to check out
8. Verify checkout also captures GPS

**Expected Results**:
- GPS coordinates display: "Latitude, Longitude"
- Coordinates update on each check-in/out
- Firestore staffAttendance collection contains GPS data

---

### 7. Firestore Data Verification

**Check Firestore Collections**:

#### staff collection
- Open Firebase Console
- Navigate to Firestore → staff collection
- Find the logged-in staff document
- Verify fields:
  - `uid`: Firebase Auth UID
  - `name`: Staff name
  - `email`: Staff email
  - `phone`: Staff phone
  - `shift`: Shift timing
  - `gate`: Gate assignment
  - `status`: Current status (on-duty/off-duty)
  - `lastCheckIn`: Last check-in timestamp
  - `lastCheckInLatitude`: GPS latitude
  - `lastCheckInLongitude`: GPS longitude

#### staffAttendance collection
- Navigate to Firestore → staffAttendance collection
- Should contain records for each check-in/out
- Verify fields:
  - `staffId`: Staff ID
  - `staffName`: Staff name
  - `gateName`: Gate name
  - `checkInTime`: Check-in timestamp
  - `checkOutTime`: Check-out timestamp (if checked out)
  - `latitude`: GPS latitude
  - `longitude`: GPS longitude
  - `status`: Attendance status

---

## Troubleshooting

### Issue: "Loading..." still shows on dashboard
**Solution**: 
- Ensure Firestore has staff collection with `uid` field
- Verify Firebase Auth user is properly signed in
- Check network connectivity

### Issue: Toggle doesn't work
**Solution**:
- Ensure GPS is enabled on device
- Grant GPS permission when prompted
- Check Firestore staffAttendance collection has write permissions

### Issue: GPS coordinates not captured
**Solution**:
- Enable GPS on device
- Grant location permission to app
- Ensure device has GPS signal
- Check location_service.dart for permission handling

### Issue: Profile screen shows "Failed to load profile"
**Solution**:
- Verify Firebase Auth user is logged in
- Check Firestore staff collection exists
- Ensure staff document has `uid` field matching Firebase Auth UID
- Tap "Retry" button to reload

### Issue: Logout doesn't work
**Solution**:
- Ensure Firebase Auth is properly initialized
- Check network connectivity
- Verify logout button is tapped (not just scrolled past)

---

## Login Credentials

**Test Account**:
- Email: `sibi@gmail.com`
- Password: `BCDEFGHIJKLM`

**Note**: Credentials are stored in Firestore staff collection and verified against Firebase Auth.

---

## Expected Behavior Summary

| Feature | Before | After |
|---------|--------|-------|
| Login | Works | Works + Persistent session |
| Dashboard | Shows "Loading..." | Shows real staff data |
| Profile | Loads slowly | Loads real staff data |
| Attendance | Button-based | Toggle-based (On/Off) |
| Check-in | No GPS | GPS captured |
| Check-out | Not available | Available with GPS |
| Session | Lost on restart | Persists across restarts |
| Logout | Clears session | Clears session + shows login |

---

## Performance Notes

- Dashboard loads staff data in ~1-2 seconds
- Profile screen loads in ~1-2 seconds
- Attendance toggle responds immediately
- GPS capture takes ~3-5 seconds (depends on device)
- Firestore writes are real-time

---

## Next Steps

1. Test all features listed above
2. Verify Firestore data is being saved correctly
3. Test on different devices if available
4. Check GPS accuracy in different locations
5. Monitor Firestore usage and optimize if needed

---

## Support

If you encounter any issues:
1. Check the troubleshooting section above
2. Verify Firestore collections and data
3. Check Firebase Auth configuration
4. Ensure GPS permissions are granted
5. Check network connectivity

