@echo off
echo ========================================
echo   Generating App Icons
echo ========================================
echo.

echo Step 1: Getting dependencies...
call flutter pub get
echo.

echo Step 2: Generating app icons...
call flutter pub run flutter_launcher_icons
echo.

echo ========================================
echo   Icon Generation Complete!
echo ========================================
echo.
echo Your app icons have been generated.
echo.
echo Next steps:
echo 1. Clean the project: flutter clean
echo 2. Get dependencies: flutter pub get  
echo 3. Run the app: flutter run
echo.
echo The new icon will appear on your device!
echo.
pause
