import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/notice_models.dart';
import '../services/notice_service.dart';

class CreateNoticeModal extends StatefulWidget {
  final Notice? notice;

  const CreateNoticeModal({super.key, this.notice});

  @override
  State<CreateNoticeModal> createState() => _CreateNoticeModalState();
}

class _CreateNoticeModalState extends State<CreateNoticeModal> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final NoticeService _noticeService = NoticeService();
  
  NoticeType selectedType = NoticeType.general;
  NoticePriority selectedPriority = NoticePriority.medium;
  bool isUrgent = false;
  bool requiresAcknowledgment = false;
  DateTime? expiryDate;
  List<String> selectedFlatIds = [];
  List<FlatOption> availableFlats = [];
  bool isLoadingFlats = true;

  @override
  void initState() {
    super.initState();
    _loadFlats();
    if (widget.notice != null) {
      _titleController.text = widget.notice!.title;
      _contentController.text = widget.notice!.content;
      selectedType = widget.notice!.type;
      selectedPriority = widget.notice!.priority;
      isUrgent = widget.notice!.isUrgent;
      requiresAcknowledgment = widget.notice!.requiresAcknowledgment;
      expiryDate = widget.notice!.expiresAt;
    }
  }

  void _loadFlats() async {
    try {
      final flats = await _noticeService.getFlats();
      setState(() {
        availableFlats = flats;
        isLoadingFlats = false;
      });
      print('CreateNoticeModal: Loaded ${flats.length} flats from Firestore');
    } catch (e) {
      print('CreateNoticeModal ERROR: Failed to load flats: $e');
      setState(() {
        isLoadingFlats = false;
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTitleField(),
                    const SizedBox(height: 20),
                    _buildContentField(),
                    const SizedBox(height: 20),
                    _buildTypeSelection(),
                    const SizedBox(height: 20),
                    _buildPrioritySelection(),
                    const SizedBox(height: 20),
                    _buildOptionsSection(),
                    const SizedBox(height: 20),
                    _buildBuildingSelection(),
                    const SizedBox(height: 20),
                    _buildExpiryDateSection(),
                    const SizedBox(height: 30),
                    _buildActionButtons(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.notifications_active,
              color: Color(0xFF10B981),
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.notice == null ? 'Create Notice' : 'Edit Notice',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF111827),
                  ),
                ),
                const Text(
                  'Send important information to residents',
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close, color: Color(0xFF6B7280)),
          ),
        ],
      ),
    );
  }

  Widget _buildTitleField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Notice Title',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF111827),
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _titleController,
          decoration: InputDecoration(
            hintText: 'Enter notice title...',
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
              borderSide: const BorderSide(color: Color(0xFF10B981), width: 2),
            ),
            contentPadding: const EdgeInsets.all(16),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter a title';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildContentField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Notice Content',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF111827),
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _contentController,
          maxLines: 5,
          decoration: InputDecoration(
            hintText: 'Enter notice content...',
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
              borderSide: const BorderSide(color: Color(0xFF10B981), width: 2),
            ),
            contentPadding: const EdgeInsets.all(16),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter notice content';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildTypeSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Notice Type',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF111827),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: NoticeType.values.map((type) {
            final isSelected = selectedType == type;
            return GestureDetector(
              onTap: () => setState(() => selectedType = type),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? type.color : Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected ? type.color : const Color(0xFFE5E7EB),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      type.icon,
                      size: 18,
                      color: isSelected ? Colors.white : type.color,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      type.displayName,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? Colors.white : const Color(0xFF374151),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildPrioritySelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Priority Level',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF111827),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: NoticePriority.values.map((priority) {
            final isSelected = selectedPriority == priority;
            return Expanded(
              child: GestureDetector(
                onTap: () => setState(() => selectedPriority = priority),
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: isSelected ? priority.color : Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected ? priority.color : const Color(0xFFE5E7EB),
                    ),
                  ),
                  child: Text(
                    priority.displayName,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? Colors.white : priority.color,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildOptionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Options',
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
            color: const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Icon(
                    Icons.priority_high,
                    color: const Color(0xFFEF4444),
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Mark as Urgent',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF111827),
                          ),
                        ),
                        Text(
                          'Urgent notices get priority display',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: isUrgent,
                    onChanged: (value) => setState(() => isUrgent = value),
                    activeThumbColor: const Color(0xFFEF4444),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    color: const Color(0xFF10B981),
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Require Acknowledgment',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF111827),
                          ),
                        ),
                        Text(
                          'Residents must acknowledge reading',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: requiresAcknowledgment,
                    onChanged: (value) => setState(() => requiresAcknowledgment = value),
                    activeThumbColor: const Color(0xFF10B981),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBuildingSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Target Flats',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF111827),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '(${selectedFlatIds.length} selected)',
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF6B7280),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: isLoadingFlats
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
                    ),
                  ),
                )
              : availableFlats.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(20),
                      child: Text(
                        'No flats available. Please add flats first.',
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF6B7280),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    )
                  : Column(
                      children: [
                        Row(
                          children: [
                            Checkbox(
                              value: selectedFlatIds.length == availableFlats.length,
                              onChanged: (value) {
                                setState(() {
                                  if (value == true) {
                                    selectedFlatIds = availableFlats.map((f) => f.id).toList();
                                  } else {
                                    selectedFlatIds.clear();
                                  }
                                });
                              },
                              activeColor: const Color(0xFF10B981),
                            ),
                            const Text(
                              'Select All Flats',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF111827),
                              ),
                            ),
                          ],
                        ),
                        const Divider(),
                        Container(
                          constraints: const BoxConstraints(maxHeight: 200),
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: availableFlats.length,
                            itemBuilder: (context, index) {
                              final flat = availableFlats[index];
                              final isSelected = selectedFlatIds.contains(flat.id);
                              
                              return Container(
                                margin: const EdgeInsets.only(bottom: 4),
                                decoration: BoxDecoration(
                                  color: isSelected 
                                      ? const Color(0xFF10B981).withOpacity(0.1)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: CheckboxListTile(
                                  value: isSelected,
                                  onChanged: (value) {
                                    setState(() {
                                      if (value == true) {
                                        selectedFlatIds.add(flat.id);
                                      } else {
                                        selectedFlatIds.remove(flat.id);
                                      }
                                    });
                                  },
                                  title: Text(
                                    flat.displayName,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                      color: isSelected ? const Color(0xFF10B981) : const Color(0xFF374151),
                                    ),
                                  ),
                                  subtitle: flat.subtitle.isNotEmpty
                                      ? Text(
                                          flat.subtitle,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: isSelected 
                                                ? const Color(0xFF059669)
                                                : const Color(0xFF9CA3AF),
                                          ),
                                        )
                                      : null,
                                  activeColor: const Color(0xFF10B981),
                                  dense: true,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
        ),
      ],
    );
  }

  Widget _buildExpiryDateSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Expiry Date (Optional)',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF111827),
          ),
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: _selectExpiryDate,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_today,
                  color: const Color(0xFF6B7280),
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    expiryDate == null
                        ? 'Select expiry date'
                        : 'Expires on ${_formatDate(expiryDate!)}',
                    style: TextStyle(
                      fontSize: 14,
                      color: expiryDate == null
                          ? const Color(0xFF9CA3AF)
                          : const Color(0xFF111827),
                    ),
                  ),
                ),
                if (expiryDate != null)
                  GestureDetector(
                    onTap: () => setState(() => expiryDate = null),
                    child: Icon(
                      Icons.clear,
                      color: const Color(0xFF6B7280),
                      size: 20,
                    ),
                  ),
              ],
            ),
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
            onPressed: () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              side: const BorderSide(color: Color(0xFFE5E7EB)),
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
            onPressed: _saveNotice,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              widget.notice == null ? 'Create Notice' : 'Update Notice',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        ElevatedButton(
          onPressed: _publishNotice,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2563EB),
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text(
            'Publish',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }

  void _selectExpiryDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: expiryDate ?? DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date != null) {
      setState(() => expiryDate = date);
    }
  }

  void _saveNotice() async {
    if (_formKey.currentState!.validate()) {
      if (selectedFlatIds.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select at least one flat'),
            backgroundColor: Color(0xFFEF4444),
          ),
        );
        return;
      }

      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) {
          throw Exception('User not authenticated');
        }

        await _noticeService.createNotice(
          title: _titleController.text.trim(),
          content: _contentController.text.trim(),
          type: selectedType.name,
          priority: selectedPriority.name,
          status: 'draft',
          authorId: user.uid,
          authorName: user.displayName ?? user.email ?? 'Admin',
          targetFlats: selectedFlatIds,
          isUrgent: isUrgent,
          requiresAcknowledgment: requiresAcknowledgment,
          expiresAt: expiryDate,
        );

        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Notice saved as draft'),
              backgroundColor: Color(0xFF10B981),
            ),
          );
        }
      } catch (e) {
        print('CreateNoticeModal ERROR: Failed to save notice: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to save notice: $e'),
              backgroundColor: const Color(0xFFEF4444),
            ),
          );
        }
      }
    }
  }

  void _publishNotice() async {
    if (_formKey.currentState!.validate()) {
      if (selectedFlatIds.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select at least one flat'),
            backgroundColor: Color(0xFFEF4444),
          ),
        );
        return;
      }

      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) {
          throw Exception('User not authenticated');
        }

        await _noticeService.createNotice(
          title: _titleController.text.trim(),
          content: _contentController.text.trim(),
          type: selectedType.name,
          priority: selectedPriority.name,
          status: 'published',
          authorId: user.uid,
          authorName: user.displayName ?? user.email ?? 'Admin',
          targetFlats: selectedFlatIds,
          isUrgent: isUrgent,
          requiresAcknowledgment: requiresAcknowledgment,
          expiresAt: expiryDate,
        );

        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Notice published successfully'),
              backgroundColor: Color(0xFF2563EB),
            ),
          );
        }
      } catch (e) {
        print('CreateNoticeModal ERROR: Failed to publish notice: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to publish notice: $e'),
              backgroundColor: const Color(0xFFEF4444),
            ),
          );
        }
      }
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}