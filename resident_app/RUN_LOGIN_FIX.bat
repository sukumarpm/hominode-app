@echo off
echo ========================================
echo Login Issue Diagnostic Tool
echo ========================================
echo.
echo This will diagnose and fix the login issue
echo.
pause

cd /d "%~dp0"
flutter run -t lib/fix_login_issue.dart

pause
