# GPS & Attendance Quick Start Guide

## What's New

✓ Real Firestore data integration (no more demo data)
✓ GPS location capture on check-in
✓ Attendance recording with coordinates
✓ Real-time dashboard updates
✓ Admin attendance tracking

## Quick Setup

### 1. Update Firestore Staff Collection

Add these fields to each staff document:

```
photoUrl: "https://example.com/photo.jpg" (optional)
status: "on-duty" or "off-duty"
lastCheckIn: null (will be updated on first check-in)
lastCheckInLatitude: null
lastCheckInLongitude: null
```

### 2. Grant Location Permissions

The app will request GPS permission on first check-in.

**Android**: Already configured in AndroidManifest.xml
**iOS**: Already configured in Info.plist

### 3. Test the Feature

1. Login with credentials:
   - Email: `sibi@gmail.com`
   - Password: `BCDEFGHIJKLM`

2. Dashboard displays:
   - Real security name
   - Real gate assignment
   - Real shift timing
   - Attendance card with "I AM IN" button

3. Tap "I AM IN" button:
   - App requests GPS permission
   - Captures current location
   - Records check-in time
   - Shows success message

4. Verify in Firestore:
   - Go to `staffAttendance` collection
   - Find today's record
   - Check latitude/longitude are populated

## Dashboard Features

### Attendance Card
Shows:
- Check-in status (Checked In / Not Checked In)
- Check-in time (if checked in)
- GPS coordinates (if checked in)
- "I AM IN" button

### Real Data
- Security name from Firestore
- Gate assignment from Firestore
- Shift timing from Firestore
- Status from Firestore

## Firestore Collections

### Staff Collection
```
staff/
  {staffId}/
    name: "Rajesh Kumar"
    gate: "Main Gate A"
    shift: "Morning Shift (6:00 AM - 2:00 PM)"
    status: "on-duty"
    lastCheckIn: Timestamp
    lastCheckInLatitude: 28.6139
    lastCheckInLongitude: 77.2090
```

### Staff Attendance Collection
```
staffAttendance/
  {attendanceId}/
    staffId: "uid"
    staffName: "Rajesh Kumar"
    gateName: "Main Gate A"
    checkInTime: Timestamp
    latitude: 28.6139
    longitude: 77.2090
    status: "on-duty"
```

## Key Services

### LocationService
Handles GPS operations:
```dart
final locationService = LocationService();
final position = await locationService.getCurrentLocation();
```

### AttendanceService
Handles attendance recording:
```dart
final attendanceService = AttendanceService();
final result = await attendanceService.recordCheckIn(staff);
```

## Error Messages

| Error | Solution |
|-------|----------|
| "Unable to get location" | Enable GPS on device |
| "Permission denied" | Grant location permission in settings |
| "Failed to record check-in" | Check network connectivity |

## Admin Features

### View All Staff Attendance
```dart
final allAttendance = await attendanceService.getAllStaffAttendanceToday();
```

### Real-Time Updates
```dart
attendanceService.getAllStaffAttendanceTodayStream().listen((attendances) {
  // Update UI with real-time data
});
```

## Testing Checklist

- [ ] Login successful
- [ ] Dashboard shows real staff data
- [ ] "I AM IN" button visible
- [ ] GPS permission request appears
- [ ] Check-in records successfully
- [ ] Attendance record appears in Firestore
- [ ] Coordinates are populated
- [ ] Dashboard shows "Checked In" status
- [ ] Check-in time displays correctly

## Troubleshooting

### GPS Not Working
1. Enable GPS on device
2. Grant location permission
3. Check network connectivity
4. Restart app

### Data Not Showing
1. Verify staff document in Firestore
2. Check all required fields are populated
3. Verify Firestore security rules
4. Check network connectivity

### Check-In Not Recording
1. Verify GPS is enabled
2. Check network connectivity
3. Verify Firestore quota
4. Check Firestore security rules

## Next Steps

1. Test login and dashboard
2. Test GPS and check-in
3. Verify Firestore records
4. Implement check-out
5. Add map view
6. Implement geofencing
7. Add attendance reports

## Support

For issues:
1. Check error message
2. Verify Firestore data
3. Check network connectivity
4. Review logs in console
5. Restart app and try again
