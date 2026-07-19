# Test Onboarding Flow - Quick Guide

## 🚀 Test the Complete Flow Now

### Step 1: Clear App Data (Reset to First Time User)
```bash
cd resident_app
flutter clean
flutter run
```

### Step 2: Watch the Flow
You should see this sequence:

```
1. SPLASH SCREEN (3 seconds)
   - Lyvo logo appears
   - "Your Community, Connected" tagline
   - Smooth fade animation

2. ONBOARDING SCREEN 1 (Welcome to Lyvo)
   - Blue gradient card with apartment icon
   - "Welcome to Lyvo" title
   - Subtitle about apartment management
   - "Skip" button top-right
   - "Next" button at bottom
   - Progress dots: ● ○ ○ ○

3. ONBOARDING SCREEN 2 (Visitor Management)
   - Blue gradient card with people icon
   - "Visitor Management" title
   - Subtitle about pre-approving visitors
   - Progress dots: ○ ● ○ ○

4. ONBOARDING SCREEN 3 (Stay Updated)
   - Blue gradient card with bell icon
   - "Stay Updated" title
   - Subtitle about notifications
   - Progress dots: ○ ○ ● ○

5. ONBOARDING SCREEN 4 (Safe & Secure)
   - Blue gradient card with shield icon
   - "Safe & Secure" title
   - Subtitle about data protection
   - "Get Started" button (instead of "Next")
   - Progress dots: ○ ○ ○ ●

6. LOGIN SCREEN
   - Phone number input
   - "Continue with Phone" button
   - "Create Account" link
```

---

## ✅ What to Test

### Onboarding Interactions
- [ ] Swipe left to go to next screen
- [ ] Swipe right to go to previous screen
- [ ] Tap "Next" button to advance
- [ ] Tap "Skip" button (should show snackbar and go to login)
- [ ] Tap "Get Started" on final screen (should go to login)
- [ ] Progress dots update correctly
- [ ] Animations are smooth (card entrance, page transitions)

### State Persistence
- [ ] Complete onboarding flow
- [ ] Close the app completely
- [ ] Reopen the app
- [ ] Onboarding should NOT show again (goes directly to login)

### Skip Functionality
- [ ] Clear app data: `flutter clean && flutter run`
- [ ] Wait for splash to finish
- [ ] Tap "Skip" on first onboarding screen
- [ ] Should show "Intro skipped" snackbar
- [ ] Should navigate to login screen
- [ ] Close and reopen app
- [ ] Onboarding should NOT show again

---

## 🎯 Expected Behavior

### First Time User
```
App Launch → Splash (3s) → Onboarding (4 screens) → Login
```

### Second Time (After Completing Onboarding)
```
App Launch → Splash (3s) → Login (skips onboarding)
```

### Logged In User
```
App Launch → Splash (3s) → Home (skips onboarding and login)
```

---

## 🔄 Reset for Testing

### Method 1: Flutter Clean (Recommended)
```bash
flutter clean
flutter run
```
This completely resets the app and clears all data.

### Method 2: Uninstall App
```bash
# On Android device/emulator
adb uninstall com.example.resident_app

# Then reinstall
flutter run
```

### Method 3: Clear App Data (Android)
- Go to Settings → Apps → Lyvo
- Tap "Storage"
- Tap "Clear Data"
- Reopen app

---

## 🎨 Visual Verification

### Check These Elements

**Onboarding Screen 1:**
- [ ] Large blue gradient card (square shape)
- [ ] White apartment icon in center
- [ ] "Welcome to Lyvo" in bold italic
- [ ] Two-line subtitle below
- [ ] "Skip" link in top-right
- [ ] "Next" button at bottom (blue gradient)
- [ ] 4 dots at bottom (first one active/elongated)

**Onboarding Screen 2:**
- [ ] Same card style
- [ ] White people icon
- [ ] "Visitor Management" title
- [ ] Second dot is active

**Onboarding Screen 3:**
- [ ] Same card style
- [ ] White bell icon
- [ ] "Stay Updated" title
- [ ] Third dot is active

**Onboarding Screen 4:**
- [ ] Same card style
- [ ] White shield icon
- [ ] "Safe & Secure" title
- [ ] "Get Started" button (not "Next")
- [ ] Fourth dot is active

---

## 🎬 Animation Checklist

- [ ] Card fades in and scales up on each screen
- [ ] Smooth slide transition when swiping
- [ ] Button scales down slightly when pressed
- [ ] Subtle wave animation in background
- [ ] Progress dots smoothly expand/contract
- [ ] All animations run at 60fps (no lag)

---

## 📱 Test on Different Devices

### iPhone 13 (Primary Target - 390px)
```bash
flutter run -d "iPhone 13"
```
- [ ] Card is properly sized
- [ ] Text is readable
- [ ] Spacing looks correct

### iPhone SE (Smaller - 375px)
```bash
flutter run -d "iPhone SE"
```
- [ ] Card scales down appropriately
- [ ] No content overflow
- [ ] Button remains full-width

### iPad (Larger)
```bash
flutter run -d "iPad"
```
- [ ] Card doesn't get too large
- [ ] Content remains centered
- [ ] Spacing adjusts properly

---

## 🐛 Common Issues & Fixes

### Issue: Onboarding Shows Every Time
**Cause:** SharedPreferences not saving

**Fix:**
```dart
// Check in onboarding_flow.dart
print('Saving onboarding flag...');
await prefs.setBool('onboarding_completed', true);
print('Flag saved: ${prefs.getBool('onboarding_completed')}');
```

### Issue: Onboarding Never Shows
**Cause:** Flag already set

**Fix:**
```bash
flutter clean
flutter run
```

### Issue: Animations Are Choppy
**Cause:** Running in debug mode

**Fix:**
```bash
flutter run --release
```

### Issue: Can't Navigate After Onboarding
**Cause:** Route not defined

**Fix:** Check `/login` route exists in main.dart

---

## 📊 Performance Check

### Frame Rate
- Open DevTools
- Check FPS during animations
- Should maintain 60fps

### Memory Usage
- Check memory usage in DevTools
- Should be ~50-80MB during onboarding

### Load Time
- Onboarding should appear immediately after splash
- No loading delays

---

## ✅ Final Checklist

### Visual
- [ ] All 4 screens display correctly
- [ ] Cards have blue gradient
- [ ] Icons are white and centered
- [ ] Titles are bold italic
- [ ] Subtitles are two lines
- [ ] Skip button visible
- [ ] Progress dots working
- [ ] Button says "Next" on screens 1-3
- [ ] Button says "Get Started" on screen 4

### Functional
- [ ] Swipe navigation works
- [ ] Next button advances
- [ ] Skip button works
- [ ] Get Started navigates to login
- [ ] State persists (doesn't show again)
- [ ] Animations are smooth

### Integration
- [ ] Splash → Onboarding → Login flow works
- [ ] First time users see onboarding
- [ ] Returning users skip onboarding
- [ ] Logged in users go directly to home

---

## 🎉 Success Criteria

✅ **Flow is working if:**
1. First launch shows: Splash → Onboarding → Login
2. Second launch shows: Splash → Login (skips onboarding)
3. All 4 onboarding screens display correctly
4. Animations are smooth
5. Skip and Next buttons work
6. State persists between app launches

---

## 🚀 Quick Test Command

```bash
# Complete test sequence
flutter clean && flutter run

# Then:
# 1. Watch splash screen (3s)
# 2. See onboarding (4 screens)
# 3. Tap through or skip
# 4. Land on login screen
# 5. Close app
# 6. Reopen app
# 7. Verify onboarding is skipped
```

---

**Ready to test?** Run `flutter clean && flutter run` now!
