@echo off
echo ========================================
echo Testing Firebase Auth Auto-Creation
echo ========================================
echo.
echo This will test if Firebase Auth users are created automatically on login
echo.
echo Test Credentials:
echo   Email: preethampriyatharson07@gmail.com
echo   Phone: 7010678124
echo   Password: tK7Fo1Ow
echo.
echo ========================================
echo.

cd /d "%~dp0"

echo Running test script...
echo.

flutter run -d ZA222LQT6VLT lib/test_firebase_auth_creation.dart

echo.
echo ========================================
echo Test Complete
echo ========================================
echo.
echo Check the app for test results
echo Check console logs for detailed information
echo.
pause
