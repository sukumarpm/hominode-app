# Admin Login - Deployment Checklist

## Pre-Deployment Verification

### Code Review
- [ ] `admin_login_service.dart` - Service implementation reviewed
- [ ] `admin_login_screen.dart` - UI screen reviewed
- [ ] Flow function pattern correctly implemented
- [ ] Error handling covers all failure points
- [ ] No hardcoded credentials in code
- [ ] No sensitive data logged to console

### Testing
- [ ] Test file runs successfully: `flutter run lib/test_admin_login.dart`
- [ ] Login with test credentials works
- [ ] Flow function logs appear in console
- [ ] Error messages display correctly
- [ ] Phone number conversion works
- [ ] Login state persists after app restart
- [ ] Logout clears all stored data

### Integration
- [ ] Admin login route added to main app
- [ ] Splash screen checks for admin login
- [ ] Admin dashboard protected with AdminAccessWrapper
- [ ] Logout functionality implemented
- [ ] Navigation between screens works correctly

### Documentation
- [ ] `ADMIN_LOGIN_FIX_COMPLETE.md` - Complete guide
- [ ] `ADMIN_LOGIN_QUICK_REFERENCE.md` - Quick reference
- [ ] `ADMIN_LOGIN_INTEGRATION_STEPS.md` - Integration guide
- [ ] `ADMIN_LOGIN_FLOW_DIAGRAM.md` - Flow diagrams
- [ ] `ADMIN_LOGIN_SUMMARY.md` - Summary document
- [ ] `ADMIN_LOGIN_DEPLOYMENT_CHECKLIST.md` - This checklist

## Firebase Configuration

### Authentication
- [ ] Firebase Authentication enabled
- [ ] Email/Password sign-in method enabled
- [ ] Admin user created in Firebase Console
- [ ] Admin password set correctly

### Firestore
- [ ] Admin user document exists in `users` collection
- [ ] Admin document has required fields:
  - [ ] `id` - Firebase Auth UID
  - [ ] `email` - Admin email
  - [ ] `phone` - Admin phone (optional)
  - [ ] `role` - Set to "admin"
  - [ ] `buildingId` - Valid building ID
  - [ ] `buildingName` - Building name
  - [ ] `status` - Set to "active"

### Security Rules
- [ ] Firestore rules allow reading user documents by authUid
- [ ] Rules prevent unauthorized access to admin data
- [ ] Rules enforce role-based access control

## App Configuration

### Dependencies
- [ ] `firebase_auth` package installed
- [ ] `cloud_firestore` package installed
- [ ] `shared_preferences` package installed
- [ ] All packages up to date

### Android Configuration
- [ ] `google-services.json` placed in `android/app/`
- [ ] Firebase plugin configured in `build.gradle`
- [ ] Minimum SDK version compatible

### iOS Configuration
- [ ] `GoogleService-Info.plist` placed in `ios/Runner/`
- [ ] Firebase pod dependencies installed
- [ ] Deployment target compatible

## Build & Release

### Debug Build
- [ ] `flutter clean` executed
- [ ] `flutter pub get` executed
- [ ] `flutter build apk --debug` succeeds
- [ ] App runs on test device
- [ ] Admin login works correctly

### Release Build
- [ ] `flutter build apk --release` succeeds
- [ ] `flutter build ios --release` succeeds (if iOS)
- [ ] APK/IPA file generated successfully
- [ ] File size reasonable

### Testing on Device
- [ ] Install APK on test device
- [ ] App launches without errors
- [ ] Admin login screen displays correctly
- [ ] Login with test credentials works
- [ ] Admin dashboard loads
- [ ] All admin features accessible

## Deployment

### Firebase App Distribution
- [ ] Firebase App Distribution configured
- [ ] Test users added
- [ ] APK uploaded to Firebase
- [ ] Test users can download and install
- [ ] Testers report successful login

### Play Store (Android)
- [ ] App signing configured
- [ ] Version code incremented
- [ ] Version name updated
- [ ] Release notes prepared
- [ ] Screenshots updated
- [ ] Description updated
- [ ] App submitted to Play Store

### App Store (iOS)
- [ ] Provisioning profiles configured
- [ ] Certificates valid
- [ ] Version number incremented
- [ ] Build number incremented
- [ ] Release notes prepared
- [ ] Screenshots updated
- [ ] App submitted to App Store

## Post-Deployment

### Monitoring
- [ ] Firebase Console monitored for errors
- [ ] Crash reports reviewed
- [ ] User feedback collected
- [ ] Performance metrics checked

### Support
- [ ] Support team trained on admin login
- [ ] Troubleshooting guide provided
- [ ] Common issues documented
- [ ] Escalation process defined

### Documentation
- [ ] User guide created
- [ ] Admin manual updated
- [ ] FAQ document created
- [ ] Video tutorial recorded (optional)

## Rollback Plan

### If Issues Found
- [ ] Previous version APK available
- [ ] Rollback procedure documented
- [ ] Communication plan ready
- [ ] User notification template prepared

### Issue Resolution
- [ ] Bug fix implemented
- [ ] Fix tested thoroughly
- [ ] New build created
- [ ] Redeployed to users

## Sign-Off

### Development Team
- [ ] Code review completed: _______________
- [ ] Testing completed: _______________
- [ ] Documentation reviewed: _______________

### QA Team
- [ ] Functional testing passed: _______________
- [ ] Integration testing passed: _______________
- [ ] Performance testing passed: _______________

### Product Team
- [ ] Feature approved: _______________
- [ ] Release approved: _______________
- [ ] Go-live approved: _______________

## Deployment Date

**Planned Deployment Date**: _______________

**Actual Deployment Date**: _______________

**Deployed By**: _______________

**Approved By**: _______________

## Notes

```
_________________________________________________________________

_________________________________________________________________

_________________________________________________________________

_________________________________________________________________
```

---

## Quick Reference

### Test Credentials
```
Email: preethampriyatharson07@gmail.com
Phone: 7201067812
Password: iQ2joLPr
Building: FUW27AsWObmYMMTDCX
```

### Key Files
- Service: `lib/src/services/admin_login_service.dart`
- Screen: `lib/src/screens/admin_login_screen.dart`
- Test: `lib/test_admin_login.dart`

### Important Routes
- Admin Login: `/admin-login`
- Admin Dashboard: `/admin-dashboard`
- Logout: Handled by AdminLoginService

### Support Contacts
- Development: _______________
- QA: _______________
- Product: _______________
- Support: _______________

---

## Deployment Status

- [ ] **NOT STARTED** - Awaiting approval
- [ ] **IN PROGRESS** - Currently deploying
- [ ] **COMPLETED** - Successfully deployed
- [ ] **ROLLED BACK** - Deployment reverted

**Current Status**: _______________

**Last Updated**: _______________

---

**Version**: 1.0.0
**Status**: Ready for Deployment ✅
