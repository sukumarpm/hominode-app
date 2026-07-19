@echo off
echo ========================================
echo Testing Messages Screen Fix
echo ========================================
echo.
echo This will test if the messages screen error is fixed
echo.
echo ========================================
echo.

cd /d "%~dp0"

echo Running test script...
echo.

flutter run -d ZA222LQT6VLT lib/test_messages_debug.dart

echo.
echo ========================================
echo Test Complete
echo ========================================
echo.
echo Check the app for test results
echo Check console logs for detailed information
echo.
pause
