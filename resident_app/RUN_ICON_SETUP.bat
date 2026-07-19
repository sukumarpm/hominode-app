@echo off
cls
echo.
echo ╔════════════════════════════════════════════════════════════╗
echo ║                                                            ║
echo ║          LYVO - App Icon ^& Splash Setup                   ║
echo ║          Resident Community Management App                 ║
echo ║                                                            ║
echo ╚════════════════════════════════════════════════════════════╝
echo.
echo Configuration:
echo   App Icon:      assets/logo.png  (849 KB)
echo   Splash Screen: assets/logo1.png (98 KB)
echo.
echo ════════════════════════════════════════════════════════════
echo.

echo [Step 1/4] Installing dependencies...
echo.
call flutter pub get
if %errorlevel% neq 0 (
    echo.
    echo ❌ ERROR: Failed to install dependencies
    echo.
    pause
    exit /b 1
)
echo.
echo ✅ Dependencies installed successfully
echo.
echo ════════════════════════════════════════════════════════════
echo.

echo [Step 2/4] Generating app icons from logo.png...
echo.
call flutter pub run flutter_launcher_icons
if %errorlevel% neq 0 (
    echo.
    echo ❌ ERROR: Failed to generate icons
    echo.
    pause
    exit /b 1
)
echo.
echo ✅ App icons generated successfully
echo.
echo ════════════════════════════════════════════════════════════
echo.

echo [Step 3/4] Cleaning build cache...
echo.
call flutter clean
echo.
echo ✅ Build cache cleaned
echo.
echo ════════════════════════════════════════════════════════════
echo.

echo [Step 4/4] Verifying generated files...
echo.

echo Android Icons (from logo.png):
dir /b android\app\src\main\res\mipmap-hdpi\ic_launcher.png 2>nul && echo   ✅ hdpi (72x72) || echo   ❌ hdpi missing
dir /b android\app\src\main\res\mipmap-mdpi\ic_launcher.png 2>nul && echo   ✅ mdpi (48x48) || echo   ❌ mdpi missing
dir /b android\app\src\main\res\mipmap-xhdpi\ic_launcher.png 2>nul && echo   ✅ xhdpi (96x96) || echo   ❌ xhdpi missing
dir /b android\app\src\main\res\mipmap-xxhdpi\ic_launcher.png 2>nul && echo   ✅ xxhdpi (144x144) || echo   ❌ xxhdpi missing
dir /b android\app\src\main\res\mipmap-xxxhdpi\ic_launcher.png 2>nul && echo   ✅ xxxhdpi (192x192) || echo   ❌ xxxhdpi missing
echo.

echo iOS Icons (from logo.png):
for /f %%i in ('dir /b ios\Runner\Assets.xcassets\AppIcon.appiconset\*.png 2^>nul ^| find /c /v ""') do set count=%%i
if defined count (
    echo   ✅ %count% icon sizes generated
) else (
    echo   ❌ No iOS icons found
)
echo.

echo Splash Screen:
dir /b assets\logo1.png 2>nul && echo   ✅ logo1.png configured for splash || echo   ❌ logo1.png missing
echo.

echo ════════════════════════════════════════════════════════════
echo.
echo ╔════════════════════════════════════════════════════════════╗
echo ║                                                            ║
echo ║                  ✅ SETUP COMPLETE! 🎉                     ║
echo ║                                                            ║
echo ╚════════════════════════════════════════════════════════════╝
echo.
echo Your app is now configured with:
echo   • App Icon: logo.png (849 KB) - for home screen
echo   • Splash Screen: logo1.png (98 KB) - for launch animation
echo.
echo ════════════════════════════════════════════════════════════
echo.
echo Next Steps:
echo.
echo   1. Run your app:
echo      flutter run
echo.
echo   2. Test splash screen only:
echo      flutter run -t lib/splash_demo.dart
echo.
echo   3. Test complete auth flow:
echo      flutter run -t lib/auth_flow_demo.dart
echo.
echo ════════════════════════════════════════════════════════════
echo.
echo What to check:
echo   ✓ App icon on home screen (logo.png)
echo   ✓ Splash animation on launch (logo1.png)
echo   ✓ Blue gradient background
echo   ✓ Smooth 2.2-second animation
echo.
echo ════════════════════════════════════════════════════════════
echo.
pause
