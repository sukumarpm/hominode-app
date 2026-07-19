# Multi-Language Testing Guide

## Quick Start

### 1. Build and Run
```bash
cd resident_app
flutter clean
flutter pub get
flutter run -d ZA222LQT6V
```

### 2. Navigate to Settings
- Tap the Profile/Settings icon in the bottom navigation
- Scroll down to "Settings" card
- Tap "Settings"

### 3. Test Language Switching
In the Settings screen, you'll see the Language section with 5 language options:
- English (en)
- Tamil (ta)
- Hindi (hi)
- Spanish (es)
- العربية (ar) - Arabic

### 4. Tap a Language
- Tap on "Tamil" (or any language)
- Observe the app UI update instantly
- No restart required

### 5. Verify Profile Screen Updates
- Go back to Profile screen
- Check that:
  - Full name displays in selected language
  - Phone number displays in selected language
  - Flat number displays in selected language
  - All UI text updates to selected language

---

## Detailed Test Cases

### Test Case 1: English to Tamil
**Steps**:
1. App opens in English (default)
2. Go to Settings → Language
3. Tap "Tamil"
4. Observe UI changes to Tamil
5. Go to Profile screen
6. Verify all text is in Tamil

**Expected Result**: ✅ All UI updates to Tamil instantly

---

### Test Case 2: Language Persistence
**Steps**:
1. Select "Hindi" language
2. Close app completely
3. Reopen app
4. Check current language

**Expected Result**: ✅ App opens in Hindi (persisted)

---

### Test Case 3: RTL Support (Arabic)
**Steps**:
1. Go to Settings → Language
2. Tap "العربية" (Arabic)
3. Observe text direction changes to RTL
4. Check all UI elements align correctly

**Expected Result**: ✅ Text flows right-to-left, UI elements reflow

---

### Test Case 4: Profile Screen Rebuild
**Steps**:
1. Open Profile screen
2. Go to Settings
3. Change language to Spanish
4. Return to Profile screen
5. Check if full name and other text updated

**Expected Result**: ✅ Profile screen shows Spanish text

---

### Test Case 5: All Languages
**Steps**:
1. Cycle through all 5 languages
2. For each language:
   - Verify UI updates
   - Check Profile screen
   - Verify no errors

**Expected Result**: ✅ All 5 languages work correctly

---

## What to Look For

### ✅ Correct Behavior
- Language changes instantly (no restart)
- Profile screen rebuilds with new language
- Text direction changes for Arabic
- Language persists after app restart
- No console errors

### ❌ Issues to Report
- UI doesn't update when language changes
- Profile screen doesn't rebuild
- Text overlaps or misaligns
- Language doesn't persist
- Console shows errors

---

## Console Output to Expect

When language changes, you should see:
```
✅ Language changed to: ta
✅ Loaded translations for: ta
```

When profile loads:
```
🔵 ProfileScreen: Loading user profile from Firestore...
✅ ProfileScreen: User data loaded successfully
✅ ProfileScreen: UI updated with data
```

---

## Troubleshooting

### Issue: App crashes on language change
**Check**: 
- Are all translation JSON files present?
- Are translation keys valid?
- Check console for error messages

### Issue: Profile screen doesn't update
**Check**:
- Is profile_screen.dart wrapped with Consumer<LocalizationProvider>?
- Is LanguageProvider properly initialized in main.dart?

### Issue: Language doesn't persist
**Check**:
- Is SharedPreferences initialized?
- Check device storage permissions

### Issue: Arabic text doesn't flow RTL
**Check**:
- Is Directionality widget in main.dart?
- Is isRTL property working in LanguageProvider?

---

## Device Testing

### Recommended Devices
- Motorola Edge 50 Fusion (ZA222LQT6V) - Your device
- Any Android 8.0+ device
- Any iOS 12.0+ device

### Test on Multiple Devices
If possible, test on:
- Phone (portrait mode)
- Tablet (landscape mode)
- Different screen sizes

---

## Performance Checks

### Expected Performance
- Language switch: < 100ms
- Profile screen rebuild: < 200ms
- App startup: < 2 seconds

### Monitor
- Check for jank or stuttering
- Monitor memory usage
- Check CPU usage during language switch

---

## Final Verification

Before considering complete:
- [ ] All 5 languages work
- [ ] Language persists after restart
- [ ] Profile screen updates on language change
- [ ] Arabic RTL works correctly
- [ ] No console errors
- [ ] No UI overlaps or misalignment
- [ ] Performance is smooth

---

## Success Criteria

✅ **Complete when**:
1. Language switching works instantly
2. Profile screen rebuilds with new language
3. Language persists across app restarts
4. All 5 languages display correctly
5. Arabic RTL layout works
6. No compilation or runtime errors

---

## Next Steps After Testing

If all tests pass:
1. Document any issues found
2. Create bug reports if needed
3. Proceed to integrate translations in other screens
4. Replace hardcoded strings with `tr()` calls

If issues found:
1. Check console output
2. Review error messages
3. Verify file structure
4. Check LanguageProvider initialization
