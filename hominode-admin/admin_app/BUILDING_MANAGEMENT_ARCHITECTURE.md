# Building Management Module - Architecture Diagram

## System Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        USER INTERFACE                            │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │         ManageBuildingsPage (Main Screen)                 │  │
│  │                                                            │  │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  │  │
│  │  │  Building 1  │  │  Building 2  │  │  Building 3  │  │  │
│  │  │  [Grid][✏️][🗑️]│  │  [Grid][✏️][🗑️]│  │  [Grid][✏️][🗑️]│  │  │
│  │  └──────────────┘  └──────────────┘  └──────────────┘  │  │
│  │                                                            │  │
│  │  [+ Add Building Button]                                  │  │
│  └──────────────────────────────────────────────────────────┘  │
│                          │                                       │
│                          │ User Actions                          │
│                          ▼                                       │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │              Modal Dialogs (Widgets)                      │  │
│  │                                                            │  │
│  │  ┌─────────────────┐  ┌─────────────────┐               │  │
│  │  │ AddBuilding     │  │ FlatOccupancy   │               │  │
│  │  │ Modal           │  │ GridModal       │               │  │
│  │  │ (Add/Edit)      │  │                 │               │  │
│  │  └─────────────────┘  └─────────────────┘               │  │
│  │                                                            │  │
│  │  ┌─────────────────┐  ┌─────────────────┐               │  │
│  │  │ FlatDetails     │  │ AssignResident  │               │  │
│  │  │ Modal           │  │ Modal           │               │  │
│  │  └─────────────────┘  └─────────────────┘               │  │
│  └──────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
                              │
                              │ Service Calls
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                       SERVICE LAYER                              │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│  ┌──────────────────┐  ┌──────────────────┐  ┌──────────────┐ │
│  │ BuildingService  │  │  FlatService     │  │ UserService  │ │
│  │                  │  │                  │  │              │ │
│  │ • addBuilding()  │  │ • generateFlats()│  │ • getUsers() │ │
│  │ • getBuildings() │  │ • getFlats()     │  │ • assign()   │ │
│  │ • updateBuilding│  │ • updateStatus() │  │              │ │
│  │ • deleteBuilding│  │ • assignResident│  │              │ │
│  │ • syncOccupancy()│  │                  │  │              │ │
│  └──────────────────┘  └──────────────────┘  └──────────────┘ │
└─────────────────────────────────────────────────────────────────┘
                              │
                              │ Firestore Operations
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                    CLOUD FIRESTORE                               │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│  ┌──────────────────┐  ┌──────────────────┐  ┌──────────────┐ │
│  │   buildings      │  │      flats       │  │    users     │ │
│  │   collection     │  │   collection     │  │  collection  │ │
│  │                  │  │                  │  │              │ │
│  │ • name           │  │ • id             │  │ • name       │ │
│  │ • floors         │  │ • buildingId     │  │ • role       │ │
│  │ • flatsPerFloor  │  │ • floor          │  │ • flatId     │ │
│  │ • totalFlats     │  │ • status         │  │ • residentId │ │
│  │ • occupied       │  │ • residentName   │  │              │ │
│  │ • vacant         │  │ • residentId     │  │              │ │
│  │ • occupancyRate  │  │                  │  │              │ │
│  └──────────────────┘  └──────────────────┘  └──────────────┘ │
└─────────────────────────────────────────────────────────────────┘
```

## Data Flow Diagrams

### Add Building Flow

```
User                UI                Service              Firestore
 │                  │                   │                     │
 │──Click Add───────>│                   │                     │
 │                  │                   │                     │
 │                  │──Show Modal───────>│                     │
 │                  │                   │                     │
 │──Fill Form───────>│                   │                     │
 │                  │                   │                     │
 │                  │──Validate─────────>│                     │
 │                  │                   │                     │
 │──Submit──────────>│                   │                     │
 │                  │                   │                     │
 │                  │──addBuilding()────>│                     │
 │                  │                   │                     │
 │                  │                   │──Create Building───>│
 │                  │                   │                     │
 │                  │                   │<──Building ID───────│
 │                  │                   │                     │
 │                  │                   │──Generate Flats────>│
 │                  │                   │                     │
 │                  │                   │<──Success───────────│
 │                  │                   │                     │
 │                  │<──Success─────────│                     │
 │                  │                   │                     │
 │<──Notification───│                   │                     │
 │                  │                   │                     │
 │<──Updated List───│<──Stream Update───│<──Real-time────────│
```

### Edit Building Flow

```
User                UI                Service              Firestore
 │                  │                   │                     │
 │──Click Edit──────>│                   │                     │
 │                  │                   │                     │
 │                  │──Show Modal───────>│                     │
 │                  │  (Pre-filled)     │                     │
 │                  │                   │                     │
 │──Modify Fields───>│                   │                     │
 │                  │                   │                     │
 │──Submit──────────>│                   │                     │
 │                  │                   │                     │
 │                  │──updateBuilding()->│                     │
 │                  │                   │                     │
 │                  │                   │──Update Document───>│
 │                  │                   │                     │
 │                  │                   │<──Success───────────│
 │                  │                   │                     │
 │                  │<──Success─────────│                     │
 │                  │                   │                     │
 │<──Notification───│                   │                     │
 │                  │                   │                     │
 │<──Updated Card───│<──Stream Update───│<──Real-time────────│
```

### Delete Building Flow

```
User                UI                Service              Firestore
 │                  │                   │                     │
 │──Click Delete────>│                   │                     │
 │                  │                   │                     │
 │                  │──Show Confirm─────>│                     │
 │                  │                   │                     │
 │──Confirm─────────>│                   │                     │
 │                  │                   │                     │
 │                  │──deleteBuilding()->│                     │
 │                  │                   │                     │
 │                  │                   │──Delete Flats──────>│
 │                  │                   │                     │
 │                  │                   │<──Success───────────│
 │                  │                   │                     │
 │                  │                   │──Delete Building───>│
 │                  │                   │                     │
 │                  │                   │<──Success───────────│
 │                  │                   │                     │
 │                  │<──Success─────────│                     │
 │                  │                   │                     │
 │<──Notification───│                   │                     │
 │                  │                   │                     │
 │<──Removed Card───│<──Stream Update───│<──Real-time────────│
```

## Component Hierarchy

```
ManageBuildingsPage
├── StandardHeader
│   └── Title: "Manage Buildings"
├── TitleRow
│   ├── Text: "Building Management"
│   └── AddBuildingButton
│       └── onClick → AddBuildingModal.show()
├── BuildingsList (StreamBuilder)
│   ├── LoadingState
│   │   └── CircularProgressIndicator
│   ├── ErrorState
│   │   └── ErrorMessage
│   ├── EmptyState
│   │   ├── Icon
│   │   ├── Title
│   │   └── Description
│   └── BuildingCards (List)
│       └── BuildingCard (for each building)
│           ├── CardHeader
│           │   ├── Icon
│           │   ├── BuildingInfo
│           │   │   ├── Name
│           │   │   └── FloorInfo
│           │   └── ActionIcons
│           │       ├── GridIcon → FlatOccupancyGridModal
│           │       ├── EditIcon → AddBuildingModal (edit mode)
│           │       └── DeleteIcon → ConfirmDialog
│           ├── StatsRow
│           │   ├── TotalFlatsChip
│           │   ├── OccupiedChip
│           │   └── VacantChip
│           └── OccupancyBar
│               ├── Label + Percentage
│               └── ProgressBar
└── StandardBottomNav
```

## State Management

```
┌─────────────────────────────────────────┐
│         StreamBuilder Pattern            │
├─────────────────────────────────────────┤
│                                          │
│  Firestore Collection                   │
│         │                                │
│         │ Real-time Stream               │
│         ▼                                │
│  BuildingService.getBuildings()         │
│         │                                │
│         │ Stream<List<BuildingModel>>   │
│         ▼                                │
│  StreamBuilder Widget                   │
│         │                                │
│         ├─ ConnectionState.waiting       │
│         │  └─> Show Loading              │
│         │                                │
│         ├─ hasError                      │
│         │  └─> Show Error                │
│         │                                │
│         ├─ data.isEmpty                  │
│         │  └─> Show Empty State          │
│         │                                │
│         └─ data available                │
│            └─> Show Building List        │
│                                          │
└─────────────────────────────────────────┘
```

## Modal Dialog Pattern

```
┌─────────────────────────────────────────┐
│      AddBuildingModal (Stateful)        │
├─────────────────────────────────────────┤
│                                          │
│  State Variables:                       │
│  • _nameController                      │
│  • _floorsController                    │
│  • _flatsPerFloorController             │
│  • _isLoading                           │
│  • _isFormValid                         │
│  • _nameError                           │
│  • _floorsError                         │
│  • _flatsError                          │
│                                          │
│  Methods:                               │
│  • initState() → Pre-fill if editing    │
│  • _validateForm() → Real-time check    │
│  • _handleAddBuilding() → Submit        │
│  • dispose() → Clean up controllers     │
│                                          │
│  UI Structure:                          │
│  ├─ Header (Title + Close)              │
│  ├─ Name Field (with validation)        │
│  ├─ Numeric Fields Row                  │
│  │  ├─ Floors                           │
│  │  └─ Flats per Floor                  │
│  ├─ Total Flats Display                 │
│  ├─ Submit Button (Add/Update)          │
│  └─ Cancel Button                       │
│                                          │
└─────────────────────────────────────────┘
```

## Service Layer Architecture

```
┌─────────────────────────────────────────────────────────┐
│                   BuildingService                        │
├─────────────────────────────────────────────────────────┤
│                                                          │
│  Dependencies:                                          │
│  • FirebaseFirestore _firestore                        │
│  • FlatService _flatService                            │
│                                                          │
│  Public Methods:                                        │
│  ┌────────────────────────────────────────────────┐   │
│  │ addBuilding(name, floors, flatsPerFloor)       │   │
│  │   ├─> Create building document                 │   │
│  │   ├─> Generate flats via FlatService           │   │
│  │   └─> Return building ID                       │   │
│  └────────────────────────────────────────────────┘   │
│                                                          │
│  ┌────────────────────────────────────────────────┐   │
│  │ getBuildings() → Stream<List<BuildingModel>>   │   │
│  │   ├─> Query buildings collection               │   │
│  │   ├─> Order by createdAt                       │   │
│  │   └─> Map to BuildingModel objects             │   │
│  └────────────────────────────────────────────────┘   │
│                                                          │
│  ┌────────────────────────────────────────────────┐   │
│  │ updateBuilding(id, name, floors, flatsPerFloor)│   │
│  │   ├─> Get current occupancy                    │   │
│  │   ├─> Recalculate stats                        │   │
│  │   └─> Update document                          │   │
│  └────────────────────────────────────────────────┘   │
│                                                          │
│  ┌────────────────────────────────────────────────┐   │
│  │ deleteBuilding(id)                             │   │
│  │   ├─> Delete all flats first                   │   │
│  │   └─> Delete building document                 │   │
│  └────────────────────────────────────────────────┘   │
│                                                          │
│  ┌────────────────────────────────────────────────┐   │
│  │ syncOccupancyFromFlats(buildingId)             │   │
│  │   ├─> Get occupancy stats from FlatService     │   │
│  │   └─> Update building document                 │   │
│  └────────────────────────────────────────────────┘   │
│                                                          │
└─────────────────────────────────────────────────────────┘
```

## Error Handling Flow

```
┌─────────────────────────────────────────┐
│         Error Handling Strategy          │
├─────────────────────────────────────────┤
│                                          │
│  Try-Catch Blocks:                      │
│  ┌────────────────────────────────┐    │
│  │ try {                          │    │
│  │   await service.operation()    │    │
│  │   showSuccessNotification()    │    │
│  │ } catch (e) {                  │    │
│  │   showErrorNotification(e)     │    │
│  │ }                              │    │
│  └────────────────────────────────┘    │
│                                          │
│  Validation Errors:                     │
│  ┌────────────────────────────────┐    │
│  │ • Check field values           │    │
│  │ • Set error messages           │    │
│  │ • Disable submit button        │    │
│  │ • Show inline errors           │    │
│  └────────────────────────────────┘    │
│                                          │
│  Network Errors:                        │
│  ┌────────────────────────────────┐    │
│  │ • Catch Firestore exceptions   │    │
│  │ • Show user-friendly message   │    │
│  │ • Log error for debugging      │    │
│  │ • Allow retry                  │    │
│  └────────────────────────────────┘    │
│                                          │
└─────────────────────────────────────────┘
```

## Performance Optimization

```
┌─────────────────────────────────────────┐
│      Performance Optimizations           │
├─────────────────────────────────────────┤
│                                          │
│  1. StreamBuilder                       │
│     • Real-time updates                 │
│     • No polling required               │
│     • Automatic UI refresh              │
│                                          │
│  2. Batch Operations                    │
│     • Flat generation uses batch        │
│     • Reduces Firestore calls           │
│     • Faster execution                  │
│                                          │
│  3. Lazy Loading                        │
│     • Flat grid loads on-demand         │
│     • Reduces initial load time         │
│     • Better memory usage               │
│                                          │
│  4. Efficient Queries                   │
│     • Indexed fields                    │
│     • Ordered queries                   │
│     • Filtered results                  │
│                                          │
│  5. Optimistic UI                       │
│     • Immediate feedback                │
│     • Loading indicators                │
│     • Smooth transitions                │
│                                          │
└─────────────────────────────────────────┘
```

## Security Architecture

```
┌─────────────────────────────────────────┐
│          Security Layers                 │
├─────────────────────────────────────────┤
│                                          │
│  Layer 1: Authentication                │
│  ┌────────────────────────────────┐    │
│  │ Firebase Authentication        │    │
│  │ • User must be logged in       │    │
│  │ • Admin role required          │    │
│  └────────────────────────────────┘    │
│                                          │
│  Layer 2: Firestore Rules              │
│  ┌────────────────────────────────┐    │
│  │ Security Rules                 │    │
│  │ • Read: authenticated          │    │
│  │ • Write: admin only            │    │
│  │ • Validate data structure      │    │
│  └────────────────────────────────┘    │
│                                          │
│  Layer 3: Client Validation            │
│  ┌────────────────────────────────┐    │
│  │ Form Validation                │    │
│  │ • Required fields              │    │
│  │ • Data type checks             │    │
│  │ • Range validation             │    │
│  └────────────────────────────────┘    │
│                                          │
│  Layer 4: Server Validation            │
│  ┌────────────────────────────────┐    │
│  │ Firestore Validation           │    │
│  │ • Schema enforcement           │    │
│  │ • Business rules               │    │
│  │ • Audit logging                │    │
│  └────────────────────────────────┘    │
│                                          │
└─────────────────────────────────────────┘
```
