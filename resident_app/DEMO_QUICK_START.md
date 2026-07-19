# Demo Quick Start - Test in 30 Seconds

## 🚀 Run the App

```bash
cd resident_app
flutter run -t lib/auth_flow_demo.dart
```

## 📱 Demo Credentials

```
┌─────────────────────────────────┐
│     LOGIN SCREEN                │
├─────────────────────────────────┤
│  Mobile Number:                 │
│  ┌───────────────────────────┐  │
│  │  1234567890               │  │
│  └───────────────────────────┘  │
│                                 │
│  [Send OTP]                     │
└─────────────────────────────────┘

┌─────────────────────────────────┐
│     OTP SCREEN                  │
├─────────────────────────────────┤
│  Enter OTP:                     │
│  ┌───┐ ┌───┐ ┌───┐ ┌───┐       │
│  │ 1 │ │ 2 │ │ 3 │ │ 4 │       │
│  └───┘ └───┘ └───┘ └───┘       │
│  ┌───┐ ┌───┐                   │
│  │ 5 │ │ 6 │                   │
│  └───┘ └───┘                   │
│                                 │
│  [Verify & Continue]            │
└─────────────────────────────────┘
```

## ⚡ Quick Test Steps

1. **Wait** - Splash screen (2.2 seconds)
2. **Type** - `1234567890`
3. **Tap** - "Send OTP"
4. **Type** - `123456`
5. **Tap** - "Verify & Continue"
6. **Done** - You're in! 🎉

## ✅ What to Expect

### Step 1: Splash Screen
- Animated logo appears
- "Lyvo" text fades in
- Auto-navigates after 2.2s

### Step 2: Login Screen
- Enter: `1234567890`
- Tap: "Send OTP"
- Loading spinner shows
- Success: Navigate to OTP

### Step 3: OTP Screen
- First box auto-focused
- Enter: `1 2 3 4 5 6`
- Auto-advance between boxes
- Button enables automatically
- Tap: "Verify & Continue"
- Loading spinner shows
- Success: Navigate to Home

### Step 4: Home Screen
- Dashboard appears
- You're logged in!

## ❌ Common Mistakes

| Mistake | Fix |
|---------|-----|
| Wrong mobile | Use exactly `1234567890` |
| Wrong OTP | Use exactly `123456` |
| Spaces in mobile | No spaces: `1234567890` |
| Incomplete OTP | Enter all 6 digits |

## 🔍 Console Output

Watch for these messages:

```
✅ OTP sent to: 1234567890
📱 Demo OTP: 123456
✅ OTP verified successfully
🎉 User authenticated
```

## 💡 Pro Tips

- **Copy-paste mobile**: `1234567890`
- **Copy-paste OTP**: `123456`
- **Check console**: See debug messages
- **Test resend**: Tap "Resend" link
- **Test errors**: Try wrong numbers

## 🎯 Full Flow (30 seconds)

```
0s  → App opens
2s  → Splash ends, login shows
5s  → Enter mobile, tap send
7s  → OTP screen shows
10s → Enter OTP, tap verify
12s → Home screen shows
```

## 📝 Credentials Card

```
╔═══════════════════════════════╗
║   DEMO CREDENTIALS            ║
╠═══════════════════════════════╣
║  Mobile: 1234567890           ║
║  OTP:    123456               ║
╚═══════════════════════════════╝
```

## 🔄 Test Again

To test again:
1. Hot restart: `r` in terminal
2. Or close and reopen app
3. Or run command again

## 📚 More Info

- Full guide: `DEMO_CREDENTIALS.md`
- Auth flow: `AUTH_FLOW_COMPLETE.md`
- Quick ref: `AUTH_QUICK_REFERENCE.md`

---

**Ready?** Run: `flutter run -t lib/auth_flow_demo.dart`

**Credentials**: Mobile `1234567890` | OTP `123456`
