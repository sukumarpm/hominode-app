@echo off
echo ========================================
echo Testing Chat Requests Flow
echo ========================================
echo.
echo This will test:
echo 1. Fetch chat requests from Firestore
echo 2. Stream requests (realtime)
echo 3. Accept request and create chat
echo 4. Direct Firestore queries
echo.
echo Device: ZA222LQT6V
echo.
pause

echo.
echo Starting test...
echo.

flutter run -d ZA222LQT6V lib/test_chat_requests_flow.dart

echo.
echo ========================================
echo Test Complete
echo ========================================
echo.
echo Check the app for results:
echo - Requests should show in list
echo - Accept button should create chat
echo - Chat conversation should open
echo.
pause
