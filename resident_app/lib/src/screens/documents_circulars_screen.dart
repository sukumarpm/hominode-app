// lib/src/screens/documents_circulars_screen.dart
// Documents & Circulars Screen

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import '../services/user_data_service.dart';
import '../widgets/skeleton_loader.dart';

// ============================================================================
// DOCUMENTS & CIRCULARS SCREEN
// ============================================================================
class DocumentsCircularsScreen extends StatefulWidget {
  const DocumentsCircularsScreen({Key? key}) : super(key: key);

  @override
  State<DocumentsCircularsScreen> createState() => _DocumentsCircularsScreenState();
}

class _DocumentsCircularsScreenState extends State<DocumentsCircularsScreen> {
  final _firestore = FirebaseFirestore.instance;
  final _userDataService = UserDataService();
  late Stream<List<Map<String, dynamic>>> _documentsStream;
  String? _buildingId;
  String _selectedTab = 'all'; // all, documents, circulars

  @override
  void initState() {
    super.initState();
    _initializeStream();
  }

  Future<void> _initializeStream() async {
    print('🔵 DOCUMENTS & CIRCULARS SCREEN: Initializing...');
    
    try {
      final userData = await _userDataService.getCurrentUserData();
      
      if (userData == null) {
        print('❌ No user data found');
        return;
      }

      final buildingId = userData['buildingId'];
      
      if (buildingId == null || buildingId.isEmpty) {
        print('❌ No building ID found');
        return;
      }

      setState(() {
        _buildingId = buildingId;
        _documentsStream = _getDocumentsStream(buildingId);
      });

      print('✅ Stream initialized for building: $buildingId');
    } catch (e) {
      print('❌ Error initializing: $e');
    }
  }

  Stream<List<Map<String, dynamic>>> _getDocumentsStream(String buildingId) {
    print('📡 DOCUMENTS FLOW: Streaming documents for building: $buildingId');
    
    return _firestore
        .collection('documents')
        .where('buildingId', isEqualTo: buildingId)
        .where('status', isEqualTo: 'published')
        .orderBy('publishedDate', descending: true)
        .snapshots()
        .map((snapshot) {
      print('📊 Found ${snapshot.docs.length} documents');
      
      return snapshot.docs.map((doc) {
        final data = doc.data();
        print('✅ Document: ${data['title']} - ${data['type']}');
        
        return {
          'id': doc.id,
          'title': data['title'] ?? 'Untitled',
          'type': data['type'] ?? 'document', // document, circular, notice
          'description': data['description'] ?? '',
          'content': data['content'] ?? '',
          'fileUrl': data['fileUrl'] ?? '',
          'fileName': data['fileName'] ?? '',
          'publishedDate': (data['publishedDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
          'expiryDate': (data['expiryDate'] as Timestamp?)?.toDate(),
          'author': data['author'] ?? 'Administrator',
          'category': data['category'] ?? 'General',
          'tags': List<String>.from(data['tags'] ?? []),
          'views': data['views'] ?? 0,
          'downloads': data['downloads'] ?? 0,
          'isImportant': data['isImportant'] ?? false,
          'attachments': List<Map<String, dynamic>>.from(
            (data['attachments'] ?? []).map((a) => {
              'name': a['name'] ?? 'Attachment',
              'url': a['url'] ?? '',
              'size': a['size'] ?? 0,
            }),
          ),
        };
      }).toList();
    }).handleError((error) {
      print('❌ Stream error: $error');
      return [];
    });
  }

  List<Map<String, dynamic>> _filterDocuments(List<Map<String, dynamic>> documents) {
    switch (_selectedTab) {
      case 'documents':
        return documents.where((d) => d['type'] == 'document').toList();
      
      case 'circulars':
        return documents.where((d) => d['type'] == 'circular').toList();
      
      case 'all':
      default:
        return documents;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Documents & Circulars'),
        backgroundColor: const Color(0xFF2563EB),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _buildingId == null
          ? const Center(
              child: Text('Unable to load documents'),
            )
          : Column(
              children: [
                // Tab selector
                Container(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      _buildTabButton('All', 'all'),
                      const SizedBox(width: 8),
                      _buildTabButton('Documents', 'documents'),
                      const SizedBox(width: 8),
                      _buildTabButton('Circulars', 'circulars'),
                    ],
                  ),
                ),
                // Documents list
                Expanded(
                  child: StreamBuilder<List<Map<String, dynamic>>>(
                    stream: _documentsStream,
                    builder: (context, snapshot) {
                      // Loading state
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: 3,
                          itemBuilder: (context, index) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: SkeletonLoader(
                              width: double.infinity,
                              height: 140,
                              borderRadius: BorderRadius.circular(12.0),
                            ),
                          ),
                        );
                      }

                      // Error state
                      if (snapshot.hasError) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.error_outline, size: 48, color: Colors.red),
                              const SizedBox(height: 16),
                              Text('Error: ${snapshot.error}'),
                            ],
                          ),
                        );
                      }

                      final allDocuments = snapshot.data ?? [];
                      final filteredDocuments = _filterDocuments(allDocuments);

                      // Empty state
                      if (filteredDocuments.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.description_outlined,
                                size: 64,
                                color: Colors.grey[300],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No $_selectedTab documents',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      // Documents list
                      return ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: filteredDocuments.length,
                        itemBuilder: (context, index) {
                          final doc = filteredDocuments[index];
                          return _buildDocumentCard(context, doc);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildTabButton(String label, String value) {
    final isSelected = _selectedTab == value;
    
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTab = value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF2563EB) : Colors.grey[200],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isSelected ? Colors.white : Colors.grey[700],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDocumentCard(BuildContext context, Map<String, dynamic> doc) {
    final publishedDate = doc['publishedDate'] as DateTime;
    final isImportant = doc['isImportant'] as bool;
    final type = doc['type'] as String;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _showDocumentDetails(context, doc),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title and important badge
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: type == 'circular' 
                          ? const Color(0xFFDCFCE7)
                          : const Color(0xFFDBEAFE),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      type == 'circular' ? Icons.notifications_active : Icons.description,
                      color: type == 'circular' 
                          ? const Color(0xFF16A34A)
                          : const Color(0xFF3B82F6),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                doc['title'] ?? 'Untitled',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isImportant)
                              Container(
                                margin: const EdgeInsets.only(left: 8),
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEF4444),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  '!',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          doc['category'] ?? 'General',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Description preview
              if ((doc['description'] as String?)?.isNotEmpty ?? false)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    doc['description'] ?? '',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[700],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              // Date and stats
              Row(
                children: [
                  const Icon(Icons.calendar_today, size: 14, color: Colors.grey),
                  const SizedBox(width: 6),
                  Text(
                    _formatDate(publishedDate),
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  const SizedBox(width: 16),
                  const Icon(Icons.visibility, size: 14, color: Colors.grey),
                  const SizedBox(width: 6),
                  Text(
                    '${doc['views']} views',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  if (((doc['downloads'] as int?) ?? 0) > 0) ...[
                    const SizedBox(width: 16),
                    const Icon(Icons.download, size: 14, color: Colors.grey),
                    const SizedBox(width: 6),
                    Text(
                      '${doc['downloads']} downloads',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDocumentDetails(BuildContext context, Map<String, dynamic> doc) {
    final publishedDate = doc['publishedDate'] as DateTime;
    final attachments = doc['attachments'] as List<Map<String, dynamic>>;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: doc['type'] == 'circular' 
                          ? const Color(0xFFDCFCE7)
                          : const Color(0xFFDBEAFE),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      doc['type'] == 'circular' ? Icons.notifications_active : Icons.description,
                      color: doc['type'] == 'circular' 
                          ? const Color(0xFF16A34A)
                          : const Color(0xFF3B82F6),
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          doc['title'] ?? 'Untitled',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          doc['category'] ?? 'General',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // Details
              _buildDetailRow('Published', _formatDate(publishedDate)),
              _buildDetailRow('Author', doc['author'] ?? 'Administrator'),
              if ((doc['expiryDate'] as DateTime?) != null)
                _buildDetailRow(
                  'Expires',
                  _formatDate(doc['expiryDate'] as DateTime),
                ),
              _buildDetailRow('Views', '${doc['views']} views'),
              _buildDetailRow('Downloads', '${doc['downloads']} downloads'),
              if ((doc['description'] as String?)?.isNotEmpty ?? false)
                _buildDetailRow('Description', doc['description'] ?? ''),
              if ((doc['content'] as String?)?.isNotEmpty ?? false)
                _buildDetailRow('Content', doc['content'] ?? ''),
              // Attachments
              if (attachments.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  'Attachments (${attachments.length})',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                ...attachments.map((att) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.attachment, size: 16, color: Colors.grey),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          att['name'] ?? 'Attachment',
                          style: const TextStyle(fontSize: 13),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                )),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Close',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
