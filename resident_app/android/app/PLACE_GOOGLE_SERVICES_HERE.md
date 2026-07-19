# Missing: google-services.json

## You need to download this file from Firebase Console

### Steps:

1. Go to https://console.firebase.google.com/
2. Select your project (or create a new one)
3. Click the gear icon ⚙️ → **Project Settings**
4. Scroll to **Your apps** section
5. Click **Add app** → Select **Android** icon
6. Enter package name: `com.marantrix.lyvo.resident`
7. Register the app
8. Download **google-services.json**
9. Place it here: `resident_app/android/app/google-services.json`

### Important:
- The file MUST be named exactly: `google-services.json`
- It MUST be placed in: `android/app/` directory
- The package name in the file MUST match: `com.marantrix.lyvo.resident`

### After placing the file:
```cmd
flutter run -d ZA222LQT6V
```

## Current Package Name
✅ Package: `com.marantrix.lyvo.resident`
❌ Missing: `google-services.json`
