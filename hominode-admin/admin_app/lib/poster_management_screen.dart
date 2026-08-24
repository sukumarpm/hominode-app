import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'services/poster_service.dart';
import 'services/admin_service.dart';

class PosterManagementScreen extends StatefulWidget {
  const PosterManagementScreen({super.key});

  @override
  State<PosterManagementScreen> createState() => _PosterManagementScreenState();
}

class _PosterManagementScreenState extends State<PosterManagementScreen> {
  final PosterService _posterService = PosterService();
  final AdminService _adminService = AdminService();
  final ImagePicker _imagePicker = ImagePicker();
  
  File? _selectedImage;
  String? _selectedBuildingId;
  String? _posterTitle;
  bool _isUploading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Poster Management'),
        backgroundColor: Colors.blue,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Upload Section
            _buildUploadSection(),
            const SizedBox(height: 32),
            
            // Posters List
            _buildPostersList(),
          ],
        ),
      ),
    );
  }

  // ==================== UPLOAD SECTION ====================
  Widget _buildUploadSection() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Upload New Poster',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            
            // Image Picker
            _buildImagePicker(),
            const SizedBox(height: 16),
            
            // Title Input
            TextField(
              onChanged: (value) => _posterTitle = value,
              decoration: InputDecoration(
                labelText: 'Poster Title',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                prefixIcon: const Icon(Icons.title),
              ),
            ),
            const SizedBox(height: 16),
            
            // Building Selector
            _buildBuildingSelector(),
            const SizedBox(height: 16),
            
            // Upload Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isUploading ? null : _uploadPoster,
                icon: _isUploading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(Colors.white),
                        ),
                      )
                    : const Icon(Icons.cloud_upload),
                label: Text(_isUploading ? 'Uploading...' : 'Upload Poster'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePicker() {
    return GestureDetector(
      onTap: _pickImage,
      child: Container(
        height: 200,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey),
          borderRadius: BorderRadius.circular(8),
          color: Colors.grey[100],
        ),
        child: _selectedImage != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(
                  _selectedImage!,
                  fit: BoxFit.cover,
                ),
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.image, size: 48, color: Colors.grey),
                  const SizedBox(height: 8),
                  const Text('Tap to select image'),
                  const SizedBox(height: 4),
                  Text(
                    'JPG, PNG (Max 5MB)',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildBuildingSelector() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _adminService.getAdminBuildings(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const CircularProgressIndicator();
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Text('No buildings available');
        }

        final buildings = snapshot.data!;
        return DropdownButtonFormField<String>(
          initialValue: _selectedBuildingId,
          items: buildings.map((building) {
            return DropdownMenuItem(
              value: building['id'],
              child: Text(building['name'] ?? 'Unknown'),
            );
          }).toList(),
          onChanged: (value) => setState(() => _selectedBuildingId = value),
          decoration: InputDecoration(
            labelText: 'Select Building',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            prefixIcon: const Icon(Icons.apartment),
          ),
        );
      },
    );
  }

  // ==================== POSTERS LIST ====================
  Widget _buildPostersList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Your Posters',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        StreamBuilder<List<PosterModel>>(
          stream: _posterService.getAdminPosters(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(
                child: Column(
                  children: [
                    const Icon(Icons.error, color: Colors.red, size: 48),
                    const SizedBox(height: 8),
                    Text('Error: ${snapshot.error}'),
                  ],
                ),
              );
            }

            final posters = snapshot.data ?? [];

            if (posters.isEmpty) {
              return Center(
                child: Column(
                  children: [
                    Icon(Icons.image_not_supported, 
                      size: 48, 
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 8),
                    const Text('No posters yet'),
                  ],
                ),
              );
            }

            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: posters.length,
              itemBuilder: (context, index) {
                final poster = posters[index];
                return _buildPosterCard(poster);
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildPosterCard(PosterModel poster) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Image.network(
            poster.imageUrl,
            width: 60,
            height: 60,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                width: 60,
                height: 60,
                color: Colors.grey[300],
                child: const Icon(Icons.image_not_supported),
              );
            },
          ),
        ),
        title: Text(poster.title),
        subtitle: Text(
          'Created: ${poster.createdAt?.toString().split('.')[0] ?? 'N/A'}',
          style: const TextStyle(fontSize: 12),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete, color: Colors.red),
          onPressed: () => _deletePoster(poster.id),
        ),
      ),
    );
  }

  // ==================== ACTIONS ====================
  Future<void> _pickImage() async {
    try {
      final pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );

      if (pickedFile != null) {
        setState(() => _selectedImage = File(pickedFile.path));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking image: $e')),
      );
    }
  }

  Future<void> _uploadPoster() async {
    if (_selectedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an image')),
      );
      return;
    }

    if (_selectedBuildingId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a building')),
      );
      return;
    }

    setState(() => _isUploading = true);

    try {
      await _posterService.uploadPoster(
        imageFile: _selectedImage!,
        buildingId: _selectedBuildingId!,
        title: _posterTitle,
      );

      setState(() {
        _selectedImage = null;
        _posterTitle = null;
        _isUploading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Poster uploaded successfully')),
      );
    } catch (e) {
      setState(() => _isUploading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _deletePoster(String posterId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Poster'),
        content: const Text('Are you sure you want to delete this poster?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _posterService.deletePoster(posterId);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Poster deleted')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }
}
