# Kotlin MainActivity Duplicate Fix

## Issue
Build was failing with a Kotlin redeclaration error:
```
e: file:///D:/lyvo/admin_App/admin_app/android/app/src/main/kotlin/com/marantrix/lyvo/MainActivity.kt:5:7 Redeclaration: class MainActivity : FlutterActivity
e: file:///D:/lyvo/admin_App/admin_app/android/app/src/main/kotlin/com/marantrix/lyvo/admin/MainActivity.kt:5:7 Redeclaration: class MainActivity : FlutterActivity
```

## Root Cause
There were two identical `MainActivity.kt` files in different locations:
1. `android/app/src/main/kotlin/com/marantrix/lyvo/MainActivity.kt`
2. `android/app/src/main/kotlin/com/marantrix/lyvo/admin/MainActivity.kt`

Both files declared the same class in the same package (`com.marantrix.lyvo.admin`), causing a redeclaration conflict.

## Solution
Deleted the duplicate file in the parent directory:
- **Deleted**: `android/app/src/main/kotlin/com/marantrix/lyvo/MainActivity.kt`
- **Kept**: `android/app/src/main/kotlin/com/marantrix/lyvo/admin/MainActivity.kt`

The correct file location matches the namespace defined in `build.gradle.kts`:
```kotlin
namespace = "com.marantrix.lyvo.admin"
```

## Files Modified
- Deleted: `admin_app/android/app/src/main/kotlin/com/marantrix/lyvo/MainActivity.kt`

## Next Steps
1. Run `flutter clean` (already done)
2. Run `flutter run -d <device_id>` to build and test

## Status
✅ Fixed - Duplicate MainActivity removed
