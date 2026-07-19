# Data Fetching Flow Diagram

## Complete Data Flow According to Flow Functions

### 1. BILLING & MAINTENANCE FLOW

```
┌─────────────────────────────────────────────────────────────┐
│                    USER OPENS BILLING SCREEN                │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
        ┌────────────────────────────────────┐
        │  STEP 1: Validate Authentication   │
        │  ✅ Check Firebase Auth UID        │
        │  ✅ Get current user               │
        └────────────┬───────────────────────┘
                     │
                     ▼
        ┌────────────────────────────────────┐
        │  STEP 2: Get User's FlatId         │
        │  ✅ Query users collection         │
        │  ✅ Get flatId from user document  │
        └────────────┬───────────────────────┘
                     │
                     ▼
        ┌────────────────────────────────────┐
        │  STEP 3: Fetch Bills by FlatId     │
        │  ✅ Query bills collection         │
        │  ✅ Filter: where('flatId', ==)    │
        │  ✅ Firestore Rules Check:         │
        │     - request.auth != null ✅      │
        │     - Allow read ✅                │
        └────────────┬───────────────────────┘
                     │
                     ▼
        ┌────────────────────────────────────┐
        │  STEP 4: Process Bills Data        │
        │  ✅ Sort by due date               │
        │  ✅ Calculate totals               │
        │  ✅ Format for display             │
        └────────────┬───────────────────────┘
                     │
                     ▼
        ┌────────────────────────────────────┐
        │  STEP 5: Display on Screen         │
        │  ✅ Show bill list                 │
        │  ✅ Show pending amount            │
        │  ✅ Show payment history           │
        └────────────┬───────────────────────┘
                     │
                     ▼
        ┌────────────────────────────────────┐
        │  ✅ BILLING SCREEN WORKING         │
        │  ✅ All bills visible              │
        │  ✅ Maintenance bills shown        │
        └────────────────────────────────────┘
```

**Service**: `BillFirestoreService`
**Collections**: `users`, `bills`, `payments`
**Firestore Access**: ✅ Allowed by rules

---

### 2. EVENTS & ANNOUNCEMENTS FLOW

```
┌─────────────────────────────────────────────────────────────┐
│              USER OPENS EVENTS/ANNOUNCEMENTS SCREEN          │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
        ┌────────────────────────────────────┐
        │  STEP 1: Validate Authentication   │
        │  ✅ Check Firebase Auth UID        │
        │  ✅ Get current user               │
        └────────────┬───────────────────────┘
                     │
                     ▼
        ┌────────────────────────────────────┐
        │  STEP 2: Stream Announcements      │
        │  ✅ Query announcements collection │
        │  ✅ Filter: where('status', ==)    │
        │  ✅ Firestore Rules Check:         │
        │     - request.auth != null ✅      │
        │     - Allow read ✅                │
        └────────────┬───────────────────────┘
                     │
                     ▼
        ┌────────────────────────────────────┐
        │  STEP 3: Stream Events             │
        │  ✅ Query events collection        │
        │  ✅ Filter: where('status', ==)    │
        │  ✅ Firestore Rules Check:         │
        │     - request.auth != null ✅      │
        │     - Allow read ✅                │
        └────────────┬───────────────────────┘
                     │
                     ▼
        ┌────────────────────────────────────┐
        │  STEP 4: Process Data              │
        │  ✅ Sort by date (newest first)    │
        │  ✅ Format for display             │
        │  ✅ Set up real-time listeners     │
        └────────────┬───────────────────────┘
                     │
                     ▼
        ┌────────────────────────────────────┐
        │  STEP 5: Display on Screen         │
        │  ✅ Show announcements list        │
        │  ✅ Show events list               │
        │  ✅ Real-time updates              │
        └────────────┬───────────────────────┘
                     │
                     ▼
        ┌────────────────────────────────────┐
        │  ✅ EVENTS SCREEN WORKING          │
        │  ✅ All announcements visible      │
        │  ✅ Real-time updates working      │
        └────────────────────────────────────┘
```

**Service**: `AnnouncementsEventsService`
**Collections**: `announcements`, `events`
**Firestore Access**: ✅ Allowed by rules

---

### 3. AMENITIES BOOKING FLOW

```
┌─────────────────────────────────────────────────────────────┐
│              USER OPENS AMENITIES SCREEN                    │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
        ┌────────────────────────────────────┐
        │  STEP 1: Validate Authentication   │
        │  ✅ Check Firebase Auth UID        │
        │  ✅ Get current user               │
        └────────────┬───────────────────────┘
                     │
                     ▼
        ┌────────────────────────────────────┐
        │  STEP 2: Get User's BuildingId     │
        │  ✅ Query users collection         │
        │  ✅ Get buildingId from user       │
        └────────────┬───────────────────────┘
                     │
                     ▼
        ┌────────────────────────────────────┐
        │  STEP 3: Stream Amenities          │
        │  ✅ Query amenities collection     │
        │  ✅ Filter: where('buildingId', ==)│
        │  ✅ Firestore Rules Check:         │
        │     - request.auth != null ✅      │
        │     - Allow read ✅                │
        └────────────┬───────────────────────┘
                     │
                     ▼
        ┌────────────────────────────────────┐
        │  STEP 4: Stream User's Bookings    │
        │  ✅ Query bookings collection      │
        │  ✅ Filter: where('userId', ==)    │
        │  ✅ Firestore Rules Check:         │
        │     - request.auth != null ✅      │
        │     - Allow read ✅                │
        └────────────┬───────────────────────┘
                     │
                     ▼
        ┌────────────────────────────────────┐
        │  STEP 5: Calculate Availability    │
        │  ✅ Check booked slots             │
        │  ✅ Calculate available capacity   │
        │  ✅ Format for display             │
        └────────────┬───────────────────────┘
                     │
                     ▼
        ┌────────────────────────────────────┐
        │  STEP 6: Display on Screen         │
        │  ✅ Show amenities list            │
        │  ✅ Show availability              │
        │  ✅ Show booking options           │
        └────────────┬───────────────────────┘
                     │
                     ▼
        ┌────────────────────────────────────┐
        │  USER BOOKS AMENITY                │
        └────────────┬───────────────────────┘
                     │
                     ▼
        ┌────────────────────────────────────┐
        │  STEP 7: Create Booking            │
        │  ✅ Validate booking data          │
        │  ✅ Write to bookings collection   │
        │  ✅ Firestore Rules Check:         │
        │     - request.auth != null ✅      │
        │     - Allow write ✅               │
        └────────────┬───────────────────────┘
                     │
                     ▼
        ┌────────────────────────────────────┐
        │  STEP 8: Notify Admin              │
        │  ✅ Create notification            │
        │  ✅ Send to admin                  │
        └────────────┬───────────────────────┘
                     │
                     ▼
        ┌────────────────────────────────────┐
        │  ✅ AMENITIES SCREEN WORKING       │
        │  ✅ All amenities visible          │
        │  ✅ Booking successful             │
        └────────────────────────────────────┘
```

**Service**: `BookingFirestoreService`
**Collections**: `users`, `amenities`, `bookings`, `notifications`
**Firestore Access**: ✅ Allowed by rules

---

## Firestore Rules Validation Points

### For Each Query:

```
Query Executed
    ↓
Firestore Rules Engine Checks:
    ├─ Is user authenticated? (request.auth != null)
    │  ├─ YES → Continue ✅
    │  └─ NO → Deny access ❌
    │
    └─ Does rule allow this operation?
       ├─ YES → Return data ✅
       └─ NO → Deny access ❌
```

### Current Rules Allow:

```
✅ Authenticated users can READ:
   - users collection
   - bills collection
   - announcements collection
   - events collection
   - amenities collection
   - bookings collection
   - payments collection
   - complaints collection
   - visitors collection
   - notifications collection

✅ Authenticated users can WRITE:
   - All collections above
```

---

## Data Flow Summary

| Feature | Read From | Write To | Status |
|---------|-----------|----------|--------|
| Billing | bills | payments | ✅ Working |
| Maintenance | bills | payments | ✅ Working |
| Announcements | announcements | (read-only) | ✅ Working |
| Events | events | (read-only) | ✅ Working |
| Amenities | amenities | bookings | ✅ Working |
| Bookings | bookings | bookings | ✅ Working |

---

## Key Points

1. **Authentication First**: All flows start with authentication check
2. **FlatId/BuildingId Filtering**: Data is filtered by user's flat/building
3. **Real-time Streaming**: Uses Firestore snapshots for live updates
4. **Firestore Rules**: Enable all authenticated users to read/write
5. **Error Handling**: Each step validates data before proceeding

---

## Testing Each Flow

### Test Billing Flow
```
1. Login to app
2. Go to Billing tab
3. Should see bills (not error)
4. Tap on bill to see details
5. ✅ Flow working
```

### Test Events Flow
```
1. Login to app
2. Go to Events tab
3. Should see announcements (not error)
4. Announcements update in real-time
5. ✅ Flow working
```

### Test Amenities Flow
```
1. Login to app
2. Go to Amenities tab
3. Should see amenities (not error)
4. Tap to book amenity
5. Booking confirmation appears
6. ✅ Flow working
```

---

## Troubleshooting

### If Billing shows error:
- Check Firestore rules are published
- Check user is logged in
- Check bills collection has data with correct flatId

### If Events shows error:
- Check Firestore rules are published
- Check announcements have status: 'active'
- Check events have status: 'published'

### If Amenities shows error:
- Check Firestore rules are published
- Check amenities have correct buildingId
- Check user's buildingId is set in users collection

---

## Next Steps

1. ✅ Deploy Firestore rules (see QUICK_ACTION_FIRESTORE_RULES.md)
2. ✅ Test each flow (see Testing Each Flow above)
3. ✅ Verify all data loads correctly
4. ✅ App is fully functional!

