# Attendance & GPS Implementation Guide

## Overview
Complete implementation of GPS-based attendance tracking with real Firestore data integration.

## Features Implemented

### 1. Real Data Fetching from Firestore
- Fetches security staff data from `staff` collection
- Displays real name, gate assignment, and shift timing
- Removes all demo/static data
- Real-time updates from Firestore

### 2. GPS Location Capture
- Captures current GPS coordinates on check-in
- Requests location permissions
- Handles location service errors gracefully
- Stores latitude and longitude with attendance

### 3. Attendance Recording
- "I AM IN" button on dashboard
- Records check-in time with GPS location
- Updates staff document with check-in info
- Creates attendance record in Firestore

### 4. Firestore Collections

#### Staff Collection (Updated)
```
staff/
  {staffId}/
    uid: "firebase-uid"
    name: "Rajesh Kumar"
    phone: "+91 98765 43210"
    gate: "Main Gate A"
    shift: "Morning Shift (6:00 AM - 2:00 PM)"
    photoUrl: "url-to-photo"
    status: "on-duty"
    lastCheckIn: Timestamp
    lastCheckInLatitude: 28.6139
    lastCheckInLongitude: 77.2090
    lastCheckOut: Timestamp
    lastCheckOutLatitude: 28.6139
    lastCheckOutLongitude: 77.2090
```

#### Staff Attendance Collection (New)
```
staffAttendance/
  {attendanceId}/
    staffId: "uid"
    staffName: "Rajesh Kumar"
    gateName: "Main Gate A"
    checkInTime: Timestamp
    checkOutTime: Timestamp (optional)
    latitude: 28.6139
    longitude: 77.2090
    checkOutLatitude: 28.6139 (optional)
    checkOutLongitude: 77.2090 (optional)
    status: "on-duty" or "off-duty"
    photoUrl: "url-to-photo"
    createdAt: Timestamp
```

## New Services

### LocationService (`lib/services/location_service.dart`)
Handles all GPS-related operations:

**Methods:**
- `requestLocationPermission()` - Request GPS permissions
- `getCurrentLocation()` - Get current GPS coordinates
- `getLocationWithTimeout()` - Get location with timeout
- `isLocationServiceEnabled()` - Check if GPS is enabled
- `getDistance()` - Calculate distance between coordinates

**Usage:**
```dart
final locationService = LocationService();
final position = await locationService.getCurrentLocation();
if (position != null) {
  print('Latitude: ${position.latitude}');
  print('Longitude: ${position.longitude}');
}
```

### AttendanceService (`lib/services/attendance_service.dart`)
Handles attendance recording and retrieval:

**Methods:**
- `recordCheckIn(staff)` - Record check-in with GPS
- `recordCheckOut(staff, attendanceId)` - Record check-out with GPS
- `getTodayAttendance(staffId)` - Get today's attendance
- `getAttendanceHistory(staffId)` - Get attendance history
- `getTodayAttendanceStream(staffId)` - Real-time attendance stream
- `getAllStaffAttendanceToday()` - Get all staff attendance (admin)
- `getAllStaffAttendanceTodayStream()` - Real-time all staff attendance (admin)

**Usage:**
```dart
final attendanceService = AttendanceService();
final result = await attendanceService.recordCheckIn(currentUser);
if (result['success']) {
  print('Check-in recorded at ${result['latitude']}, ${result['longitude']}');
}
```

## Models

### AttendanceModel (`lib/models/attendance_model.dart`)
Represents an attendance record:

```dart
class AttendanceModel {
  final String id;
  final String staffId;
  final String staffName;
  final String gateName;
  final DateTime checkInTime;
  final DateTime? checkOutTime;
  final double latitude;
  final double longitude;
  final String status;
  final String? photoUrl;
}
```

## Dashboard Updates

### Attendance Card
New card on dashboard showing:
- Today's attendance status (Checked In / Not Checked In)
- Check-in time
- GPS coordinates
- "I AM IN" button for check-in

### Real Data Display
- Security name from Firestore
- Assigned gate from Firestore
- Shift timing from Firestore
- All data updates in real-time

## Dependencies Added

```yaml
# Location & GPS
geolocator: ^11.0.0
google_maps_flutter: ^2.5.3
```

## Android Configuration

Add to `android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_BACKGROUND_LOCATION" />
```

Add to `android/app/build.gradle`:

```gradle
android {
    compileSdkVersion 34
    
    defaultConfig {
        minSdkVersion 21
    }
}
```

## iOS Configuration

Add to `ios/Runner/Info.plist`:

```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>This app needs your location to record attendance</string>
<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>This app needs your location to record attendance</string>
```

## Usage Flow

### Check-In Process
1. User taps "I AM IN" button
2. App requests GPS permission (if not granted)
3. App captures current GPS coordinates
4. App records check-in time
5. App creates attendance record in Firestore
6. App updates staff document with check-in info
7. Dashboard shows "Checked In" status

### Data Flow
```
User taps "I AM IN"
    ↓
LocationService.getCurrentLocation()
    ↓
Request GPS permission
    ↓
Capture coordinates
    ↓
AttendanceService.recordCheckIn()
    ↓
Create staffAttendance document
    ↓
Update staff document
    ↓
Return success with coordinates
    ↓
Dashboard updates with check-in info
```

## Firestore Security Rules

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Staff collection
    match /staff/{staffId} {
      allow read: if request.auth != null;
      allow write: if request.auth.uid == staffId;
    }
    
    // Attendance collection
    match /staffAttendance/{attendanceId} {
      allow read: if request.auth != null;
      allow create: if request.auth != null;
      allow update: if request.auth.uid == resource.data.staffId;
    }
  }
}
```

## Testing

### Test Credentials
```
Email: sibi@gmail.com
Password: BCDEFGHIJKLM
```

### Test Steps
1. Login with test credentials
2. Dashboard displays real staff data
3. Tap "I AM IN" button
4. Grant GPS permission when prompted
5. Check-in recorded with GPS coordinates
6. Dashboard shows "Checked In" status
7. Check Firestore for attendance record

### Verify in Firestore
1. Go to `staffAttendance` collection
2. Find today's record for the staff member
3. Verify:
   - `checkInTime` is current time
   - `latitude` and `longitude` are populated
   - `status` is "on-duty"
   - `staffName` matches logged-in user

## Admin Tracking

### View All Staff Attendance
```dart
final attendanceService = AttendanceService();
final allAttendance = await attendanceService.getAllStaffAttendanceToday();

for (var attendance in allAttendance) {
  print('${attendance.staffName} checked in at ${attendance.checkInTime}');
  print('Location: ${attendance.latitude}, ${attendance.longitude}');
}
```

### Real-Time Updates
```dart
attendanceService.getAllStaffAttendanceTodayStream().listen((attendances) {
  // Update UI with real-time attendance data
  setState(() {
    allStaffAttendance = attendances;
  });
});
```

## Error Handling

### GPS Not Available
- Shows error message: "Unable to get location. Please enable GPS."
- User can enable GPS and retry

### Permission Denied
- App requests permission
- If permanently denied, opens location settings
- User can grant permission and retry

### Network Error
- Shows error message with details
- User can retry

## Performance Considerations

1. **Location Accuracy**: Uses `LocationAccuracy.high` for precise coordinates
2. **Timeout**: 10-second timeout for location capture
3. **Caching**: Attendance data cached locally
4. **Real-time**: Uses Firestore streams for real-time updates

## Future Enhancements

1. **Check-Out**: Add check-out functionality with GPS
2. **Geofencing**: Verify check-in within gate boundaries
3. **Photo Capture**: Capture photo during check-in
4. **Offline Support**: Cache attendance data offline
5. **Map View**: Display staff locations on map
6. **Attendance Reports**: Generate attendance reports
7. **Notifications**: Send notifications on check-in/out
8. **Analytics**: Track attendance patterns

## Troubleshooting

### GPS Not Working
1. Verify location permissions are granted
2. Check if GPS is enabled on device
3. Ensure app has location permission in settings
4. Try again after enabling GPS

### Attendance Not Saving
1. Check network connectivity
2. Verify Firestore security rules
3. Check Firestore quota
4. Verify staff document exists in Firestore

### Real Data Not Displaying
1. Verify staff document exists in Firestore
2. Check all required fields are populated
3. Verify Firestore security rules allow read access
4. Check network connectivity

## Files Created/Modified

### New Files
- `lib/models/attendance_model.dart`
- `lib/services/location_service.dart`
- `lib/services/attendance_service.dart`

### Modified Files
- `pubspec.yaml` - Added geolocator and google_maps_flutter
- `lib/models/security_user_model.dart` - Added photoUrl and status
- `lib/screens/security_dashboard_screen.dart` - Added attendance card and check-in button

## Verification

All files compile without errors:
```
✓ lib/models/attendance_model.dart
✓ lib/services/location_service.dart
✓ lib/services/attendance_service.dart
✓ lib/models/security_user_model.dart
✓ lib/screens/security_dashboard_screen.dart
```

## Next Steps

1. Test login and dashboard
2. Test GPS permission request
3. Test check-in functionality
4. Verify attendance records in Firestore
5. Test real-time updates
6. Implement check-out functionality
7. Add map view for admin
8. Implement geofencing
