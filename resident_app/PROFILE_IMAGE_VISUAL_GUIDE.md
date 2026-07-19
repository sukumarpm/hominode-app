# Profile Image Implementation - Visual Guide

## ARCHITECTURE DIAGRAM

```
┌──────────────────────────────────────────────────────────────┐
│                    USER INTERFACE                            │
├──────────────────────────────────────────────────────────────┤
│                                                               │
│  Profile Screen                    Edit Profile Screen       │
│  ┌─────────────────────┐          ┌──────────────────────┐   │
│  │ StreamBuilder       │          │ Image Picker         │   │
│  │ ├─ Loading spinner  │          │ ├─ Camera            │   │
│  │ ├─ Image display    │          │ └─ Gallery           │   │
│  │ └─ Error fallback   │          │                      │   │
│  └─────────────────────┘          │ Upload Button        │   │
│                                    └──────────────────────┘   │
│                                                               │
└──────────────────────────────────────────────────────────────┘
                            ↓
┌──────────────────────────────────────────────────────────────┐
│                    SERVICES LAYER                            │
├──────────────────────────────────────────────────────────────┤
│                                                               │
│  ProfileImageService                                         │
│  ├─ uploadProfileImage()                                     │
│  │  └─ Calls CloudinaryService.uploadImage()                │
│  │                                                            │
│  ├─ fetchProfileImage()                                      │
│  │  └─ Queries Firestore once                               │
│  │                                                            │
│  └─ streamProfileImage() ← USED IN PROFILE SCREEN           │
│     └─ Streams Firestore in real-time                       │
│                                                               │
│  CloudinaryService                                           │
│  ├─ uploadImage()                                            │
│  │  └─ POST to Cloudinary API                               │
│  │                                                            │
│  └─ deleteImage()                                            │
│     └─ DELETE from Cloudinary                               │
│                                                               │
└──────────────────────────────────────────────────────────────┘
                            ↓
┌──────────────────────────────────────────────────────────────┐
│                    DATA LAYER                                │
├──────────────────────────────────────────────────────────────┤
│                                                               │
│  Firestore Database                                          │
│  └─ users/{userId}                                           │
│     ├─ name                                                  │
│     ├─ email                                                 │
│     ├─ phone                                                 │
│     ├─ profileImage ← URL from Cloudinary                    │
│     ├─ profileImageUrl ← URL from Cloudinary                 │
│     └─ profileImageUpdatedAt ← Timestamp                     │
│                                                               │
│  Cloudinary CDN                                              │
│  └─ /profile_pictures/user_{userId}.jpg                      │
│     └─ Actual image file                                     │
│                                                               │
└──────────────────────────────────────────────────────────────┘
```

## FLOW SEQUENCE

### Upload Sequence
```
User selects image
    ↓
ImagePicker opens
    ↓
User chooses photo
    ↓
ProfileImageService.uploadProfileImage()
    ├─ CloudinaryService.uploadImage()
    │  ├─ POST to Cloudinary API
    │  └─ Returns secure_url
    │
    └─ Save URL to Firestore
       ├─ users/{userId}/profileImage = url
       ├─ users/{userId}/profileImageUrl = url
       └─ users/{userId}/profileImageUpdatedAt = now
    ↓
Success message shown
    ↓
Edit Profile closes
```

### Display Sequence
```
Profile Screen loads
    ↓
_loadUserProfile() called
    ├─ Fetch user data from Firestore
    └─ Capture userId from SharedPreferences
    ↓
_buildHeader() called
    ├─ Create StreamBuilder
    └─ Pass userId to streamProfileImage()
    ↓
StreamBuilder listens to Firestore
    ├─ Loading: Show spinner
    ├─ Data received: Show image
    └─ Error: Show placeholder
    ↓
Image displays in CircleAvatar
    ├─ Source: Cloudinary URL
    └─ Real-time updates on changes
```

## STATE MANAGEMENT

### Profile Screen State
```dart
class _ProfileScreenState extends State<ProfileScreen> {
  String? _userId;              // ← Captured from SharedPreferences
  Map<String, dynamic>? _userProfile;
  bool _isLoading = true;
  
  // StreamBuilder uses _userId to fetch image
  StreamBuilder<ProfileImageResult>(
    stream: ProfileImageService.instance.streamProfileImage(
      userId: _userId!,  // ← Passed here
    ),
    builder: (context, snapshot) {
      // Handle states
    },
  )
}
```

## RESULT CLASS PATTERN

```dart
class ProfileImageResult {
  final bool success;
  final String? message;
  final String? imageUrl;
  final String? errorCode;
  
  // Success: success=true, imageUrl="https://..."
  // Failure: success=false, message="error", errorCode="CODE"
}
```

## LOGGING FLOW

```
Upload:
  🔵 Starting upload
  📤 Uploading to Cloudinary
  ✅ Upload successful
  🔗 URL received
  💾 Saving to Firestore
  ✅ Firestore saved

Display:
  🔵 Stream update
  ⏳ Loading...
  ✅ Image URL received
  
Error:
  ❌ Error occurred
  ⚠️ Warning message
```

## KEY COMPONENTS

### 1. ProfileImageService
- Singleton pattern
- Three methods: upload, fetch, stream
- Returns ProfileImageResult
- Proper error handling

### 2. CloudinaryService
- Static methods
- Handles API calls
- Returns image URLs
- Supports deletion

### 3. StreamBuilder
- Listens to Firestore
- Updates UI automatically
- Handles loading/error states
- No manual refresh needed

### 4. CircleAvatar
- Displays image from URL
- Shows spinner while loading
- Shows icon if no image
- Handles network errors

## COMPLETE CODE FLOW

```dart
// 1. Profile Screen loads
@override
void initState() {
  _loadUserProfile();  // Captures userId
}

// 2. Build header with StreamBuilder
Widget _buildHeader() {
  return StreamBuilder<ProfileImageResult>(
    stream: ProfileImageService.instance.streamProfileImage(
      userId: _userId!,
    ),
    builder: (context, snapshot) {
      // 3. Handle states
      if (snapshot.connectionState == ConnectionState.waiting) {
        return CircleAvatar(child: CircularProgressIndicator());
      }
      
      if (snapshot.hasData && snapshot.data!.success) {
        return CircleAvatar(
          backgroundImage: NetworkImage(snapshot.data!.imageUrl!),
        );
      }
      
      return CircleAvatar(child: Icon(Icons.person));
    },
  );
}

// 4. Edit Profile uploads
Future<void> _handleSave() {
  final result = await ProfileImageService.instance
    .uploadProfileImage(imagePath: _photoFile!.path);
  
  if (result.success) {
    // Image uploaded and saved to Firestore
    // Profile Screen StreamBuilder automatically updates
  }
}
```

## TESTING FLOW

```
1. Open Edit Profile
   ↓
2. Upload image
   ↓
3. Verify Cloudinary upload (console logs)
   ↓
4. Verify Firestore save (Firebase Console)
   ↓
5. Close Edit Profile
   ↓
6. Profile Screen shows image
   ↓
7. Upload different image
   ↓
8. Profile Screen updates automatically
```

## SUMMARY

✅ Upload: Image → Cloudinary → Firestore
✅ Display: Firestore → StreamBuilder → CircleAvatar
✅ Real-time: StreamBuilder listens to Firestore
✅ Error handling: Graceful fallbacks
✅ Logging: Complete flow function pattern
