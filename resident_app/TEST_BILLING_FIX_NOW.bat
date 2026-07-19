@echo off
echo ========================================
echo Testing Billing flatLabel Fix
echo ========================================
echo.
echo This will run the test on your Android device
echo to verify billing data fetches correctly.
echo.
echo Expected result:
echo - User data fetched with flatLabel: t202
echo - Billing data fetched successfully
echo - Bill amount: Rs850 displayed
echo.
pause
echo.
echo Running test...
flutter run lib/test_billing_flatLabel_fix.dart -d ZA222LQT6V
