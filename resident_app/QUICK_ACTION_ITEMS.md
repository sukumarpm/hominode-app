# Quick Action Items - Priority Order

## 🔴 CRITICAL - Fix These First (Day 1)

### 1. Auth Service 2FA Methods
**File**: `lib/src/services/auth_service.dart` (Lines 18-120)
**Time**: 30 minutes
**Action**: Replace stub implementations with Firestore integration
```
- isTwoFactorEnabled() → Query Firestore user document
- verify2FACode() → Validate TOTP code format
- changePassword() → Re-authenticate and update Firebase Auth
```

### 2. Poll Repository
**File**: `lib/src/services/poll_repository.dart` (Lines 34-187)
**Time**: 45 minutes
**Action**: Replace mock data with Firestore queries
```
- fetchPolls() → Query Firestore polls collection
- submitVote() → Update Firestore vote counts
- queueVoteWhenOffline() → Persist to SharedPreferences
- _checkConnectivity() → Use connectivity_plus package
```

### 3. Two Factor Service
**File**: `lib/src/services/two_factor_service.dart`
**Time**: 30 minutes
**Action**: Replace mock implementations with real TOTP
```
- getTwoFactorStatus() → Query Firestore
- verify2FACode() → Validate TOTP code
- setupTwoFactor() → Generate TOTP secret
```

---

## 🟠 HIGH PRIORITY - Fix These Next (Day 1-2)

### 4. Events Repository
**File**: `lib/src/services/events_repository.dart`
**Time**: 20 minutes
**Action**: Replace mock data with Firestore queries
```
- fetchUpcomingEvents() → Query events where date >= now
- fetchPastEvents() → Query events where date < now
- toggleRsvp() → Update Firestore RSVP status
```

### 5. Notices Repository
**File**: `lib/src/services/notices_repository.dart`
**Time**: 15 minutes
**Action**: Replace mock data with Firestore queries
```
- fetchNotices() → Query Firestore notices collection
- Filter by priority if needed
```

### 6. Notification Preferences
**File**: `lib/src/services/notification_preferences_service.dart`
**Time**: 25 minutes
**Action**: Add persistence layer
```
- getAllPreferences() → Load from SharedPreferences + Firestore
- updatePreference() → Save to both SharedPreferences and Firestore
- _syncToBackend() → Implement backend sync
```

---

## 🟡 MEDIUM PRIORITY - Complete These (Day 2-3)

### 7. Image Picker in Edit Profile
**File**: `lib/src/modals/edit_profile_modal.dart`
**Time**: 20 minutes
**Action**: Add image picker functionality
```
- Add image_picker to pubspec.yaml
- Implement _pickImage() method
- Upload to Cloudinary
```

### 8. Edit Complaint Feature
**File**: `lib/src/screens/complaints_screen.dart`
**Time**: 30 minutes
**Action**: Implement edit functionality
```
- Add edit button to complaint card
- Show edit modal with current data
- Update Firestore on save
```

### 9. Share Post Feature
**File**: `lib/src/services/community_service.dart`
**Time**: 15 minutes
**Action**: Implement share functionality
```
- Add share_plus to pubspec.yaml
- Implement sharePost() method
- Test on Android and iOS
```

### 10. Chat with Technician
**File**: `lib/src/screens/chat_with_technician_screen.dart`
**Time**: 45 minutes
**Action**: Complete implementation
```
- Implement real-time messaging
- Add user presence tracking
- Load message history
```

---

## 📦 Dependencies to Add (5 minutes)

Add to `pubspec.yaml`:

```yaml
dependencies:
  # 2FA Support
  totp: ^0.7.0
  
  # Connectivity
  connectivity_plus: ^5.0.0
  
  # Image Picker
  image_picker: ^1.0.0
  
  # Share
  share_plus: ^7.0.0
  
  # Offline Support
  hive: ^2.2.0
  hive_flutter: ^1.1.0
  
  # Dependency Injection
  get_it: ^7.6.0
```

Then run: `flutter pub get`

---

## 🗄️ Firestore Setup (10 minutes)

Create these collections in Firebase Console:

### 1. polls
```
- id (string)
- question (string)
- options (array of objects)
  - id (string)
  - label (string)
  - votes (number)
- totalVotes (number)
- status (string: "open", "closed")
- createdAt (timestamp)
- expiresAt (timestamp)
```

### 2. events
```
- id (string)
- title (string)
- description (string)
- imageUrl (string)
- date (timestamp)
- startTime (string)
- endTime (string)
- location (string)
- attendees (number)
- capacity (number)
```

### 3. notices
```
- id (string)
- title (string)
- excerpt (string)
- fullContent (string)
- date (timestamp)
- priority (string: "high", "medium", "low")
```

---

## ✅ Testing Checklist

### After Each Fix
- [ ] No compilation errors
- [ ] No runtime errors
- [ ] Feature works as expected
- [ ] Error handling works
- [ ] Offline mode works (if applicable)

### Before Deployment
- [ ] All 10 issues fixed
- [ ] All tests passing
- [ ] No console errors
- [ ] Performance acceptable
- [ ] All features working

---

## 📊 Progress Tracking

### Day 1 (Critical Issues)
- [ ] Auth Service 2FA - 30 min
- [ ] Poll Repository - 45 min
- [ ] Two Factor Service - 30 min
- [ ] Add Dependencies - 5 min
- [ ] Create Firestore Collections - 10 min
**Total**: ~2 hours

### Day 2 (High Priority Issues)
- [ ] Events Repository - 20 min
- [ ] Notices Repository - 15 min
- [ ] Notification Preferences - 25 min
- [ ] Image Picker - 20 min
- [ ] Testing - 1 hour
**Total**: ~2 hours

### Day 3 (Medium Priority Issues)
- [ ] Edit Complaint - 30 min
- [ ] Share Post - 15 min
- [ ] Chat with Technician - 45 min
- [ ] Comprehensive Testing - 2 hours
**Total**: ~3.5 hours

**Grand Total**: ~7.5 hours (1 day for experienced developer)

---

## 🚀 Deployment Steps

1. **Prepare** (30 min)
   - [ ] Apply all fixes
   - [ ] Update dependencies
   - [ ] Create Firestore collections
   - [ ] Deploy security rules

2. **Test** (1 hour)
   - [ ] Run all unit tests
   - [ ] Run integration tests
   - [ ] Manual testing on devices
   - [ ] Check error logs

3. **Build** (15 min)
   - [ ] Build APK for Android
   - [ ] Build IPA for iOS
   - [ ] Sign with production keys

4. **Deploy** (30 min)
   - [ ] Upload to Play Store
   - [ ] Upload to App Store
   - [ ] Monitor crash reports
   - [ ] Check user feedback

---

## 📝 Documentation Files

All documentation has been created:

1. ✅ `COMPREHENSIVE_APP_CLEANUP_REPORT.md` - Overview of all fixes
2. ✅ `APP_FIXES_IMPLEMENTATION_GUIDE.md` - Detailed implementation guide
3. ✅ `FINAL_APP_STATUS_REPORT.md` - Complete audit report
4. ✅ `QUICK_ACTION_ITEMS.md` - This file (priority checklist)

---

## 💡 Tips for Success

1. **Start with Critical Issues** - These block other features
2. **Test After Each Fix** - Catch errors early
3. **Use the Implementation Guide** - Copy-paste code examples
4. **Follow the Priority Order** - Don't skip ahead
5. **Keep Error Logs Open** - Monitor for issues
6. **Commit After Each Fix** - Easy rollback if needed
7. **Document Changes** - Update comments in code

---

## 🆘 If You Get Stuck

1. Check `APP_FIXES_IMPLEMENTATION_GUIDE.md` for code examples
2. Review `FINAL_APP_STATUS_REPORT.md` for detailed explanations
3. Check Firebase documentation for Firestore queries
4. Test with mock data first, then integrate real data
5. Use debugPrint() for debugging

---

## ✨ Success Criteria

- [ ] All 10 issues fixed
- [ ] No compilation errors
- [ ] No runtime errors
- [ ] All features working
- [ ] Tests passing
- [ ] Performance acceptable
- [ ] Ready for production

**You've got this! 🎉**
