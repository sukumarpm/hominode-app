@echo off
echo ========================================
echo  App Icon ^& Splash Setup
echo  Resident App - Lyvo
echo ========================================
echo.
echo App Icon: assets/logo.png (849 KB)
echo Splash Screen: assets/logo1.png (98 KB)
echo.

echo [1/4] Installing dependencies...
call flutter pub get
if %errorlevel% neq 0 (
    echo ERROR: Failed to get dependencies
    pause
    exit /b 1
)
echo ✓ Dependencies installed
echo.

echo [2/4] Generating app icons...
call flutter pub run flutter_launcher_icons
if %errorlevel% neq 0 (
    echo ERROR: Failed to generate icons
    pause
    exit /b 1
)
echo ✓ Icons generated
echo.

echo [3/4] Cleaning build...
call flutter clean
echo ✓ Build cleaned
echo.

echo [4/4] Verifying icon files...
echo.
echo Android Icons:
dir /b android\app\src\main\res\mipmap-hdpi\ic_launcher.png 2>nul && echo   ✓ hdpi || echo   ✗ hdpi
dir /b android\app\src\main\res\mipmap-mdpi\ic_launcher.png 2>nul && echo   ✓ mdpi || echo   ✗ mdpi
dir /b android\app\src\main\res\mipmap-xhdpi\ic_launcher.png 2>nul && echo   ✓ xhdpi || echo   ✗ xhdpi
dir /b android\app\src\main\res\mipmap-xxhdpi\ic_launcher.png 2>nul && echo   ✓ xxhdpi || echo   ✗ xxhdpi
dir /b android\app\src\main\res\mipmap-xxxhdpi\ic_launcher.png 2>nul && echo   ✓ xxxhdpi || echo   ✗ xxxhdpi
echo.

echo iOS Icons:
for /f %%i in ('dir /b ios\Runner\Assets.xcassets\AppIcon.appiconset\*.png 2^>nul ^| find /c /v ""') do set count=%%i
if defined count (
    echo   ✓ %count% icon files generated
) else (
    echo   ✗ No icons found
)
echo.

echo ========================================
echo  Setup Complete! 🎉
echo ========================================
echo.
echo Your app icon and splash screen are ready!
echo.
echo Next steps:
echo   1. Run: flutter run
echo   2. Check app icon on home screen
echo   3. Watch splash animation on launch
echo.
echo To test splash screen only:
echo   flutter run -t lib/splash_demo.dart
echo.
pause
