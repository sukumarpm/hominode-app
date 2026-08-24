# Login Credentials - Quick Reference

## What Gets Auto-Generated?

When admin creates a new resident:

### 1. Username (Resident ID)
- **Format**: `RES` + 4 digits
- **Example**: `RES5326`
- **Purpose**: Username for login

### 2. Password
- **Format**: 8 alphanumeric characters
- **Example**: `aB3xK9mP`
- **Purpose**: Password for login

### 3. Auth Email (Internal Only)
- **Format**: `{residentId}@lyvo.com`
- **Example**: `RES5326@lyvo.com`
- **Purpose**: Firebase Auth (never shown to users)

## How Resident Logs In

```
Login Screen:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Username: RES5326
Password: aB3xK9mP
━━━━━━━━━━━━━━━━━━━━━━━━━━━━
[Login]
```

## What Gets Sent to Resident

**SMS/Email Message:**
```
Welcome to [Society]!

Your login credentials:
Username: RES5326
Password: aB3xK9mP

Download app: [link]
```

## Behind the Scenes

```
User enters: RES5326 + aB3xK9mP
    ↓
System converts: RES5326 → RES5326@lyvo.com
    ↓
Firebase Auth: RES5326@lyvo.com + aB3xK9mP
    ↓
Login successful!
```

## Key Points

✅ Resident ID = Username
✅ Password = Auto-generated
✅ Both sent via SMS/Email
✅ Simple and secure
✅ No complex emails to remember

## Files Modified

- `lib/widgets/assign_resident_modal.dart` - Shows both credentials in UI
- `lib/services/user_service.dart` - Stores credentials in Firestore
- `RESIDENT_LOGIN_CREDENTIALS_SYSTEM.md` - Complete documentation
- `FLAT_OCCUPANCY_ASSIGN_RESIDENT_FIRESTORE_FLOW.md` - Updated flow

## Status

✅ **COMPLETE** - System is fully functional and production-ready!
