import 'package:flutter/material.dart';

class QuickBroadcastModal extends StatefulWidget {
  const QuickBroadcastModal({super.key});

  @override
  State<QuickBroadcastModal> createState() => _QuickBroadcastModalState();
}

class _QuickBroadcastModalState extends State<QuickBroadcastModal> {
  final _formKey = GlobalKey<FormState>();
  final _messageController = TextEditingController();
  String selectedPriority = 'Normal';
  bool sendToAllStaff = true;
  bool sendSMS = false;
  bool sendPushNotification = true;
  bool isLoading = false;

  final List<String> priorities = ['Low', 'Normal', 'High', 'Urgent'];

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
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
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Quick Broadcast',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF111827),
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Send instant notification to staff members',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w400,
                                color: Color(0xFF6B7280),
                              ),
                            ),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          child: const Icon(
                            Icons.close,
                            color: Color(0xFF9CA3AF),
                            size: 24,
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // Message Field
                  const Text(
                    'Message',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                      color: Colors.white,
                    ),
                    child: TextFormField(
                      controller: _messageController,
                      maxLines: 4,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter a message';
                        }
                        return null;
                      },
                      style: const TextStyle(
                        fontSize: 15,
                        color: Color(0xFF111827),
                      ),
                      decoration: const InputDecoration(
                        hintText: 'Enter your broadcast message...',
                        hintStyle: TextStyle(
                          fontSize: 15,
                          color: Color(0xFF9CA3AF),
                        ),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.all(16),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Priority Field
                  const Text(
                    'Priority',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                      color: Colors.white,
                    ),
                    child: DropdownButtonFormField<String>(
                      initialValue: selectedPriority,
                      onChanged: (value) {
                        setState(() {
                          selectedPriority = value!;
                        });
                      },
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                      ),
                      style: const TextStyle(
                        fontSize: 15,
                        color: Color(0xFF111827),
                      ),
                      icon: const Icon(
                        Icons.keyboard_arrow_down,
                        color: Color(0xFF9CA3AF),
                      ),
                      items: priorities.map((String priority) {
                        return DropdownMenuItem<String>(
                          value: priority,
                          child: Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: _getPriorityColor(priority),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(priority),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Recipients Section
                  const Text(
                    'Recipients',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  // Send to All Staff Toggle
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.people_outline,
                          color: Colors.grey[600],
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Send to all staff members',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF111827),
                            ),
                          ),
                        ),
                        Switch(
                          value: sendToAllStaff,
                          onChanged: (value) {
                            setState(() {
                              sendToAllStaff = value;
                            });
                          },
                          activeThumbColor: const Color(0xFF2563EB),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Delivery Options
                  const Text(
                    'Delivery Options',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  // Push Notification Toggle
                  _buildToggleOption(
                    icon: Icons.notifications_outlined,
                    title: 'Push Notification',
                    subtitle: 'Send via app notification',
                    value: sendPushNotification,
                    onChanged: (value) {
                      setState(() {
                        sendPushNotification = value;
                      });
                    },
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // SMS Toggle
                  _buildToggleOption(
                    icon: Icons.sms_outlined,
                    title: 'SMS Message',
                    subtitle: 'Send via text message',
                    value: sendSMS,
                    onChanged: (value) {
                      setState(() {
                        sendSMS = value;
                      });
                    },
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // Send Button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: isLoading ? null : _handleSendBroadcast,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        disabledBackgroundColor: const Color(0xFF2563EB).withOpacity(0.6),
                      ),
                      child: isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Text(
                              'Send Broadcast',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildToggleOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required Function(bool) onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: Colors.grey[600],
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF111827),
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: const Color(0xFF2563EB),
          ),
        ],
      ),
    );
  }

  Color _getPriorityColor(String priority) {
    switch (priority) {
      case 'Low':
        return const Color(0xFF10B981);
      case 'Normal':
        return const Color(0xFF2563EB);
      case 'High':
        return const Color(0xFFF59E0B);
      case 'Urgent':
        return const Color(0xFFEF4444);
      default:
        return const Color(0xFF2563EB);
    }
  }

  Future<void> _handleSendBroadcast() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (!sendPushNotification && !sendSMS) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one delivery option'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    // Simulate API call
    await Future.delayed(const Duration(seconds: 2));

    setState(() {
      isLoading = false;
    });

    Navigator.of(context).pop(true);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Broadcast sent to ${sendToAllStaff ? 'all staff members' : 'selected staff'}',
        ),
        backgroundColor: const Color(0xFF16A34A),
        duration: const Duration(seconds: 3),
      ),
    );
  }
}