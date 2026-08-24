/// Resident Management Screen for Admin App with Firestore Integration
///
/// Features:
/// - List all residents (role == "resident")
/// - Search and filter by building and flat
/// - Add new resident
/// - Edit resident details
/// - Activate/deactivate resident
/// - View resident profile
/// - Real-time updates with StreamBuilder
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'widgets/standard_bottom_nav.dart';
import 'widgets/standard_header.dart';
import 'widgets/add_resident_modal_clean.dart';
import 'edit_resident_screen.dart';
import 'services/user_service.dart';
import 'services/building_service.dart';
import 'services/billing_service.dart';
import 'pending_residents_screen.dart';

class AdminResidentsPageFirestore extends StatefulWidget {
  const AdminResidentsPageFirestore({super.key});

  @override
  State<AdminResidentsPageFirestore> createState() =>
      _AdminResidentsPageFirestoreState();
}

class _AdminResidentsPageFirestoreState
    extends State<AdminResidentsPageFirestore> {
  final UserService _userService = UserService();
  final BuildingService _buildingService = BuildingService();
  final BillingService _billingService = BillingService();

  // Search and filter
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  String? _selectedBuilding;
  String? _selectedStatus;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Filter residents based on search and filters
  List<UserModel> _filterResidents(List<UserModel> residents) {
    return residents.where((resident) {
      // Search filter
      final matchesSearch =
          _searchQuery.isEmpty ||
          resident.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (resident.flatLabel?.toLowerCase().contains(
                _searchQuery.toLowerCase(),
              ) ??
              false) ||
          resident.residentId.toLowerCase().contains(
            _searchQuery.toLowerCase(),
          );

      // Building filter (via flatLabel prefix)
      final matchesBuilding =
          _selectedBuilding == null ||
          _selectedBuilding == 'all' ||
          (resident.flatLabel?.startsWith(_selectedBuilding!) ?? false);

      // Status filter
      final matchesStatus =
          _selectedStatus == null ||
          _selectedStatus == 'all' ||
          resident.status == _selectedStatus;

      return matchesSearch && matchesBuilding && matchesStatus;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          const StandardHeader(title: 'Resident Management'),
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionHeader(),
                const SizedBox(height: 16),
                _buildSearchBar(),
                const SizedBox(height: 12),
                _buildFilters(),
                const SizedBox(height: 16),
                _buildResidentList(),
                const SizedBox(height: 100),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: const StandardBottomNav(selectedIndex: 2),
    );
  }

  Widget _buildSectionHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Resident Management',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF111111),
            ),
          ),
          Row(
            children: [
              IconButton(
                tooltip: 'Pending registrations',
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => PendingResidentsScreen()),
                ),
                icon: const Icon(
                  Icons.how_to_reg_outlined,
                  color: Color(0xFF2563EB),
                ),
              ),
              ElevatedButton.icon(
                onPressed: _showAddResidentDialog,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: TextField(
        controller: _searchController,
        onChanged: (value) => setState(() => _searchQuery = value),
        style: const TextStyle(fontSize: 14, color: Color(0xFF111111)),
        decoration: InputDecoration(
          hintText: 'Search by name, flat, or resident ID...',
          hintStyle: const TextStyle(fontSize: 14, color: Color(0xFF9CA3AF)),
          prefixIcon: const Icon(
            Icons.search,
            color: Color(0xFF9CA3AF),
            size: 20,
          ),
          filled: true,
          fillColor: const Color(0xFFF3F4F6),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 12,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1),
          ),
        ),
      ),
    );
  }

  Widget _buildFilters() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: StreamBuilder<List<BuildingModel>>(
              stream: _buildingService.getBuildings(),
              builder: (context, snapshot) {
                final buildings = snapshot.data ?? [];
                return _buildFilterDropdown(
                  label: 'Building',
                  value: _selectedBuilding,
                  items: [
                    const DropdownMenuItem(
                      value: 'all',
                      child: Text('All Buildings'),
                    ),
                    ...buildings.map(
                      (b) => DropdownMenuItem(
                        value: b.name[0], // First letter for filtering
                        child: Text(b.name),
                      ),
                    ),
                  ],
                  onChanged: (value) =>
                      setState(() => _selectedBuilding = value),
                );
              },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildFilterDropdown(
              label: 'Status',
              value: _selectedStatus,
              items: const [
                DropdownMenuItem(value: 'all', child: Text('All Status')),
                DropdownMenuItem(value: 'active', child: Text('Active')),
                DropdownMenuItem(value: 'inactive', child: Text('Inactive')),
              ],
              onChanged: (value) => setState(() => _selectedStatus = value),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterDropdown({
    required String label,
    required String? value,
    required List<DropdownMenuItem<String>> items,
    required void Function(String?) onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          hint: Text(label, style: const TextStyle(fontSize: 14)),
          isExpanded: true,
          items: items,
          onChanged: onChanged,
          style: const TextStyle(fontSize: 14, color: Color(0xFF111111)),
        ),
      ),
    );
  }

  Widget _buildResidentList() {
    return StreamBuilder<List<UserModel>>(
      stream: _userService.getUsers(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32.0),
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 48,
                    color: Color(0xFFEF4444),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading residents: ${snapshot.error}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF6B7280),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        final allResidents = snapshot.data ?? [];
        final filteredResidents = _filterResidents(allResidents);

        if (filteredResidents.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(32),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.people_outline, size: 56, color: Colors.grey[400]),
                  const SizedBox(height: 12),
                  Text(
                    _searchQuery.isNotEmpty ||
                            _selectedBuilding != null ||
                            _selectedStatus != null
                        ? 'No residents found'
                        : 'No residents yet',
                    style: TextStyle(fontSize: 15, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: filteredResidents.map((resident) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildResidentCard(resident),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  Widget _buildResidentCard(UserModel resident) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E5E5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.person,
                    color: Color(0xFF2563EB),
                    size: 28,
                  ),
                ),
                const SizedBox(width: 12),
                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              resident.name,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF111111),
                              ),
                            ),
                          ),
                          _buildStatusBadge(resident.status),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${resident.flatLabel ?? "No flat"} • ${resident.familyMembers} members',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'ID: ${resident.residentId}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF9CA3AF),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        resident.phone,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                ),
                // Action icons
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.visibility_outlined, size: 20),
                      color: const Color(0xFF6B7280),
                      onPressed: () => _showResidentProfile(resident),
                      tooltip: 'View Profile',
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 20),
                      color: const Color(0xFF6B7280),
                      onPressed: () => _showEditResidentDialog(resident),
                      tooltip: 'Edit',
                    ),
                    PopupMenuButton<String>(
                      icon: const Icon(
                        Icons.more_vert,
                        size: 20,
                        color: Color(0xFF6B7280),
                      ),
                      onSelected: (value) {
                        switch (value) {
                          case 'activate':
                            _toggleResidentStatus(resident, 'active');
                            break;
                          case 'deactivate':
                            _toggleResidentStatus(resident, 'inactive');
                            break;
                          case 'delete':
                            _deleteResident(resident);
                            break;
                        }
                      },
                      itemBuilder: (context) => [
                        if (resident.status == 'inactive')
                          const PopupMenuItem(
                            value: 'activate',
                            child: Row(
                              children: [
                                Icon(
                                  Icons.check_circle_outline,
                                  size: 18,
                                  color: Color(0xFF10B981),
                                ),
                                SizedBox(width: 8),
                                Text('Activate'),
                              ],
                            ),
                          ),
                        if (resident.status == 'active')
                          const PopupMenuItem(
                            value: 'deactivate',
                            child: Row(
                              children: [
                                Icon(
                                  Icons.block,
                                  size: 18,
                                  color: Color(0xFFF4A100),
                                ),
                                SizedBox(width: 8),
                                Text('Deactivate'),
                              ],
                            ),
                          ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(
                                Icons.delete_outline,
                                size: 18,
                                color: Color(0xFFEF4444),
                              ),
                              SizedBox(width: 8),
                              Text('Delete'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    final isActive = status == 'active';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFFD1FAE5) : const Color(0xFFFEE2E2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        isActive ? 'Active' : 'Inactive',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: isActive ? const Color(0xFF059669) : const Color(0xFFDC2626),
        ),
      ),
    );
  }

  // Action handlers
  void _showAddResidentDialog() async {
    await AddResidentModal.show(
      context,
      onSubmit: (residentData) async {
        try {
          // Show loading indicator
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Row(
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                    SizedBox(width: 12),
                    Text('Creating resident...'),
                  ],
                ),
                backgroundColor: Color(0xFF2563EB),
                duration: Duration(seconds: 30),
              ),
            );
          }

          // Use the generated password from the modal
          final password = residentData.generatedPassword;

          // Create user in Firestore
          final userId = await _userService.createUser(
            name: residentData.fullName,
            phone: residentData.phone,
            email: residentData.email.isNotEmpty ? residentData.email : null,
            password: password,
            familyMembers: residentData.membersCount,
          );

          // Close loading snackbar
          if (mounted) {
            ScaffoldMessenger.of(context).clearSnackBars();

            // Show success dialog with password
            await showDialog(
              context: context,
              barrierDismissible: false,
              builder: (context) => AlertDialog(
                title: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD1FAE5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.check_circle,
                        color: Color(0xFF059669),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Resident Added',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${residentData.fullName} has been added successfully!',
                      style: const TextStyle(fontSize: 15),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF2563EB)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.lock_outline,
                                color: Color(0xFF2563EB),
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'Login Credentials',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF2563EB),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _buildCredentialRow(
                            'Username',
                            residentData.email.isNotEmpty
                                ? residentData.email
                                : residentData.phone,
                          ),
                          const SizedBox(height: 8),
                          _buildCredentialRow('Password', password),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              const Icon(
                                Icons.info_outline,
                                size: 16,
                                color: Color(0xFF2563EB),
                              ),
                              const SizedBox(width: 6),
                              const Expanded(
                                child: Text(
                                  'Save these credentials securely',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF2563EB),
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                actions: [
                  TextButton.icon(
                    onPressed: () {
                      Clipboard.setData(
                        ClipboardData(
                          text:
                              'Username: ${residentData.email.isNotEmpty ? residentData.email : residentData.phone}\nPassword: $password',
                        ),
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Credentials copied to clipboard'),
                          backgroundColor: Color(0xFF10B981),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                    icon: const Icon(Icons.copy, size: 18),
                    label: const Text('Copy'),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                    child: const Text('Done'),
                  ),
                ],
              ),
            );
          }
        } catch (e) {
          // Show error with user-friendly message
          if (mounted) {
            ScaffoldMessenger.of(context).clearSnackBars();

            // Parse Firebase Auth errors
            String errorMessage = 'Failed to add resident';
            final errorString = e.toString().toLowerCase();

            if (errorString.contains('email-already-in-use')) {
              errorMessage =
                  'This email address is already registered. Please use a different email.';
            } else if (errorString.contains('invalid-email')) {
              errorMessage =
                  'Invalid email address format. Please check and try again.';
            } else if (errorString.contains('weak-password')) {
              errorMessage =
                  'Password is too weak. Please use a stronger password.';
            } else if (errorString.contains('network')) {
              errorMessage =
                  'Network error. Please check your internet connection.';
            } else {
              errorMessage =
                  'Failed to add resident: ${e.toString().replaceAll('Exception: ', '')}';
            }

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(errorMessage),
                backgroundColor: const Color(0xFFEF4444),
                duration: const Duration(seconds: 5),
                action: SnackBarAction(
                  label: 'Dismiss',
                  textColor: Colors.white,
                  onPressed: () {
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  },
                ),
              ),
            );
          }
        }
      },
    );
  }

  Widget _buildCredentialRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(
            '$label:',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Color(0xFF6B7280),
            ),
          ),
        ),
        Expanded(
          child: SelectableText(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF111827),
              fontFamily: 'monospace',
            ),
          ),
        ),
      ],
    );
  }

  void _showEditResidentDialog(UserModel resident) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => EditResidentScreen(resident: resident),
      ),
    );

    if (result == true && mounted) {
      // Data will auto-refresh via StreamBuilder
      setState(() {});
    }
  }

  void _showResidentProfile(UserModel resident) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ResidentProfilePage(resident: resident),
      ),
    );
  }

  Future<void> _toggleResidentStatus(
    UserModel resident,
    String newStatus,
  ) async {
    try {
      await _userService.updateUserStatus(
        userId: resident.id,
        status: newStatus,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${resident.name} ${newStatus == "active" ? "activated" : "deactivated"}',
            ),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update status: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  Future<void> _deleteResident(UserModel resident) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Resident'),
        content: Text(
          'Are you sure you want to delete ${resident.name}? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFEF4444),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _userService.deleteUser(resident.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${resident.name} deleted successfully'),
              backgroundColor: const Color(0xFF10B981),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete resident: $e'),
              backgroundColor: const Color(0xFFEF4444),
            ),
          );
        }
      }
    }
  }
}

// Resident Profile Page
class ResidentProfilePage extends StatelessWidget {
  final UserModel resident;

  const ResidentProfilePage({super.key, required this.resident});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF111827)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Resident Details',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Color(0xFF111827),
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Profile Header
            Container(
              width: double.infinity,
              color: Colors.white,
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  // Profile Icon
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(40),
                    ),
                    child: const Icon(
                      Icons.person,
                      size: 40,
                      color: Color(0xFF2563EB),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Name
                  Text(
                    resident.name,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF111827),
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 8),

                  // Resident ID
                  Text(
                    'ID: ${resident.residentId}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF6B7280),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Status Badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: resident.status == 'active'
                          ? const Color(0xFFD1FAE5)
                          : const Color(0xFFFEE2E2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      resident.status == 'active' ? 'Active' : 'Inactive',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: resident.status == 'active'
                            ? const Color(0xFF059669)
                            : const Color(0xFFDC2626),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Personal Information
            _buildSection(
              context,
              title: 'Personal Information',
              child: Column(
                children: [
                  _buildInfoRow(
                    icon: Icons.phone_outlined,
                    label: 'Phone',
                    value: resident.phone,
                  ),
                  if (resident.email != null && resident.email!.isNotEmpty) ...[
                    const Divider(height: 24),
                    _buildInfoRow(
                      icon: Icons.email_outlined,
                      label: 'Email',
                      value: resident.email!,
                    ),
                  ],
                  const Divider(height: 24),
                  _buildInfoRow(
                    icon: Icons.people_outline,
                    label: 'Family Members',
                    value: '${resident.familyMembers}',
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Login Credentials
            _buildSection(
              context,
              title: 'Login Credentials',
              badge: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.lock, size: 12, color: Color(0xFFF59E0B)),
                    SizedBox(width: 4),
                    Text(
                      'Confidential',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFF59E0B),
                      ),
                    ),
                  ],
                ),
              ),
              child: Column(
                children: [
                  _buildCopyableInfoRow(
                    context,
                    icon: Icons.fingerprint,
                    label: 'User ID',
                    value: resident.id, // Firebase Auth UID
                  ),
                  if (resident.password != null &&
                      resident.password!.isNotEmpty) ...[
                    const Divider(height: 24),
                    _buildCopyableInfoRow(
                      context,
                      icon: Icons.lock_outline,
                      label: 'Password',
                      value: resident.password!,
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Flat Information
            _buildSection(
              context,
              title: 'Flat Information',
              child: Column(
                children: [
                  _buildInfoRow(
                    icon: Icons.home_outlined,
                    label: 'Flat',
                    value: resident.flatLabel ?? 'Not assigned',
                  ),
                  if (resident.ownershipType != null) ...[
                    const Divider(height: 24),
                    _buildInfoRow(
                      icon: Icons.key_outlined,
                      label: 'Ownership',
                      value: resident.ownershipType!,
                    ),
                  ],
                  if (resident.flatId != null) ...[
                    const Divider(height: 24),
                    _buildInfoRow(
                      icon: Icons.tag,
                      label: 'Flat ID',
                      value: resident.flatId!,
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Billing & Payments
            _buildSection(
              context,
              title: 'Billing & Payments',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Payment history will be displayed here',
                    style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        // TODO: Show payment history
                      },
                      icon: const Icon(Icons.receipt_long, size: 18),
                      label: const Text('View Payment History'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required String title,
    Widget? badge,
    required Widget child,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF111827),
                  ),
                ),
                if (badge != null) ...[const Spacer(), badge],
              ],
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, size: 20, color: const Color(0xFF6B7280)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF6B7280),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF111827),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCopyableInfoRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, size: 20, color: const Color(0xFF6B7280)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF6B7280),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF111827),
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.copy, size: 18),
          color: const Color(0xFF2563EB),
          onPressed: () {
            Clipboard.setData(ClipboardData(text: value));
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('$label copied to clipboard'),
                backgroundColor: const Color(0xFF10B981),
                duration: const Duration(seconds: 2),
              ),
            );
          },
        ),
      ],
    );
  }

  // Password row removed - passwords are managed by Firebase Auth
  // and are not stored in Firestore for security reasons
}
