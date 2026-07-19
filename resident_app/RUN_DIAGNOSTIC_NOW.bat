@echo off
echo ========================================
echo Running Firestore Permission Diagnostic
echo ========================================
echo.

cd /d "%~dp0"

echo Step 1: Running diagnostic script...
echo.
flutter run lib/diagnose_firestore_permission.dart

echo.
echo ========================================
echo Diagnostic Complete
echo ========================================
echo.
echo Read the output above to identify the issue.
echo.
echo Common issues:
echo 1. User document ID does not match Firebase Auth UID
echo 2. Missing buildingId, flatId, or role fields
echo 3. User not logged in
echo.
echo Next step: Run FIX_PERMISSION_NOW.bat to fix the issue
echo.
pause
