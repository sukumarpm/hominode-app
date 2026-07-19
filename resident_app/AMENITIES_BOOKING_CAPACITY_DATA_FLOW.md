# Amenities Booking - Capacity Display Data Flow

## Complete Data Flow Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│ 1. MODAL OPENS                                                  │
│    BookingModal(amenity: Amenity)                               │
└────────────────────────┬────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│ 2. LOAD AMENITY DETAILS                                         │
│    _loadAmenityDetails()                                        │
│                                                                 │
│    BookingFirestoreService.getAmenityDetails(amenityId)        │
│    ↓                                                            │
│    Firestore: amenities/{amenityId}                            │
│    ↓                                                            │
│    Returns: AmenityModel {                                     │
│      id: "gym-1"                                               │
│      name: "Gym"                                               │
│      maxCapacity: 5  ← CRITICAL: Should be 5                   │
│      timeSlots: ["6:00 AM - 7:00 AM", ...]                    │
│      allowMultipleBookings: true                               │
│    }                                                            │
│                                                                 │
│    setState(() {                                               │
│      _amenityDetails = amenity;  ← Store capacity here         │
│      _timeSlots = amenity.timeSlots;                           │
│    });                                                          │
└────────────────────────┬────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│ 3. AUTO-SELECT TODAY & LOAD AVAILABILITY                        │
│    _selectedDate = DateTime.now()                               │
│    _loadSlotAvailability()                                      │
└────────────────────────┬────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│ 4. CALL FLOW FUNCTION                                           │
│    AmenitiesBookingFlowFunction.getAvailableSlots()            │
│                                                                 │
│    Parameters:                                                  │
│      amenityId: "gym-1"                                        │
│      selectedDate: DateTime.now()                              │
│      allTimeSlots: ["6:00 AM - 7:00 AM", ...]                 │
│      capacity: 5  ← From _amenityDetails.maxCapacity           │
│      numberOfPeople: 1                                         │
└────────────────────────┬────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│ 5. FLOW FUNCTION PROCESSING                                     │
│                                                                 │
│    STEP 1: Validate user authentication ✅                     │
│    STEP 2: Validate amenity exists ✅                          │
│    STEP 3: Apply RULE 1 - Hide past time slots ✅              │
│    STEP 4: Apply RULE 2 - Check capacity                       │
│                                                                 │
│    For each time slot:                                         │
│      Query: amenityBookings where:                             │
│        - amenityId = "gym-1"                                   │
│        - date = today                                          │
│        - timeSlot = "6:00 AM - 7:00 AM"                        │
│        - status = "confirmed" or "pending"                     │
│                                                                 │
│      Calculate:                                                │
│        totalPersonsBooked = SUM(numberOfPeople)                │
│        remainingCapacity = 5 - totalPersonsBooked              │
│        canBook = remainingCapacity >= numberOfPeople           │
│                                                                 │
│      Return slotDetails:                                       │
│        "6:00 AM - 7:00 AM": {                                  │
│          totalPersonsBooked: 0,  ← NEW SLOT                    │
│          remainingCapacity: 5,                                 │
│          capacity: 5,                                          │
│          canBook: true,                                        │
│          isSlotFull: false,                                    │
│          status: "AVAILABLE"                                   │
│        }                                                        │
│                                                                 │
│    STEP 5: Return available slots with details ✅              │
│                                                                 │
│    Returns: BookingFlowResult {                                │
│      success: true                                             │
│      availableSlots: ["6:00 AM - 7:00 AM", ...]               │
│      slotDetails: {                                            │
│        "6:00 AM - 7:00 AM": {                                  │
│          totalPersonsBooked: 0,                                │
│          remainingCapacity: 5,                                 │
│          capacity: 5,                                          │
│          ...                                                   │
│        }                                                        │
│      }                                                          │
│    }                                                            │
└────────────────────────┬────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│ 6. BUILD AVAILABILITY MAP                                       │
│    _loadSlotAvailability() continues...                         │
│                                                                 │
│    For each time slot:                                         │
│      slotDetail = result.slotDetails[timeSlot]                 │
│      totalPersonsBooked = slotDetail['totalPersonsBooked']     │
│                                                                 │
│      _slotAvailability[timeSlot] = {                           │
│        available: true,                                        │
│        bookedSpots: 0,  ← From flow function                   │
│        totalCapacity: 5,  ← From _amenityDetails               │
│        reason: "Available"                                     │
│      }                                                          │
│                                                                 │
│    setState(() {                                               │
│      _availableSlots = result.availableSlots;                  │
│      _slotAvailability = availability;                         │
│    });                                                          │
└────────────────────────┬────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│ 7. RENDER TIME SLOT SELECTOR                                    │
│    _buildTimeSlotSelector()                                     │
│                                                                 │
│    For each time slot:                                         │
│      remainingSpots = _getRemainingSpots(slot)                 │
│      totalCapacity = _getTotalCapacity(slot)                   │
│                                                                 │
│      Display: "$remainingSpots/$totalCapacity spots booked"    │
└────────────────────────┬────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│ 8. DISPLAY RESULT                                               │
│                                                                 │
│    ✅ CORRECT:                                                 │
│    "6:00 AM - 7:00 AM"                                         │
│    "0/5 spots booked"                                          │
│                                                                 │
│    ❌ WRONG (Before Fix):                                      │
│    "6:00 AM - 7:00 AM"                                         │
│    "0/8 spots booked"  ← Capacity was 8                        │
└─────────────────────────────────────────────────────────────────┘
```

---

## Data Sources for Capacity Display

### Source 1: Amenity Document (Primary)
```
Firestore: amenities/{amenityId}
Field: maxCapacity
Value: 5
Used by: _getTotalCapacity()
```

### Source 2: Flow Function Result (Secondary)
```
Flow function returns: slotDetails
Each slot contains:
  - totalPersonsBooked: 0 (for new slots)
  - remainingCapacity: 5
  - capacity: 5
Used by: _getRemainingSpots()
```

### Source 3: Availability Map (Cached)
```
_slotAvailability[timeSlot] = {
  bookedSpots: 0,
  totalCapacity: 5
}
Used by: Display logic
```

---

## Method Call Chain

### _getRemainingSpots(timeSlot)
```
1. Check _slotAvailability[timeSlot]
2. Get 'bookedSpots' value
3. Return bookedSpots (0 for new slots)

Example:
  _slotAvailability["6:00 AM - 7:00 AM"] = {
    bookedSpots: 0,  ← Returns this
    totalCapacity: 5
  }
  
  Result: 0
```

### _getTotalCapacity(timeSlot)
```
1. Check _amenityDetails (Primary)
2. Get maxCapacity value
3. Return maxCapacity (5)

Example:
  _amenityDetails.maxCapacity = 5  ← Returns this
  
  Result: 5
```

### Display Logic
```
remainingSpots = _getRemainingSpots(slot)  // 0
totalCapacity = _getTotalCapacity(slot)    // 5

Display: "$remainingSpots/$totalCapacity spots booked"
Result: "0/5 spots booked"  ✅
```

---

## Capacity Values at Each Stage

| Stage | Capacity Value | Source | Expected |
|-------|---|---|---|
| Firestore | 5 | amenities.maxCapacity | 5 ✅ |
| AmenityModel | 5 | AmenityModel.maxCapacity | 5 ✅ |
| _amenityDetails | 5 | _amenityDetails.maxCapacity | 5 ✅ |
| Flow Function | 5 | capacity parameter | 5 ✅ |
| slotDetails | 5 | slotDetails['capacity'] | 5 ✅ |
| _slotAvailability | 5 | _slotAvailability[slot]['totalCapacity'] | 5 ✅ |
| Display | 5 | _getTotalCapacity() | 5 ✅ |

---

## Booked Spots Values at Each Stage

| Stage | Booked Spots | Source | Expected |
|-------|---|---|---|
| Firestore | 0 | No bookings | 0 ✅ |
| Flow Function | 0 | totalPersonsBooked | 0 ✅ |
| slotDetails | 0 | slotDetails['totalPersonsBooked'] | 0 ✅ |
| _slotAvailability | 0 | _slotAvailability[slot]['bookedSpots'] | 0 ✅ |
| Display | 0 | _getRemainingSpots() | 0 ✅ |

---

## Example: Complete Flow for New Slot

### Input
```
Amenity: Gym (ID: gym-1)
Capacity: 5
Date: Today
Time Slot: 6:00 AM - 7:00 AM
Bookings: None
```

### Processing
```
1. Load amenity → maxCapacity = 5
2. Call flow function with capacity = 5
3. Query bookings → 0 bookings found
4. Calculate totalPersonsBooked = 0
5. Return slotDetails with totalPersonsBooked = 0
6. Build _slotAvailability with bookedSpots = 0, totalCapacity = 5
7. Call _getRemainingSpots() → returns 0
8. Call _getTotalCapacity() → returns 5
```

### Output
```
Display: "0/5 spots booked"  ✅
```

---

## Example: Complete Flow After 2 Bookings

### Input
```
Amenity: Gym (ID: gym-1)
Capacity: 5
Date: Today
Time Slot: 6:00 AM - 7:00 AM
Bookings: 2 (1 person each)
```

### Processing
```
1. Load amenity → maxCapacity = 5
2. Call flow function with capacity = 5
3. Query bookings → 2 bookings found
4. Calculate totalPersonsBooked = 1 + 1 = 2
5. Return slotDetails with totalPersonsBooked = 2
6. Build _slotAvailability with bookedSpots = 2, totalCapacity = 5
7. Call _getRemainingSpots() → returns 2
8. Call _getTotalCapacity() → returns 5
```

### Output
```
Display: "2/5 spots booked"  ✅
```

---

## Example: Complete Flow When Full (5 Bookings)

### Input
```
Amenity: Gym (ID: gym-1)
Capacity: 5
Date: Today
Time Slot: 6:00 AM - 7:00 AM
Bookings: 5 (1 person each)
```

### Processing
```
1. Load amenity → maxCapacity = 5
2. Call flow function with capacity = 5
3. Query bookings → 5 bookings found
4. Calculate totalPersonsBooked = 1+1+1+1+1 = 5
5. Return slotDetails with totalPersonsBooked = 5, isSlotFull = true
6. Build _slotAvailability with bookedSpots = 5, totalCapacity = 5
7. Call _getRemainingSpots() → returns 5
8. Call _getTotalCapacity() → returns 5
9. Check _isSlotAvailable() → returns false (not in availableSlots)
```

### Output
```
Display: "5/5 spots booked" + "Slot Full" message  ✅
Button: Disabled  ✅
```

---

## Troubleshooting: Wrong Capacity (8 instead of 5)

### Scenario 1: Firestore has maxCapacity = 8
```
Firestore: amenities/gym-1 → maxCapacity: 8
↓
AmenityModel.maxCapacity = 8
↓
_amenityDetails.maxCapacity = 8
↓
_getTotalCapacity() returns 8
↓
Display: "0/8 spots booked"  ❌

Fix: Update Firestore to maxCapacity: 5
```

### Scenario 2: Flow function receives wrong capacity
```
_loadSlotAvailability() passes capacity: 8
↓
Flow function calculates with capacity = 8
↓
slotDetails['capacity'] = 8
↓
_slotAvailability['totalCapacity'] = 8
↓
_getTotalCapacity() returns 8
↓
Display: "0/8 spots booked"  ❌

Fix: Verify _loadSlotAvailability() passes _amenityDetails!.maxCapacity
```

### Scenario 3: _getTotalCapacity() uses wrong source
```
_getTotalCapacity() uses _slotAvailability instead of _amenityDetails
↓
Returns _slotAvailability[slot]['totalCapacity'] = 8
↓
Display: "0/8 spots booked"  ❌

Fix: Ensure _getTotalCapacity() prioritizes _amenityDetails.maxCapacity
```

---

## Key Takeaways

1. **Capacity Source**: Always use `_amenityDetails.maxCapacity` (from Firestore)
2. **Booked Spots Source**: Use flow function's `totalPersonsBooked`
3. **Display Format**: `"$bookedSpots/$totalCapacity spots booked"`
4. **New Slots**: Show "0/5 spots booked" (not "5/5")
5. **Full Slots**: Show "5/5 spots booked" + "Slot Full" message
