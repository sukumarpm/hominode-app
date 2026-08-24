# Security Management - Quick Reference

## Quick Access
Dashboard → Quick Actions → **Security** button

## Key Features

### 1. View Security Staff
- Real-time list of all security personnel
- Status badges (On Duty, Off Duty, On Leave)
- Search by name, phone, or gate

### 2. Assign Work
- Shift timing selection
- Gate assignment
- Work status
- Special instructions

### 3. Track Status
- Total security count
- On duty count
- Off duty count
- On leave count

## Common Tasks

### Assign Work to Security
```
1. Open Security Management
2. Find security staff
3. Tap "Assign Work"
4. Select shift, gate, and status
5. Add instructions (optional)
6. Tap "Assign Work"
```

### View Security Details
```
1. Tap on security card
2. View full details
3. Tap "Close"
```

### Search Security
```
1. Type in search bar
2. Search by name/phone/gate
3. Results filter automatically
```

## Shift Options
- Morning (6 AM - 2 PM)
- Afternoon (2 PM - 10 PM)
- Night (10 PM - 6 AM)
- Full Day (6 AM - 6 PM)
- Flexible

## Gate Options
- Main Gate
- Side Gate
- Back Gate
- Parking Gate
- Service Gate
- Emergency Gate

## Work Status Options
- Active Duty
- Standby
- Patrol
- Monitoring
- Emergency Response

## Status Colors
- 🟢 Green: On Duty
- 🔴 Red: Off Duty
- 🟠 Orange: On Leave
- ⚪ Gray: Pending

## Firestore Structure
```
staff/{staffId}
  ├── role: "Security"
  ├── shiftTiming: String
  ├── gateAssignment: String
  ├── workStatus: String
  ├── specialInstructions: String
  └── adminId: String (filter)
```

## Integration Points
- **Staff Management**: Add security staff
- **Attendance**: Mark attendance
- **Dashboard**: Quick access button
- **Visitor Management**: Gate operations

## Tips
- Add security staff from Staff Management first
- Set role to "Security" when adding
- Assign work shifts for better organization
- Use special instructions for important notes
- Search is case-insensitive
- Real-time updates - no refresh needed

## Troubleshooting
- **No security staff?** → Add from Staff Management with role="Security"
- **Can't assign work?** → Check Firestore permissions
- **Not updating?** → Check internet connection
- **Wrong data?** → Verify adminId filter
