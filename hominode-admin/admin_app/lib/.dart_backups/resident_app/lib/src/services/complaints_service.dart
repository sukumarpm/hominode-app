// lib/src/services/complaints_service.dart
// Complaints service with Firestore integration

import '../models/complaint.dart';
import 'complaint_firestore_service.dart';

class ComplaintsService {
  static final ComplaintsService _instance = ComplaintsService._internal();
  factory ComplaintsService() => _instance;
  ComplaintsService._internal();

  final _firestoreService = ComplaintFirestoreService();

  /// Fetch all complaints from Firestore
  Future<List<Complaint>> fetchComplaints() async {
    return await _firestoreService.getMyComplaints();
  }

  /// Create a new complaint in Firestore
  Future<Complaint> createComplaint({
    required String title,
    required String description,
    required ComplaintCategory category,
  }) async {
    final result = await _firestoreService.createComplaint(
      title: title,
      description: description,
      category: category,
    );

    if (!result.success) {
      throw Exception(result.message ?? 'Failed to create complaint');
    }

    // Return a complaint object with the new ID
    return Complaint(
      id: result.complaintId!,
      title: title,
      description: description,
      category: category,
      status: ComplaintStatus.pending,
      createdDate: DateTime.now(),
    );
  }

  /// Delete a complaint from Firestore
  Future<void> deleteComplaint(String complaintId) async {
    final result = await _firestoreService.deleteComplaint(complaintId);
    
    if (!result.success) {
      throw Exception(result.message ?? 'Failed to delete complaint');
    }
  }

  /// Stream complaints (real-time updates)
  Stream<List<Complaint>> streamComplaints() {
    return _firestoreService.streamMyComplaints();
  }
}
