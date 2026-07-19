# Test Login Flow - Step by Step

## Prerequisites
1. Ensure you have test users in Firestore with:
   - email: test@example.com
   - password: test123
   - name: Test User
   - phone: 9876543210

2. Ensure Cloudinary upload preset is created:
   - Name: resident_app_upload
   - Signing Mode: Unsigned
   - Resource Type: Image

## Test Steps

### 1. Email/Password Login
- Run: `flutter run`
- Go to Login Screen
- Click "Email" tab
- Enter: test@example.com
- Enter password: test123
- Click "Login"
- Expected: Navigate to home screen

### 2. Phone OTP Login
- Go to Login Screen
- Click "Phone OTP" tab
- Enter: 9876543210
- Click "Send OTP"
- Expected: OTP screen appears

### 3. Profile Image Upload
- After login, go to Profile
- Click Edit Profile
- Upload an image
- Expected: Image displays on profile

### 4. Password Reset
- Go to Login Screen
- Click "Forgot Password?"
- Enter email: test@example.com
- Click "Send"
- Expected: Email sent message

## Console Logs to Check
Look for flow function pattern logging:
- 🔵 Starting operation
- 📁 Loading data
- ✅ Success
- ❌ Errors

## Status
All methods now implemented and tested
