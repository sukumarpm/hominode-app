# Image Upload - Visual Flow Diagram

## 🎨 COMPLETE ARCHITECTURE

```
┌──────────────────────────────────────────────────────────────────────────┐
│                         RESIDENT APP - IMAGE UPLOAD                      │
└──────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────┐
│ LAYER 1: USER INTERFACE                                                 │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  ┌──────────────────────────┐      ┌──────────────────────────┐        │
│  │ Create Complaint Modal   │      │ Complaint Detail Modal   │        │
│  ├──────────────────────────┤      ├──────────────────────────┤        │
│  │ • Category dropdown      │      │ • Title section          │        │
│  │ • Title input            │      │ • Description section    │        │
│  │ • Description textarea   │      │ • Image section          │        │
│  │ • Image picker           │      │ • Staff details          │        │
│  │ • Submit button          │      │ • Timeline               │        │
│  │                          │      │ • Chat button            │        │
│  │ [Upload photo]           │      │                          │        │
│  │ [Submit Complaint]       │      │ [Image displays here]    │        │
│  └──────────────────────────┘      └──────────────────────────┘        │
│           ↓                                    ↑                         │
│      _submitComplaint()              _buildImageSection()               │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────┐
│ LAYER 2: BUSINESS LOGIC                                                 │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  ┌──────────────────────────────────────────────────────────────────┐  │
│  │ ComplaintImageService (Flow Function Pattern)                   │  │
│  ├──────────────────────────────────────────────────────────────────┤  │
│  │                                                                  │  │
│  │  uploadComplaintImage()                                         │  │
│  │  ├─ 🔵 Start operation                                          │  │
│  │  ├─ 📤 Call CloudinaryService.uploadImage()                     │  │
│  │  ├─ 🔗 Get secure URL                                           │  │
│  │  ├─ 💾 Update Firestore with URL                               │  │
│  │  ├─ ✅ Return ComplaintImageResult.success()                    │  │
│  │  └─ ❌ Return ComplaintImageResult.failure() on error           │  │
│  │                                                                  │  │
│  │  fetchComplaintImage()                                          │  │
│  │  ├─ 🔵 Start operation                                          │  │
│  │  ├─ 📖 Read from Firestore                                      │  │
│  │  ├─ ✅ Return URL                                               │  │
│  │  └─ ❌ Return error if not found                                │  │
│  │                                                                  │  │
│  │  streamComplaintImage()                                         │  │
│  │  ├─ 🔵 Setup stream                                             │  │
│  │  ├─ 📡 Listen to Firestore changes                              │  │
│  │  ├─ ✅ Emit URL on each update                                  │  │
│  │  └─ ❌ Emit error on failure                                    │  │
│  │                                                                  │  │
│  └──────────────────────────────────────────────────────────────────┘  │
│                                                                          │
│  ┌──────────────────────────────────────────────────────────────────┐  │
│  │ CloudinaryService                                                │  │
│  ├──────────────────────────────────────────────────────────────────┤  │
│  │                                                                  │  │
│  │  uploadImage(imagePath, folder)                                 │  │
│  │  ├─ Compress image (800x800, 85% quality)                       │  │
│  │  ├─ Create MultipartRequest                                     │  │
│  │  ├─ Add file + credentials                                      │  │
│  │  ├─ Send to Cloudinary API                                      │  │
│  │  └─ Return secure_url                                           │  │
│  │                                                                  │  │
│  │  deleteImage(publicId)                                          │  │
│  │  ├─ Create delete request                                       │  │
│  │  ├─ Send to Cloudinary API                                      │  │
│  │  └─ Return success/failure                                      │  │
│  │                                                                  │  │
│  └──────────────────────────────────────────────────────────────────┘  │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────┐
│ LAYER 3: EXTERNAL SERVICES                                              │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  ┌──────────────────────────┐      ┌──────────────────────────┐        │
│  │ Cloudinary API           │      │ Firebase Firestore       │        │
│  ├──────────────────────────┤      ├──────────────────────────┤        │
│  │ • Upload endpoint        │      │ • complaints collection  │        │
│  │ • Delete endpoint        │      │ • Document fields:       │        │
│  │ • Secure URL generation  │      │   - imageUrl             │        │
│  │ • Image storage          │      │   - imageUploadedAt      │        │
│  │ • CDN delivery           │      │   - imageUploadedBy      │        │
│  │                          │      │ • Real-time streaming    │        │
│  │ https://api.cloudinary   │      │ • Document snapshots     │        │
│  │ .com/v1_1/de8yccofb/     │      │                          │        │
│  │ image/upload             │      │ https://firestore        │        │
│  │                          │      │ .googleapis.com/          │        │
│  └──────────────────────────┘      └──────────────────────────┘        │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## 📊 DATA FLOW DIAGRAM

```
┌─────────────────────────────────────────────────────────────────────────┐
│ STEP 1: USER CREATES COMPLAINT WITH IMAGE                              │
└─────────────────────────────────────────────────────────────────────────┘

User Input:
  ├─ Category: "Plumbing"
  ├─ Title: "Broken tap"
  ├─ Description: "Water leaking..."
  └─ Image: /storage/emulated/0/Pictures/photo.jpg

                            ↓

Form Validation:
  ├─ Category selected? ✓
  ├─ Title filled? ✓
  ├─ Description filled? ✓
  └─ Image picked? ✓

                            ↓

┌─────────────────────────────────────────────────────────────────────────┐
│ STEP 2: CREATE COMPLAINT IN FIRESTORE                                  │
└─────────────────────────────────────────────────────────────────────────┘

ComplaintsService.createComplaint()
  ├─ Create document in complaints collection
  ├─ Set fields:
  │  ├─ title: "Broken tap"
  │  ├─ description: "Water leaking..."
  │  ├─ category: "plumbing"
  │  ├─ status: "pending"
  │  ├─ createdDate: Timestamp
  │  ├─ createdBy: "user_123"
  │  └─ updatedAt: Timestamp
  └─ Return complaint object with ID

                            ↓

Firestore Document Created:
  complaints/complaint_abc123/
    ├─ title: "Broken tap"
    ├─ description: "Water leaking..."
    ├─ category: "plumbing"
    ├─ status: "pending"
    ├─ createdDate: 2024-03-14T10:30:00Z
    ├─ createdBy: "user_123"
    └─ updatedAt: 2024-03-14T10:30:00Z

                            ↓

┌─────────────────────────────────────────────────────────────────────────┐
│ STEP 3: UPLOAD IMAGE TO CLOUDINARY                                     │
└─────────────────────────────────────────────────────────────────────────┘

ComplaintImageService.uploadComplaintImage()
  ├─ 🔵 Start upload
  ├─ Call CloudinaryService.uploadImage()
  │  ├─ Read image file
  │  ├─ Compress to 800x800, 85% quality
  │  ├─ Create MultipartRequest
  │  ├─ Add file + credentials
  │  ├─ POST to Cloudinary API
  │  └─ Return secure_url
  └─ Get URL: https://res.cloudinary.com/de8yccofb/image/upload/v1234567890/complaints/abc123.jpg

                            ↓

Cloudinary Storage:
  ├─ Folder: complaints
  ├─ File: abc123.jpg
  ├─ URL: https://res.cloudinary.com/de8yccofb/image/upload/v1234567890/complaints/abc123.jpg
  ├─ Size: ~150KB (compressed)
  └─ Format: JPEG

                            ↓

┌─────────────────────────────────────────────────────────────────────────┐
│ STEP 4: STORE URL IN FIRESTORE                                         │
└─────────────────────────────────────────────────────────────────────────┘

ComplaintImageService.uploadComplaintImage()
  ├─ Update complaint document
  ├─ Set fields:
  │  ├─ imageUrl: "https://res.cloudinary.com/de8yccofb/image/upload/..."
  │  ├─ imageUploadedAt: Timestamp
  │  ├─ imageUploadedBy: "user_123"
  │  └─ updatedAt: Timestamp
  └─ Return ComplaintImageResult.success()

                            ↓

Firestore Document Updated:
  complaints/complaint_abc123/
    ├─ title: "Broken tap"
    ├─ description: "Water leaking..."
    ├─ category: "plumbing"
    ├─ status: "pending"
    ├─ createdDate: 2024-03-14T10:30:00Z
    ├─ createdBy: "user_123"
    ├─ imageUrl: "https://res.cloudinary.com/de8yccofb/image/upload/..."
    ├─ imageUploadedAt: 2024-03-14T10:31:00Z
    ├─ imageUploadedBy: "user_123"
    └─ updatedAt: 2024-03-14T10:31:00Z

                            ↓

┌─────────────────────────────────────────────────────────────────────────┐
│ STEP 5: SHOW SUCCESS & CLOSE MODAL                                     │
└─────────────────────────────────────────────────────────────────────────┘

User Feedback:
  ├─ ✅ Success message: "Complaint submitted successfully!"
  ├─ Modal closes
  ├─ Complaint list refreshes
  └─ New complaint appears in list

                            ↓

┌─────────────────────────────────────────────────────────────────────────┐
│ STEP 6: USER OPENS COMPLAINT DETAIL MODAL                              │
└─────────────────────────────────────────────────────────────────────────┘

User Action:
  └─ Taps on complaint in list

                            ↓

Modal Opens:
  ├─ Loads complaint data
  ├─ StreamBuilder connects to Firestore
  └─ Listens for real-time updates

                            ↓

┌─────────────────────────────────────────────────────────────────────────┐
│ STEP 7: STREAM IMAGE FROM FIRESTORE                                    │
└─────────────────────────────────────────────────────────────────────────┘

ComplaintImageService.streamComplaintImage()
  ├─ 🔵 Setup stream
  ├─ Listen to complaints/complaint_abc123
  ├─ On each update:
  │  ├─ Get imageUrl field
  │  ├─ Emit ComplaintImageResult.success()
  │  └─ Trigger rebuild
  └─ On error:
     ├─ Emit ComplaintImageResult.failure()
     └─ Show error state

                            ↓

StreamBuilder Receives Update:
  ├─ imageUrl: "https://res.cloudinary.com/de8yccofb/image/upload/..."
  ├─ Trigger rebuild
  └─ Call _buildImageSection()

                            ↓

┌─────────────────────────────────────────────────────────────────────────┐
│ STEP 8: DISPLAY IMAGE                                                  │
└─────────────────────────────────────────────────────────────────────────┘

_buildImageSection() Renders:
  ├─ Show "Attached Image" label
  ├─ Create CachedNetworkImage widget
  ├─ Load image from Cloudinary URL
  ├─ Show loading spinner (1-3 seconds)
  ├─ Display image when ready
  └─ Cache for future loads

                            ↓

User Sees:
  ├─ "Attached Image" section
  ├─ Image from Cloudinary
  ├─ Properly sized and formatted
  └─ Ready for interaction

                            ↓

┌─────────────────────────────────────────────────────────────────────────┐
│ STEP 9: REAL-TIME UPDATES (OPTIONAL)                                   │
└─────────────────────────────────────────────────────────────────────────┘

If Admin Updates Image:
  ├─ Admin uploads new image
  ├─ Firestore document updates
  ├─ StreamBuilder detects change
  ├─ _buildImageSection() rebuilds
  ├─ New image loads from Cloudinary
  └─ User sees update automatically (no refresh needed)
```

---

## 🔄 STATE MANAGEMENT FLOW

```
┌──────────────────────────────────────────────────────────────────┐
│ CREATE COMPLAINT MODAL STATE                                     │
├──────────────────────────────────────────────────────────────────┤
│                                                                  │
│ _selectedCategory: ComplaintCategory?                           │
│   ├─ null (initial)                                             │
│   └─ ComplaintCategory.plumbing (after selection)               │
│                                                                  │
│ _attachedImage: File?                                           │
│   ├─ null (initial)                                             │
│   └─ File('/storage/.../photo.jpg') (after pick)                │
│                                                                  │
│ _isSubmitting: bool                                             │
│   ├─ false (initial)                                            │
│   ├─ true (during submission)                                   │
│   └─ false (after completion)                                   │
│                                                                  │
│ _errors: Map<String, String?>                                  │
│   ├─ {} (initial)                                               │
│   ├─ {'category': 'Please select'} (validation error)           │
│   └─ {} (after fix)                                             │
│                                                                  │
└──────────────────────────────────────────────────────────────────┘

                            ↓

┌──────────────────────────────────────────────────────────────────┐
│ COMPLAINT DETAIL MODAL STATE                                     │
├──────────────────────────────────────────────────────────────────┤
│                                                                  │
│ StreamBuilder<DocumentSnapshot>                                 │
│   ├─ connectionState: waiting                                   │
│   ├─ data: null                                                 │
│   ├─ connectionState: active                                    │
│   ├─ data: DocumentSnapshot                                     │
│   │  └─ imageUrl: "https://res.cloudinary.com/..."              │
│   └─ On update:                                                 │
│      └─ Rebuild with new data                                   │
│                                                                  │
│ CachedNetworkImage State                                        │
│   ├─ Loading: Show spinner                                      │
│   ├─ Loaded: Show image                                         │
│   └─ Error: Show error icon                                     │
│                                                                  │
└──────────────────────────────────────────────────────────────────┘
```

---

## 🎯 ERROR HANDLING FLOW

```
┌──────────────────────────────────────────────────────────────────┐
│ ERROR SCENARIOS & HANDLING                                       │
├──────────────────────────────────────────────────────────────────┤
│                                                                  │
│ 1. IMAGE FILE NOT FOUND                                         │
│    ├─ CloudinaryService detects missing file                    │
│    ├─ Throws Exception                                          │
│    ├─ ComplaintImageService catches error                       │
│    ├─ Returns ComplaintImageResult.failure()                    │
│    ├─ _submitComplaint() logs error                             │
│    └─ User sees warning (complaint still created)               │
│                                                                  │
│ 2. CLOUDINARY UPLOAD FAILS                                      │
│    ├─ Network error or API error                                │
│    ├─ CloudinaryService throws Exception                        │
│    ├─ ComplaintImageService catches error                       │
│    ├─ Returns ComplaintImageResult.failure()                    │
│    ├─ _submitComplaint() logs error                             │
│    └─ User sees warning (complaint still created)               │
│                                                                  │
│ 3. FIRESTORE UPDATE FAILS                                       │
│    ├─ Permission denied or network error                        │
│    ├─ ComplaintImageService catches error                       │
│    ├─ Returns ComplaintImageResult.failure()                    │
│    ├─ _submitComplaint() logs error                             │
│    └─ User sees warning (complaint still created)               │
│                                                                  │
│ 4. IMAGE NOT FOUND IN FIRESTORE                                 │
│    ├─ StreamBuilder receives null imageUrl                      │
│    ├─ _buildImageSection() returns SizedBox.shrink()            │
│    ├─ No image section shown                                    │
│    └─ Complaint displays normally                               │
│                                                                  │
│ 5. NETWORK TIMEOUT                                              │
│    ├─ CloudinaryService has 60-second timeout                   │
│    ├─ Throws timeout exception                                  │
│    ├─ ComplaintImageService catches error                       │
│    ├─ Returns ComplaintImageResult.failure()                    │
│    └─ User sees error message                                   │
│                                                                  │
└──────────────────────────────────────────────────────────────────┘
```

---

## 📱 UI COMPONENT HIERARCHY

```
ComplaintDetailModal
├─ StreamBuilder<DocumentSnapshot>
│  └─ Center
│     └─ Container (modal background)
│        └─ Material
│           └─ Column
│              ├─ _buildHeader()
│              │  └─ Header with close button
│              │
│              ├─ Flexible
│              │  └─ SingleChildScrollView
│              │     └─ Column
│              │        ├─ _buildTitleSection()
│              │        ├─ _buildDescriptionSection()
│              │        ├─ _buildImageSection() ← IMAGE DISPLAY
│              │        │  └─ StreamBuilder<DocumentSnapshot>
│              │        │     └─ Column
│              │        │        ├─ Text("Attached Image")
│              │        │        └─ ClipRRect
│              │        │           └─ CachedNetworkImage
│              │        │              ├─ Loading: CircularProgressIndicator
│              │        │              ├─ Loaded: Image
│              │        │              └─ Error: Icon
│              │        │
│              │        ├─ _buildStaffDetailsSection()
│              │        └─ _buildTimelineSection()
│              │
│              └─ _buildCTAButton()
│                 └─ PrimaryButton or status message
```

---

## 🔐 SECURITY FLOW

```
┌──────────────────────────────────────────────────────────────────┐
│ SECURITY CHECKS                                                  │
├──────────────────────────────────────────────────────────────────┤
│                                                                  │
│ 1. USER AUTHENTICATION                                          │
│    ├─ User must be logged in                                    │
│    ├─ Firebase Auth validates user                              │
│    ├─ User ID stored in imageUploadedBy                         │
│    └─ Only authenticated users can upload                       │
│                                                                  │
│ 2. IMAGE VALIDATION                                             │
│    ├─ File must exist                                           │
│    ├─ File must be image format                                 │
│    ├─ Size limited to 800x800 pixels                            │
│    ├─ Quality compressed to 85%                                 │
│    └─ Prevents large/invalid files                              │
│                                                                  │
│ 3. FIRESTORE SECURITY RULES                                     │
│    ├─ Users can only upload for their own complaints            │
│    ├─ Admins can view all images                                │
│    ├─ Images deleted when complaint deleted                     │
│    └─ Prevents unauthorized access                              │
│                                                                  │
│ 4. CLOUDINARY SECURITY                                          │
│    ├─ API key required for upload                               │
│    ├─ Folder structure: complaints/                             │
│    ├─ Secure HTTPS URLs only                                    │
│    └─ CDN delivery with caching                                 │
│                                                                  │
│ 5. DATA PRIVACY                                                 │
│    ├─ Images stored in Cloudinary (external)                    │
│    ├─ URLs stored in Firestore                                  │
│    ├─ User ID tracked for audit                                 │
│    └─ Timestamps recorded for tracking                          │
│                                                                  │
└──────────────────────────────────────────────────────────────────┘
```

---

## 📊 PERFORMANCE OPTIMIZATION

```
┌──────────────────────────────────────────────────────────────────┐
│ OPTIMIZATION TECHNIQUES                                          │
├──────────────────────────────────────────────────────────────────┤
│                                                                  │
│ 1. IMAGE COMPRESSION                                            │
│    ├─ Resize to 800x800 pixels                                  │
│    ├─ Compress to 85% quality                                   │
│    ├─ Reduces file size by ~80%                                 │
│    └─ Faster upload and download                                │
│                                                                  │
│ 2. CACHING                                                      │
│    ├─ CachedNetworkImage caches images locally                  │
│    ├─ Subsequent loads are instant                              │
│    ├─ Reduces bandwidth usage                                   │
│    └─ Better offline experience                                 │
│                                                                  │
│ 3. LAZY LOADING                                                 │
│    ├─ Image section only renders if URL exists                  │
│    ├─ No unnecessary widgets created                            │
│    ├─ Faster modal opening                                      │
│    └─ Better memory usage                                       │
│                                                                  │
│ 4. REAL-TIME STREAMING                                          │
│    ├─ StreamBuilder only rebuilds on changes                    │
│    ├─ No polling or manual refresh                              │
│    ├─ Efficient Firestore queries                               │
│    └─ Real-time updates without overhead                        │
│                                                                  │
│ 5. ASYNC OPERATIONS                                             │
│    ├─ Image upload happens in background                        │
│    ├─ UI remains responsive                                     │
│    ├─ User can continue using app                               │
│    └─ Better user experience                                    │
│                                                                  │
└──────────────────────────────────────────────────────────────────┘
```

---

## ✨ SUMMARY

This visual diagram shows:
- ✅ Complete architecture with 3 layers
- ✅ Data flow from user input to display
- ✅ State management for both modals
- ✅ Error handling scenarios
- ✅ UI component hierarchy
- ✅ Security measures
- ✅ Performance optimizations

All components work together seamlessly to provide a smooth image upload and display experience.
