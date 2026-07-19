@echo off
echo ========================================
echo Testing Messages Fixes
echo ========================================
echo.
echo This will test:
echo 1. Flat number display (no more flatId)
echo 2. Requests tab error handling
echo.
echo Device: ZA222LQT6V
echo.
pause

echo.
echo Starting test...
echo.

flutter run -d ZA222LQT6V lib/test_messages_fixes.dart

echo.
echo ========================================
echo Test Complete
echo ========================================
echo.
echo Check the app for results:
echo - Flat numbers should show "Unknown" not flatId
echo - Requests tab should work without errors
echo.
pause
