@echo off
echo ========================================
echo Testing Dashboard Real Data Integration
echo ========================================
echo.
echo This will run the app and display real data
echo in the dashboard summary cards.
echo.
echo Expected results:
echo - Pending Bill: Shows real amount from Firestore
echo - Visitor Today: Shows count of today's visitors
echo - Open Complaint: Shows count of pending/in-progress complaints
echo.
echo Check console logs for:
echo   "Dashboard: Summary data calculated"
echo   "Pending Bill: Rs{amount}"
echo   "Visitors Today: {count}"
echo   "Open Complaints: {count}"
echo.
pause
echo.
echo Running app...
flutter run
