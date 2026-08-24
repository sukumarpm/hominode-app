# Poster Expiry Feature - Flow Diagram

## Admin Create Poster Flow

```
┌─────────────────────────────────────────────────────────────────┐
│ ADMIN CREATES POSTER WITH EXPIRY                                │
└─────────────────────────────────────────────────────────────────┘

1. ADMIN INTERACTION
   ┌──────────────────────────────────────────┐
   │ Admin App → Quick Access                 │
   │ Click "Manage Posters"                   │
   │ Click "Create Poster" button             │
   └──────────────────────────────────────────┘
                    ↓
   ┌──────────────────────────────────────────┐
   │ MODAL OPENS (Centered Overlay)           │
   │ - Dark background (0.4 opacity)          │
   │ - Header with title & close button       │
   │ - Form fields                            │
   └──────────────────────────────────────────┘
                    ↓
   ┌──────────────────────────────────────────┐
   │ ADMIN FILLS FORM                         │
   │ ✓ Poster Title (required)                │
   │ ✓ Category (dropdown)                    │
   │ ✓ Description (optional)                 │
   │ ✓ Expiry Date (date picker) ← NEW        │
   │ ✓ Expiry Time (time picker) ← NEW        │
   │ ✓ Upload Image (required)                │
   └──────────────────────────────────────────┘
                    ↓
   ┌──────────────────────────────────────────┐
   │ ADMIN CLICKS "Create & Publish"          │
   │ Modal validates form                     │
   └──────────────────────────────────────────┘

2. BACKEND PROCESSING (Flow Function)
   ┌──────────────────────────────────────────┐
   │ 🔵 CLOUDINARY POSTER SERVICE             │
   │ Starting poster creation...              │
   └──────────────────────────────────────────┘
                    ↓
   ┌──────────────────────────────────────────┐
   │ 🔐 STEP 1: Validate Admin Auth           │
   │ ✅ Admin authenticated - [adminId]       │
   └──────────────────────────────────────────┘
                    ↓
   ┌──────────────────────────────────────────┐
   │ 📋 STEP 2: Validate Input Data           │
   │ ✅ Title, Image, etc. validated          │
   └──────────────────────────────────────────┘
                    ↓
   ┌──────────────────────────────────────────┐
   │ 📤 STEP 3A: Upload to Cloudinary         │
   │ ✅ Image uploaded - [imageUrl]           │
   └──────────────────────────────────────────┘
                    ↓
   ┌──────────────────────────────────────────┐
   │ 📋 STEP 4: Parse Expiry Date/Time ← NEW  │
   │ Input: "25-03-2026" + "18:30"            │
   │ Parse: DateTime(2026, 3, 25, 18, 30)     │
   │ ✅ Expiry datetime parsed                │
   └──────────────────────────────────────────┘
                    ↓
   ┌──────────────────────────────────────────┐
   │ 💾 STEP 5: Save to Firestore             │
   │ Document: {                              │
   │   title: "...",                          │
   │   imageUrl: "...",                       │
   │   expiryDate: "25-03-2026",   ← NEW      │
   │   expiryTime: "18:30",        ← NEW      │
   │   expiryDateTime: Timestamp,  ← NEW      │
   │   ...                                    │
   │ }                                        │
   │ ✅ Poster saved - [posterId]             │
   └──────────────────────────────────────────┘
                    ↓
   ┌──────────────────────────────────────────┐
   │ 🔔 STEP 6: Log Completion                │
   │ ✅ POSTER CREATION COMPLETE              │
   └──────────────────────────────────────────┘

3. ADMIN SEES RESULT
   ┌──────────────────────────────────────────┐
   │ Modal closes                             │
   │ Success message shown                    │
   │ Poster appears in management screen      │
   │ Shows expiry info:                       │
   │ - Expiry date: "25-03-2026"              │
   │ - Expiry time: "18:30"                   │
   │ - Status: "active"                       │
   └──────────────────────────────────────────┘
```

## Resident View Posters Flow

```
┌─────────────────────────────────────────────────────────────────┐
│ RESIDENT VIEWS POSTERS (Real-time Filtering)                    │
└─────────────────────────────────────────────────────────────────┘

1. RESIDENT INTERACTION
   ┌──────────────────────────────────────────┐
   │ Resident App → Home Screen               │
   │ Scroll to Posters section                │
   │ OR Click "View All Posters"              │
   └──────────────────────────────────────────┘
                    ↓
   ┌──────────────────────────────────────────┐
   │ CAROUSEL SCREEN LOADS                    │
   │ Initializes data streams                 │
   └──────────────────────────────────────────┘

2. BACKEND PROCESSING (Flow Function)
   ┌──────────────────────────────────────────┐
   │ 🔵 CLOUDINARY POSTER SERVICE             │
   │ Fetching posters for building...         │
   │ buildingId: [buildingId]                 │
   └──────────────────────────────────────────┘
                    ↓
   ┌──────────────────────────────────────────┐
   │ ✅ STEP 1: Validate Building ID          │
   │ ✅ Building ID validated                 │
   └──────────────────────────────────────────┘
                    ↓
   ┌──────────────────────────────────────────┐
   │ 📋 STEP 2: Fetch Active Posters          │
   │ Query: status = "active"                 │
   │ ✅ Received [count] posters              │
   └──────────────────────────────────────────┘
                    ↓
   ┌──────────────────────────────────────────┐
   │ 🔄 STEP 3: Filter by Building & Expiry   │
   │                                          │
   │ For each poster:                         │
   │ ├─ Check: buildingIds.contains(id)?      │
   │ ├─ Check: expiryDateTime > now? ← NEW    │
   │ └─ Include if both true                  │
   │                                          │
   │ ✅ Filtered [count] active posters       │
   └──────────────────────────────────────────┘

3. FILTERING LOGIC (In Memory)
   ┌──────────────────────────────────────────┐
   │ Current Time: 2026-03-25 15:00           │
   │                                          │
   │ Poster A:                                │
   │ - buildingIds: [building1] ✓             │
   │ - expiryDateTime: 2026-03-25 18:30 ✓     │
   │ - Status: VISIBLE ✓                      │
   │                                          │
   │ Poster B:                                │
   │ - buildingIds: [building1] ✓             │
   │ - expiryDateTime: 2026-03-25 14:00 ✗     │
   │ - Status: HIDDEN (EXPIRED)               │
   │                                          │
   │ Poster C:                                │
   │ - buildingIds: [building1] ✓             │
   │ - expiryDateTime: null ✓                 │
   │ - Status: VISIBLE (NO EXPIRY)            │
   └──────────────────────────────────────────┘

4. RESIDENT SEES RESULT
   ┌──────────────────────────────────────────┐
   │ CAROUSEL DISPLAYS:                       │
   │ - Poster A (active, not expired)         │
   │ - Poster C (active, no expiry)           │
   │                                          │
   │ HIDDEN:                                  │
   │ - Poster B (expired)                     │
   │                                          │
   │ Features:                                │
   │ - Swipe left/right to browse             │
   │ - Dots indicator showing position        │
   │ - Counter: "1 of 2"                      │
   │ - No expiry info shown to resident       │
   └──────────────────────────────────────────┘
```

## Admin Management Screen - Expired Poster Display

```
┌─────────────────────────────────────────────────────────────────┐
│ ADMIN MANAGEMENT SCREEN - POSTER CARD                           │
└─────────────────────────────────────────────────────────────────┘

ACTIVE POSTER (Not Expired)
┌─────────────────────────────────────────┐
│ ┌─────────────────────────────────────┐ │
│ │                                     │ │
│ │      [Poster Image]                 │ │
│ │                                     │ │
│ └─────────────────────────────────────┘ │
│                                         │
│ Title: "Community Maintenance"          │
│ Status: [active] (green badge)          │
│ Description: "Please maintain..."       │
│ Category: [Maintenance]                 │
│ Expiry: 25-03-2026 (hover for time)     │
│ Created: 2h ago                         │
│ [Delete button]                         │
└─────────────────────────────────────────┘

EXPIRED POSTER (After Expiry Time)
┌─────────────────────────────────────────┐
│ ┌─────────────────────────────────────┐ │
│ │                                     │ │
│ │      [Poster Image]                 │ │
│ │                                     │ │
│ │  ┌─────────────────────────────┐   │ │
│ │  │ Expired (red badge)         │   │ │
│ │  └─────────────────────────────┘   │ │
│ │                                     │ │
│ └─────────────────────────────────────┘ │
│ (Red border around card)                │
│                                         │
│ Title: "Old Announcement"               │
│ Status: [expired] (red badge)           │
│ Description: "This is old..."           │
│ Category: [Announcement]                │
│ Expiry: 24-03-2026 (red text)           │
│ Created: 1d ago                         │
│ [Delete button]                         │
└─────────────────────────────────────────┘
```

## Date/Time Parsing Flow

```
┌─────────────────────────────────────────────────────────────────┐
│ DATE/TIME PARSING LOGIC                                         │
└─────────────────────────────────────────────────────────────────┘

INPUT FROM PICKERS
┌──────────────────────────────────────────┐
│ Date Picker Output: "25-03-2026"         │
│ Time Picker Output: "18:30"              │
└──────────────────────────────────────────┘
         ↓
PARSING LOGIC
┌──────────────────────────────────────────┐
│ dateParts = "25-03-2026".split('-')      │
│ → ["25", "03", "2026"]                   │
│                                          │
│ day = 25                                 │
│ month = 3                                │
│ year = 2026                              │
│                                          │
│ timeParts = "18:30".split(':')           │
│ → ["18", "30"]                           │
│                                          │
│ hour = 18                                │
│ minute = 30                              │
└──────────────────────────────────────────┘
         ↓
DATETIME CREATION
┌──────────────────────────────────────────┐
│ expiryDateTime = DateTime(                │
│   2026,  // year                         │
│   3,     // month                        │
│   25,    // day                          │
│   18,    // hour                         │
│   30     // minute                       │
│ )                                        │
│                                          │
│ Result: 2026-03-25 18:30:00              │
└──────────────────────────────────────────┘
         ↓
FIRESTORE STORAGE
┌──────────────────────────────────────────┐
│ expiryDate: "25-03-2026" (string)        │
│ expiryTime: "18:30" (string)             │
│ expiryDateTime: Timestamp (for query)    │
└──────────────────────────────────────────┘
```

## Expiry Comparison Logic

```
┌─────────────────────────────────────────────────────────────────┐
│ EXPIRY COMPARISON (Real-time)                                   │
└─────────────────────────────────────────────────────────────────┘

CURRENT TIME: 2026-03-25 15:00:00

POSTER A
├─ expiryDateTime: 2026-03-25 18:30:00
├─ Comparison: 18:30 > 15:00? YES
├─ Result: NOT EXPIRED ✓
└─ Display: Show to resident

POSTER B
├─ expiryDateTime: 2026-03-25 14:00:00
├─ Comparison: 14:00 > 15:00? NO
├─ Result: EXPIRED ✗
└─ Display: Hide from resident

POSTER C
├─ expiryDateTime: null
├─ Comparison: null > 15:00? SKIP
├─ Result: NO EXPIRY ✓
└─ Display: Show to resident (permanent)

AFTER 18:30 (POSTER A EXPIRES)
├─ Current Time: 2026-03-25 18:31:00
├─ Poster A expiryDateTime: 2026-03-25 18:30:00
├─ Comparison: 18:30 > 18:31? NO
├─ Result: NOW EXPIRED ✗
└─ Display: Hide from resident (automatic)
```

## Real-time Update Flow

```
┌─────────────────────────────────────────────────────────────────┐
│ REAL-TIME UPDATE (StreamBuilder)                                │
└─────────────────────────────────────────────────────────────────┘

RESIDENT OPENS CAROUSEL
         ↓
StreamBuilder subscribes to Firestore
         ↓
Service fetches all active posters
         ↓
Filters by building ID and expiry
         ↓
Returns filtered list
         ↓
Carousel displays posters
         ↓
POSTER EXPIRES (18:30 arrives)
         ↓
Firestore snapshot updates
         ↓
StreamBuilder receives new data
         ↓
Service re-filters (now excludes expired)
         ↓
Carousel automatically updates
         ↓
Expired poster disappears (no refresh needed)
```

## Summary

The poster expiry feature implements a complete flow from admin creation through resident viewing:

1. **Admin Creates**: Selects date/time using pickers
2. **Backend Parses**: Converts to DateTime for filtering
3. **Firestore Stores**: Saves in three formats (string + Timestamp)
4. **Real-time Filters**: Automatically hides expired posters
5. **Resident Views**: Only sees active, non-expired posters
6. **Auto-Updates**: Changes reflected immediately via StreamBuilder

All operations follow the flow function pattern with proper logging and validation.
