# Auth Flow Test Guide ✅

## Complete Authentication Flow (No OTP)

### Flow Overview
```
Splash Screen (3s)
    ↓
Login Screen
    ├─→ Click "Login" → Home/Dashboard
    └─→ Click "Register" → Create Account Screen
                              ↓
                         Fill Form + Click "Continue"
                              ↓
                         Success Message
                              ↓
                         Home/Dashboard
```

## Testing Steps

### 1. Start App
- **Hot restart** your app
- Splash screen appears with:
  - Blue gradient background
  - Logo fade-in animation
  - "Lyvo" and tagline
  - Pulsing loading dots
  - Duration: 3 seconds

### 2. Login Screen
After splash completes, you'll see:
- Blue gradient background
- White card with "Login" form
- Mobile number input field
- "Login" button
- **"Don't have an account? Register"** link at bottom

### 3. Test Registration Flow

#### Step A: Click "Register"
- Tap on the **"Register"** text (blue color)
- Create Account screen appears

#### Step B: Create Account Screen
You should see:
- ✅ Blue gradient header with back arrow
- ✅ "Create Account" title in header
- ✅ "Enter your details to register" heading
- ✅ Four input fields:
  1. Full Name
  2. Phone Number (with +91 placeholder)
  3. Block and Flat Number (side-by-side)
- ✅ "Continue" button (disabled/grey initially)

#### Step C: Fill Form
1. **Full Name**: Enter any name (e.g., "John Doe")
2. **Phone Number**: Enter 10 digits (e.g., "9876543210")
3. **Block**: Enter block (e.g., "A")
4. **Flat Number**: Enter flat (e.g., "101")

**Watch the button:**
- Initially: Disabled (40% opacity)
- After all fields filled: Enabled (full color with gradient)

#### Step D: Submit Form
- Click "Continue" button
- Button shows loading spinner for 2 seconds
- Success message appears: "Account created successfully!"
- Navigates directly to Home/Dashboard

### 4. Test Validation

#### Empty Fields
- Leave any field empty
- Try to click "Continue"
- Button should be disabled (can't click)

#### Invalid Phone
- Enter less than 10 digits
- Button remains disabled
- On submit, shows error: "Please enter a valid phone number"

#### Back Navigation
- Click back arrow in header
- Returns to Login screen
- All data is cleared

### 5. Test Login Flow (Quick)
From Login screen:
1. Enter mobile number: "9876543210"
2. Click "Login"
3. Goes directly to Home/Dashboard

## Visual Checklist

### Splash Screen
- [ ] Blue gradient background
- [ ] Logo appears with scale animation
- [ ] "Lyvo" text fades in
- [ ] "Your Community, Connected" tagline
- [ ] Three pulsing dots at bottom
- [ ] "Loading..." text
- [ ] Lasts exactly 3 seconds

### Login Screen
- [ ] Blue gradient background
- [ ] White rounded card
- [ ] "Welcome Back" title
- [ ] Mobile number input
- [ ] "Login" button
- [ ] "Don't have an account? Register" link
- [ ] "Register" text is blue and clickable

### Create Account Screen
- [ ] Blue gradient header (#2563EB → #1E40AF)
- [ ] Back arrow works
- [ ] "Create Account" in header
- [ ] "Enter your details to register" heading
- [ ] All 4 input fields present
- [ ] Block and Flat Number side-by-side
- [ ] White input backgrounds
- [ ] Grey borders (#E5E5E5)
- [ ] Grey placeholders (#A3A3A3)
- [ ] Continue button gradient matches header
- [ ] Button disabled when form invalid
- [ ] Button shows spinner on submit

## Common Issues & Solutions

### Issue: Register link not working
**Solution**: Hot restart the app (not just hot reload)

### Issue: Create Account screen shows "Coming Soon"
**Solution**: The route is now fixed - hot restart

### Issue: Button stays disabled
**Solution**: Make sure all 4 fields are filled:
- Full Name (not empty)
- Phone Number (exactly 10 digits)
- Block (not empty)
- Flat Number (not empty)

### Issue: Splash screen too long
**Solution**: Duration is set to 3 seconds in main.dart:
```dart
duration: const Duration(milliseconds: 3000)
```

## Quick Test Commands

```bash
# Hot restart
r

# Full restart
R

# Clear and restart
flutter clean
flutter run
```

## Expected Behavior Summary

| Action | Expected Result |
|--------|----------------|
| App starts | Splash screen (3s) → Login |
| Click "Register" | Create Account screen appears |
| Fill all fields | Button becomes enabled |
| Leave field empty | Button stays disabled |
| Click Continue | Loading spinner → OTP screen |
| Click back arrow | Returns to Login |
| Click "Login" | Goes to Home/Dashboard |

## Files Involved

- `lib/main.dart` - Route configuration
- `lib/src/screens/splash_screen_clean.dart` - Splash screen
- `lib/src/screens/login_screen.dart` - Login with register link
- `lib/src/screens/create_account_screen.dart` - Registration form
- `lib/src/screens/verify_otp_screen.dart` - OTP verification

---

**Status**: ✅ Complete - Full auth flow working
**Last Updated**: Now
**Ready for**: Testing and production use
