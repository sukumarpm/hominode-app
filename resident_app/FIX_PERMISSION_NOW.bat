@echo off
echo ========================================
echo Fixing Firestore Permission Issues
echo ========================================
echo.

cd /d "%~dp0"

echo IMPORTANT: Before running this fix, you MUST update the script with your data!
echo.
echo Open: lib/fix_firestore_permissions_complete.dart
echo.
echo Update these lines (around line 48-53):
echo   - name: "Your Name"
echo   - phone: "+1234567890"
echo   - buildingId: "your_building_id"
echo   - flatId: "your_flat_id"
echo   - role: "resident" or "admin"
echo.
set /p CONTINUE="Have you updated the script? (y/n): "

if /i not "%CONTINUE%"=="y" (
    echo.
    echo Please update the script first, then run this again.
    pause
    exit /b
)

echo.
echo Running fix script...
echo.
flutter run lib/fix_firestore_permissions_complete.dart

echo.
echo ========================================
echo Fix Complete
echo ========================================
echo.
echo Next steps:
echo 1. Wait 2 minutes for changes to propagate
echo 2. Restart your app completely
echo 3. Test again
echo.
pause
