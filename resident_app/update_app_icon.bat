@echo off
echo ========================================
echo  Lyvo App Icon Generator
echo ========================================
echo.
echo Configuration:
echo - Source: assets/logo1.png
echo - Background: #2563EB (Blue)
echo - Platforms: Android, iOS, Web
echo - Centered with proper safe zones
echo.

cd /d "%~dp0"

echo Step 1: Fetching dependencies...
call flutter pub get
if errorlevel 1 (
    echo ERROR: Failed to get dependencies
    pause
    exit /b 1
)
echo.

echo Step 2: Generating app icons for all platforms...
call flutter pub run flutter_launcher_icons
if errorlevel 1 (
    echo ERROR: Failed to generate icons
    pause
    exit /b 1
)
echo.

echo ========================================
echo  SUCCESS! App Icons Generated
echo ========================================
echo.
echo Generated icons for:
echo  - Android (all densities + adaptive)
echo  - iOS (all sizes)
echo  - Web (favicon + manifest)
echo.
echo IMPORTANT - To see the new icon:
echo 1. Uninstall the old app from your device
echo 2. Run: flutter run
echo 3. The new centered icon will appear
echo.
echo The icon is now properly centered with
echo standard safe zones for all platforms.
echo.
pause
