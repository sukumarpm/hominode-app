@echo off
echo ========================================
echo Messages Screen Diagnostic
echo ========================================
echo.
echo This will show you exactly what's happening
echo and why the error is occurring.
echo.
echo ========================================
echo.

cd /d "%~dp0"

echo Running diagnostic...
echo.

flutter run -d ZA222LQT6V lib/diagnose_messages_now.dart

echo.
echo ========================================
echo Diagnostic Complete
echo ========================================
echo.
echo Check the output above for issues
echo.
pause
