# 🧪 Test Guide: Real-Time Billing Implementation

## Quick Test Steps

### 1. Run the App
```bash
cd resident_app
flutter run
```

### 2. Login as Resident
Use test credentials:
- Email: `resident@test.com` (or your test account)
- Password: Your test password

### 3. Navigate to Maintenance & Billing
- From dashboard, tap "Maintenance & Billing" card
- OR use bottom navigation

### 4. Verify Loading State
- Should see CircularProgressIndicator briefly
- Blue spinner while fetching data

### 5. Verify Data Display

#### If Bills Exist:
- ✅ Current pending bill shows in orange gradient card
- ✅ Amount displays correctly (₹XXX)
- ✅ Due date shows
- ✅ "Pay Now" button visible
- ✅ Bill breakdown shows itemized charges
- ✅ Payment history shows paid bills

#### If No Bills:
- ✅ "No Pending Bills" card shows
- ✅ Checkmark icon visible
- ✅ "You're all caught up!" message

### 6. Test Real-Time Updates

#### Create New Bill (Admin):
1. Open Firebase Console
2. Go to Firestore Database
3. Navigate to `bills` collection
4. Click "Add document"
5. Add fields:
   ```
   residentId: "your-resident-id"
   flatId: "t202" (or your flat)
   amount: 1500
   status: "pending"
   month: "March"
   year: "2024"
   dueDate: [timestamp]
   createdAt: [timestamp]
   ```
6. Save document

#### Verify in App:
- ✅ New bill appears INSTANTLY (no refresh needed)
- ✅ Amount updates
- ✅ UI refreshes automatically

### 7. Test Payment Flow

1. Tap "Pay Now" button
2. Select payment method (UPI/Card/Net Banking)
3. Confirm payment
4. ✅ Success message shows
5. ✅ Bill status updates to "Paid" instantly
6. ✅ Bill moves to payment history
7. ✅ "No Pending Bills" card shows

### 8. Test Error Handling

#### Simulate Network Error:
1. Turn off WiFi/Mobile data
2. Open Maintenance & Billing screen
3. ✅ Error state shows with error icon
4. ✅ Error message displays

#### Simulate No User Data:
1. Logout
2. Try to access billing screen
3. ✅ Should redirect to login OR show empty state

## Expected Console Output

### On Screen Load:
```
🔍 BillService: Fetching flat for user: [uid]
✅ BillService: Found flat ID: t202 (cached)
📡 Streaming bills with identifiers
📡 Streamed 2 bills
```

### On Bill Match:
```
📋 BillService: Fetching pending bill with identifiers:
   flatId: t202
   residentId: RES001
   residentName: John Doe
   ✓ Matched by flatId: t202
✅ BillService: Found current bill (cached)
   Amount: 850
   Month: March
```

### On Payment:
```
✅ Bill paid successfully: [bill-id] (cache cleared)
```

## Firestore Data Structure

### User Document (users/{uid}):
```json
{
  "uid": "firebase-auth-uid",
  "email": "resident@test.com",
  "name": "John Doe",
  "flatId": "t202",
  "flatLabel": "t202",
  "residentId": "RES001",
  "role": "resident"
}
```

### Bill Document (bills/{billId}):
```json
{
  "residentId": "RES001",
  "flatId": "t202",
  "flatLabel": "T-202",
  "residentName": "John Doe",
  "amount": 850,
  "status": "pending",
  "month": "March",
  "year": "2024",
  "dueDate": "2024-03-31T00:00:00Z",
  "createdAt": "2024-03-01T10:00:00Z",
  "chargeBreakdown": {
    "Maintenance": 500,
    "Water": 150,
    "Parking": 100,
    "Security": 100
  }
}
```

## Troubleshooting

### Bills Not Showing?

1. **Check Firebase Auth:**
   ```dart
   print(FirebaseAuth.instance.currentUser?.uid);
   ```
   - Should print user UID

2. **Check User Document:**
   - Open Firebase Console → Firestore
   - Navigate to `users/{uid}`
   - Verify `flatId` or `flatLabel` exists

3. **Check Bills Collection:**
   - Navigate to `bills` collection
   - Verify bills exist with matching `flatId` or `residentId`

4. **Check Console Logs:**
   - Look for "BillService" logs
   - Check for error messages

### Real-Time Not Working?

1. **Check Firestore Rules:**
   ```javascript
   match /bills/{billId} {
     allow read: if request.auth != null;
   }
   ```

2. **Check Network:**
   - Ensure device has internet connection
   - Check Firebase Console for connection status

3. **Restart App:**
   - Hot restart may be needed for stream initialization

## Success Criteria

- ✅ Loading state shows on initial load
- ✅ Bills display for logged-in user only
- ✅ Real-time updates work (no manual refresh)
- ✅ Empty state shows when no bills
- ✅ Error state shows on network failure
- ✅ Payment flow works end-to-end
- ✅ No demo data visible
- ✅ Console logs show proper data flow

## Performance Metrics

- Initial load: < 2 seconds
- Real-time update: < 500ms
- Payment processing: < 1 second
- Cache hit: < 100ms

---

**Status**: Ready for Testing ✓
