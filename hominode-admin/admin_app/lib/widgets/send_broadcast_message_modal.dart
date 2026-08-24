import 'package:flutter/material.dart';
import '../services/broadcast_service.dart';

class SendBroadcastMessageModal extends StatefulWidget {
  const SendBroadcastMessageModal({super.key});

  @override
  State<SendBroadcastMessageModal> createState() =>
      _SendBroadcastMessageModalState();
}

class _SendBroadcastMessageModalState extends State<SendBroadcastMessageModal> {
  final BroadcastService _broadcastService = BroadcastService();

  String selectedMessageType = 'Push';
  Map<String, dynamic>? selectedRecipient;
  final TextEditingController _subjectController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  bool isLoading = false;
  bool isLoadingRecipients = true;

  List<Map<String, dynamic>> recipientOptions = [];

  @override
  void initState() {
    super.initState();
    _loadRecipients();
  }

  Future<void> _loadRecipients() async {
    setState(() {
      isLoadingRecipients = true;
    });

    try {
      final options = await _broadcastService.getRecipientOptions();
      setState(() {
        recipientOptions = options;
        if (options.isNotEmpty) {
          selectedRecipient = options.first;
        }
        isLoadingRecipients = false;
      });
    } catch (e) {
      print('Error loading recipients: $e');
      setState(() {
        isLoadingRecipients = false;
      });
    }
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  void _sendBroadcast() async {
    // Validate inputs
    if (_subjectController.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter a subject')));
      return;
    }

    if (_messageController.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter a message')));
      return;
    }

    if (selectedRecipient == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select recipients')));
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      final recipientIds = selectedRecipient!['recipientIds'] as List<dynamic>;

      final broadcastId = await _broadcastService.sendBroadcast(
        title: _subjectController.text.trim(),
        content: _messageController.text.trim(),
        type: selectedMessageType,
        recipientIds: recipientIds.cast<String>(),
        recipientFilter: selectedRecipient!['type'],
      );

      if (broadcastId != null && mounted) {
        Navigator.of(context).pop(true); // Return true to indicate success
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Broadcast message sent successfully!'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to send broadcast message'),
            backgroundColor: Color(0xFFEF4444),
          ),
        );
      }
    } catch (e) {
      print('Error sending broadcast: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Send Broadcast Message',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1F2937),
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Send a message to residents',
                            style: TextStyle(
                              fontSize: 14,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(
                        Icons.close,
                        color: Color(0xFF6B7280),
                        size: 24,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Message Type Selector
                Row(
                  children: [
                    Expanded(
                      child: _buildBroadcastTypeCard(
                        'Push',
                        Icons.notifications,
                        selectedMessageType == 'Push',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildBroadcastTypeCard(
                        'Email',
                        Icons.email,
                        selectedMessageType == 'Email',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildBroadcastTypeCard(
                        'SMS',
                        Icons.chat_bubble,
                        selectedMessageType == 'SMS',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Recipients Dropdown
                const Text(
                  'Recipients',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1F2937),
                  ),
                ),
                const SizedBox(height: 8),
                isLoadingRecipients
                    ? Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          border: Border.all(color: const Color(0xFFE5E7EB)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          children: [
                            SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            SizedBox(width: 12),
                            Text('Loading recipients...'),
                          ],
                        ),
                      )
                    : recipientOptions.isEmpty
                    ? Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          border: Border.all(color: const Color(0xFFE5E7EB)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text('No recipients available'),
                      )
                    : Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: const Color(0xFFE5E7EB)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<Map<String, dynamic>>(
                            value: selectedRecipient,
                            isExpanded: true,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            icon: const Icon(
                              Icons.keyboard_arrow_down,
                              color: Color(0xFF6B7280),
                              size: 20,
                            ),
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF1F2937),
                            ),
                            dropdownColor: Colors.white,
                            items: recipientOptions.map((
                              Map<String, dynamic> option,
                            ) {
                              return DropdownMenuItem<Map<String, dynamic>>(
                                value: option,
                                child: _buildDropdownItem(
                                  option['label'],
                                  option['type'],
                                ),
                              );
                            }).toList(),
                            onChanged: (Map<String, dynamic>? newValue) {
                              if (newValue != null) {
                                setState(() {
                                  selectedRecipient = newValue;
                                });
                              }
                            },
                          ),
                        ),
                      ),
                const SizedBox(height: 20),

                // Subject Input
                const Text(
                  'Subject',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1F2937),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _subjectController,
                  decoration: InputDecoration(
                    hintText: 'Message Subject',
                    hintStyle: const TextStyle(
                      color: Color(0xFF9CA3AF),
                      fontSize: 15,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFF0E4778)),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 20),

                // Message Text Area
                const Text(
                  'Message',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1F2937),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _messageController,
                  maxLines: 5,
                  minLines: 5,
                  decoration: InputDecoration(
                    hintText: 'Type your message here…',
                    hintStyle: const TextStyle(
                      color: Color(0xFF9CA3AF),
                      fontSize: 15,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFF0E4778)),
                    ),
                    contentPadding: const EdgeInsets.all(16),
                  ),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 24),

                // Send Button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: isLoading ? null : _sendBroadcast,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0E4778),
                      disabledBackgroundColor: const Color(0xFF9CA3AF),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    child: isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : Text(
                            _getSendButtonText(),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBroadcastTypeCard(String type, IconData icon, bool isSelected) {
    return GestureDetector(
      onTap: () {
        setState(() {
          selectedMessageType = type;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFEFF6FF) : Colors.white,
          border: Border.all(
            color: isSelected
                ? const Color(0xFF0E4778)
                : const Color(0xFFE5E7EB),
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 24,
              color: isSelected
                  ? const Color(0xFF0E4778)
                  : const Color(0xFF6B7280),
            ),
            const SizedBox(height: 8),
            Text(
              type,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isSelected
                    ? const Color(0xFF0E4778)
                    : const Color(0xFF1F2937),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdownItem(String label, String type) {
    IconData icon;
    Color iconColor;

    if (type == 'all') {
      icon = Icons.groups;
      iconColor = const Color(0xFF0E4778);
    } else if (type == 'building') {
      icon = Icons.apartment;
      iconColor = const Color(0xFF059669);
    } else if (type == 'flat') {
      icon = Icons.home;
      iconColor = const Color(0xFF8B5CF6);
    } else {
      icon = Icons.group;
      iconColor = const Color(0xFF6B7280);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF1F2937),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getSendButtonText() {
    if (selectedRecipient == null) {
      return 'Send Message';
    }
    final count = selectedRecipient!['count'] as int;
    return 'Send to ${count > 1 ? "$count Recipients" : "Recipient"}';
  }
}

// Helper function to show the modal
void showSendBroadcastMessageModal(BuildContext context) {
  showDialog(
    context: context,
    barrierColor: const Color(0x80000000), // Semi-transparent black background
    barrierDismissible: true,
    builder: (BuildContext context) {
      return const SendBroadcastMessageModal();
    },
  );
}
