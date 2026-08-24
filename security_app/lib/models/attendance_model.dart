import 'package:cloud_firestore/cloud_firestore.dart';

class AttendanceModel {
  final String id;
  final String staffId;
  final String staffName;
  final String gateName;
  final DateTime checkInTime;
  final DateTime? checkOutTime;
  final double latitude;
  final double longitude;
  final String status;
  final String? photoUrl;

  AttendanceModel({
    required this.id,
    required this.staffId,
    required this.staffName,
    required this.gateName,
    required this.checkInTime,
    this.checkOutTime,
    this.latitude = 0.0,
    this.longitude = 0.0,
    required this.status,
    this.photoUrl,
  });

  factory AttendanceModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AttendanceModel(
      id: doc.id,
      staffId: data['staffId'] ?? '',
      staffName: data['staffName'] ?? '',
      gateName: data['gateName'] ?? '',
      checkInTime: (data['checkInTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
      checkOutTime: (data['checkOutTime'] as Timestamp?)?.toDate(),
      latitude: (data['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (data['longitude'] as num?)?.toDouble() ?? 0.0,
      status: data['status'] ?? 'on-duty',
      photoUrl: data['photoUrl'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'staffId': staffId,
      'staffName': staffName,
      'gateName': gateName,
      'checkInTime': Timestamp.fromDate(checkInTime),
      'checkOutTime': checkOutTime != null ? Timestamp.fromDate(checkOutTime!) : null,
      'latitude': latitude,
      'longitude': longitude,
      'status': status,
      'photoUrl': photoUrl,
    };
  }
}
