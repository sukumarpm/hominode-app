/// Create Monthly Bill Modal
/// 
/// A centered overlay modal for generating monthly maintenance bills.
/// Matches the admin app visual system with compact UI flow.
/// 
/// Usage:
/// ```dart
/// CreateMonthlyBillModal.show(
///   context,
///   onGenerate: (config) {
///     ScaffoldMessenger.of(context).showSnackBar(
///       SnackBar(content: Text('Bills generated for ${config.monthName} ${config.year}')),
///     );
///   },
/// );
/// ```
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/monthly_bill_config.dart';

// ============================================================================
// CREATE MONTHLY BILL MODAL
// ============================================================================

class CreateMonthlyBillModal extends StatefulWidget {
  final void Function(MonthlyBillConfig config) onGenerate;

  const CreateMonthlyBillModal({
    super.key,
    required this.onGenerate,
  });

  /// Show the modal with fade and scale animation
  static Future<void> show(
    BuildContext context, {
    required void Function(MonthlyBillConfig config) onGenerate,
  }) {
    return showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close',
      barrierColor: const Color(0x59000000), // rgba(0, 0, 0, 0.35)
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (context, animation, secondaryAnimation) {
        return CreateMonthlyBillModal(onGenerate: onGenerate);
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.96, end: 1.0).animate(
              CurvedAnimation(
                parent: animation,
                curve: Curves.easeOut,
              ),
            ),
            child: child,
          ),
        );
      },
    );
  }

  @override
  State<CreateMonthlyBillModal> createState() => _CreateMonthlyBillModalState();
}

class _CreateMonthlyBillModalState extends State<CreateMonthlyBillModal> {
  final _formKey = GlobalKey<FormState>();
  
  // Individual amount controllers for each charge type
  final _maintenanceController = TextEditingController();
  final _waterController = TextEditingController();
  final _parkingController = TextEditingController();
  final _serviceController = TextEditingController();
  final _electricityController = TextEditingController();
  final _securityController = TextEditingController();
  final _otherController = TextEditingController();
  
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? _selectedMonth;
  int? _selectedYear;
  int? _selectedMonthNumber;
  DateTime? _selectedDueDate;
  String _selectedScope = 'All Residents';
  String? _selectedBuildingId;
  String? _selectedBuildingName;
  List<String> _selectedFlatIds = [];
  bool _isGenerating = false;
  
  List<Map<String, dynamic>> _buildings = [];
  List<Map<String, dynamic>> _flats = [];
  bool _loadingBuildings = false;
  bool _loadingFlats = false;

  final List<String> _scopeOptions = [
    'All Residents',
    'Specific Units',
  ];

  @override
  void initState() {
    super.initState();
    _loadBuildings();
  }

  @override
  void dispose() {
    _maintenanceController.dispose();
    _waterController.dispose();
    _parkingController.dispose();
    _serviceController.dispose();
    _electricityController.dispose();
    _securityController.dispose();
    _otherController.dispose();
    super.dispose();
  }

  // Generate month/year options dynamically
  List<Map<String, dynamic>> _generateMonthYearOptions() {
    final now = DateTime.now();
    final options = <Map<String, dynamic>>[];
    
    // Generate options for current month + next 12 months
    for (int i = 0; i < 13; i++) {
      final date = DateTime(now.year, now.month + i, 1);
      options.add({
        'display': DateFormat('MMMM yyyy').format(date),
        'month': date.month,
        'year': date.year,
        'monthName': DateFormat('MMMM').format(date),
      });
    }
    
    return options;
  }

  // Load buildings from Firestore
  Future<void> _loadBuildings() async {
    setState(() {
      _loadingBuildings = true;
    });

    try {
      final snapshot = await _firestore
          .collection('buildings')
          .orderBy('name')
          .get();

      setState(() {
        _buildings = snapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'id': doc.id,
            'name': data['name'] ?? '',
          };
        }).toList();
        _loadingBuildings = false;
      });
    } catch (e) {
      setState(() {
        _loadingBuildings = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load buildings: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  // Load flats for selected building from Firestore
  Future<void> _loadFlatsForBuilding(String buildingId) async {
    setState(() {
      _loadingFlats = true;
      _flats = [];
      _selectedFlatIds = [];
    });

    try {
      // Fetch flats for the building
      final flatsSnapshot = await _firestore
          .collection('flats')
          .where('buildingId', isEqualTo: buildingId)
          .get();

      final flats = <Map<String, dynamic>>[];

      for (var flatDoc in flatsSnapshot.docs) {
        final flatData = flatDoc.data();
        final flatId = flatData['id'] ?? flatDoc.id;
        
        // Fetch residents (users) assigned to this flat
        final usersSnapshot = await _firestore
            .collection('users')
            .where('flatId', isEqualTo: flatId)
            .where('role', isEqualTo: 'resident')
            .get();

        // Collect resident names
        final residentNames = usersSnapshot.docs
            .map((doc) => doc.data()['name'] as String?)
            .where((name) => name != null && name.isNotEmpty)
            .toList();

        flats.add({
          'id': flatId,
          'floor': flatData['floor'] ?? 0,
          'flatNumber': flatData['flatNumber'] ?? 0,
          'status': flatData['status'] ?? 'vacant',
          'residentNames': residentNames,
          'residentCount': residentNames.length,
        });
      }

      // Sort by floor (descending) then flatNumber (ascending)
      flats.sort((a, b) {
        final floorCompare = (b['floor'] as int).compareTo(a['floor'] as int);
        if (floorCompare != 0) return floorCompare;
        return (a['flatNumber'] as int).compareTo(b['flatNumber'] as int);
      });

      setState(() {
        _flats = flats;
        _loadingFlats = false;
      });
    } catch (e) {
      setState(() {
        _loadingFlats = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load flats: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  bool get _isFormValid {
    if (_selectedMonth == null || _selectedYear == null) return false;
    
    // At least one charge amount must be entered
    final hasMaintenanceAmount = _maintenanceController.text.trim().isNotEmpty &&
        (double.tryParse(_maintenanceController.text.trim()) ?? 0) > 0;
    final hasWaterAmount = _waterController.text.trim().isNotEmpty &&
        (double.tryParse(_waterController.text.trim()) ?? 0) > 0;
    final hasParkingAmount = _parkingController.text.trim().isNotEmpty &&
        (double.tryParse(_parkingController.text.trim()) ?? 0) > 0;
    final hasServiceAmount = _serviceController.text.trim().isNotEmpty &&
        (double.tryParse(_serviceController.text.trim()) ?? 0) > 0;
    final hasElectricityAmount = _electricityController.text.trim().isNotEmpty &&
        (double.tryParse(_electricityController.text.trim()) ?? 0) > 0;
    final hasSecurityAmount = _securityController.text.trim().isNotEmpty &&
        (double.tryParse(_securityController.text.trim()) ?? 0) > 0;
    final hasOtherAmount = _otherController.text.trim().isNotEmpty &&
        (double.tryParse(_otherController.text.trim()) ?? 0) > 0;
    
    if (!hasMaintenanceAmount && !hasWaterAmount && !hasParkingAmount &&
        !hasServiceAmount && !hasElectricityAmount && !hasSecurityAmount &&
        !hasOtherAmount) {
      return false;
    }
    
    if (_selectedDueDate == null) return false;
    
    // Due date must be today or in the future
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    if (_selectedDueDate!.isBefore(todayDate)) return false;
    
    // If Specific Units is selected, must have building and at least one flat
    if (_selectedScope == 'Specific Units') {
      if (_selectedBuildingId == null) return false;
      if (_selectedFlatIds.isEmpty) return false;
    }
    
    return true;
  }

  Future<void> _handleGenerate() async {
    if (!_formKey.currentState!.validate() || !_isFormValid) {
      return;
    }

    setState(() {
      _isGenerating = true;
    });

    try {
      // Parse all charge amounts (default to 0 if empty)
      final maintenanceAmount = double.tryParse(_maintenanceController.text.trim()) ?? 0;
      final waterAmount = double.tryParse(_waterController.text.trim()) ?? 0;
      final parkingAmount = double.tryParse(_parkingController.text.trim()) ?? 0;
      final serviceAmount = double.tryParse(_serviceController.text.trim()) ?? 0;
      final electricityAmount = double.tryParse(_electricityController.text.trim()) ?? 0;
      final securityAmount = double.tryParse(_securityController.text.trim()) ?? 0;
      final otherAmount = double.tryParse(_otherController.text.trim()) ?? 0;
      
      final config = MonthlyBillConfig(
        year: _selectedYear!,
        month: _selectedMonthNumber!,
        dueDate: _selectedDueDate!,
        billingScope: _selectedScope == 'All Residents' ? 'all' : 'specific_units',
        building: _selectedBuildingName,
        selectedUnits: _selectedFlatIds.isNotEmpty ? _selectedFlatIds : null,
        maintenanceAmount: maintenanceAmount,
        waterAmount: waterAmount,
        parkingAmount: parkingAmount,
        serviceAmount: serviceAmount,
        electricityAmount: electricityAmount,
        securityAmount: securityAmount,
        otherAmount: otherAmount,
      );

      if (mounted) {
        widget.onGenerate(config);
        Navigator.of(context).pop();
      }
    } catch (e) {
      setState(() {
        _isGenerating = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to generate bills: $e'),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    }
  }

  void _showMonthPicker() {
    final monthYearOptions = _generateMonthYearOptions();
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 16),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Select Month & Year',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF111111),
                ),
              ),
              const SizedBox(height: 16),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: monthYearOptions.length,
                  itemBuilder: (context, index) {
                    final option = monthYearOptions[index];
                    final display = option['display'] as String;
                    final isSelected = display == _selectedMonth;

                    return InkWell(
                      onTap: () {
                        setState(() {
                          _selectedMonth = display;
                          _selectedYear = option['year'] as int;
                          _selectedMonthNumber = option['month'] as int;
                        });
                        Navigator.of(context).pop();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 16,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFFEFF6FF)
                              : Colors.white,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              display,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                                color: isSelected
                                    ? const Color(0xFF2563EB)
                                    : const Color(0xFF111111),
                              ),
                            ),
                            if (isSelected)
                              const Icon(
                                Icons.check_circle,
                                color: Color(0xFF2563EB),
                                size: 22,
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  void _showScopePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 16),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Apply Bills To',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF111111),
                ),
              ),
              const SizedBox(height: 16),
              ...List.generate(_scopeOptions.length, (index) {
                final scope = _scopeOptions[index];
                final isSelected = scope == _selectedScope;

                return InkWell(
                  onTap: () {
                    setState(() {
                      _selectedScope = scope;
                      // Reset building and flats when changing scope
                      if (scope == 'All Residents') {
                        _selectedBuildingId = null;
                        _selectedBuildingName = null;
                        _selectedFlatIds = [];
                        _flats = [];
                      }
                    });
                    Navigator.of(context).pop();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFFEFF6FF)
                          : Colors.white,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          scope,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.w400,
                            color: isSelected
                                ? const Color(0xFF2563EB)
                                : const Color(0xFF111111),
                          ),
                        ),
                        if (isSelected)
                          const Icon(
                            Icons.check_circle,
                            color: Color(0xFF2563EB),
                            size: 22,
                          ),
                      ],
                    ),
                  ),
                );
              }),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  void _showBuildingPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 16),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Select Building / Tower',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF111111),
                ),
              ),
              const SizedBox(height: 16),
              if (_loadingBuildings)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(),
                )
              else if (_buildings.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    'No buildings found',
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.grey[600],
                    ),
                  ),
                )
              else
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _buildings.length,
                    itemBuilder: (context, index) {
                      final building = _buildings[index];
                      final buildingId = building['id'] as String;
                      final buildingName = building['name'] as String;
                      final isSelected = buildingId == _selectedBuildingId;

                      return InkWell(
                        onTap: () {
                          setState(() {
                            _selectedBuildingId = buildingId;
                            _selectedBuildingName = buildingName;
                            _selectedFlatIds = [];
                          });
                          // Load flats for this building
                          _loadFlatsForBuilding(buildingId);
                          Navigator.of(context).pop();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 16,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFFEFF6FF)
                                : Colors.white,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                buildingName,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                  color: isSelected
                                      ? const Color(0xFF2563EB)
                                      : const Color(0xFF111111),
                                ),
                              ),
                              if (isSelected)
                                const Icon(
                                  Icons.check_circle,
                                  color: Color(0xFF2563EB),
                                  size: 22,
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  void _showUnitPicker() {
    if (_selectedBuildingId == null) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.7,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 16),
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE5E7EB),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Select Unit(s)',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF111111),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Select flats to generate bills for',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_loadingFlats)
                      const Padding(
                        padding: EdgeInsets.all(32),
                        child: CircularProgressIndicator(),
                      )
                    else if (_flats.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(32),
                        child: Text(
                          'No flats found for this building',
                          style: TextStyle(
                            fontSize: 15,
                            color: Colors.grey[600],
                          ),
                        ),
                      )
                    else
                      Flexible(
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: _flats.length,
                          itemBuilder: (context, index) {
                            final flat = _flats[index];
                            final flatId = flat['id'] as String;
                            final status = flat['status'] as String;
                            final residentNames = flat['residentNames'] as List<dynamic>;
                            final residentCount = flat['residentCount'] as int;
                            final isSelected = _selectedFlatIds.contains(flatId);
                            final hasResidents = residentCount > 0;

                            return InkWell(
                              onTap: () {
                                setModalState(() {
                                  if (isSelected) {
                                    _selectedFlatIds.remove(flatId);
                                  } else {
                                    _selectedFlatIds.add(flatId);
                                  }
                                });
                                setState(() {});
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 14,
                                ),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? const Color(0xFFEFF6FF)
                                      : Colors.white,
                                  border: Border(
                                    bottom: BorderSide(
                                      color: const Color(0xFFF3F4F6),
                                      width: 1,
                                    ),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Text(
                                                flatId,
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: isSelected
                                                      ? FontWeight.w600
                                                      : FontWeight.w500,
                                                  color: isSelected
                                                      ? const Color(0xFF2563EB)
                                                      : const Color(0xFF111111),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Container(
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: 8,
                                                  vertical: 3,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: hasResidents
                                                      ? const Color(0xFFDCFCE7)
                                                      : const Color(0xFFF3F4F6),
                                                  borderRadius: BorderRadius.circular(10),
                                                ),
                                                child: Text(
                                                  hasResidents ? 'Occupied' : 'Vacant',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w600,
                                                    color: hasResidents
                                                        ? const Color(0xFF16A34A)
                                                        : const Color(0xFF6B7280),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          if (hasResidents) ...[
                                            const SizedBox(height: 6),
                                            Row(
                                              children: [
                                                Icon(
                                                  Icons.people_outline,
                                                  size: 14,
                                                  color: Colors.grey[600],
                                                ),
                                                const SizedBox(width: 4),
                                                Expanded(
                                                  child: Text(
                                                    residentCount == 1
                                                        ? residentNames[0]
                                                        : '${residentNames[0]} +${residentCount - 1} member${residentCount > 2 ? 's' : ''}',
                                                    style: TextStyle(
                                                      fontSize: 13,
                                                      color: Colors.grey[600],
                                                    ),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            if (residentCount > 1) ...[
                                              const SizedBox(height: 4),
                                              Padding(
                                                padding: const EdgeInsets.only(left: 18),
                                                child: Text(
                                                  residentNames.join(', '),
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.grey[500],
                                                  ),
                                                  maxLines: 2,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ],
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    if (isSelected)
                                      const Icon(
                                        Icons.check_circle,
                                        color: Color(0xFF2563EB),
                                        size: 24,
                                      )
                                    else
                                      Container(
                                        width: 24,
                                        height: 24,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: const Color(0xFFD1D5DB),
                                            width: 2,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border(
                          top: BorderSide(
                            color: const Color(0xFFE5E7EB),
                            width: 1,
                          ),
                        ),
                      ),
                      child: SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            _selectedFlatIds.isEmpty
                                ? 'Cancel'
                                : 'Done (${_selectedFlatIds.length} selected)',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showDatePicker() async {
    final today = DateTime.now();
    final initialDate = _selectedDueDate ?? today;
    
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: today,
      lastDate: DateTime(today.year + 1),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF2563EB),
              onPrimary: Colors.white,
              onSurface: Color(0xFF111111),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedDueDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final keyboardInsets = MediaQuery.of(context).viewInsets;

    return Center(
      child: Container(
        constraints: BoxConstraints(
          maxWidth: screenWidth > 720 ? 720 : screenWidth * 0.92,
          maxHeight: screenHeight * 0.80,
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          elevation: 8,
          shadowColor: Colors.black.withOpacity(0.15),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHeader(),
              Flexible(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.only(
                    bottom: keyboardInsets.bottom > 0
                        ? keyboardInsets.bottom + 12
                        : 20,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                    child: Form(
                      key: _formKey,
                      onChanged: () => setState(() {}),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(height: 18),
                          _buildMonthYearField(),
                          const SizedBox(height: 16),
                          _buildChargeAmountsSection(), // NEW: All charge types
                          const SizedBox(height: 16),
                          _buildDueDateField(),
                          const SizedBox(height: 16),
                          _buildScopeField(),
                          const SizedBox(height: 16),
                          // Conditional UI based on scope selection
                          if (_selectedScope == 'All Residents')
                            _buildInfoBanner()
                          else if (_selectedScope == 'Specific Units') ...[
                            _buildBuildingSection(),
                            if (_selectedBuildingId != null) ...[
                              const SizedBox(height: 16),
                              _buildUnitField(),
                            ],
                          ],
                          const SizedBox(height: 20),
                          _buildGenerateButton(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 16),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 40),
            child: Column(
              children: const [
                Text(
                  'Create Monthly Bill',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF111111),
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Generate maintenance bills for residents',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: -6,
            right: -6,
            child: Semantics(
              label: 'Close',
              button: true,
              child: InkWell(
                onTap: () => Navigator.of(context).pop(),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.close,
                    color: Color(0xFF9CA3AF),
                    size: 22,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthYearField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Month & Year',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Color(0xFF111111),
          ),
        ),
        const SizedBox(height: 8),
        Semantics(
          label: 'Month & Year dropdown',
          button: true,
          child: InkWell(
            onTap: _showMonthPicker,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 14,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: const Color(0xFFE5E7EB)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _selectedMonth ?? 'Select month',
                    style: TextStyle(
                      fontSize: 15,
                      color: _selectedMonth == null
                          ? const Color(0xFF9CA3AF)
                          : const Color(0xFF111111),
                    ),
                  ),
                  const Icon(
                    Icons.keyboard_arrow_down,
                    color: Color(0xFF9CA3AF),
                    size: 24,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildChargeAmountsSection() {
    // Calculate total from all fields
    double calculateTotal() {
      final maintenance = double.tryParse(_maintenanceController.text.trim()) ?? 0;
      final water = double.tryParse(_waterController.text.trim()) ?? 0;
      final parking = double.tryParse(_parkingController.text.trim()) ?? 0;
      final service = double.tryParse(_serviceController.text.trim()) ?? 0;
      final electricity = double.tryParse(_electricityController.text.trim()) ?? 0;
      final security = double.tryParse(_securityController.text.trim()) ?? 0;
      final other = double.tryParse(_otherController.text.trim()) ?? 0;
      return maintenance + water + parking + service + electricity + security + other;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Bill Charges',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Color(0xFF111111),
              ),
            ),
            Text(
              '(Fill optional charges)',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        
        // Maintenance Charge
        _buildChargeField(
          label: 'Maintenance',
          controller: _maintenanceController,
          icon: Icons.home_repair_service,
        ),
        const SizedBox(height: 12),
        
        // Water Charge
        _buildChargeField(
          label: 'Water',
          controller: _waterController,
          icon: Icons.water_drop,
        ),
        const SizedBox(height: 12),
        
        // Parking Charge
        _buildChargeField(
          label: 'Parking',
          controller: _parkingController,
          icon: Icons.local_parking,
        ),
        const SizedBox(height: 12),
        
        // Service Charge
        _buildChargeField(
          label: 'Service',
          controller: _serviceController,
          icon: Icons.cleaning_services,
        ),
        const SizedBox(height: 12),
        
        // Electricity Charge
        _buildChargeField(
          label: 'Electricity',
          controller: _electricityController,
          icon: Icons.electric_bolt,
        ),
        const SizedBox(height: 12),
        
        // Security Charge
        _buildChargeField(
          label: 'Security',
          controller: _securityController,
          icon: Icons.security,
        ),
        const SizedBox(height: 12),
        
        // Other Charge
        _buildChargeField(
          label: 'Other',
          controller: _otherController,
          icon: Icons.receipt_long,
        ),
        const SizedBox(height: 16),
        
        // Total Amount Display
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF2563EB), width: 2),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total Amount',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF111111),
                ),
              ),
              Row(
                children: [
                  const Icon(
                    Icons.currency_rupee,
                    size: 20,
                    color: Color(0xFF2563EB),
                  ),
                  Text(
                    calculateTotal().toStringAsFixed(0).replaceAllMapped(
                      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
                      (Match m) => '${m[1]},',
                    ),
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF2563EB),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildChargeField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
  }) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            size: 20,
            color: const Color(0xFF6B7280),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: TextFormField(
            controller: controller,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
            ],
            style: const TextStyle(
              fontSize: 15,
              color: Color(0xFF111111),
            ),
            decoration: InputDecoration(
              labelText: label,
              hintText: '0',
              prefixIcon: const Icon(
                Icons.currency_rupee,
                color: Color(0xFF6B7280),
                size: 18,
              ),
              hintStyle: const TextStyle(
                fontSize: 15,
                color: Color(0xFF9CA3AF),
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFF2563EB), width: 2),
              ),
            ),
            onChanged: (value) {
              // Trigger rebuild to update total
              setState(() {});
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDueDateField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Due Date',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Color(0xFF111111),
          ),
        ),
        const SizedBox(height: 8),
        Semantics(
          label: 'Due Date field',
          button: true,
          child: InkWell(
            onTap: _showDatePicker,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 14,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: const Color(0xFFE5E7EB)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _selectedDueDate != null
                        ? DateFormat('dd-MM-yyyy').format(_selectedDueDate!)
                        : 'dd-mm-yyyy',
                    style: TextStyle(
                      fontSize: 15,
                      color: _selectedDueDate == null
                          ? const Color(0xFF9CA3AF)
                          : const Color(0xFF111111),
                    ),
                  ),
                  const Icon(
                    Icons.calendar_today,
                    color: Color(0xFF9CA3AF),
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildScopeField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Apply Bills To',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Color(0xFF111111),
          ),
        ),
        const SizedBox(height: 8),
        Semantics(
          label: 'Apply Bills To dropdown',
          button: true,
          child: InkWell(
            onTap: _showScopePicker,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 14,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: const Color(0xFFE5E7EB)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _selectedScope,
                    style: const TextStyle(
                      fontSize: 15,
                      color: Color(0xFF111111),
                    ),
                  ),
                  const Icon(
                    Icons.keyboard_arrow_down,
                    color: Color(0xFF9CA3AF),
                    size: 24,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Icon(
            Icons.people_outline,
            color: Color(0xFF2563EB),
            size: 22,
          ),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Bills will be generated for all residents',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF2563EB),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBuildingSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(
                Icons.apartment,
                color: Color(0xFF2563EB),
                size: 20,
              ),
              SizedBox(width: 8),
              Text(
                'Select Building / Tower',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF111111),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Semantics(
            label: 'Select building dropdown',
            button: true,
            child: InkWell(
              onTap: _showBuildingPicker,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _selectedBuildingName ?? 'Choose building...',
                      style: TextStyle(
                        fontSize: 15,
                        color: _selectedBuildingName == null
                            ? const Color(0xFFB9BDC1)
                            : const Color(0xFF111111),
                      ),
                    ),
                    const Icon(
                      Icons.keyboard_arrow_down,
                      color: Color(0xFF9CA3AF),
                      size: 24,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUnitField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Select Unit(s)',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Color(0xFF111111),
          ),
        ),
        const SizedBox(height: 8),
        Semantics(
          label: 'Select units',
          button: true,
          child: InkWell(
            onTap: _showUnitPicker,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 14,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(
                  color: _selectedFlatIds.isEmpty
                      ? const Color(0xFFE5E7EB)
                      : const Color(0xFF2563EB),
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      _selectedFlatIds.isEmpty
                          ? 'Select units'
                          : _selectedFlatIds.length == 1
                              ? _selectedFlatIds[0]
                              : '${_selectedFlatIds.length} units selected',
                      style: TextStyle(
                        fontSize: 15,
                        color: _selectedFlatIds.isEmpty
                            ? const Color(0xFF9CA3AF)
                            : const Color(0xFF111111),
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.keyboard_arrow_down,
                    color: Color(0xFF9CA3AF),
                    size: 24,
                  ),
                ],
              ),
            ),
          ),
        ),
        if (_selectedFlatIds.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 4),
            child: Text(
              'Select flats to generate bills for',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[500],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildGenerateButton() {
    final isEnabled = _isFormValid && !_isGenerating;

    return Semantics(
      label: 'Generate bills',
      button: true,
      child: SizedBox(
        width: double.infinity,
        height: 50,
        child: ElevatedButton(
          onPressed: isEnabled ? _handleGenerate : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2563EB),
            disabledBackgroundColor: const Color(0x662563EB), // 40% opacity
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: _isGenerating
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Text(
                  'Generate Bills',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
        ),
      ),
    );
  }
}
