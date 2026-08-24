# Staff QR Entry Management - Code Examples

## Quick Code Snippets

### 1. Add Staff with QR Code

```dart
// In your staff management screen
void _showAddStaffDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (context) => AddStaffWithQRModal(
      buildingId: 'building_123',
    ),
  ).then((result) {
    if (result == true) {
      setState(() {}); // Refresh staff list
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Staff member added successfully'),
          backgroundColor: Color(0xFF10B981),
        ),
      );
    }
  });
}
```

### 2. View Staff Profile with QR

```dart
// Navigate to staff profile
void _viewStaffProfile(String staffId) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => StaffProfileQRScreen(
        staffId: staffId,
      ),
    ),
  );
}
```

### 3. Open QR Scanner

```dart
// In security app
void _openQRScanner() {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => const SecurityStaffQRScanner(),
    ),
  );
}
```

### 4. View Attendance History

```dart
// Navigate to attendance details
void _viewAttendance(String staffId, String staffName) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => StaffAttendanceDetailsScreen(
        staffId: staffId,
        staffName: staffName,
      ),
    ),
  );
}
```

---

## Service Usage Examples

### 1. Create Staff with QR

```dart
final StaffQRService _qrService = StaffQRService();

Future<void> _createStaff() async {
  try {
    final staffId = await _qrService.createStaffWithQRCode(
      name: 'John Doe',
      phone: '+91 98765 43210',
      role: 'Security Guard',
      buildingId: 'building_123',
      gateName: 'Gate A',
      shiftTiming: 'Morning (6 AM - 2 PM)',
      photoUrl: 'https://example.com/photo.jpg',
    );
    
    print('Staff created with ID: $staffId');
  } catch (e) {
    print('Error: $e');
  }
}
```

### 2. Get Staff Details

```dart
Future<void> _getStaffDetails(String staffId) async {
  try {
    final staffData = await _qrService.getStaffDetails(staffId);
    
    print('Name: ${staffData['name']}');
    print('Role: ${staffData['role']}');
    print('Phone: ${staffData['phone']}');
    print('Gate: ${staffData['gateName']}');
    print('Shift: ${staffData['shiftTiming']}');
  } catch (e) {
    print('Error: $e');
  }
}
```

### 3. Mark Entry

```dart
Future<void> _markEntry(String staffId) async {
  try {
    await _qrService.markStaffEntry(staffId);
    print('Entry marked successfully');
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Entry marked successfully'),
        backgroundColor: Color(0xFF10B981),
      ),
    );
  } catch (e) {
    print('Error: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error: $e')),
    );
  }
}
```

### 4. Mark Exit

```dart
Future<void> _markExit(String staffId) async {
  try {
    await _qrService.markStaffExit(staffId);
    print('Exit marked successfully');
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Exit marked successfully'),
        backgroundColor: Color(0xFF10B981),
      ),
    );
  } catch (e) {
    print('Error: $e');
  }
}
```

### 5. Get Attendance Records

```dart
Future<void> _getAttendance(String staffId) async {
  try {
    final records = await _qrService.getStaffAttendance(staffId);
    
    for (var record in records) {
      print('Entry: ${record['entryTime']}');
      print('Exit: ${record['exitTime']}');
      print('Status: ${record['status']}');
      print('---');
    }
  } catch (e) {
    print('Error: $e');
  }
}
```

### 6. Update Staff Details

```dart
Future<void> _updateStaff(String staffId) async {
  try {
    await _qrService.updateStaffDetails(staffId, {
      'phone': '+91 98765 99999',
      'role': 'Senior Security Guard',
      'shiftTiming': 'Night (10 PM - 6 AM)',
    });
    
    print('Staff updated successfully');
  } catch (e) {
    print('Error: $e');
  }
}
```

### 7. Delete Staff

```dart
Future<void> _deleteStaff(String staffId) async {
  try {
    await _qrService.deleteStaffMember(staffId);
    print('Staff deleted successfully');
  } catch (e) {
    print('Error: $e');
  }
}
```

### 8. Get All Staff

```dart
Future<void> _getAllStaff() async {
  try {
    final staffList = await _qrService.getAllStaffMembers();
    
    for (var staff in staffList) {
      print('${staff['name']} - ${staff['role']}');
    }
  } catch (e) {
    print('Error: $e');
  }
}
```

---

## Widget Integration Examples

### 1. Add Staff Button in Staff Management

```dart
class StaffManagementScreen extends StatefulWidget {
  @override
  State<StaffManagementScreen> createState() => _StaffManagementScreenState();
}

class _StaffManagementScreenState extends State<StaffManagementScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Staff Management'),
        actions: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: ElevatedButton.icon(
              onPressed: () => _showAddStaffDialog(context),
              icon: const Icon(Icons.add),
              label: const Text('Add Staff'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3B82F6),
              ),
            ),
          ),
        ],
      ),
      body: _buildStaffList(),
    );
  }

  void _showAddStaffDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AddStaffWithQRModal(
        buildingId: 'building_123',
      ),
    ).then((result) {
      if (result == true) {
        setState(() {}); // Refresh
      }
    });
  }

  Widget _buildStaffList() {
    // Your staff list implementation
    return const Center(child: Text('Staff List'));
  }
}
```

### 2. Staff Card with QR Navigation

```dart
Widget _buildStaffCard(Map<String, dynamic> staff) {
  return Card(
    child: ListTile(
      leading: CircleAvatar(
        backgroundImage: staff['photoUrl'] != null
            ? NetworkImage(staff['photoUrl'])
            : null,
        child: staff['photoUrl'] == null
            ? const Icon(Icons.person)
            : null,
      ),
      title: Text(staff['name'] ?? 'N/A'),
      subtitle: Text(staff['role'] ?? 'N/A'),
      trailing: const Icon(Icons.arrow_forward),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => StaffProfileQRScreen(
              staffId: staff['staffId'],
            ),
          ),
        );
      },
    ),
  );
}
```

### 3. Attendance Button in Staff Details

```dart
Widget _buildAttendanceButton(String staffId, String staffName) {
  return ElevatedButton.icon(
    onPressed: () {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => StaffAttendanceDetailsScreen(
            staffId: staffId,
            staffName: staffName,
          ),
        ),
      );
    },
    icon: const Icon(Icons.calendar_today),
    label: const Text('View Attendance'),
    style: ElevatedButton.styleFrom(
      backgroundColor: const Color(0xFF10B981),
    ),
  );
}
```

---

## Firestore Query Examples

### 1. Get Staff by ID

```dart
Future<Map<String, dynamic>> getStaffById(String staffId) async {
  final doc = await FirebaseFirestore.instance
      .collection('staff')
      .doc(staffId)
      .get();
  
  return doc.data() ?? {};
}
```

### 2. Get All Staff for Admin

```dart
Future<List<Map<String, dynamic>>> getAdminStaff(String adminId) async {
  final snapshot = await FirebaseFirestore.instance
      .collection('staff')
      .where('adminId', isEqualTo: adminId)
      .orderBy('createdAt', descending: true)
      .get();
  
  return snapshot.docs.map((doc) => doc.data()).toList();
}
```

### 3. Get Today's Attendance

```dart
Future<List<Map<String, dynamic>>> getTodayAttendance(String staffId) async {
  final now = DateTime.now();
  final startOfDay = DateTime(now.year, now.month, now.day);
  final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);
  
  final snapshot = await FirebaseFirestore.instance
      .collection('staffAttendance')
      .where('staffId', isEqualTo: staffId)
      .where('entryTime', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
      .where('entryTime', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
      .get();
  
  return snapshot.docs.map((doc) => doc.data()).toList();
}
```

### 4. Get Attendance by Date Range

```dart
Future<List<Map<String, dynamic>>> getAttendanceByDateRange(
  String staffId,
  DateTime startDate,
  DateTime endDate,
) async {
  final snapshot = await FirebaseFirestore.instance
      .collection('staffAttendance')
      .where('staffId', isEqualTo: staffId)
      .where('entryTime', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
      .where('entryTime', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
      .orderBy('entryTime', descending: true)
      .get();
  
  return snapshot.docs.map((doc) => doc.data()).toList();
}
```

---

## Error Handling Examples

### 1. Try-Catch Pattern

```dart
Future<void> _safeMarkEntry(String staffId) async {
  try {
    await _qrService.markStaffEntry(staffId);
    _showSuccessMessage('Entry marked successfully');
  } on FirebaseException catch (e) {
    _showErrorMessage('Firebase Error: ${e.message}');
  } on Exception catch (e) {
    _showErrorMessage('Error: $e');
  }
}
```

### 2. Error Message Display

```dart
void _showErrorMessage(String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: const Color(0xFFEF4444),
      duration: const Duration(seconds: 3),
    ),
  );
}

void _showSuccessMessage(String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: const Color(0xFF10B981),
      duration: const Duration(seconds: 2),
    ),
  );
}
```

---

## State Management Examples

### 1. Using FutureBuilder

```dart
FutureBuilder<Map<String, dynamic>>(
  future: _qrService.getStaffDetails(staffId),
  builder: (context, snapshot) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return const Center(child: CircularProgressIndicator());
    }
    
    if (snapshot.hasError) {
      return Center(child: Text('Error: ${snapshot.error}'));
    }
    
    final staffData = snapshot.data ?? {};
    return _buildStaffProfile(staffData);
  },
)
```

### 2. Using StreamBuilder

```dart
StreamBuilder<DocumentSnapshot>(
  stream: FirebaseFirestore.instance
      .collection('staff')
      .doc(staffId)
      .snapshots(),
  builder: (context, snapshot) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return const Center(child: CircularProgressIndicator());
    }
    
    if (snapshot.hasError) {
      return Center(child: Text('Error: ${snapshot.error}'));
    }
    
    final staffData = snapshot.data?.data() as Map<String, dynamic>? ?? {};
    return _buildStaffProfile(staffData);
  },
)
```

---

## Testing Examples

### 1. Unit Test for Service

```dart
void main() {
  group('StaffQRService', () {
    late StaffQRService service;
    
    setUp(() {
      service = StaffQRService();
    });
    
    test('Generate QR code', () async {
      final qrCode = await service.generateQRCode('staff_123');
      expect(qrCode, isNotNull);
      expect(qrCode, isA<Uint8List>());
    });
    
    test('Create staff with QR', () async {
      final staffId = await service.createStaffWithQRCode(
        name: 'Test Staff',
        phone: '+91 98765 43210',
        role: 'Guard',
        buildingId: 'building_123',
        gateName: 'Gate A',
        shiftTiming: 'Morning',
      );
      
      expect(staffId, isNotNull);
      expect(staffId, isA<String>());
    });
  });
}
```

### 2. Widget Test

```dart
void main() {
  testWidgets('Add Staff Modal displays form', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AddStaffWithQRModal(buildingId: 'building_123'),
        ),
      ),
    );
    
    expect(find.byType(TextFormField), findsWidgets);
    expect(find.byType(DropdownButtonFormField), findsWidgets);
    expect(find.byType(ElevatedButton), findsOneWidget);
  });
}
```

---

## Integration Examples

### 1. Main.dart Routes

```dart
void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Admin & Security App',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const AdminDashboard(),
      routes: {
        '/staff-profile-qr': (context) {
          final staffId = ModalRoute.of(context)?.settings.arguments as String;
          return StaffProfileQRScreen(staffId: staffId);
        },
        '/security-staff-scanner': (context) => const SecurityStaffQRScanner(),
        '/staff-attendance': (context) {
          final args = ModalRoute.of(context)?.settings.arguments as Map;
          return StaffAttendanceDetailsScreen(
            staffId: args['staffId'],
            staffName: args['staffName'],
          );
        },
      },
    );
  }
}
```

### 2. Navigation Examples

```dart
// Navigate to staff profile
Navigator.pushNamed(
  context,
  '/staff-profile-qr',
  arguments: 'staff_123',
);

// Navigate to scanner
Navigator.pushNamed(context, '/security-staff-scanner');

// Navigate to attendance
Navigator.pushNamed(
  context,
  '/staff-attendance',
  arguments: {
    'staffId': 'staff_123',
    'staffName': 'John Doe',
  },
);
```

---

## Performance Optimization Examples

### 1. Image Caching

```dart
CircleAvatar(
  backgroundImage: CachedNetworkImageProvider(
    staffData['photoUrl'],
    cacheManager: CacheManager(
      Config(
        'staff_photos',
        stalePeriod: const Duration(days: 7),
      ),
    ),
  ),
)
```

### 2. Lazy Loading

```dart
ListView.builder(
  itemCount: staffList.length,
  itemBuilder: (context, index) {
    return _buildStaffCard(staffList[index]);
  },
)
```

---

## Complete Example: Staff Management Screen

```dart
class StaffManagementScreen extends StatefulWidget {
  const StaffManagementScreen({Key? key}) : super(key: key);

  @override
  State<StaffManagementScreen> createState() => _StaffManagementScreenState();
}

class _StaffManagementScreenState extends State<StaffManagementScreen> {
  final StaffQRService _qrService = StaffQRService();
  late Future<List<Map<String, dynamic>>> _staffFuture;

  @override
  void initState() {
    super.initState();
    _staffFuture = _qrService.getAllStaffMembers();
  }

  void _showAddStaffDialog() {
    showDialog(
      context: context,
      builder: (context) => AddStaffWithQRModal(
        buildingId: 'building_123',
      ),
    ).then((result) {
      if (result == true) {
        setState(() {
          _staffFuture = _qrService.getAllStaffMembers();
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Staff Management'),
        actions: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: ElevatedButton.icon(
              onPressed: _showAddStaffDialog,
              icon: const Icon(Icons.add),
              label: const Text('Add Staff'),
            ),
          ),
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _staffFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final staffList = snapshot.data ?? [];

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: staffList.length,
            itemBuilder: (context, index) {
              final staff = staffList[index];
              return _buildStaffCard(staff);
            },
          );
        },
      ),
    );
  }

  Widget _buildStaffCard(Map<String, dynamic> staff) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundImage: staff['photoUrl'] != null
              ? NetworkImage(staff['photoUrl'])
              : null,
          child: staff['photoUrl'] == null
              ? const Icon(Icons.person)
              : null,
        ),
        title: Text(staff['name'] ?? 'N/A'),
        subtitle: Text(staff['role'] ?? 'N/A'),
        trailing: const Icon(Icons.arrow_forward),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => StaffProfileQRScreen(
                staffId: staff['staffId'],
              ),
            ),
          );
        },
      ),
    );
  }
}
```

---

## Notes

- All examples use proper error handling
- Follow the service-based architecture
- Use FutureBuilder for async operations
- Implement proper state management
- Always validate user input
- Show appropriate user feedback
