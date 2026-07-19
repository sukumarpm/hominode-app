@echo off
echo ========================================
echo Messages Performance Diagnostic
echo ========================================
echo.
echo This will test BOTH tabs:
echo 1. Chats tab loading speed
echo 2. Requests tab loading speed
echo.
echo It will tell you if Firestore indexes are missing.
echo.
echo Device: ZA222LQT6V
echo.
pause

echo.
echo Running complete diagnosis...
echo.

flutter run -d ZA222LQT6V lib/diagnose_messages_complete.dart

echo.
echo ========================================
echo Diagnosis Complete
echo ========================================
echo.
echo WHAT TO DO NEXT:
echo.
echo If you see "FIRESTORE INDEX MISSING":
echo   1. Go to Firebase Console
echo   2. Firestore Database -^> Indexes
echo   3. Create the missing indexes
echo   4. Wait 2-5 minutes
echo   5. Run this diagnostic again
echo.
echo If you see "GOOD PERFORMANCE":
echo   - Your indexes are working!
echo   - App should load instantly
echo   - Test the main app now
echo.
echo See CREATE_FIRESTORE_INDEXES_NOW.md for detailed guide
echo.
pause
