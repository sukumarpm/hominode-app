# 🚀 Quick Integration Guide

## How to Use the New Flat Management System

### Step 1: Test the Demo (Recommended First Step)

1. **Update your `main.dart`** to test the demo:

```dart
import 'package:flutter/material.dart';
import 'flat_management_demo.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flat Management Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2563EB)),
        useMaterial3: true,
      ),
      home: const FlatManagementDemo(),
    );
  }
}
```

2. **Run the app:**
```bash
flutter run
```

3. **Test all flows:**
   - Tap "Open Flat Grid"
   - Click on grey tiles (vacant) → Assign residents
   - Click on green tiles (occupied) → Remove residents or change status
   - Click on yellow tiles (maintenance) → Change status
   - Watch the grid update in real-time!

---

### Step 2: Integrate into Your Existing App

#### Option A: Add to Manage Buildings Page

Update `lib/manage_buildings_page.dart`:

```dart
import 'package:flutter/material.dart';
import 'services/flat_service.dart';
import 'widgets/flat_occupancy_grid_with_state.dart';

class ManageBuildingsPage extends StatefulWidget {
  const ManageBuildingsPage({super.key});

  @override
  State<ManageBuildingsPage> createState() => _ManageBuildingsPageState();
}

class _ManageBuildingsPageState extends State<ManageBuildingsPage> {
  late final FlatService _flatService;

  @override
  void initState() {
    super.initState();
    _flatService = FlatService();
    _flatService.initializeMockData(); // Replace with API call later
    _flatService.addListener(_onDataChanged);
  }

  @override
  void dispose() {
    _flatService.removeListener(_onDataChanged);
    _flatService.dispose();
    super.dispose();
  }

  void _onDataChanged() {
    setState(() {});
  }

  void _openFlatGrid() {
    FlatOccupancyGridWithState.show(
      context,
      flatService: _flatService,
    );
  }

  @override
  Widget build(BuildContext context) {
    final counts = _flatService.getStatusCounts();
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Buildings'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Your existing building list...
            
            // Add this button to open flat grid
            Card(
              child: ListTile(
                leading: const Icon(Icons.grid_view),
                title: const Text('Tower A - Flat Occupancy Grid'),
                subtitle: Text(
                  'Occupied: ${counts['occupied']} | Vacant: ${counts['vacant']} | Maintenance: ${counts['maintenance']}'
                ),
                trailing: const Icon(Icons.arrow_forward_ios),
                onTap: _openFlatGrid,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

#### Option B: Add as Floating Action Button

```dart
floatingActionButton: FloatingActionButton.extended(
  onPressed: _openFlatGrid,
  icon: const Icon(Icons.grid_view),
  label: const Text('Flat Grid'),
),
```

---

### Step 3: Replace Mock Data with API

Update `lib/services/flat_service.dart`:

```dart
// Add this method to FlatService class
Future<void> loadFromApi() async {
  try {
    // Replace with your actual API endpoint
    final response = await http.get(Uri.parse('YOUR_API_URL/buildings'));
    
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      
      // Parse and populate _buildings
      for (var buildingData in data) {
        final building = Building.fromJson(buildingData);
        _buildings[building.id] = building;
      }
      
      notifyListeners();
    }
  } catch (e) {
    debugPrint('Error loading buildings: $e');
    // Fallback to mock data for development
    initializeMockData();
  }
}
```

Then in your page:

```dart
@override
void initState() {
  super.initState();
  _flatService = FlatService();
  _flatService.loadFromApi(); // Instead of initializeMockData()
  _flatService.addListener(_onDataChanged);
}
```

---

### Step 4: Add API Calls for Actions

Update the action methods in `flat_service.dart`:

```dart
Future<void> assignResidentToFlatApi(
  String flatId,
  Resident resident,
  String ownershipType,
) async {
  try {
    final response = await http.post(
      Uri.parse('YOUR_API_URL/flats/$flatId/assign'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'residentId': resident.id,
        'residentName': resident.name,
        'phone': resident.phone,
        'email': resident.email,
        'ownershipType': ownershipType,
        'familyMembers': resident.familyMembers,
      }),
    );

    if (response.statusCode == 200) {
      // Update local state
      assignResidentToFlat(flatId, resident, ownershipType);
    } else {
      throw Exception('Failed to assign resident');
    }
  } catch (e) {
    debugPrint('Error assigning resident: $e');
    rethrow;
  }
}
```

Similar pattern for:
- `changeFlatStatusApi()`
- `removeResidentFromFlatApi()`

---

## 🎯 Key Points

### 1. FlatService is the Single Source of Truth
- Initialize it once in your page
- Pass it to all modals
- All changes go through FlatService
- UI updates automatically

### 2. Listen to Changes
```dart
_flatService.addListener(_onDataChanged);

void _onDataChanged() {
  setState(() {}); // Rebuild to show updated data
}
```

### 3. Clean Up
```dart
@override
void dispose() {
  _flatService.removeListener(_onDataChanged);
  _flatService.dispose();
  super.dispose();
}
```

---

## 📋 Checklist

- [ ] Test demo page works
- [ ] Integrate into your existing page
- [ ] Replace mock data with API calls
- [ ] Add error handling
- [ ] Add loading indicators
- [ ] Test all flows (vacant → occupied → maintenance)
- [ ] Test search and filters
- [ ] Test grid/list view switching

---

## 🐛 Troubleshooting

### Issue: Grid doesn't update after changes
**Solution:** Make sure you're calling `addListener()` and `setState()` in `_onDataChanged()`

### Issue: Modal doesn't close after action
**Solution:** Check that `Navigator.of(context).pop()` is called after successful action

### Issue: Data not persisting
**Solution:** Implement API calls to save changes to backend

### Issue: Multiple FlatService instances
**Solution:** Create FlatService once at app level and pass down, or use Provider/Riverpod

---

## 🎓 Advanced: Using Provider (Optional)

If you want to use Provider for better state management:

1. Add dependency:
```yaml
dependencies:
  provider: ^6.1.1
```

2. Wrap your app:
```dart
void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => FlatService()..initializeMockData(),
      child: const MyApp(),
    ),
  );
}
```

3. Access in widgets:
```dart
final flatService = Provider.of<FlatService>(context);
// or
final flatService = context.watch<FlatService>();
```

---

## 📞 Need Help?

Check these files for reference:
- **Complete docs:** `FLAT_MANAGEMENT_COMPLETE_IMPLEMENTATION.md`
- **Working demo:** `lib/flat_management_demo.dart`
- **State management:** `lib/services/flat_service.dart`
- **Models:** `lib/models/flat_models.dart`

---

**Ready to go! 🚀**
