# Flat Management - Quick Reference Guide

## Access Flat Occupancy Grid

**From Building Management:**
1. Navigate to "Manage Buildings"
2. Find the building
3. Click the grid icon (⚙️) on building card
4. Flat occupancy grid opens

## Quick Actions

### View All Flats
```
Building Card → Grid Icon → Flat Occupancy Grid
```
- See all flats grouped by floor
- Color-coded by status
- Real-time updates

### Search Flats
```
Grid → Search Box → Type flat number or resident name
```
**Examples:**
- Search "A101" → Shows flat A101
- Search "John" → Shows all flats with John as resident

### Filter by Status
```
Grid → Filter Dropdown → Select status
```
**Options:**
- All - Show all flats
- Occupied - Show only occupied flats
- Vacant - Show only vacant flats
- Maintenance - Show only maintenance flats

### Toggle View Mode
```
Grid → [Grid View] or [List View] buttons
```
- Grid View: Visual grid layout
- List View: Detailed list layout

## Flat Status Colors

| Color | Status | Description |
|-------|--------|-------------|
| 🟦 Blue | Occupied | Resident assigned |
| ⚪ Grey | Vacant | No resident |
| 🟧 Orange | Maintenance | Under maintenance |

## Assign Resident to Flat

### Method 1: Select Existing Resident
```
1. Click vacant flat (grey)
2. Click "Assign Resident"
3. Select "Select Existing" tab
4. Search for resident
5. Select resident from list
6. Choose ownership type:
   - Owner
   - Tenant
   - Lease
7. Click "Assign Resident"
8. ✅ Done! Flat turns blue
```

**What Happens:**
- User document updated with flatId
- Flat document updated with residentId
- Building occupancy stats updated
- Grid updates in real-time

### Method 2: Create New Resident
```
1. Click vacant flat (grey)
2. Click "Assign Resident"
3. Select "Add New" tab
4. Fill form:
   - Name* (required)
   - Phone* (required)
   - Family Members
   - Email
5. Choose ownership type
6. See auto-generated credentials:
   - Resident ID: RES1234
   - Password: abc123XY
   - Auth Email: RES1234@lyvo.com
7. Click "Assign Resident"
8. ✅ Done! Resident created and assigned
```

**What Happens:**
- Firebase Auth account created
- User document created in Firestore
- Flat assigned to new resident
- Building occupancy updated
- Resident can now login!

## Remove Resident from Flat

```
1. Click occupied flat (blue)
2. Click "Remove" button
3. Confirm removal
4. ✅ Done! Flat turns grey
```

**What Happens:**
- User document updated (flatId=null)
- Flat document updated (status=vacant)
- Building occupancy updated
- Grid updates in real-time

## Change Flat Status

```
1. Click any flat
2. Select new status from dropdown:
   - Vacant
   - Occupied
   - Maintenance
3. Confirm change
4. ✅ Done! Flat color changes
```

**Status Change Rules:**
- Occupied → Vacant: Removes resident
- Occupied → Maintenance: Keeps resident
- Maintenance → Vacant: Changes status
- Vacant → Occupied: Requires resident assignment

## View Flat Details

### Vacant Flat
```
Click grey flat → See:
- Flat number (e.g., A101)
- Floor number
- Flat type (2BHK, 3BHK)
- Area (sqft)
- Status badge (Vacant)
- "Assign Resident" button
```

### Occupied Flat
```
Click blue flat → See:
- Flat number
- Resident name
- Floor number
- Flat type
- Area
- Status badge (Occupied)
- "Remove" button
- Status dropdown
```

### Maintenance Flat
```
Click orange flat → See:
- Flat number
- Floor number
- Flat type
- Area
- Status badge (Maintenance)
- Status dropdown
```

## Common Scenarios

### Scenario 1: New Building Setup
```
1. Add building (e.g., Tower A, 10 floors, 4 flats/floor)
2. System auto-creates 40 flats
3. All flats start as vacant (grey)
4. Open grid to view all flats
5. Start assigning residents
```

### Scenario 2: Assign Multiple Residents
```
1. Open flat occupancy grid
2. Click first vacant flat
3. Assign resident (existing or new)
4. Flat turns blue
5. Click next vacant flat
6. Repeat until all assigned
```

### Scenario 3: Resident Moving Out
```
1. Open flat occupancy grid
2. Find resident's flat (blue)
3. Click the flat
4. Click "Remove"
5. Confirm removal
6. Flat turns grey (vacant)
7. Resident can be assigned to another flat
```

### Scenario 4: Flat Under Maintenance
```
1. Open flat occupancy grid
2. Click the flat
3. Select "Maintenance" from dropdown
4. Flat turns orange
5. When maintenance done:
   - Change status back to "Vacant" or "Occupied"
```

### Scenario 5: Find Specific Flat
```
1. Open flat occupancy grid
2. Use search box
3. Type flat number (e.g., "A505")
4. Flat appears in results
5. Click to view/edit
```

### Scenario 6: View All Occupied Flats
```
1. Open flat occupancy grid
2. Click filter dropdown
3. Select "Occupied"
4. See only blue flats
5. View resident names
```

## Flat Naming Convention

Flats are auto-named based on:
- First letter of building name
- Floor number
- Flat number (zero-padded)

**Examples:**
```
Building: "Tower A"
Floor 1, Flat 1 → A101
Floor 1, Flat 2 → A102
Floor 10, Flat 1 → A1001
Floor 10, Flat 4 → A1004

Building: "Block B"
Floor 5, Flat 3 → B503
Floor 12, Flat 2 → B1202
```

## Resident Credentials

### Auto-Generated for New Residents
- **Resident ID**: RES + 4 random digits (e.g., RES1234)
- **Password**: 8 random alphanumeric characters (e.g., aB3xY9Zk)
- **Auth Email**: ResidentID@lyvo.com (e.g., RES1234@lyvo.com)

### Resident Can Login With
1. Phone + Password
2. Resident ID + Password
3. Auth Email + Password

**Example:**
```
Resident ID: RES1234
Password: abc123XY
Phone: 1234567890

Login Options:
- 1234567890 + abc123XY
- RES1234 + abc123XY
- RES1234@lyvo.com + abc123XY
```

## Occupancy Statistics

### Calculation
```
Total Flats = Floors × Flats per Floor
Occupied = Count of flats with status="occupied"
Vacant = Count of flats with status="vacant"
Maintenance = Count of flats with status="maintenance"
Occupancy Rate = (Occupied / Total Flats) × 100
```

### Auto-Update Triggers
- Resident assigned → Occupied +1, Vacant -1
- Resident removed → Occupied -1, Vacant +1
- Status changed → Recalculate stats

### View Statistics
```
Building Card shows:
- Total Flats: 40
- Occupied: 25
- Vacant: 15
- Occupancy Rate: 62%
```

## Keyboard Shortcuts

- **Tab**: Move between fields
- **Enter**: Submit form
- **Escape**: Close modal
- **Ctrl+F**: Focus search box (in grid)

## Troubleshooting

### Flat Not Appearing in Grid
- Check if building has flats
- Verify Firestore connection
- Check search/filter settings
- Refresh the page

### Cannot Assign Resident
- Verify flat is vacant
- Check resident is available
- Ensure all required fields filled
- Check Firestore permissions

### Resident Not Removed
- Verify you clicked "Confirm"
- Check Firestore connection
- Check for error messages
- Try again after a moment

### Occupancy Stats Wrong
- Click grid icon to view actual flats
- Check flat statuses in grid
- Verify resident assignments
- Stats auto-sync from flats

### Grid Not Updating
- Check internet connection
- Verify Firestore rules
- Refresh the page
- Check for error messages

## Best Practices

1. **Consistent Naming**: Use clear building names (Tower A, Block B)
2. **Regular Updates**: Keep flat statuses current
3. **Verify Assignments**: Check resident details before assigning
4. **Document Credentials**: Save resident credentials securely
5. **Regular Audits**: Review occupancy grid periodically

## Data Persistence

- All data stored in Firestore
- Real-time synchronization
- Automatic backup by Firebase
- Works across devices
- No local storage required

## Security

- Firebase Authentication required
- Admin role verification
- Firestore security rules enforced
- Audit trail maintained
- Encrypted data transmission

## Performance Tips

1. **Batch Operations**: Flats created in batches
2. **Lazy Loading**: Grid loads on-demand
3. **Real-Time Updates**: No manual refresh needed
4. **Efficient Queries**: Optimized Firestore queries
5. **Client-Side Sorting**: Reduces server load

## Integration with Other Modules

### Dashboard
- Total flats count
- Occupancy statistics
- Real-time updates

### Building Management
- Auto-create flats
- Sync occupancy stats
- Cascading delete

### Resident Management
- Assign residents
- Create new residents
- Update assignments

### Billing
- Flat-based billing
- Resident billing info
- Occupancy tracking

## Quick Commands

### View Flats
```dart
// In code
final flats = await FlatService().getFlatsForBuilding(buildingId).first;
```

### Assign Resident
```dart
// In code
await FlatService().assignResident(
  flatId: 'A101',
  residentName: 'John Doe',
  residentId: 'user_id',
);
```

### Remove Resident
```dart
// In code
await FlatService().removeResident('A101');
```

### Change Status
```dart
// In code
await FlatService().updateFlatStatus(
  flatId: 'A101',
  status: 'maintenance',
);
```

## Color Reference

### Status Colors
- **Occupied**: #2563EB (Blue)
- **Vacant**: #E5E7EB (Grey)
- **Maintenance**: #F97316 (Orange)

### UI Colors
- **Success**: #10B981 (Green)
- **Error**: #EF4444 (Red)
- **Warning**: #F4A100 (Yellow)
- **Info**: #2563EB (Blue)

## Accessibility

- All buttons have labels
- Keyboard navigation supported
- Screen reader friendly
- Color contrast compliant
- Focus indicators visible

## Support

For issues or questions:
1. Check this quick reference
2. Review error messages
3. Check Firestore console
4. Verify authentication
5. Test internet connection

---

**Tip**: Keep this guide handy for quick reference while managing flats!
