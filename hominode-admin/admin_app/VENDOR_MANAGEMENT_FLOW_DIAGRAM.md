# Vendor Management - Flow Diagram 📊

## Complete System Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                    VENDOR MANAGEMENT SYSTEM                      │
│                     (Staff & Vendors Screen)                     │
└─────────────────────────────────────────────────────────────────┘
                                 │
                                 ▼
                    ┌────────────────────────┐
                    │   Vendors Tab Active   │
                    │  (Real-time Stream)    │
                    └────────────────────────┘
                                 │
                ┌────────────────┼────────────────┐
                │                │                │
                ▼                ▼                ▼
        ┌──────────────┐  ┌──────────┐  ┌──────────────┐
        │  Add Vendor  │  │  Search  │  │ Vendor List  │
        │   Button     │  │   Bar    │  │   Display    │
        └──────────────┘  └──────────┘  └──────────────┘
                │                │                │
                ▼                ▼                ▼
```

---

## 1. Add Vendor Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                        ADD VENDOR FLOW                           │
└─────────────────────────────────────────────────────────────────┘

    [Click Add Vendor Button]
              │
              ▼
    ┌──────────────────────┐
    │  Add Vendor Modal    │
    │  Opens (Scrollable)  │
    └──────────────────────┘
              │
              ▼
    ┌──────────────────────────────────────────────────────┐
    │              REQUIRED FIELDS                          │
    │  ┌────────────────────────────────────────────────┐  │
    │  │  1. Business Name (Text Input)                 │  │
    │  │  2. Category (Dropdown - 12 options)           │  │
    │  │  3. Contact Person (Text Input)                │  │
    │  │  4. Phone Number (Phone Input)                 │  │
    │  └────────────────────────────────────────────────┘  │
    └──────────────────────────────────────────────────────┘
              │
              ▼
    ┌──────────────────────────────────────────────────────┐
    │              OPTIONAL FIELDS                          │
    │  ┌────────────────────────────────────────────────┐  │
    │  │  5. Email (Email Input)                        │  │
    │  │  6. Address (Multi-line Text)                  │  │
    │  │  7. Contract Start Date (Date Picker)          │  │
    │  │  8. Contract End Date (Date Picker)            │  │
    │  │  9. Services (Multi-select Chips - 8 options)  │  │
    │  └────────────────────────────────────────────────┘  │
    └──────────────────────────────────────────────────────┘
              │
              ▼
    [Click Add Vendor Button]
              │
              ▼
    ┌──────────────────────┐
    │  Form Validation     │
    │  - Check required    │
    │  - Validate formats  │
    └──────────────────────┘
              │
         ┌────┴────┐
         │         │
    [Valid]   [Invalid]
         │         │
         │         └──> [Show Error Messages]
         │
         ▼
    ┌──────────────────────┐
    │  Save to Firestore   │
    │  - Generate ID       │
    │  - Add timestamps    │
    │  - Set defaults      │
    └──────────────────────┘
              │
              ▼
    ┌──────────────────────┐
    │  Success Response    │
    │  - Close modal       │
    │  - Show success msg  │
    │  - Update list       │
    └──────────────────────┘
              │
              ▼
    [Vendor appears in list immediately]
```

---

## 2. View Vendors Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                      VIEW VENDORS FLOW                           │
└─────────────────────────────────────────────────────────────────┘

    [Vendors Tab Active]
              │
              ▼
    ┌──────────────────────┐
    │  Firestore Stream    │
    │  - Real-time listen  │
    │  - Auto-updates      │
    └──────────────────────┘
              │
              ▼
    ┌──────────────────────────────────────────┐
    │         VENDOR LIST DISPLAY              │
    │  ┌────────────────────────────────────┐  │
    │  │  For each vendor:                  │  │
    │  │  ┌──────────────────────────────┐  │  │
    │  │  │  📦 Business Icon            │  │  │
    │  │  │  Business Name               │  │  │
    │  │  │  Category • Contact Person   │  │  │
    │  │  │  📞 Call Button              │  │  │
    │  │  └──────────────────────────────┘  │  │
    │  └────────────────────────────────────┘  │
    └──────────────────────────────────────────┘
              │
              ▼
    [Click Vendor Card]
              │
              ▼
    [Navigate to Vendor Details]
```

---

## 3. Vendor Details Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                    VENDOR DETAILS FLOW                           │
└─────────────────────────────────────────────────────────────────┘

    [Vendor Card Clicked]
              │
              ▼
    ┌──────────────────────┐
    │  Fetch Vendor by ID  │
    │  from Firestore      │
    └──────────────────────┘
              │
              ▼
    ┌─────────────────────────────────────────────────────────┐
    │              VENDOR DETAILS SCREEN                       │
    │  ┌───────────────────────────────────────────────────┐  │
    │  │  HEADER                                           │  │
    │  │  - Business Icon                                  │  │
    │  │  - Business Name                                  │  │
    │  │  - Category Badge                                 │  │
    │  │  - Rating & Total Services                        │  │
    │  │  - Edit Icon (top right)                          │  │
    │  │  - Delete Icon (top right)                        │  │
    │  └───────────────────────────────────────────────────┘  │
    │                                                          │
    │  ┌───────────────────────────────────────────────────┐  │
    │  │  CONTACT INFORMATION                              │  │
    │  │  - Contact Person                                 │  │
    │  │  - Phone (with call button)                       │  │
    │  │  - Email                                          │  │
    │  │  - Address                                        │  │
    │  └───────────────────────────────────────────────────┘  │
    │                                                          │
    │  ┌───────────────────────────────────────────────────┐  │
    │  │  CONTRACT DETAILS                                 │  │
    │  │  - Start Date                                     │  │
    │  │  - End Date                                       │  │
    │  │  - Status (Active/Expired/Upcoming)               │  │
    │  └───────────────────────────────────────────────────┘  │
    │                                                          │
    │  ┌───────────────────────────────────────────────────┐  │
    │  │  SERVICES PROVIDED                                │  │
    │  │  - Service chips                                  │  │
    │  └───────────────────────────────────────────────────┘  │
    │                                                          │
    │  ┌───────────────────────────────────────────────────┐  │
    │  │  PERFORMANCE                                      │  │
    │  │  - Total Services Card                            │  │
    │  │  - Rating Card                                    │  │
    │  └───────────────────────────────────────────────────┘  │
    └─────────────────────────────────────────────────────────┘
              │
         ┌────┴────┐
         │         │
    [Edit]    [Delete]
         │         │
         ▼         ▼
```

---

## 4. Edit Vendor Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                       EDIT VENDOR FLOW                           │
└─────────────────────────────────────────────────────────────────┘

    [Click Edit Icon in Details]
              │
              ▼
    ┌──────────────────────┐
    │  Edit Vendor Modal   │
    │  Opens (Scrollable)  │
    └──────────────────────┘
              │
              ▼
    ┌──────────────────────────────────────────────────────┐
    │         ALL FIELDS PRE-POPULATED                      │
    │  ┌────────────────────────────────────────────────┐  │
    │  │  1. Business Name (editable)                   │  │
    │  │  2. Category (editable dropdown)               │  │
    │  │  3. Contact Person (editable)                  │  │
    │  │  4. Phone Number (editable)                    │  │
    │  │  5. Email (editable)                           │  │
    │  │  6. Address (editable)                         │  │
    │  │  7. Contract Start Date (editable picker)      │  │
    │  │  8. Contract End Date (editable picker)        │  │
    │  │  9. Services (editable multi-select)           │  │
    │  └────────────────────────────────────────────────┘  │
    └──────────────────────────────────────────────────────┘
              │
              ▼
    [Update any fields]
              │
              ▼
    [Click Update Vendor Button]
              │
              ▼
    ┌──────────────────────┐
    │  Form Validation     │
    └──────────────────────┘
              │
         ┌────┴────┐
         │         │
    [Valid]   [Invalid]
         │         │
         │         └──> [Show Error Messages]
         │
         ▼
    ┌──────────────────────┐
    │  Update Firestore    │
    │  - Update fields     │
    │  - Update timestamp  │
    └──────────────────────┘
              │
              ▼
    ┌──────────────────────┐
    │  Success Response    │
    │  - Close modal       │
    │  - Show success msg  │
    │  - Refresh details   │
    └──────────────────────┘
              │
              ▼
    [Details screen shows updated data]
```

---

## 5. Delete Vendor Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                      DELETE VENDOR FLOW                          │
└─────────────────────────────────────────────────────────────────┘

    [Click Delete Icon in Details]
              │
              ▼
    ┌──────────────────────────────────────────┐
    │  Delete Confirmation Dialog              │
    │  ┌────────────────────────────────────┐  │
    │  │  Title: "Delete Vendor"            │  │
    │  │  Message: Confirmation text        │  │
    │  │  Vendor Name: Display              │  │
    │  │  Reason Field: Required input      │  │
    │  │  [Cancel] [Delete Vendor]          │  │
    │  └────────────────────────────────────┘  │
    └──────────────────────────────────────────┘
              │
         ┌────┴────┐
         │         │
    [Cancel]  [Confirm]
         │         │
         │         ▼
         │    ┌──────────────────────┐
         │    │  Delete from         │
         │    │  Firestore           │
         │    └──────────────────────┘
         │         │
         │         ▼
         │    ┌──────────────────────┐
         │    │  Success Response    │
         │    │  - Close dialog      │
         │    │  - Show success msg  │
         │    │  - Navigate back     │
         │    └──────────────────────┘
         │         │
         └─────────┼──> [Return to Vendor List]
                   │
                   ▼
         [Vendor removed from list]
```

---

## 6. Search Vendors Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                      SEARCH VENDORS FLOW                         │
└─────────────────────────────────────────────────────────────────┘

    [Type in Search Bar]
              │
              ▼
    ┌──────────────────────┐
    │  Search Query        │
    │  - Real-time         │
    │  - Case-insensitive  │
    └──────────────────────┘
              │
              ▼
    ┌─────────────────────────────────────────┐
    │      SEARCH CRITERIA                     │
    │  ┌───────────────────────────────────┐  │
    │  │  Search in:                       │  │
    │  │  - Business Name                  │  │
    │  │  - Category                       │  │
    │  │  - Contact Person                 │  │
    │  │  - Phone Number                   │  │
    │  └───────────────────────────────────┘  │
    └─────────────────────────────────────────┘
              │
              ▼
    ┌──────────────────────┐
    │  Filter Results      │
    │  - Match query       │
    │  - Update list       │
    └──────────────────────┘
              │
              ▼
    [Display Filtered Vendors]
              │
              ▼
    [Clear Search → Show All Vendors]
```

---

## 7. Real-Time Updates Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                   REAL-TIME UPDATES FLOW                         │
└─────────────────────────────────────────────────────────────────┘

    ┌──────────────────────┐
    │  Firestore Database  │
    │  (vendors collection)│
    └──────────────────────┘
              │
              │ (Real-time Stream)
              │
              ▼
    ┌──────────────────────┐
    │  StreamBuilder       │
    │  - Listen to changes │
    │  - Auto-rebuild UI   │
    └──────────────────────┘
              │
         ┌────┴────┬────────┬────────┐
         │         │        │        │
         ▼         ▼        ▼        ▼
    [Add]    [Update]  [Delete]  [Any Change]
         │         │        │        │
         └─────────┴────────┴────────┘
                   │
                   ▼
         [UI Updates Automatically]
                   │
                   ▼
         [All Devices See Changes]
```

---

## Data Flow Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                      DATA FLOW ARCHITECTURE                      │
└─────────────────────────────────────────────────────────────────┘

    ┌──────────────────┐
    │   UI Layer       │
    │  (Screens/       │
    │   Widgets)       │
    └──────────────────┘
            │
            │ (Calls)
            ▼
    ┌──────────────────┐
    │  Service Layer   │
    │  (staff_vendor_  │
    │   service.dart)  │
    └──────────────────┘
            │
            │ (CRUD Operations)
            ▼
    ┌──────────────────┐
    │  Firestore       │
    │  (vendors        │
    │   collection)    │
    └──────────────────┘
            │
            │ (Real-time Stream)
            ▼
    ┌──────────────────┐
    │  StreamBuilder   │
    │  (Auto-updates   │
    │   UI)            │
    └──────────────────┘
```

---

## State Management Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                    STATE MANAGEMENT FLOW                         │
└─────────────────────────────────────────────────────────────────┘

    [User Action]
         │
         ▼
    ┌──────────────────┐
    │  setState()      │
    │  - Update local  │
    │  - Show loading  │
    └──────────────────┘
         │
         ▼
    ┌──────────────────┐
    │  Service Call    │
    │  - Async         │
    │  - Try/Catch     │
    └──────────────────┘
         │
    ┌────┴────┐
    │         │
[Success] [Error]
    │         │
    │         └──> ┌──────────────────┐
    │              │  Show Error      │
    │              │  - setState()    │
    │              │  - SnackBar      │
    │              └──────────────────┘
    │
    ▼
┌──────────────────┐
│  Show Success    │
│  - setState()    │
│  - SnackBar      │
│  - Navigate      │
└──────────────────┘
```

---

## Complete User Journey

```
START
  │
  ▼
[Open App] → [Navigate to Staff & Vendors] → [Switch to Vendors Tab]
  │
  ├─> [Add Vendor] → [Fill Form] → [Submit] → [Success] → [See in List]
  │
  ├─> [Search Vendor] → [Type Query] → [See Results] → [Click Vendor]
  │
  └─> [Click Vendor] → [View Details]
        │
        ├─> [Edit] → [Update Form] → [Submit] → [Success] → [See Updates]
        │
        ├─> [Delete] → [Confirm] → [Success] → [Back to List]
        │
        └─> [Call] → [Initiate Call]
```

---

**Status:** Complete Flow Documentation ✅
**Last Updated:** February 20, 2026
