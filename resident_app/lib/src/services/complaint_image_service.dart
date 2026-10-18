import 'package:cloud_firestore/cloud_firestore.dart';
import 'resident_image_operations.dart';

class ComplaintImageResult {
  final bool success;
  final String? message, imageUrl, errorCode;
  ComplaintImageResult({
    required this.success,
    this.message,
    this.imageUrl,
    this.errorCode,
  });
  factory ComplaintImageResult.success({String? message, String? imageUrl}) =>
      ComplaintImageResult(success: true, message: message, imageUrl: imageUrl);
  factory ComplaintImageResult.failure({
    required String message,
    String? errorCode,
  }) => ComplaintImageResult(
    success: false,
    message: message,
    errorCode: errorCode,
  );
}

class ComplaintImageService {
  static final instance = ComplaintImageService._internal();
  factory ComplaintImageService() => instance;
  ComplaintImageService._internal();
  final _operations = ResidentImageOperations();
  Future<ComplaintImageResult> uploadComplaintImage({
    required String imagePath,
    required String complaintId,
  }) async {
    try {
      final record = await _operations.record('complaints', complaintId);
      final reference = await _operations.upload(
        feature: 'complaints',
        resourceId: complaintId,
        imagePath: imagePath,
      );
      await _operations.save(
        feature: 'complaints',
        resourceId: complaintId,
        revision: record['imageRevision'] as int? ?? 0,
        references: [reference],
      );
      return ComplaintImageResult.success(imageUrl: reference);
    } catch (_) {
      return ComplaintImageResult.failure(
        message: 'Your complaint is saved. Please retry its photo.',
        errorCode: 'UPLOAD_ERROR',
      );
    }
  }

  ComplaintImageResult _result(Map<String, dynamic>? data) =>
      ComplaintImageResult.success(imageUrl: data?['imageUrl'] as String?);
  Future<ComplaintImageResult> fetchComplaintImage({
    required String complaintId,
  }) async => _result(
    (await FirebaseFirestore.instance
            .collection('complaints')
            .doc(complaintId)
            .get())
        .data(),
  );
  Stream<ComplaintImageResult> streamComplaintImage({
    required String complaintId,
  }) => FirebaseFirestore.instance
      .collection('complaints')
      .doc(complaintId)
      .snapshots()
      .map((doc) => _result(doc.data()));
  Future<ComplaintImageResult> deleteComplaintImage({
    required String complaintId,
    required String publicId,
  }) async {
    try {
      final record = await _operations.record('complaints', complaintId);
      await _operations.save(
        feature: 'complaints',
        resourceId: complaintId,
        revision: record['imageRevision'] as int? ?? 0,
        references: [],
      );
      return ComplaintImageResult.success();
    } catch (_) {
      return ComplaintImageResult.failure(
        message: 'Unable to remove the photo.',
        errorCode: 'DELETE_ERROR',
      );
    }
  }
}
