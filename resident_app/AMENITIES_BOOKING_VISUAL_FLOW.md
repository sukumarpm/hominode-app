# Amenities Booking - Visual Flow Diagram

## Complete Booking Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                    USER OPENS BOOKING MODAL                      │
└────────────────────────────┬────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│              STEP 1: LOAD AMENITY DETAILS                        │
│  - Fetch amenity from Firestore                                 │
│  - Parse timeSlots: List<String>.from(data['timeSlots'])        │
│  - Get maxCapacity, allowMultipleBookings, packages             │
└────────────────────────────┬────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│              STEP 2: USER SELECTS DATE                           │
│  - Calendar picker shows available dates                        │
│  - Blocked dates are grayed out                                 │
└────────────────────────────┬────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│              STEP 3: APPLY RULE 1 - FILTER PAST SLOTS           │
│                                                                  │
│  IF date is TODAY:                                              │
│    ├─ Get current time (fresh)                                 │
│    ├─ For each slot:                                           │
│    │  ├─ Parse slot start time                                │
│    │  ├─ Compare with current time                            │
│    │  └─ If start time <= current time: HIDE                  │
│    └─ Return filtered slots                                    │
│                                                                  │
│  IF date is FUTURE:                                             │
│    └─ Show all slots                                           │
│                                                                  │
│  IF date is PAST:                                               │
│    └─ Hide all slots                                           │
└────────────────────────────┬────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│              STEP 4: APPLY RULE 2 - CHECK CAPACITY              │
│                                                                  │
│  For each remaining slot:                                       │
│    ├─ Query bookings for this date + timeSlot                  │
│    ├─ Sum numberOfPeople from all bookings                     │
│    ├─ Calculate: remainingCapacity = maxCapacity - totalPeople │
│    │                                                             │
│    ├─ IF remainingCapacity <= 0:                               │
│    │  └─ Mark as "SLOT FULL" (DISABLED)                       │
│    │                                                             │
│    ├─ ELSE IF remainingCapacity >= numberOfPeople:            │
│    │  └─ Mark as "AVAILABLE" (ENABLED)                        │
│    │                                                             │
│    └─ ELSE:                                                     │
│       └─ Mark as "NOT ENOUGH CAPACITY" (DISABLED)             │
│                                                                  │
│  Return: availableSlots list                                    │
└────────────────────────────┬────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│              STEP 5: DISPLAY TIME SLOTS                          │
│                                                                  │
│  For each slot:                                                 │
│    ├─ IF AVAILABLE:                                            │
│    │  └─ Show: "9:00 AM - 10:00 AM"                           │
│    │           "2 / 4 spots booked"                            │
│    │           [Book Now] ← ENABLED                            │
│    │                                                             │
│    ├─ IF SLOT FULL:                                            │
│    │  └─ Show: "9:00 AM - 10:00 AM"                           │
│    │           "Slot Full"                                     │
│    │           [Book Now] ← DISABLED                           │
│    │                                                             │
│    └─ IF PAST (today only):                                    │
│       └─ HIDDEN from list                                      │
└────────────────────────────┬────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│              STEP 6: USER SELECTS TIME SLOT                      │
│  - Tap on available slot                                        │
│  - Slot is highlighted                                          │
└────────────────────────────┬────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│              STEP 7: USER CONFIRMS BOOKING                       │
│  - Tap "Confirm Booking" button                                 │
│  - Show loading spinner                                         │
└────────────────────────────┬────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│              STEP 8: VALIDATE SLOT STILL AVAILABLE              │
│  - Re-check slot availability (RULE 3)                          │
│  - If slot became full: REJECT with error                       │
│  - If slot available: PROCEED                                   │
└────────────────────────────┬────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│              STEP 9: CREATE BOOKING IN FIRESTORE                │
│  - Save booking document with:                                  │
│    ├─ userId, amenityId, date, timeSlot                        │
│    ├─ numberOfPeople, bookingType, status                      │
│    └─ createdAt timestamp                                       │
└────────────────────────────┬────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│              STEP 10: SHOW SUCCESS MESSAGE                       │
│  - Close modal                                                  │
│  - Show: "Amenity booked successfully!"                         │
│  - Booking appears in "My Bookings" section                     │
└─────────────────────────────────────────────────────────────────┘
```

---

## Type Casting Fix Flow

```
┌──────────────────────────────────────────────────────────────┐
│         FIRESTORE RETURNS DATA                               │
│  data['timeSlots'] = [                                       │
│    "6:00 AM - 7:00 AM",                                      │
│    "7:00 AM - 8:00 AM",                                      │
│    ...                                                        │
│  ]                                                            │
│  Type: List<dynamic>                                         │
└────────────────┬─────────────────────────────────────────────┘
                 │
                 ▼
        ┌────────────────────┐
        │ WRONG APPROACH     │
        │ ❌ FAILS           │
        │                    │
        │ as List<String>    │
        │                    │
        │ Error: type        │
        │ 'List<dynamic>'    │
        │ is not a subtype   │
        │ of 'List<String>'  │
        └────────────────────┘
                 
        ┌────────────────────┐
        │ CORRECT APPROACH   │
        │ ✅ WORKS           │
        │                    │
        │ List<String>.from( │
        │   data['timeSlots']│
        │   as List<dynamic> │
        │ )                  │
        │                    │
        │ Result:            │
        │ List<String>       │
        └────────────────────┘
                 │
                 ▼
┌──────────────────────────────────────────────────────────────┐
│         SAFELY CONVERTED TO List<String>                     │
│  [                                                            │
│    "6:00 AM - 7:00 AM",                                      │
│    "7:00 AM - 8:00 AM",                                      │
│    ...                                                        │
│  ]                                                            │
│  Type: List<String> ✅                                       │
└──────────────────────────────────────────────────────────────┘
```

---

## Capacity Calculation Flow

```
┌─────────────────────────────────────────────────────────────┐
│  AMENITY: Gym                                               │
│  maxCapacity: 4 people                                      │
│  Date: 2026-03-15                                           │
│  TimeSlot: 9:00 AM - 10:00 AM                              │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│  QUERY FIRESTORE                                            │
│  Collection: amenityBookings                                │
│  Where: amenityId = "gym_001"                              │
│  Where: date = "2026-03-15"                                │
│  Where: timeSlot = "9:00 AM - 10:00 AM"                    │
│  Where: status in ["confirmed", "pending"]                 │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│  RESULTS: 2 bookings found                                  │
│                                                              │
│  Booking 1: numberOfPeople = 2                             │
│  Booking 2: numberOfPeople = 1                             │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│  CALCULATE CAPACITY                                         │
│                                                              │
│  totalPeople = 2 + 1 = 3                                   │
│  remainingCapacity = 4 - 3 = 1                             │
│  requestedPeople = 1                                        │
│                                                              │
│  canBook = remainingCapacity >= requestedPeople            │
│  canBook = 1 >= 1 = TRUE ✅                                │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│  DISPLAY RESULT                                             │
│                                                              │
│  9:00 AM - 10:00 AM                                        │
│  3 / 4 spots booked                                        │
│  [Book Now] ← ENABLED ✅                                   │
└─────────────────────────────────────────────────────────────┘
```

---

## Real-Time Update Flow

```
┌──────────────────────────────────────────────────────────────┐
│  DEVICE A: User viewing booking modal                        │
│  Slot: 9:00 AM - 10:00 AM                                  │
│  Status: AVAILABLE (1 spot remaining)                       │
└────────────────────┬─────────────────────────────────────────┘
                     │
                     ▼
┌──────────────────────────────────────────────────────────────┐
│  DEVICE B: User books the last spot                          │
│  Creates booking with numberOfPeople = 1                    │
│  Saves to Firestore                                         │
└────────────────────┬─────────────────────────────────────────┘
                     │
                     ▼
┌──────────────────────────────────────────────────────────────┐
│  FIRESTORE LISTENER TRIGGERED                               │
│  Detects new booking for same slot                          │
│  Broadcasts update to all listeners                         │
└────────────────────┬─────────────────────────────────────────┘
                     │
                     ▼
┌──────────────────────────────────────────────────────────────┐
│  DEVICE A: Receives real-time update                         │
│  Re-calculates capacity:                                     │
│  totalPeople = 4 (was 3, now +1)                           │
│  remainingCapacity = 0                                      │
│  Status: SLOT FULL                                          │
└────────────────────┬─────────────────────────────────────────┘
                     │
                     ▼
┌──────────────────────────────────────────────────────────────┐
│  DEVICE A: UI Updates                                        │
│  Slot: 9:00 AM - 10:00 AM                                  │
│  Status: Slot Full                                          │
│  [Book Now] ← DISABLED ❌                                   │
└──────────────────────────────────────────────────────────────┘
```

---

## Error Handling Flow

```
┌─────────────────────────────────────────────────────────────┐
│  USER TRIES TO BOOK FULL SLOT                               │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│  VALIDATION CHECK                                           │
│  - Re-check slot availability                              │
│  - Query current bookings                                  │
│  - Calculate remaining capacity                            │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
        ┌────────────────────────────┐
        │ IS SLOT STILL AVAILABLE?   │
        └────────┬───────────┬───────┘
                 │           │
            YES │           │ NO
                 │           │
                 ▼           ▼
        ┌──────────────┐  ┌──────────────────┐
        │ CREATE       │  │ REJECT BOOKING   │
        │ BOOKING ✅   │  │ Show error:      │
        │              │  │ "Slot no longer  │
        │ Success msg  │  │  available"      │
        └──────────────┘  └──────────────────┘
```

---

## Time Slot Filtering Example

```
Current Time: 7:30 PM (19:30)
Selected Date: TODAY

Available Slots:
┌─────────────────────────────────────────┐
│ 6:00 AM - 7:00 AM    ❌ HIDE (past)    │
│ 7:00 AM - 8:00 AM    ❌ HIDE (past)    │
│ ...                                     │
│ 7:00 PM - 8:00 PM    ❌ HIDE (past)    │
│ 8:00 PM - 9:00 PM    ✅ SHOW           │
│ 9:00 PM - 10:00 PM   ✅ SHOW           │
│ 10:00 PM - 11:00 PM  ✅ SHOW           │
└─────────────────────────────────────────┘

Logic:
- 7:00 PM start time <= 7:30 PM current time → HIDE
- 8:00 PM start time > 7:30 PM current time → SHOW
```

---

## Booking Status Lifecycle

```
┌──────────────┐
│   PENDING    │  ← Initial state (optional)
└──────┬───────┘
       │
       ▼
┌──────────────┐
│  CONFIRMED   │  ← Booking is active
└──────┬───────┘
       │
       ├─────────────────┬──────────────────┐
       │                 │                  │
       ▼                 ▼                  ▼
┌──────────────┐  ┌──────────────┐  ┌──────────────┐
│  COMPLETED   │  │  CANCELLED   │  │   EXPIRED    │
│ (after date) │  │ (user cancel)│  │ (past date)  │
└──────────────┘  └──────────────┘  └──────────────┘
```
