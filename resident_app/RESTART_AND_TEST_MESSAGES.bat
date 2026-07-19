@echo off
echo ========================================
echo Restarting App to Test Messages Fix
echo ========================================
echo.
echo IMPORTANT: This will restart the app
echo The previous fix requires a full restart (not hot reload)
echo.
echo ========================================
echo.

cd /d "%~dp0"

echo Cleaning build...
call flutter clean

echo.
echo Getting dependencies...
call flutter pub get

echo.
echo Running app on device...
echo.
echo Navigate to Messages screen after app launches
echo.

flutter run -d ZA222LQT6V

pause
