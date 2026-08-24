import 'package:flutter/material.dart';
import 'models/vendor_models.dart';
import 'widgets/add_vendor_modal.dart';
import 'widgets/standard_header.dart';
import 'vendor_details_screen.dart';
import 'services/staff_vendor_service.dart';

class StaffVendorsScreen extends StatefulWidget {
  const StaffVendorsScreen({super.key});

  @override
  State<StaffVendorsScreen> createState() => _StaffVendorsScreenState();
}

class _StaffVendorsScreenState extends State<StaffVendorsScreen> {
  final TextEditingController _searchController = TextEditingController();
  final StaffVendorService _service = StaffVendorService();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showAddVendorModal(BuildContext context) {
    showDialog(
      context: context,
      barrierColor: const Color(0x59000000), // Semi-transparent black (35% opacity)
      builder: (BuildContext context) {
        return const AddVendorModal();
      },
    ).then((result) {
      if (result == true) {
        // No need to manually refresh - StreamBuilder handles it automatically
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vendor added successfully'),
            backgroundColor: Color(0xFF16A34A),
            duration: Duration(seconds: 2),
          ),
        );
      }
    });
  }

  void _makePhoneCall(String phoneNumber, String vendorName) {
    // TODO: Implement actual phone dialer using url_launcher
    // For now, show a snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Calling $vendorName at $phoneNumber...'),
        backgroundColor: const Color(0xFF2563EB),
        duration: const Duration(seconds: 2),
        action: SnackBarAction(
          label: 'Cancel',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  Widget _buildVendorCard(VendorModel vendor) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => VendorDetailsScreen(vendorId: vendor.id),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE5E7EB)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Icon
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFF2563EB).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.business,
                color: Color(0xFF2563EB),
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            // Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    vendor.businessName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${vendor.category} • ${vendor.contactPerson}',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ),
            // Call button
            IconButton(
              onPressed: () => _makePhoneCall(vendor.phone, vendor.businessName),
              icon: const Icon(
                Icons.phone,
                color: Color(0xFF2563EB),
                size: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          const StandardHeader(
            title: 'Vendor Management',
            showBackButton: true,
          ),
          
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),
                
                // Header Section
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: const Color(0xFF2563EB).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.business,
                          color: Color(0xFF2563EB),
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Vendor Management',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF111827),
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Manage vendor information',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w400,
                                color: Color(0xFF6B7280),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 20),
                  
                  // Add Vendor Button
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: () => _showAddVendorModal(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Add Vendor',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Search Bar
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Search by name, category, or phone...',
                          hintStyle: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 14,
                          ),
                          prefixIcon: Icon(
                            Icons.search,
                            color: Colors.grey[500],
                            size: 20,
                          ),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 20),
                                  onPressed: () {
                                    _searchController.clear();
                                  },
                                )
                              : null,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Vendor List with StreamBuilder
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: StreamBuilder<List<VendorModel>>(
                    stream: _service.getVendors(),
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
                                  size: 64,
                                  color: Color(0xFFEF4444),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Error loading vendors',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '${snapshot.error}',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[500],
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      final vendors = snapshot.data ?? [];
                      
                      // Filter vendors based on search
                      final filteredVendors = _searchQuery.isEmpty
                          ? vendors
                          : vendors.where((vendor) {
                              return vendor.businessName.toLowerCase().contains(_searchQuery) ||
                                     vendor.category.toLowerCase().contains(_searchQuery) ||
                                     vendor.contactPerson.toLowerCase().contains(_searchQuery) ||
                                     vendor.phone.contains(_searchQuery);
                            }).toList();

                      if (filteredVendors.isEmpty) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Column(
                              children: [
                                Icon(
                                  _searchQuery.isEmpty ? Icons.business : Icons.search_off,
                                  size: 64,
                                  color: Colors.grey[300],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  _searchQuery.isEmpty ? 'No vendors added yet' : 'No vendors found',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _searchQuery.isEmpty 
                                      ? 'Add your first vendor using the button above'
                                      : 'Try adjusting your search',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[500],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      return Column(
                        children: filteredVendors.asMap().entries.map((entry) {
                          final index = entry.key;
                          final vendor = entry.value;
                          return Column(
                            children: [
                              if (index > 0) const SizedBox(height: 12),
                              _buildVendorCard(vendor),
                            ],
                          );
                        }).toList(),
                      );
                    },
                  ),
                ),
                  
                const SizedBox(height: 80),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Vendor Card Widget
class VendorCard extends StatelessWidget {
  final Vendor vendor;
  final VoidCallback? onTap;
  final Function(String, String)? onCallPressed;

  const VendorCard({
    super.key,
    required this.vendor,
    this.onTap,
    this.onCallPressed,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE5E7EB)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row
            Row(
              children: [
                // Avatar
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCECFE),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: vendor.profileImage != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            vendor.profileImage!,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Icon(
                                Icons.business,
                                color: const Color(0xFF2563EB).withOpacity(0.5),
                                size: 28,
                              );
                            },
                          ),
                        )
                      : Icon(
                          Icons.business,
                          color: const Color(0xFF2563EB).withOpacity(0.5),
                          size: 28,
                        ),
                ),
                
                const SizedBox(width: 12),
                
                // Name and Category
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              vendor.businessName,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF111827),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Rating
                          Row(
                            children: [
                              const Icon(
                                Icons.star,
                                color: Color(0xFFFACC15),
                                size: 16,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                vendor.rating.toString(),
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF111827),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      // Category Chip
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          vendor.category,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Contact Information
            Row(
              children: [
                Icon(
                  Icons.person_outline,
                  size: 16,
                  color: Colors.grey[500],
                ),
                const SizedBox(width: 6),
                Text(
                  'Contact: ${vendor.contactPerson}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 4),
            
            Row(
              children: [
                Icon(
                  Icons.phone_outlined,
                  size: 16,
                  color: Colors.grey[500],
                ),
                const SizedBox(width: 6),
                Text(
                  vendor.phone,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Action Buttons Row
            Row(
              children: [
                // Call Vendor Button
                Expanded(
                  child: SizedBox(
                    height: 44,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        if (onCallPressed != null) {
                          onCallPressed!(vendor.phone, vendor.businessName);
                        }
                      },
                      icon: const Icon(
                        Icons.phone,
                        size: 18,
                        color: Color(0xFF2563EB),
                      ),
                      label: const Text(
                        'Call',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF2563EB),
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFF2563EB)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(width: 12),
                
                // View Details Button
                Expanded(
                  child: SizedBox(
                    height: 44,
                    child: ElevatedButton.icon(
                      onPressed: onTap,
                      icon: const Icon(
                        Icons.visibility_outlined,
                        size: 18,
                        color: Colors.white,
                      ),
                      label: const Text(
                        'Details',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}