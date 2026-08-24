import 'package:flutter/material.dart';

class CreateAnnouncementModal extends StatefulWidget {
  const CreateAnnouncementModal({super.key});

  @override
  State<CreateAnnouncementModal> createState() => _CreateAnnouncementModalState();
}

class _CreateAnnouncementModalState extends State<CreateAnnouncementModal> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _messageController = TextEditingController();
  String _selectedPriority = 'Low';
  bool _isLoading = false;

  final List<String> _priorities = ['Low', 'Medium', 'High'];

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(20),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400, maxHeight: 600),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            _buildHeader(),
            
            // Form Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),
                      
                      // Title Field
                      _buildFieldLabel('Title'),
                      const SizedBox(height: 8),
                      _buildTextField(
                        controller: _titleController,
                        placeholder: 'Announcement title',
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Title is required';
                          }
                          return null;
                        },
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Priority Field
                      _buildFieldLabel('Priority'),
                      const SizedBox(height: 8),
                      _buildPriorityDropdown(),
                      
                      const SizedBox(height: 24),
                      
                      // Message Field
                      _buildFieldLabel('Message'),
                      const SizedBox(height: 8),
                      _buildTextField(
                        controller: _messageController,
                        placeholder: 'Announcement details...',
                        maxLines: 5,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Message is required';
                          }
                          return null;
                        },
                      ),
                      
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ),
            
            // Primary Action Button
            _buildPrimaryButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          Expanded(
            child: Column(
              children: [
                const Text(
                  'Create Announcement',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF111827),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Post a new announcement to all residents',
                  style: TextStyle(
                    fontSize: 16,
                    color: Color(0xFF6B7280),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          Positioned(
            top: 0,
            right: 0,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.all(8),
                child: const Icon(
                  Icons.close,
                  size: 24,
                  color: Color(0xFF6B7280),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFieldLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: Color(0xFF111827),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String placeholder,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE5E7EB)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        validator: validator,
        style: const TextStyle(
          fontSize: 16,
          color: Color(0xFF111827),
        ),
        decoration: InputDecoration(
          hintText: placeholder,
          hintStyle: const TextStyle(
            fontSize: 16,
            color: Color(0xFF9CA3AF),
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(16),
        ),
      ),
    );
  }

  Widget _buildPriorityDropdown() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE5E7EB)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonFormField<String>(
        initialValue: _selectedPriority,
        onChanged: (String? newValue) {
          setState(() {
            _selectedPriority = newValue!;
          });
        },
        decoration: const InputDecoration(
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
        style: const TextStyle(
          fontSize: 16,
          color: Color(0xFF111827),
        ),
        icon: const Icon(
          Icons.keyboard_arrow_down,
          color: Color(0xFF6B7280),
          size: 24,
        ),
        items: _priorities.map<DropdownMenuItem<String>>((String value) {
          return DropdownMenuItem<String>(
            value: value,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 16,
                color: value == _selectedPriority 
                    ? const Color(0xFF111827) 
                    : const Color(0xFF9CA3AF),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildPrimaryButton() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      child: ElevatedButton(
        onPressed: _isLoading ? null : _handleCreateAnnouncement,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF2563EB),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
        child: _isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Text(
                'Post & Notify All',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }

  Future<void> _handleCreateAnnouncement() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      // TODO: Implement backend integration
      // - Save announcement to database
      // - Send push notifications to all residents
      // - Send in-app notifications
      // - Update announcements list

      // Simulate API call
      await Future.delayed(const Duration(seconds: 2));

      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        final announcementData = {
          'title': _titleController.text,
          'priority': _selectedPriority,
          'message': _messageController.text,
          'createdAt': DateTime.now().toIso8601String(),
        };

        Navigator.pop(context, announcementData);

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white, size: 20),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Announcement posted successfully! All residents have been notified.',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }
}

// Helper function to show the modal
Future<Map<String, dynamic>?> showCreateAnnouncementModal(BuildContext context) async {
  return await showDialog<Map<String, dynamic>>(
    context: context,
    barrierDismissible: true, // Allow dismissing by tapping outside
    barrierColor: Colors.black.withOpacity(0.5), // Semi-transparent background
    builder: (BuildContext context) {
      return const CreateAnnouncementModal();
    },
  );
}