import 'package:flutter/material.dart';
import '../parking_management_vehicles_screen.dart';

/// VehicleDetailsModal - Shows full vehicle details when card is tapped
/// 
/// This modal displays comprehensive vehicle information including:
/// - Vehicle details (number, type, model)
/// - Owner information (name, flat number)
/// - Registration status and dates
/// - Action buttons (Edit, Remove, Assign Slot)
class VehicleDetailsModal extends StatelessWidget {
  final VehicleEntry vehicle;
  final VoidCallback onEdit;
  final VoidCallback onRemove;
  final VoidCallback? onAssignSlot;

  const VehicleDetailsModal({
    super.key,
    required this.vehicle,
    required this.onEdit,
    required this.onRemove,
    this.onAssignSlot,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        constraints: const BoxConstraints(maxWidth: 400),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFFFF),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Section
                _buildHeader(context),
                const SizedBox(height: 24),
                
                // Vehicle Icon and Basic Info
                _buildVehicleHeader(),
                const SizedBox(height: 24),
                
                // Vehicle Details Section
                _buildDetailsSection(),
                const SizedBox(height: 24),
                
                // Owner Information Section
                _buildOwnerSection(),
                const SizedBox(height: 24),
                
                // Registration Status Section
                _buildRegistrationSection(),
                const SizedBox(height: 32),
                
                // Action Buttons
                _buildActionButtons(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Builds the modal header with title and close button
  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Vehicle Details',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                vehicle.vehicleNumber,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF6B7280),
                ),
              ),
            ],
          ),
        ),
        GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.close,
              size: 18,
              color: Color(0xFF6B7280),
            ),
          ),
        ),
      ],
    );
  }

  /// Builds vehicle icon and basic info header
  Widget _buildVehicleHeader() {
    return Row(
      children: [
        // Large Vehicle Icon
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: const Color(0xFFEDE9FE),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(
            vehicle.vehicleType == 'Car' 
                ? Icons.directions_car_rounded 
                : Icons.two_wheeler_rounded,
            color: const Color(0xFF7C3AED),
            size: 36,
          ),
        ),
        const SizedBox(width: 16),
        
        // Vehicle Number and Type
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                vehicle.vehicleNumber,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: vehicle.vehicleType == 'Car'
                          ? const Color(0xFFDCFDF7)
                          : const Color(0xFFF3E8FF),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      vehicle.vehicleType,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: vehicle.vehicleType == 'Car'
                            ? const Color(0xFF059669)
                            : const Color(0xFF7C3AED),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'Registered',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF059669),
                      ),
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

  /// Builds vehicle details section
  Widget _buildDetailsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Vehicle Information',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF111827),
          ),
        ),
        const SizedBox(height: 12),
        
        _buildDetailRow('Vehicle Number', vehicle.vehicleNumber),
        const SizedBox(height: 8),
        _buildDetailRow('Vehicle Type', vehicle.vehicleType),
        const SizedBox(height: 8),
        _buildDetailRow('Model', vehicle.model),
        const SizedBox(height: 8),
        _buildDetailRow('Registration Date', '15 Jan 2024'), // TODO: Add to model
      ],
    );
  }

  /// Builds owner information section
  Widget _buildOwnerSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Owner Information',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF111827),
          ),
        ),
        const SizedBox(height: 12),
        
        _buildDetailRow('Owner Name', vehicle.ownerName),
        const SizedBox(height: 8),
        _buildDetailRow('Flat Number', vehicle.flatNumber),
        const SizedBox(height: 8),
        _buildDetailRow('Contact', '+91 98765 43210'), // TODO: Add to model
        const SizedBox(height: 8),
        _buildDetailRow('Email', 'owner@example.com'), // TODO: Add to model
      ],
    );
  }

  /// Builds registration status section
  Widget _buildRegistrationSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Registration Status',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF111827),
          ),
        ),
        const SizedBox(height: 12),
        
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF0FDF4),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFFBBF7D0),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFF16A34A).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.check_circle_outline,
                  color: Color(0xFF16A34A),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Vehicle Registered',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Approved by admin on 15 Jan 2024',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 12),
        
        // Parking Status
        _buildDetailRow('Parking Slot', 'A-15 (Assigned)'), // TODO: Add to model
        const SizedBox(height: 8),
        _buildDetailRow('Last Entry', 'Today, 9:30 AM'), // TODO: Add to model
      ],
    );
  }

  /// Builds a detail row with label and value
  Widget _buildDetailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            '$label:',
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF6B7280),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF111827),
            ),
          ),
        ),
      ],
    );
  }

  /// Builds action buttons
  Widget _buildActionButtons(BuildContext context) {
    return Column(
      children: [
        // Primary Actions Row
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  onEdit();
                },
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF2563EB)),
                  foregroundColor: const Color(0xFF2563EB),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.edit_outlined, size: 18),
                    SizedBox(width: 8),
                    Text(
                      'Edit Details',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: onAssignSlot ?? () {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Assign Parking Slot - Coming soon'),
                      backgroundColor: Color(0xFF2563EB),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.local_parking_outlined, size: 18),
                    SizedBox(width: 8),
                    Text(
                      'Assign Slot',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 12),
        
        // Remove Vehicle Button
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: () {
              Navigator.of(context).pop();
              onRemove();
            },
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFFEF4444)),
              foregroundColor: const Color(0xFFEF4444),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.delete_outline, size: 18),
                SizedBox(width: 8),
                Text(
                  'Remove Vehicle',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

