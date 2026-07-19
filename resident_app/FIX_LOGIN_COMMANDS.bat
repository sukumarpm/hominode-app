@echo off
echo ========================================
echo LOGIN FIX - Quick Commands
echo ========================================
echo.
echo Your Login Credentials:
echo   Phone: 7010678124
echo   Email: preethampriyadharshan07@gmail.com
echo   Password: 121456
echo.
echo ========================================
echo Choose an option:
echo ========================================
echo.
echo 1. Create/Verify Firebase Auth User
echo 2. Test Login (Test App)
echo 3. Run Main App
echo 4. Debug Login Issues
echo 5. Exit
echo.
set /p choice="Enter your choice (1-5): "

if "%choice%"=="1" goto create_user
if "%choice%"=="2" goto test_login
if "%choice%"=="3" goto run_app
if "%choice%"=="4" goto debug
if "%choice%"=="5" goto end

:create_user
echo.
echo Creating/Verifying Firebase Auth user...
echo.
flutter run lib/create_firebase_user.dart -d chrome
pause
goto end

:test_login
echo.
echo Running login test app...
echo.
flutter run lib/test_login_now.dart
pause
goto end

:run_app
echo.
echo Running main app...
echo.
flutter run
pause
goto end

:debug
echo.
echo Running debug script...
echo.
flutter run lib/test_login_debug.dart
pause
goto end

:end
echo.
echo Done!
pause
