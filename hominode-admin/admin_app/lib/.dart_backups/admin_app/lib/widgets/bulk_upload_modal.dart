import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

class BulkUploadFlatsModal extends StatefulWidget {
  final void Function(PlatformFile file) onUploadSuccess;

  const BulkUploadFlatsModal({
    super.key,
    required this.onUploadSuccess,
  });

  static Future<void> show(
    BuildContext context, {
    required void Function(PlatformFile file) onUploadSuccess,
  }) {
    return showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close',
      barrierColor: Colors.black.withOpacity(0.35),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (context, animation, secondaryAnimation) {
        return BulkUploadFlatsModal(onUploadSuccess: onUploadSuccess);
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
  State<BulkUploadFlatsModal> createState() => _BulkUploadFlatsModalState();
}

class _BulkUploadFlatsModalState extends State<BulkUploadFlatsModal> {
  PlatformFile? _selectedFile;
  bool _isLoading = false;
  String? _errorMessage;

  void _downloadTemplate() {
    // TODO: Implement real template download
    // Example: launch('https://your-api.com/download-template')
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Template downloaded'),
        backgroundColor: Color(0xFF10B981),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _pickFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'xlsx', 'xls'],
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        
        // Validate file extension
        final fileName = file.name.toLowerCase();
        if (!fileName.endsWith('.csv') && 
            !fileName.endsWith('.xlsx') && 
            !fileName.endsWith('.xls')) {
          setState(() {
            _errorMessage = 'Only CSV and Excel files are allowed';
            _selectedFile = null;
          });
          return;
        }

        setState(() {
          _selectedFile = file;
          _errorMessage = null;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to pick file. Please try again.';
        _selectedFile = null;
      });
    }
  }

  Future<void> _handleUpload() async {
    if (_selectedFile == null) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    // Simulate upload delay
    await Future.delayed(const Duration(milliseconds: 1000));

    // TODO: Implement real file upload
    // Example:
    // try {
    //   await uploadFileToServer(_selectedFile!);
    //   if (mounted) {
    //     Navigator.of(context).pop();
    //     widget.onUploadSuccess(_selectedFile!);
    //   }
    // } catch (e) {
    //   setState(() {
    //     _errorMessage = 'Upload failed. Please try again.';
    //     _isLoading = false;
    //   });
    // }

    // Mock success
    if (mounted) {
      Navigator.of(context).pop();
      widget.onUploadSuccess(_selectedFile!);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.92 > 720
              ? 720
              : MediaQuery.of(context).size.width * 0.92,
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16),
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          elevation: 8,
          child: SingleChildScrollView(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 16),
                  _buildTemplatePanel(),
                  const SizedBox(height: 20),
                  _buildDropLabel(),
                  const SizedBox(height: 14),
                  _buildUploadRow(),
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 8),
                    _buildErrorMessage(),
                  ],
                  const SizedBox(height: 24),
                  _buildUploadButton(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Stack(
      children: [
        Column(
          children: [
            const Text(
              'Bulk Upload Flats',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: Color(0xFF111111),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Upload multiple flats using Excel or CSV file.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: const Color(0xFF6B7280),
              ),
            ),
          ],
        ),
        Positioned(
          top: 0,
          right: 0,
          child: Semantics(
            label: 'Close bulk upload',
            button: true,
            child: InkWell(
              onTap: () => Navigator.of(context).pop(),
              borderRadius: BorderRadius.circular(22),
              child: Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                child: const Icon(
                  Icons.close,
                  color: Color(0xFF9CA3AF),
                  size: 24,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTemplatePanel() {
    return Semantics(
      label: 'Download template',
      button: true,
      child: InkWell(
        onTap: _downloadTemplate,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFFF8F9FB),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.upload_outlined,
                color: Color(0xFF9CA3AF),
                size: 32,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  'Download the template, fill in flat details, and upload back.',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF9CA3AF),
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDropLabel() {
    return const Text(
      'Drop your file here',
      style: TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w700,
        color: Color(0xFF111111),
      ),
    );
  }

  Widget _buildUploadRow() {
    return Semantics(
      label: _selectedFile == null ? 'Choose file to upload' : 'Change file',
      button: true,
      child: InkWell(
        onTap: _isLoading ? null : _pickFile,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(
              color: _errorMessage != null
                  ? const Color(0xFFEF4444)
                  : const Color(0xFFE5E7EB),
              width: 1,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _selectedFile == null ? Icons.download : Icons.insert_drive_file,
                color: const Color(0xFF111827),
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _selectedFile == null ? 'Upload photo' : _selectedFile!.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF111827),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (_selectedFile != null) ...[
                const SizedBox(width: 8),
                const Text(
                  'Change',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF2563EB),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorMessage() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFEE2E2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline,
            color: Color(0xFFEF4444),
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _errorMessage!,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFFEF4444),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUploadButton() {
    final isEnabled = _selectedFile != null && !_isLoading;

    return Semantics(
      label: 'Upload file',
      button: true,
      enabled: isEnabled,
      child: ElevatedButton(
        onPressed: isEnabled ? _handleUpload : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF2563EB),
          disabledBackgroundColor: const Color(0xFF2563EB).withOpacity(0.4),
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          minimumSize: const Size(double.infinity, 54),
        ),
        child: _isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Text(
                'Upload File',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }
}
