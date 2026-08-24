import 'package:flutter/material.dart';

/// UnauthorizedVehicleActionModal - Modal for handling unauthorized vehicle actions
///
/// This modal opens when admin clicks "Take Action" on unauthorized vehicle alert
/// Features:
/// - Multiple action options (Remove, Fine, Contact Owner, etc.)
/// - Reason selection for actions
/// - Notes/comments functionality
/// - Confirmation before action execution
class UnauthorizedVehicleActionModal extends StatefulWidget {
  final String vehicleNumber;
  final String slotId;
  final Function(String action, String reason, String notes) onActionTaken;

  const UnauthorizedVehicleActionModal({
    super.key,
    required this.vehicleNumber,
    required this.slotId,
    required this.onActionTaken,
  });

  @override
  State<UnauthorizedVehicleActionModal> createState() =>
      _UnauthorizedVehicleActionModalState();
}

class _UnauthorizedVehicleActionModalState
    extends State<UnauthorizedVehicleActionModal> {
  String? _selectedAction;
  String? _selectedReason;
  final TextEditingController _notesController = TextEditingController();
  bool _isFormValid = false;

  final List<ActionOption> _actions = [
    ActionOption(
      id: 'remove_vehicle',
      title: 'Remove Vehicle',
      description: 'Tow or remove the unauthorized vehicle',
      icon: Icons.local_shipping_outlined,
      color: Color(0xFFEF4444),
    ),
    ActionOption(
      id: 'issue_fine',
      title: 'Issue Fine',
      description: 'Issue a parking violation fine',
      icon: Icons.receipt_outlined,
      color: Color(0xFFF59E0B),
    ),
    ActionOption(
      id: 'contact_owner',
      title: 'Contact Owner',
      description: 'Send notification to vehicle owner',
      icon: Icons.phone_outlined,
      color: Color(0xFF0E4778),
    ),
    ActionOption(
      id: 'mark_warning',
      title: 'Issue Warning',
      description: 'Place warning notice on vehicle',
      icon: Icons.warning_outlined,
      color: Color(0xFF7C3AED),
    ),
  ];

  final List<String> _reasons = [
    'Parked in unauthorized slot',
    'Expired parking permit',
    'Blocking emergency access',
    'Visitor overstay',
    'No valid registration',
    'Other violation',
  ];

  @override
  void initState() {
    super.initState();
    _notesController.addListener(_validateForm);
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  void _validateForm() {
    final isValid = _selectedAction != null && _selectedReason != null;
    if (isValid != _isFormValid) {
      setState(() {
        _isFormValid = isValid;
      });
    }
  }

  void _onActionSelected(String actionId) {
    setState(() {
      _selectedAction = actionId;
    });
    _validateForm();
  }

  void _onReasonSelected(String reason) {
    setState(() {
      _selectedReason = reason;
    });
    _validateForm();
  }

  void _onTakeAction() {
    if (!_isFormValid) return;

    widget.onActionTaken(
      _selectedAction!,
      _selectedReason!,
      _notesController.text.trim(),
    );

    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        constraints: const BoxConstraints(maxWidth: 450),
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
                // Header
                _buildHeader(),
                const SizedBox(height: 24),

                // Vehicle Info
                _buildVehicleInfo(),
                const SizedBox(height: 24),

                // Action Selection
                _buildActionSelection(),
                const SizedBox(height: 20),

                // Reason Selection
                if (_selectedAction != null) ...[
                  _buildReasonSelection(),
                  const SizedBox(height: 20),
                ],

                // Notes Section
                if (_selectedAction != null) ...[
                  _buildNotesSection(),
                  const SizedBox(height: 32),
                ],

                // Action Buttons
                _buildActionButtons(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Take Action',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Handle unauthorized vehicle violation',
                style: TextStyle(
                  fontSize: 14,
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
            child: const Icon(Icons.close, size: 18, color: Color(0xFF6B7280)),
          ),
        ),
      ],
    );
  }

  Widget _buildVehicleInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFEF4444).withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFEF4444).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.warning_rounded,
              color: Color(0xFFEF4444),
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Vehicle: ${widget.vehicleNumber}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Location: Slot ${widget.slotId}',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Select Action',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF111827),
          ),
        ),
        const SizedBox(height: 12),
        ..._actions.map((action) => _buildActionOption(action)),
      ],
    );
  }

  Widget _buildActionOption(ActionOption action) {
    final isSelected = _selectedAction == action.id;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: () => _onActionSelected(action.id),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isSelected ? action.color.withOpacity(0.1) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? action.color : const Color(0xFFE5E7EB),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: action.color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(action.icon, color: action.color, size: 20),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      action.title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: isSelected
                            ? action.color
                            : const Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      action.description,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                Icon(Icons.check_circle, color: action.color, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReasonSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Reason for Action',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF111827),
          ),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: _selectedReason,
          decoration: InputDecoration(
            hintText: 'Select reason',
            hintStyle: const TextStyle(fontSize: 15, color: Color(0xFF9CA3AF)),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF0E4778), width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
          items: _reasons.map((reason) {
            return DropdownMenuItem<String>(value: reason, child: Text(reason));
          }).toList(),
          onChanged: (value) => _onReasonSelected(value!),
        ),
      ],
    );
  }

  Widget _buildNotesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Additional Notes (Optional)',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF111827),
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _notesController,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: 'Add any additional details or instructions...',
            hintStyle: const TextStyle(fontSize: 15, color: Color(0xFF9CA3AF)),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF0E4778), width: 2),
            ),
            contentPadding: const EdgeInsets.all(16),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFFE5E7EB)),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Cancel',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF6B7280),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton(
            onPressed: _isFormValid ? _onTakeAction : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: _isFormValid
                  ? const Color(0xFFEF4444)
                  : const Color(0xFFE5E7EB),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: const Text(
              'Take Action',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }
}

/// Action Option Data Model
class ActionOption {
  final String id;
  final String title;
  final String description;
  final IconData icon;
  final Color color;

  ActionOption({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
  });
}

/// Utility function to show the UnauthorizedVehicleActionModal
Future<void> showUnauthorizedVehicleActionModal(
  BuildContext context, {
  required String vehicleNumber,
  required String slotId,
  required Function(String action, String reason, String notes) onActionTaken,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierColor: Colors.black.withOpacity(0.4),
    builder: (BuildContext context) {
      return UnauthorizedVehicleActionModal(
        vehicleNumber: vehicleNumber,
        slotId: slotId,
        onActionTaken: onActionTaken,
      );
    },
  );
}
