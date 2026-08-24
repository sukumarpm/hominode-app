/// Document model for Documents & Circulars feature
class Document {
  final String id;
  final String title;
  final String description;
  final DateTime date;
  final String fileType; // PDF, DOC, etc.
  final double fileSizeInMB;
  final DocumentCategory category;
  final String? fileUrl;

  const Document({
    required this.id,
    required this.title,
    required this.description,
    required this.date,
    required this.fileType,
    required this.fileSizeInMB,
    required this.category,
    this.fileUrl,
  });

  // Sample data
  static List<Document> getSampleDocuments() {
    return [
      Document(
        id: '1',
        title: 'Annual General Meeting - 2024',
        description: 'Minutes of the Annual General Meeting held on January 15, 2024',
        date: DateTime(2024, 1, 15),
        fileType: 'PDF',
        fileSizeInMB: 2.4,
        category: DocumentCategory.meeting,
      ),
      Document(
        id: '2',
        title: 'Society Maintenance Rules',
        description: 'Updated maintenance and society rules for all residents',
        date: DateTime(2024, 1, 10),
        fileType: 'PDF',
        fileSizeInMB: 1.8,
        category: DocumentCategory.circular,
      ),
      Document(
        id: '3',
        title: 'Legal Notice - Parking',
        description: 'Legal notice regarding parking violations and penalties',
        date: DateTime(2024, 1, 8),
        fileType: 'PDF',
        fileSizeInMB: 0.9,
        category: DocumentCategory.legal,
      ),
      Document(
        id: '4',
        title: 'Water Supply Schedule',
        description: 'New water supply schedule effective from February 2024',
        date: DateTime(2024, 1, 5),
        fileType: 'PDF',
        fileSizeInMB: 0.5,
        category: DocumentCategory.circular,
      ),
      Document(
        id: '5',
        title: 'Building Renovation Approval',
        description: 'Legal document for building renovation approval process',
        date: DateTime(2024, 1, 3),
        fileType: 'PDF',
        fileSizeInMB: 3.2,
        category: DocumentCategory.legal,
      ),
      Document(
        id: '6',
        title: 'Monthly Committee Meeting',
        description: 'Minutes of monthly committee meeting held on December 28, 2023',
        date: DateTime(2023, 12, 28),
        fileType: 'PDF',
        fileSizeInMB: 1.5,
        category: DocumentCategory.meeting,
      ),
      Document(
        id: '7',
        title: 'Festival Celebration Notice',
        description: 'Notice regarding upcoming festival celebrations and guidelines',
        date: DateTime(2023, 12, 20),
        fileType: 'PDF',
        fileSizeInMB: 0.7,
        category: DocumentCategory.circular,
      ),
      Document(
        id: '8',
        title: 'Emergency Contact List',
        description: 'Updated emergency contact list for all residents',
        date: DateTime(2023, 12, 15),
        fileType: 'PDF',
        fileSizeInMB: 0.4,
        category: DocumentCategory.circular,
      ),
      Document(
        id: '9',
        title: 'Annual Financial Report - 2024',
        description: 'Comprehensive financial report for the year 2024',
        date: DateTime(2024, 1, 20),
        fileType: 'PDF',
        fileSizeInMB: 3.8,
        category: DocumentCategory.financial,
      ),
      Document(
        id: '10',
        title: 'Maintenance Collection Summary - Q1',
        description: 'Quarterly maintenance collection and expense summary',
        date: DateTime(2024, 1, 18),
        fileType: 'PDF',
        fileSizeInMB: 1.2,
        category: DocumentCategory.financial,
      ),
      Document(
        id: '11',
        title: 'Society Fund Allocation Breakdown',
        description: 'Detailed breakdown of society fund allocation for 2024',
        date: DateTime(2024, 1, 12),
        fileType: 'PDF',
        fileSizeInMB: 2.1,
        category: DocumentCategory.financial,
      ),
      Document(
        id: '12',
        title: 'Fire Safety Compliance Report 2024',
        description: 'Annual fire safety compliance and inspection report',
        date: DateTime(2024, 1, 22),
        fileType: 'PDF',
        fileSizeInMB: 1.9,
        category: DocumentCategory.compliance,
      ),
      Document(
        id: '13',
        title: 'Annual Building Certification',
        description: 'Building safety and structural certification document',
        date: DateTime(2024, 1, 16),
        fileType: 'PDF',
        fileSizeInMB: 2.7,
        category: DocumentCategory.compliance,
      ),
      Document(
        id: '14',
        title: 'Society Legal Compliance Statement',
        description: 'Legal compliance statement and regulatory adherence report',
        date: DateTime(2024, 1, 10),
        fileType: 'PDF',
        fileSizeInMB: 1.5,
        category: DocumentCategory.compliance,
      ),
    ];
  }
}

enum DocumentCategory {
  all,
  circular,
  legal,
  meeting,
  financial,
  compliance,
}

extension DocumentCategoryExtension on DocumentCategory {
  String get displayName {
    switch (this) {
      case DocumentCategory.all:
        return 'All Documents';
      case DocumentCategory.circular:
        return 'Circular';
      case DocumentCategory.legal:
        return 'Legal';
      case DocumentCategory.meeting:
        return 'Meeting';
      case DocumentCategory.financial:
        return 'Financial';
      case DocumentCategory.compliance:
        return 'Compliance';
    }
  }

  int getCount(List<Document> documents) {
    if (this == DocumentCategory.all) {
      return documents.length;
    }
    return documents.where((doc) => doc.category == this).length;
  }
}
