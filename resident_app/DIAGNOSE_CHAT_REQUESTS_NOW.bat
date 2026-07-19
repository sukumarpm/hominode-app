@echo off
echo ========================================
echo Diagnosing Chat Requests Flow
echo ========================================
echo.
echo This will check:
echo 1. Firebase Auth user
echo 2. User document lookup
echo 3. Chat requests query
echo 4. Firestore index status
echo.
echo Device: ZA222LQT6V
echo.
pause

echo.
echo Running diagnosis...
echo.

flutter run -d ZA222LQT6V lib/diagnose_chat_requests_now.dart

echo.
echo ========================================
echo Diagnosis Complete
echo ========================================
echo.
echo Check the output for:
echo - User document ID
echo - Chat requests found
echo - Any errors or missing indexes
echo.
pause
