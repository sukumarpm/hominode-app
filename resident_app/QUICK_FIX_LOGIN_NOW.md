# QUICK FIX - Create User Now

## The Problem
Your user exists in Firestore but NOT in Firebase Authentication.
That's why you get "Invalid credentials" error.

## Quick Solution - Run This Command

Open terminal and run:

```bash
cd resident_app
flutter run lib/create_firebase_user.dart -d chrome
```

Wait for the success message, then:

```bash
# Hot restart the app
Press R in the terminal where your app is running
```

## What This Does

1. Creates user in Firebase Authentication:
   - Email: `preethampriyatharson07@gmail.com`
   - Password: `teste123`

2. Updates Firestore with correct UID

3. Now you can login with:
   - Email: `preethampriyatharson07@gmail.com` + Password: `teste123`
   - OR Phone: `7010678124` + Password: `teste123`

## If Script Fails

Go to Firebase Console manually:
1. https://console.firebase.google.com/
2. Select "lyvo-app" project
3. Authentication → Users → Add user
4. Email: `preethampriyatharson07@gmail.com`
5. Password: `teste123`
6. Click "Add user"

## After Creating User

1. Hot restart app (press `R`)
2. Login screen now has NO Phone OTP tab
3. Just one field: "Email or Phone Number"
4. Enter either email or phone
5. Enter password
6. Click Login
7. ✅ Should work!

## New Login Screen

- ✅ No tabs
- ✅ No Phone OTP
- ✅ Just Email/Phone + Password
- ✅ Simple and clean

Run the command now and your login will work!
