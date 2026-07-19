# 📱 OTP Login Flow - Visual Guide

## 🎯 Complete Flow Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                         START APP                               │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│                      LOGIN SCREEN                               │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │  Welcome Back                                             │  │
│  │  Login to your SocietyConnect account                     │  │
│  │                                                           │  │
│  │  ┌─────────────────────────────────────────────────────┐ │  │
│  │  │ Mobile Number                                       │ │  │
│  │  │ ┌─────────────────────────────────────────────────┐ │ │  │
│  │  │ │ 1234567890                                      │ │ │  │ ← Enter this
│  │  │ └─────────────────────────────────────────────────┘ │ │  │
│  │  │                                                     │ │  │
│  │  │ ┌─────────────────────────────────────────────────┐ │ │  │
│  │  │ │           Send OTP                              │ │ │  │ ← Tap this
│  │  │ └─────────────────────────────────────────────────┘ │ │  │
│  │  │                                                     │ │  │
│  │  │ Don't have an account? Register                    │ │  │
│  │  └─────────────────────────────────────────────────────┘ │  │
│  └───────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
                              ↓
                    [Sending OTP...]
                              ↓
                    ✅ OTP sent successfully
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│                      OTP SCREEN                                 │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │  ← Verify OTP                                            │  │
│  │                                                           │  │
│  │  Enter OTP                                                │  │
│  │  We've sent a verification code to your mobile number    │  │
│  │                                                           │  │
│  │  ┌───┐ ┌───┐ ┌───┐ ┌───┐ ┌───┐ ┌───┐                    │  │
│  │  │ 1 │ │ 2 │ │ 3 │ │ 4 │ │ 5 │ │ 6 │                    │  │ ← Enter this
│  │  └───┘ └───┘ └───┘ └───┘ └───┘ └───┘                    │  │
│  │                                                           │  │
│  │  ┌─────────────────────────────────────────────────────┐ │  │
│  │  │         Verify & Continue                           │ │  │ ← Tap this
│  │  └─────────────────────────────────────────────────────┘ │  │
│  │                                                           │  │
│  │  Didn't receive code? Resend                             │  │
│  └───────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
                              ↓
                    [Verifying OTP...]
                              ↓
                    ✅ OTP verified successfully
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│                      DASHBOARD                                  │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │  🏠 Welcome to SocietyConnect!                           │  │
│  │                                                           │  │
│  │  Quick Access:                                            │  │
│  │  [Visitor] [Bills] [Complaints] [Events]                 │  │
│  │                                                           │  │
│  │  Recent Activity:                                         │  │
│  │  • Visitor pass approved                                  │  │
│  │  • Maintenance bill due                                   │  │
│  │                                                           │  │
│  │  ┌─────────┬─────────┬─────────┬─────────┐              │  │
│  │  │  Home   │ Visitor │  Bills  │  More   │              │  │
│  │  └─────────┴─────────┴─────────┴─────────┘              │  │
│  └───────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
                              ↓
                    ✅ LOGGED IN!
```

## 🔄 Alternative Flows

### ❌ Wrong Mobile Number
```
Login Screen
    ↓
Enter: 9876543210
    ↓
Tap: Send OTP
    ↓
❌ Error: "Failed to send OTP. Please use demo mobile: 1234567890"
    ↓
Stay on Login Screen
```

### ❌ Wrong OTP
```
OTP Screen
    ↓
Enter: 654321
    ↓
Tap: Verify & Continue
    ↓
❌ Error: "Invalid OTP. Please try again."
    ↓
OTP boxes cleared
    ↓
Stay on OTP Screen (try again)
```

### 🔄 Resend OTP
```
OTP Screen
    ↓
Tap: "Resend" link
    ↓
✅ Success: "OTP resent successfully"
    ↓
OTP boxes cleared
    ↓
Enter: 123456 (again)
```

### ← Back Navigation
```
OTP Screen
    ↓
Tap: Back button (←)
    ↓
Return to Login Screen
```

## 🎨 Screen Details

### Login Screen Components
```
┌─────────────────────────────────┐
│ [Blue Gradient Background]      │
│                                 │
│   Welcome Back                  │ ← Title (28px, Bold)
│   Login to your account         │ ← Subtitle (16px)
│                                 │
│   ┌─────────────────────────┐   │
│   │ [White Card]            │   │
│   │                         │   │
│   │ Login                   │   │ ← Heading (22px)
│   │                         │   │
│   │ Mobile Number           │   │ ← Label (16px)
│   │ ┌─────────────────────┐ │   │
│   │ │ Enter mobile number │ │   │ ← Input field
│   │ └─────────────────────┘ │   │
│   │                         │   │
│   │ ┌─────────────────────┐ │   │
│   │ │    Send OTP         │ │   │ ← Button (Blue gradient)
│   │ └─────────────────────┘ │   │
│   │                         │   │
│   │ Don't have account?     │   │ ← Register link
│   │ Register                │   │
│   └─────────────────────────┘   │
└─────────────────────────────────┘
```

### OTP Screen Components
```
┌─────────────────────────────────┐
│ [Blue Gradient Header]          │
│ ← Verify OTP                    │ ← Header with back button
└─────────────────────────────────┘
│ [Gray Background]               │
│                                 │
│   Enter OTP                     │ ← Title (28px, Bold)
│   We've sent a verification     │ ← Subtitle (16px)
│   code to your mobile number    │
│                                 │
│   ┌───┐ ┌───┐ ┌───┐            │
│   │ 1 │ │ 2 │ │ 3 │            │ ← 6 OTP boxes
│   └───┘ └───┘ └───┘            │   (50x56px each)
│   ┌───┐ ┌───┐ ┌───┐            │
│   │ 4 │ │ 5 │ │ 6 │            │
│   └───┘ └───┘ └───┘            │
│                                 │
│   ┌─────────────────────────┐   │
│   │  Verify & Continue      │   │ ← Button (Blue gradient)
│   └─────────────────────────┘   │
│                                 │
│   Didn't receive code? Resend   │ ← Resend link
└─────────────────────────────────┘
```

## 🎯 Interactive Elements

### Login Screen
| Element | Action | Result |
|---------|--------|--------|
| Mobile Input | Type 10 digits | Validates format |
| Send OTP Button | Tap | Sends OTP, navigates to OTP screen |
| Register Link | Tap | Navigate to registration |

### OTP Screen
| Element | Action | Result |
|---------|--------|--------|
| Back Button | Tap | Return to login screen |
| OTP Box 1-6 | Type digit | Auto-focus next box |
| OTP Box | Backspace | Move to previous box |
| OTP Box | Paste 6 digits | Fill all boxes |
| Verify Button | Tap | Verify OTP, navigate to dashboard |
| Resend Link | Tap | Resend OTP, clear boxes |

## 🎨 Visual States

### OTP Box States
```
┌───┐  Empty box (gray border)
│   │
└───┘

┌───┐  Focused box (blue border + shadow)
│ █ │
└───┘

┌───┐  Filled box (gray border)
│ 5 │
└───┘
```

### Button States
```
┌─────────────────────┐  Enabled (blue gradient + shadow)
│    Send OTP         │
└─────────────────────┘

┌─────────────────────┐  Loading (spinner)
│    ⟳               │
└─────────────────────┘

┌─────────────────────┐  Disabled (light gray)
│    Send OTP         │
└─────────────────────┘
```

## 📊 Flow Metrics

| Step | Screen | Average Time | Success Rate |
|------|--------|--------------|--------------|
| 1 | Login | 10 seconds | 100% (with correct mobile) |
| 2 | OTP | 15 seconds | 100% (with correct OTP) |
| 3 | Dashboard | Instant | 100% |

**Total Flow Time**: ~25 seconds

## ✅ Validation Rules

### Mobile Number
- ✅ Must be exactly 10 digits
- ✅ Only numeric characters
- ✅ Must be 1234567890 (demo mode)
- ❌ Cannot be empty
- ❌ Cannot have letters or special characters

### OTP
- ✅ Must be exactly 6 digits
- ✅ Only numeric characters
- ✅ Must be 123456 (demo mode)
- ❌ Cannot be empty
- ❌ Cannot have letters or special characters

## 🎉 Success Indicators

### Visual Feedback
- ✅ Green snackbar: "OTP sent successfully"
- ✅ Green snackbar: "OTP verified successfully"
- ❌ Red snackbar: Error messages
- 🔄 Loading spinner: Processing

### Console Logs
```
✅ OTP sent to: 1234567890
📱 Demo OTP: 123456
Verifying OTP: 123456 for mobile: 1234567890
✅ OTP verified successfully
🎉 User authenticated
```

---

**Test Credentials**: Mobile: `1234567890` | OTP: `123456`
