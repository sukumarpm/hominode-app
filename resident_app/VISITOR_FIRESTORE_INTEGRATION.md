# Visitor Firestore Integration - Complete

## ✅ Implementation Complete

Visitor management now saves expected visitor details to Firestore when the add button is clicked.

---

## 📁 Files Created/Updated

### 1. Visitor Firestore Service
**File:** `lib/src/services/visitor_firestore_service.dart`

Complete visitor management service with:
- Add expected visitor to Firestore
- Get all visitors for current user
- Get expected visitors
- Stream visitors (real-time updates)
- Update visitor status
- Approve visitor
- Mark visitor as arrived
- Delete/Cancel visitor

### 2. Updated Add Visitor Modal
**File:** `lib/add_expected_visitor_modal.dart`

Enhanced with:
- Firestore integration
- Loading states
- Error handling
- Success/error feedback
- Phone number field (optional)
- Vehicle number field (optional)

---

## 🔥 Firestore Structure

### Collection: `visitors`

```
visitors/
  └── {visitorId}/  ← Auto-generated document ID
      ├── hostUserId: string (Firebase Auth UID of resident)
      ├── hostName: string
      ├── hostEmail: string
      ├── visitorName: string
      ├── purpose: string
      ├── expectedArrival: timestamp
      ├── phoneNumber: string | null
      ├── vehicleNumber: string | null
      ├── status: "expected" | "arrived" | "departed" | "cancelled"
      ├── isApproved: boolean
      ├── approvedBy: string | null
      ├── approvedAt: timestamp | null
      ├── actualArrival: timestamp | null
      ├── departure: timestamp | null
      ├── createdAt: timestamp (server timestamp)
      └── updatedAt: timestamp (server timestamp)
```

### Example Document

```json
{
  "hostUserId": "abc123xyz789",
  "hostName": "John Doe",
  "hostEmail": "john@example.com",
  "visitorName": "Amit Kumar",
  "purpose": "Personal visit",
  "expectedArrival": "2026-02-16T14:30:00Z",
  "phoneNumber": "+91 98765 43210",
  "vehicleNumber": "MH 01 AB 1234",
  "status": "expected",
  "isApproved": false,
  "approvedBy": null,
  "approvedAt": null,
  "actualArrival": null,
  "departure": null,
  "createdAt": "2026-02-15T10:30:00Z",
  "updatedAt": "2026-02-15T10:30:00Z"
}
```

---

## 🚀 How It Works

### Step-by-Step Flow

1. **User clicks FAB (+) button** on Visitor Management screen
2. **Modal opens** with form fields
3. **User fills in details:**
   - Visitor Name (required)
   - Purpose (required)
   - Date (required)
   - Time (required)
   - Phone Number (optional)
   - Vehicle Number (optional)
4. **User clicks "Add Visitor"**
5. **Service validates** user is logged in
6. **Data is saved** to Firestore `visitors` collection
7. **Success message** is shown
8. **Modal closes**
9. **Visitor list** updates automatically (if using stream)

---

## 📝 Usage Examples

### Add Expected Visitor

```dart
import 'src/services/visitor_firestore_service.dart';

final visitorService = VisitorFirestoreService();

// Add visitor
final result = await visitorService.addExpectedVisitor(
  visitorName: 'Amit Kumar',
  purpose: 'Personal visit',
  expectedDate: DateTime(2026, 2, 16),
  expectedTime: DateTime(2000, 1, 1, 14, 30), // 2:30 PM
  phoneNumber: '+91 98765 43210',
  vehicleNumber: 'MH 01 AB 1234',
);

if (result.success) {
  print('Visitor added: ${result.visitorId}');
} else {
  print('Error: ${result.message}');
}
```

### Get All Visitors

```dart
// Get all visitors for current user
final visitors = await visitorService.getMyVisitors();
print('Total visitors: ${visitors.length}');

// Get only expected visitors
final expectedVisitors = await visitorService.getExpectedVisitors();
print('Expected visitors: ${expectedVisitors.length}');
```

### Stream Visitors (Real-time)

```dart
// Listen to visitor updates in real-time
visitorService.streamMyVisitors().listen((visitors) {
  print('Visitors updated: ${visitors.length}');
  // Update UI with new data
});
```

### Update Visitor Status

```dart
// Approve visitor
await visitorService.approveVisitor('visitor123');

// Mark as arrived
await visitorService.markVisitorArrived('visitor123');

// Update status
await visitorService.updateVisitorStatus(
  visitorId: 'visitor123',
  status: 'departed',
);
```

### Delete Visitor

```dart
// Cancel/Delete visitor
await visitorService.deleteVisitor('visitor123');
```

---

## 🔒 Security Rules

### Development Rules (Testing)

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /{document=**} {
      allow read, write: if true;
    }
  }
}
```

### Production Rules (Secure)

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Visitors collection
    match /visitors/{visitorId} {
      // Users can read their own visitors
      allow read: if request.auth != null 
                  && request.auth.uid == resource.data.hostUserId;
      
      // Users can create visitors for themselves
      allow create: if request.auth != null 
                    && request.auth.uid == request.resource.data.hostUserId;
      
      // Users can update their own visitors
      allow update: if request.auth != null 
                    && request.auth.uid == resource.data.hostUserId;
      
      // Users can delete their own visitors
      allow delete: if request.auth != null 
                    && request.auth.uid == resource.data.hostUserId;
    }
  }
}
```

---

## 🎨 UI Features

### Add Visitor Modal

- ✅ Clean, modern design
- ✅ Form validation
- ✅ Date picker
- ✅ Time picker
- ✅ Loading state with spinner
- ✅ Success/error feedback
- ✅ Optional fields (phone, vehicle)
- ✅ Disabled state when loading
- ✅ Auto-close on success

---

## 🐛 Error Handling

All errors are caught and converted to user-friendly messages:

| Error Code | User Message |
|------------|--------------|
| `not-authenticated` | No user is currently signed in |
| `permission-denied` | Permission denied. Please check your access rights. |
| `unavailable` | Service temporarily unavailable. Please try again. |
| `not-found` | Visitor not found. |

---

## 🧪 Testing

### Test Adding Visitor

1. **Run the app**
2. **Navigate to Visitor Management screen**
3. **Click FAB (+) button**
4. **Fill in the form:**
   - Name: Test Visitor
   - Purpose: Testing
   - Date: Tomorrow
   - Time: 2:00 PM
   - Phone: 9876543210 (optional)
   - Vehicle: MH 01 AB 1234 (optional)
5. **Click "Add Visitor"**
6. **Check terminal for logs:**
   ```
   🔵 Adding expected visitor...
   👤 Visitor Name: Test Visitor
   📝 Purpose: Testing
   ✅ Visitor added successfully!
   🆔 Visitor ID: abc123...
   ```
7. **Verify in Firebase Console:**
   - Firestore → visitors collection
   - Document should exist with all data

### Test Error Handling

1. **Disable internet**
2. **Try adding visitor**
3. **Should show error message**
4. **Re-enable internet**
5. **Try again - should work**

---

## 📊 Debug Logging

The service includes comprehensive logging:

```
🔵 Adding expected visitor...
👤 Visitor Name: Amit Kumar
📝 Purpose: Personal visit
📅 Expected Date: 2026-02-16
⏰ Expected Time: 14:30
🆔 User ID: abc123xyz789
📦 Visitor data: {...}
✅ Visitor added successfully!
🆔 Visitor ID: xyz789abc123
```

---

## 🔧 Integration with Visitor Screen

### Update Visitor Management Screen

To show real-time visitors from Firestore:

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'src/services/visitor_firestore_service.dart';

class _VisitorManagementScreenNewState extends State<VisitorManagementScreenNew> {
  final _visitorService = VisitorFirestoreService();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _visitorService.streamMyVisitors(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final visitors = snapshot.data ?? [];

        return ListView.builder(
          itemCount: visitors.length,
          itemBuilder: (context, index) {
            final visitor = visitors[index];
            return _buildVisitorCard(visitor);
          },
        );
      },
    );
  }
}
```

---

## ✅ Checklist

Before testing:

- [ ] Firebase project is set up
- [ ] Firestore is enabled
- [ ] Security rules are set (test mode for dev)
- [ ] User is logged in
- [ ] Internet connection is working
- [ ] `visitor_firestore_service.dart` is imported
- [ ] Modal has been updated

After adding visitor:

- [ ] Success message appears
- [ ] Modal closes
- [ ] Terminal shows success logs
- [ ] Firebase Console shows visitor document
- [ ] All fields are saved correctly
- [ ] Timestamps are set

---

## 🚀 Next Steps

### Recommended Enhancements

1. **Display Visitors from Firestore**
   - Replace mock data with real Firestore data
   - Use StreamBuilder for real-time updates

2. **Add Visitor Approval Flow**
   - Security guard can approve/reject
   - Send notifications to resident

3. **Generate QR Code**
   - Create unique QR code for approved visitors
   - Store QR code data in Firestore

4. **Add Visitor Check-in/Check-out**
   - Mark actual arrival time
   - Mark departure time
   - Track visitor duration

5. **Add Visitor History**
   - Show past visitors
   - Filter by date range
   - Export visitor logs

6. **Add Notifications**
   - Notify when visitor arrives
   - Notify when visitor is approved
   - Remind about expected visitors

---

## 📞 Troubleshooting

### Issue: Visitor not saving

**Check:**
1. User is logged in (`FirebaseAuth.instance.currentUser != null`)
2. Firestore security rules allow writes
3. Internet connection is working
4. Check terminal for error logs

**Solution:**
- Set security rules to test mode
- Verify user authentication
- Check Firebase Console for errors

### Issue: "permission-denied" error

**Solution:**
Update Firestore security rules to allow writes (see Security Rules section above)

### Issue: No success message

**Check:**
- Modal is properly closing
- ScaffoldMessenger context is valid
- Check terminal for errors

---

## 🎉 Summary

You now have a complete visitor management system with:

- ✅ Add expected visitor to Firestore
- ✅ Save all visitor details
- ✅ Loading states
- ✅ Error handling
- ✅ Success feedback
- ✅ Optional fields (phone, vehicle)
- ✅ Real-time updates capability
- ✅ Comprehensive logging
- ✅ Security rules

**Ready to use in your Resident App!**

---

## 📸 Expected Result

After clicking "Add Visitor":

1. **Terminal Output:**
   ```
   🔵 Adding expected visitor...
   ✅ Visitor added successfully!
   ```

2. **Firebase Console:**
   - Navigate to Firestore Database
   - See "visitors" collection
   - See new document with visitor data

3. **App UI:**
   - Success message appears
   - Modal closes
   - Visitor appears in list (if using real-time updates)
