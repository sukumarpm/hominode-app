# Chat Technician Display Examples

## Example 1: Plumbing Complaint

**Complaint**: Water Leakage in Bathroom  
**Assigned To**: Ramesh Kumar  
**Phone**: +91 98765 43210  
**Category**: Plumbing

**Chat Header Shows**:
```
┌────────────────────────────────────┐
│  [R]  Ramesh Kumar            ✕   │
│       Plumbing Technician          │
│       📞 +91 98765 43210           │
└────────────────────────────────────┘
```

---

## Example 2: Maintenance Complaint

**Complaint**: Lift Maintenance Required  
**Assigned To**: Suresh Patel  
**Phone**: +91 98765 43211  
**Category**: Maintenance

**Chat Header Shows**:
```
┌────────────────────────────────────┐
│  [S]  Suresh Patel            ✕   │
│       Maintenance Technician       │
│       📞 +91 98765 43211           │
└────────────────────────────────────┘
```

---

## Example 3: No Technician Assigned

**Complaint**: Hallway Light Not Working  
**Assigned To**: null  
**Phone**: null  
**Category**: Electrical

**When User Taps "Chat With Technician"**:
```
┌────────────────────────────────────┐
│  ⚠️ No technician assigned yet.   │
│     Please wait for assignment.    │
└────────────────────────────────────┘
```
(SnackBar appears, chat doesn't open)

---

## Category to Role Mapping

| Complaint Category | Technician Role Display |
|-------------------|------------------------|
| Plumbing | Plumbing Technician |
| Electrical | Electrical Technician |
| Maintenance | Maintenance Technician |
| Cleaning | Cleaning Staff |
| Security | Security Personnel |
| Other | Support Staff |

---

## Code Flow

```
User Action: Tap "Chat With Technician"
                    ↓
Check: complaint.assignedTo != null?
                    ↓
        ┌───────────┴───────────┐
        │                       │
       YES                     NO
        │                       │
        ↓                       ↓
Open Chat Screen        Show SnackBar
with technician         "No technician
name & phone           assigned yet"
```

---

## Real API Response Example

```json
{
  "id": "complaint_123",
  "title": "Water Leakage in Bathroom",
  "description": "Tap is leaking continuously",
  "category": "plumbing",
  "status": "in-progress",
  "createdDate": "2025-10-28T10:00:00Z",
  "assignedTo": "Ramesh Kumar",
  "technicianPhone": "+91 98765 43210",
  "technicianId": "tech_001"
}
```

This data automatically populates the chat screen with the correct technician information.
