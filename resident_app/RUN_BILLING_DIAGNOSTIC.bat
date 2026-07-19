@echo off
echo ========================================
echo   BILLING DATA FLOW DIAGNOSTIC
echo ========================================
echo.
echo This will run a comprehensive diagnostic to verify:
echo   1. Login saves userId to SharedPreferences
echo   2. UserDataService retrieves user data
echo   3. BillService queries Firestore correctly
echo   4. Bills are returned from Firestore
echo.
echo Press any key to start...
pause >nul

echo.
echo Starting diagnostic app...
echo.

flutter run -t lib/diagnose_billing_flow.dart

echo.
echo ========================================
echo   DIAGNOSTIC COMPLETE
echo ========================================
echo.
echo Check the app logs above for results.
echo.
pause
