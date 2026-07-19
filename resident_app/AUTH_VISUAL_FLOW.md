# Authentication Flow - Visual Diagram

## Complete User Journey

```
┌─────────────────────────────────────────────────────────────────┐
│                        USER JOURNEY                             │
└─────────────────────────────────────────────────────────────────┘

    ┌──────────────┐
    │  App Opens   │
    └──────┬───────┘
           │
           ↓
    ┌──────────────────────────────────────┐
    │      SPLASH SCREEN (2.2s)            │
    │  ┌────────────────────────────────┐  │
    │  │  ╔════════════════════════╗    │  │
    │  │  ║    Animated Logo       ║    │  │
    │  │  ║    with Shadow         ║    │  │
    │  │  ╚════════════════════════╝    │  │
    │  │                                │  │
    │  │         Lyvo                   │  │
    │  │  Your Community, Connected     │  │
    │  └────────────────────────────────┘  │
    │  Gradient: #2F80ED → #2563EB        │
    └──────────────┬───────────────────────┘
                   │
                   ↓
    ┌──────────────────────────────────────┐
    │      LOGIN SCREEN                    │
    │  ┌────────────────────────────────┐  │
    │  │     Welcome Back               │  │
    │  │  Login to your SocietyConnect  │  │
    │  │                                │  │
    │  │  ╔══════════════════════════╗  │  │
    │  │  ║  Login                   ║  │  │
    │  │  ║                          ║  │  │
    │  │  ║  Mobile Number           ║  │  │
    │  │  ║  ┌────────────────────┐  ║  │  │
    │  │  ║  │ Enter mobile...    │  ║  │  │
    │  │  ║  └────────────────────┘  ║  │  │
    │  │  ║                          ║  │  │
    │  │  ║  ┌────────────────────┐  ║  │  │
    │  │  ║  │   Send OTP         │  ║  │  │
    │  │  ║  └────────────────────┘  ║  │  │
    │  │  ║                          ║  │  │
    │  │  ║  Don't have account?     ║  │  │
    │  │  ║  Register                ║  │  │
    │  │  ╚══════════════════════════╝  │  │
    │  └────────────────────────────────┘  │
    │  Gradient: #2F80ED → #2563EB        │
    └──────────────┬───────────────────────┘
                   │ User enters: 9876543210
                   │ Taps "Send OTP"
                   ↓
    ┌──────────────────────────────────────┐
    │      OTP VERIFICATION SCREEN         │
    │  ┌────────────────────────────────┐  │
    │  │ ╔══════════════════════════╗   │  │
    │  │ ║ ← Verify OTP             ║   │  │
    │  │ ╚══════════════════════════╝   │  │
    │  │                                │  │
    │  │      Enter OTP                 │  │
    │  │  We've sent a verification     │  │
    │  │  code to your mobile number    │  │
    │  │                                │  │
    │  │  ┌───┐ ┌───┐ ┌───┐ ┌───┐      │  │
    │  │  │ 1 │ │ 2 │ │ 3 │ │ 4 │      │  │
    │  │  └───┘ └───┘ └───┘ └───┘      │  │
    │  │  ┌───┐ ┌───┐                  │  │
    │  │  │ 5 │ │ 6 │                  │  │
    │  │  └───┘ └───┘                  │  │
    │  │                                │  │
    │  │  ┌────────────────────────┐   │  │
    │  │  │ Verify & Continue      │   │  │
    │  │  └────────────────────────┘   │  │
    │  │                                │  │
    │  │  Didn't receive code? Resend   │  │
    │  └────────────────────────────────┘  │
    │  Header: #2F80ED → #2563EB          │
    │  Background: #F7F7F7                │
    └──────────────┬───────────────────────┘
                   │ User enters: 123456
                   │ Taps "Verify & Continue"
                   ↓
    ┌──────────────────────────────────────┐
    │      HOME SCREEN (Main App)          │
    │  ┌────────────────────────────────┐  │
    │  │  Dashboard                     │  │
    │  │  ┌──────────────────────────┐  │  │
    │  │  │  Welcome, User!          │  │  │
    │  │  │                          │  │  │
    │  │  │  [Quick Access Cards]    │  │  │
    │  │  │  [Recent Activity]       │  │  │
    │  │  │  [Notifications]         │  │  │
    │  │  └──────────────────────────┘  │  │
    │  │                                │  │
    │  │  ┌──────────────────────────┐  │  │
    │  │  │ [Bottom Navigation]      │  │  │
    │  │  └──────────────────────────┘  │  │
    │  └────────────────────────────────┘  │
    │  User is now logged in               │
    └──────────────────────────────────────┘
```

## Screen Transitions

```
SPLASH → LOGIN
├─ Duration: Instant after 2.2s
├─ Animation: Fade out splash, fade in login
└─ Method: pushReplacementNamed('/login')

LOGIN → OTP
├─ Duration: Instant
├─ Animation: Slide from right
├─ Data: Mobile number passed as argument
└─ Method: pushNamed('/verify-otp', arguments: {...})

OTP → HOME
├─ Duration: Instant
├─ Animation: Fade transition
├─ Clear Stack: Yes (can't go back)
└─ Method: pushNamedAndRemoveUntil('/home', (route) => false)
```

## State Flow

```
┌─────────────────────────────────────────────────────────────┐
│                     APPLICATION STATE                       │
└─────────────────────────────────────────────────────────────┘

Initial State:
  ├─ isAuthenticated: false
  ├─ currentScreen: splash
  └─ userData: null

After Splash (2.2s):
  ├─ isAuthenticated: false
  ├─ currentScreen: login
  └─ userData: null

After Login (OTP sent):
  ├─ isAuthenticated: false
  ├─ currentScreen: otp
  ├─ userData: null
  └─ tempMobile: "9876543210"

After OTP Verified:
  ├─ isAuthenticated: true
  ├─ currentScreen: home
  ├─ userData: {...}
  └─ authToken: "..."
```

## Data Flow

```
┌─────────────────────────────────────────────────────────────┐
│                        DATA FLOW                            │
└─────────────────────────────────────────────────────────────┘

LOGIN SCREEN:
  Input: Mobile Number (10 digits)
    ↓
  Validation: Check format
    ↓
  API Call: POST /auth/send-otp
    ↓
  Response: { success: true, message: "OTP sent" }
    ↓
  Navigate: /verify-otp with mobile number

OTP SCREEN:
  Input: 6-digit OTP
    ↓
  Auto-advance: Fill all boxes
    ↓
  API Call: POST /auth/verify-otp
    ↓
  Response: { success: true, token: "...", user: {...} }
    ↓
  Save: Token + User data
    ↓
  Navigate: /home (clear stack)

HOME SCREEN:
  Load: User data from storage
    ↓
  Display: Dashboard with user info
    ↓
  Access: All app features
```

## Component Hierarchy

```
┌─────────────────────────────────────────────────────────────┐
│                   COMPONENT STRUCTURE                       │
└─────────────────────────────────────────────────────────────┘

MaterialApp
  └─ Routes
      ├─ /splash
      │   └─ AnimatedSplashScreen
      │       ├─ Gradient Container
      │       ├─ Animated Logo
      │       ├─ Text (Lyvo)
      │       └─ Text (Tagline)
      │
      ├─ /login
      │   └─ LoginScreen
      │       ├─ Gradient Container
      │       ├─ Welcome Text
      │       └─ White Card
      │           ├─ Heading (Login)
      │           ├─ Label (Mobile Number)
      │           ├─ AuthTextField
      │           ├─ AuthPrimaryButton
      │           └─ Link (Register)
      │
      ├─ /verify-otp
      │   └─ VerifyOTPScreen
      │       ├─ Gradient Header
      │       │   ├─ Back Button
      │       │   └─ Title (Verify OTP)
      │       └─ Content
      │           ├─ Heading (Enter OTP)
      │           ├─ Subtitle
      │           ├─ OTP Boxes (6x)
      │           │   └─ OTPInputBox
      │           ├─ AuthPrimaryButton
      │           └─ Link (Resend)
      │
      └─ /home
          └─ MainNavigation
              └─ Dashboard
```

## Animation Timeline

```
┌─────────────────────────────────────────────────────────────┐
│                   SPLASH ANIMATIONS                         │
└─────────────────────────────────────────────────────────────┘

0ms ────────────────────────────────────────────────── 2200ms
│                                                            │
├─ Logo Entry (0-600ms)                                     │
│  ├─ Scale: 0.6 → 1.05                                     │
│  ├─ Opacity: 0 → 1                                        │
│  ├─ Rotate: -3° → 0°                                      │
│  └─ TranslateY: 20px → 0                                  │
│                                                            │
├─ Shadow (350-900ms)                                       │
│  ├─ Opacity: 0 → 0.35                                     │
│  └─ Blur: 8px → 24px                                      │
│                                                            │
├─ Bounce (600-690ms)                                       │
│  ├─ ScaleX: 1.0 → 1.08 → 1.0                             │
│  └─ ScaleY: 1.0 → 0.94 → 1.0                             │
│                                                            │
├─ Tagline (850-1250ms)                                     │
│  ├─ Opacity: 0 → 1                                        │
│  └─ TranslateY: 12px → 0                                  │
│                                                            │
├─ Hold (1250-1900ms)                                       │
│  └─ Static display                                        │
│                                                            │
└─ Exit (1900-2200ms)                                       │
   ├─ Scale: 1.0 → 0.98                                     │
   └─ Opacity: 1 → 0                                        │

┌─────────────────────────────────────────────────────────────┐
│                    OTP ANIMATIONS                           │
└─────────────────────────────────────────────────────────────┘

0ms ──────────────────────────────────────────────── 400ms
│                                                         │
├─ Content Entry (100-500ms)                             │
│  ├─ Fade: 0 → 1                                        │
│  └─ Slide: 5% down → 0                                 │
│                                                         │
└─ Focus Animation (instant)                             │
   ├─ Border: 1px → 2px                                  │
   ├─ Color: #E5E5E5 → #2563EB                          │
   └─ Shadow: None → Blue 10%                            │
```

## Error Handling Flow

```
┌─────────────────────────────────────────────────────────────┐
│                    ERROR SCENARIOS                          │
└─────────────────────────────────────────────────────────────┘

LOGIN ERRORS:
  Empty Mobile
    └─ Show: "Please enter your mobile number"
  
  Invalid Format
    └─ Show: "Please enter valid 10-digit number"
  
  API Failure
    └─ Show: "Failed to send OTP. Please try again."
  
  Network Error
    └─ Show: "Network error. Check your connection."

OTP ERRORS:
  Incomplete OTP
    └─ Show: "Please enter complete OTP"
  
  Invalid OTP
    └─ Show: "Invalid OTP. Please try again."
    └─ Clear: All OTP boxes
    └─ Focus: First box
  
  Expired OTP
    └─ Show: "OTP expired. Please request new one."
    └─ Enable: Resend button
  
  API Failure
    └─ Show: "Verification failed. Please try again."
```

## Success Flow

```
┌─────────────────────────────────────────────────────────────┐
│                     SUCCESS PATH                            │
└─────────────────────────────────────────────────────────────┘

1. User opens app
   └─ Splash screen shows (2.2s)

2. User sees login screen
   └─ Enters mobile: 9876543210

3. User taps "Send OTP"
   └─ Loading spinner shows
   └─ API call succeeds
   └─ Navigate to OTP screen

4. User sees OTP screen
   └─ First box auto-focused
   └─ Keyboard appears

5. User enters OTP: 123456
   └─ Auto-advance between boxes
   └─ Button enables when complete

6. User taps "Verify & Continue"
   └─ Loading spinner shows
   └─ API call succeeds
   └─ Token saved
   └─ User data saved

7. User sees home screen
   └─ Dashboard loads
   └─ User is logged in
   └─ Can access all features
```

---

**Visual Guide Complete** ✅

This diagram shows the complete user journey through the authentication flow with all screens, transitions, animations, and data flow.

