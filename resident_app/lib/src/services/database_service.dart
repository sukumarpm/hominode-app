// lib/src/services/database_service.dart
// Cloud Firestore Database Service with CRUD operations

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../models/building_model.dart';
import '../models/flat_model.dart';
import '../models/resident_model.dart';
import '../models/bill_model.dart';
import '../models/payment_model.dart';
import '../models/visitor_model.dart';
import '../models/notice_model.dart';
import '../models/complaint_model.dart';

/// Result class for database operations
class DatabaseResult<T> {
  final bool success;
  final String? message;
  final T? data;
  final String? errorCode;

  DatabaseResult({
    required this.success,
    this.message,
    this.data,
    this.errorCode,
  });

  factory DatabaseResult.success({String? message, T? data}) {
    return DatabaseResult(
      success: true,
      message: message ?? 'Operation successful',
      data: data,
    );
  }

  factory DatabaseResult.failure({required String message, String? errorCode}) {
    return DatabaseResult(
      success: false,
      message: message,
      errorCode: errorCode,
    );
  }
}

/// Cloud Firestore Database Service
class DatabaseService {
  // Singleton pattern
  static final DatabaseService instance = DatabaseService._internal();
  factory DatabaseService() => instance;
  DatabaseService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Collection names
  static const String usersCollection = 'users';
  static const String buildingsCollection = 'buildings';
  static const String flatsCollection = 'flats';
  static const String residentsCollection = 'residents';
  static const String billsCollection = 'bills';
  static const String paymentsCollection = 'payments';
  static const String visitorsCollection = 'visitors';
  static const String noticesCollection = 'notices';
  static const String complaintsCollection = 'complaints';

  // ============================================================================
  // USERS CRUD
  // ============================================================================

  /// Create a new user
  Future<DatabaseResult<UserModel>> createUser(UserModel user) async {
    try {
      await _firestore.collection(usersCollection).doc(user.id).set(user.toMap());
      return DatabaseResult.success(message: 'User created successfully', data: user);
    } on FirebaseException catch (e) {
      return DatabaseResult.failure(
        message: _getErrorMessage(e.code),
        errorCode: e.code,
      );
    } catch (e) {
      return DatabaseResult.failure(message: 'Failed to create user: $e');
    }
  }

  /// Get user by ID
  Future<DatabaseResult<UserModel>> getUser(String userId) async {
    try {
      final doc = await _firestore.collection(usersCollection).doc(userId).get();
      
      if (!doc.exists) {
        return DatabaseResult.failure(message: 'User not found');
      }

      final user = UserModel.fromSnapshot(doc);
      return DatabaseResult.success(data: user);
    } on FirebaseException catch (e) {
      return DatabaseResult.failure(
        message: _getErrorMessage(e.code),
        errorCode: e.code,
      );
    } catch (e) {
      return DatabaseResult.failure(message: 'Failed to get user: $e');
    }
  }

  /// Update user
  Future<DatabaseResult<UserModel>> updateUser(String userId, Map<String, dynamic> updates) async {
    try {
      updates['updatedAt'] = Timestamp.now();
      await _firestore.collection(usersCollection).doc(userId).update(updates);
      
      final result = await getUser(userId);
      return result;
    } on FirebaseException catch (e) {
      return DatabaseResult.failure(
        message: _getErrorMessage(e.code),
        errorCode: e.code,
      );
    } catch (e) {
      return DatabaseResult.failure(message: 'Failed to update user: $e');
    }
  }

  /// Delete user
  Future<DatabaseResult<void>> deleteUser(String userId) async {
    try {
      await _firestore.collection(usersCollection).doc(userId).delete();
      return DatabaseResult.success(message: 'User deleted successfully');
    } on FirebaseException catch (e) {
      return DatabaseResult.failure(
        message: _getErrorMessage(e.code),
        errorCode: e.code,
      );
    } catch (e) {
      return DatabaseResult.failure(message: 'Failed to delete user: $e');
    }
  }

  /// Get all users
  Future<DatabaseResult<List<UserModel>>> getAllUsers() async {
    try {
      final snapshot = await _firestore.collection(usersCollection).get();
      final users = snapshot.docs.map((doc) => UserModel.fromSnapshot(doc)).toList();
      return DatabaseResult.success(data: users);
    } on FirebaseException catch (e) {
      return DatabaseResult.failure(
        message: _getErrorMessage(e.code),
        errorCode: e.code,
      );
    } catch (e) {
      return DatabaseResult.failure(message: 'Failed to get users: $e');
    }
  }

  /// Stream users
  Stream<List<UserModel>> streamUsers() {
    return _firestore
        .collection(usersCollection)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => UserModel.fromSnapshot(doc)).toList());
  }

  // ============================================================================
  // BUILDINGS CRUD
  // ============================================================================

  Future<DatabaseResult<BuildingModel>> createBuilding(BuildingModel building) async {
    try {
      final docRef = await _firestore.collection(buildingsCollection).add(building.toMap());
      final created = building.copyWith(id: docRef.id);
      await docRef.update({'id': docRef.id});
      return DatabaseResult.success(message: 'Building created successfully', data: created);
    } catch (e) {
      return DatabaseResult.failure(message: 'Failed to create building: $e');
    }
  }

  Future<DatabaseResult<BuildingModel>> getBuilding(String buildingId) async {
    try {
      final doc = await _firestore.collection(buildingsCollection).doc(buildingId).get();
      if (!doc.exists) return DatabaseResult.failure(message: 'Building not found');
      return DatabaseResult.success(data: BuildingModel.fromSnapshot(doc));
    } catch (e) {
      return DatabaseResult.failure(message: 'Failed to get building: $e');
    }
  }

  Future<DatabaseResult<BuildingModel>> updateBuilding(String buildingId, Map<String, dynamic> updates) async {
    try {
      updates['updatedAt'] = Timestamp.now();
      await _firestore.collection(buildingsCollection).doc(buildingId).update(updates);
      final result = await getBuilding(buildingId);
      return result;
    } catch (e) {
      return DatabaseResult.failure(message: 'Failed to update building: $e');
    }
  }

  Future<DatabaseResult<void>> deleteBuilding(String buildingId) async {
    try {
      await _firestore.collection(buildingsCollection).doc(buildingId).delete();
      return DatabaseResult.success(message: 'Building deleted successfully');
    } catch (e) {
      return DatabaseResult.failure(message: 'Failed to delete building: $e');
    }
  }

  Future<DatabaseResult<List<BuildingModel>>> getAllBuildings() async {
    try {
      final snapshot = await _firestore.collection(buildingsCollection).get();
      final buildings = snapshot.docs.map((doc) => BuildingModel.fromSnapshot(doc)).toList();
      return DatabaseResult.success(data: buildings);
    } catch (e) {
      return DatabaseResult.failure(message: 'Failed to get buildings: $e');
    }
  }

  Stream<List<BuildingModel>> streamBuildings() {
    return _firestore
        .collection(buildingsCollection)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => BuildingModel.fromSnapshot(doc)).toList());
  }

  // ============================================================================
  // FLATS CRUD
  // ============================================================================

  Future<DatabaseResult<FlatModel>> createFlat(FlatModel flat) async {
    try {
      final docRef = await _firestore.collection(flatsCollection).add(flat.toMap());
      final created = flat.copyWith(id: docRef.id);
      await docRef.update({'id': docRef.id});
      return DatabaseResult.success(message: 'Flat created successfully', data: created);
    } catch (e) {
      return DatabaseResult.failure(message: 'Failed to create flat: $e');
    }
  }

  Future<DatabaseResult<FlatModel>> getFlat(String flatId) async {
    try {
      final doc = await _firestore.collection(flatsCollection).doc(flatId).get();
      if (!doc.exists) return DatabaseResult.failure(message: 'Flat not found');
      return DatabaseResult.success(data: FlatModel.fromSnapshot(doc));
    } catch (e) {
      return DatabaseResult.failure(message: 'Failed to get flat: $e');
    }
  }

  Future<DatabaseResult<FlatModel>> updateFlat(String flatId, Map<String, dynamic> updates) async {
    try {
      updates['updatedAt'] = Timestamp.now();
      await _firestore.collection(flatsCollection).doc(flatId).update(updates);
      final result = await getFlat(flatId);
      return result;
    } catch (e) {
      return DatabaseResult.failure(message: 'Failed to update flat: $e');
    }
  }

  Future<DatabaseResult<void>> deleteFlat(String flatId) async {
    try {
      await _firestore.collection(flatsCollection).doc(flatId).delete();
      return DatabaseResult.success(message: 'Flat deleted successfully');
    } catch (e) {
      return DatabaseResult.failure(message: 'Failed to delete flat: $e');
    }
  }

  Future<DatabaseResult<List<FlatModel>>> getFlatsByBuilding(String buildingId) async {
    try {
      final snapshot = await _firestore
          .collection(flatsCollection)
          .where('buildingId', isEqualTo: buildingId)
          .get();
      final flats = snapshot.docs.map((doc) => FlatModel.fromSnapshot(doc)).toList();
      return DatabaseResult.success(data: flats);
    } catch (e) {
      return DatabaseResult.failure(message: 'Failed to get flats: $e');
    }
  }

  Stream<List<FlatModel>> streamFlatsByBuilding(String buildingId) {
    return _firestore
        .collection(flatsCollection)
        .where('buildingId', isEqualTo: buildingId)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => FlatModel.fromSnapshot(doc)).toList());
  }

  // ============================================================================
  // RESIDENTS CRUD
  // ============================================================================

  Future<DatabaseResult<ResidentModel>> createResident(ResidentModel resident) async {
    try {
      final docRef = await _firestore.collection(residentsCollection).add(resident.toMap());
      return DatabaseResult.success(message: 'Resident created successfully');
    } catch (e) {
      return DatabaseResult.failure(message: 'Failed to create resident: $e');
    }
  }

  Future<DatabaseResult<List<ResidentModel>>> getResidentsByFlat(String flatId) async {
    try {
      final snapshot = await _firestore
          .collection(residentsCollection)
          .where('flatId', isEqualTo: flatId)
          .get();
      final residents = snapshot.docs.map((doc) => ResidentModel.fromSnapshot(doc)).toList();
      return DatabaseResult.success(data: residents);
    } catch (e) {
      return DatabaseResult.failure(message: 'Failed to get residents: $e');
    }
  }

  Future<DatabaseResult<void>> deleteResident(String residentId) async {
    try {
      await _firestore.collection(residentsCollection).doc(residentId).delete();
      return DatabaseResult.success(message: 'Resident deleted successfully');
    } catch (e) {
      return DatabaseResult.failure(message: 'Failed to delete resident: $e');
    }
  }

  // ============================================================================
  // BILLS CRUD
  // ============================================================================

  Future<DatabaseResult<BillModel>> createBill(BillModel bill) async {
    try {
      final docRef = await _firestore.collection(billsCollection).add(bill.toMap());
      final created = bill.copyWith(id: docRef.id);
      await docRef.update({'id': docRef.id});
      return DatabaseResult.success(message: 'Bill created successfully', data: created);
    } catch (e) {
      return DatabaseResult.failure(message: 'Failed to create bill: $e');
    }
  }

  Future<DatabaseResult<BillModel>> getBill(String billId) async {
    try {
      final doc = await _firestore.collection(billsCollection).doc(billId).get();
      if (!doc.exists) return DatabaseResult.failure(message: 'Bill not found');
      return DatabaseResult.success(data: BillModel.fromSnapshot(doc));
    } catch (e) {
      return DatabaseResult.failure(message: 'Failed to get bill: $e');
    }
  }

  Future<DatabaseResult<List<BillModel>>> getBillsByFlat(String flatId) async {
    try {
      final snapshot = await _firestore
          .collection(billsCollection)
          .where('flatId', isEqualTo: flatId)
          .orderBy('dueDate', descending: true)
          .get();
      final bills = snapshot.docs.map((doc) => BillModel.fromSnapshot(doc)).toList();
      return DatabaseResult.success(data: bills);
    } catch (e) {
      return DatabaseResult.failure(message: 'Failed to get bills: $e');
    }
  }

  Future<DatabaseResult<BillModel>> updateBill(String billId, Map<String, dynamic> updates) async {
    try {
      updates['updatedAt'] = Timestamp.now();
      await _firestore.collection(billsCollection).doc(billId).update(updates);
      final result = await getBill(billId);
      return result;
    } catch (e) {
      return DatabaseResult.failure(message: 'Failed to update bill: $e');
    }
  }

  Stream<List<BillModel>> streamBillsByFlat(String flatId) {
    return _firestore
        .collection(billsCollection)
        .where('flatId', isEqualTo: flatId)
        .orderBy('dueDate', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => BillModel.fromSnapshot(doc)).toList());
  }

  // ============================================================================
  // PAYMENTS CRUD
  // ============================================================================

  Future<DatabaseResult<PaymentModel>> createPayment(PaymentModel payment) async {
    try {
      final docRef = await _firestore.collection(paymentsCollection).add(payment.toMap());
      final created = payment.copyWith(id: docRef.id);
      await docRef.update({'id': docRef.id});
      return DatabaseResult.success(message: 'Payment created successfully', data: created);
    } catch (e) {
      return DatabaseResult.failure(message: 'Failed to create payment: $e');
    }
  }

  Future<DatabaseResult<List<PaymentModel>>> getPaymentsByFlat(String flatId) async {
    try {
      final snapshot = await _firestore
          .collection(paymentsCollection)
          .where('flatId', isEqualTo: flatId)
          .orderBy('paymentDate', descending: true)
          .get();
      final payments = snapshot.docs.map((doc) => PaymentModel.fromSnapshot(doc)).toList();
      return DatabaseResult.success(data: payments);
    } catch (e) {
      return DatabaseResult.failure(message: 'Failed to get payments: $e');
    }
  }

  Future<DatabaseResult<PaymentModel>> updatePayment(String paymentId, Map<String, dynamic> updates) async {
    try {
      updates['updatedAt'] = Timestamp.now();
      await _firestore.collection(paymentsCollection).doc(paymentId).update(updates);
      final doc = await _firestore.collection(paymentsCollection).doc(paymentId).get();
      return DatabaseResult.success(data: PaymentModel.fromSnapshot(doc));
    } catch (e) {
      return DatabaseResult.failure(message: 'Failed to update payment: $e');
    }
  }

  // ============================================================================
  // VISITORS CRUD
  // ============================================================================

  Future<DatabaseResult<VisitorModel>> createVisitor(VisitorModel visitor) async {
    try {
      final docRef = await _firestore.collection(visitorsCollection).add(visitor.toMap());
      final created = visitor.copyWith(id: docRef.id);
      await docRef.update({'id': docRef.id});
      return DatabaseResult.success(message: 'Visitor created successfully', data: created);
    } catch (e) {
      return DatabaseResult.failure(message: 'Failed to create visitor: $e');
    }
  }

  Future<DatabaseResult<List<VisitorModel>>> getVisitorsByFlat(String flatId) async {
    try {
      final snapshot = await _firestore
          .collection(visitorsCollection)
          .where('flatId', isEqualTo: flatId)
          .orderBy('expectedArrival', descending: true)
          .get();
      final visitors = snapshot.docs.map((doc) => VisitorModel.fromSnapshot(doc)).toList();
      return DatabaseResult.success(data: visitors);
    } catch (e) {
      return DatabaseResult.failure(message: 'Failed to get visitors: $e');
    }
  }

  Future<DatabaseResult<VisitorModel>> updateVisitor(String visitorId, Map<String, dynamic> updates) async {
    try {
      updates['updatedAt'] = Timestamp.now();
      await _firestore.collection(visitorsCollection).doc(visitorId).update(updates);
      final doc = await _firestore.collection(visitorsCollection).doc(visitorId).get();
      return DatabaseResult.success(data: VisitorModel.fromSnapshot(doc));
    } catch (e) {
      return DatabaseResult.failure(message: 'Failed to update visitor: $e');
    }
  }

  Stream<List<VisitorModel>> streamVisitorsByFlat(String flatId) {
    return _firestore
        .collection(visitorsCollection)
        .where('flatId', isEqualTo: flatId)
        .orderBy('expectedArrival', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => VisitorModel.fromSnapshot(doc)).toList());
  }

  // ============================================================================
  // NOTICES CRUD
  // ============================================================================

  Future<DatabaseResult<NoticeModel>> createNotice(NoticeModel notice) async {
    try {
      final docRef = await _firestore.collection(noticesCollection).add(notice.toMap());
      final created = notice.copyWith(id: docRef.id);
      await docRef.update({'id': docRef.id});
      return DatabaseResult.success(message: 'Notice created successfully', data: created);
    } catch (e) {
      return DatabaseResult.failure(message: 'Failed to create notice: $e');
    }
  }

  Future<DatabaseResult<List<NoticeModel>>> getActiveNotices() async {
    try {
      final snapshot = await _firestore
          .collection(noticesCollection)
          .where('isActive', isEqualTo: true)
          .orderBy('publishDate', descending: true)
          .get();
      final notices = snapshot.docs.map((doc) => NoticeModel.fromSnapshot(doc)).toList();
      return DatabaseResult.success(data: notices);
    } catch (e) {
      return DatabaseResult.failure(message: 'Failed to get notices: $e');
    }
  }

  Future<DatabaseResult<NoticeModel>> updateNotice(String noticeId, Map<String, dynamic> updates) async {
    try {
      updates['updatedAt'] = Timestamp.now();
      await _firestore.collection(noticesCollection).doc(noticeId).update(updates);
      final doc = await _firestore.collection(noticesCollection).doc(noticeId).get();
      return DatabaseResult.success(data: NoticeModel.fromSnapshot(doc));
    } catch (e) {
      return DatabaseResult.failure(message: 'Failed to update notice: $e');
    }
  }

  Future<DatabaseResult<void>> deleteNotice(String noticeId) async {
    try {
      await _firestore.collection(noticesCollection).doc(noticeId).delete();
      return DatabaseResult.success(message: 'Notice deleted successfully');
    } catch (e) {
      return DatabaseResult.failure(message: 'Failed to delete notice: $e');
    }
  }

  Stream<List<NoticeModel>> streamActiveNotices() {
    return _firestore
        .collection(noticesCollection)
        .where('isActive', isEqualTo: true)
        .orderBy('publishDate', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => NoticeModel.fromSnapshot(doc)).toList());
  }

  // ============================================================================
  // COMPLAINTS CRUD
  // ============================================================================

  Future<DatabaseResult<ComplaintModel>> createComplaint(ComplaintModel complaint) async {
    try {
      final docRef = await _firestore.collection(complaintsCollection).add(complaint.toMap());
      final created = complaint.copyWith(id: docRef.id);
      await docRef.update({'id': docRef.id});
      return DatabaseResult.success(message: 'Complaint created successfully', data: created);
    } catch (e) {
      return DatabaseResult.failure(message: 'Failed to create complaint: $e');
    }
  }

  Future<DatabaseResult<List<ComplaintModel>>> getComplaintsByFlat(String flatId) async {
    try {
      final snapshot = await _firestore
          .collection(complaintsCollection)
          .where('flatId', isEqualTo: flatId)
          .orderBy('createdAt', descending: true)
          .get();
      final complaints = snapshot.docs.map((doc) => ComplaintModel.fromSnapshot(doc)).toList();
      return DatabaseResult.success(data: complaints);
    } catch (e) {
      return DatabaseResult.failure(message: 'Failed to get complaints: $e');
    }
  }

  Future<DatabaseResult<ComplaintModel>> updateComplaint(String complaintId, Map<String, dynamic> updates) async {
    try {
      updates['updatedAt'] = Timestamp.now();
      await _firestore.collection(complaintsCollection).doc(complaintId).update(updates);
      final doc = await _firestore.collection(complaintsCollection).doc(complaintId).get();
      return DatabaseResult.success(data: ComplaintModel.fromSnapshot(doc));
    } catch (e) {
      return DatabaseResult.failure(message: 'Failed to update complaint: $e');
    }
  }

  Future<DatabaseResult<void>> deleteComplaint(String complaintId) async {
    try {
      await _firestore.collection(complaintsCollection).doc(complaintId).delete();
      return DatabaseResult.success(message: 'Complaint deleted successfully');
    } catch (e) {
      return DatabaseResult.failure(message: 'Failed to delete complaint: $e');
    }
  }

  Stream<List<ComplaintModel>> streamComplaintsByFlat(String flatId) {
    return _firestore
        .collection(complaintsCollection)
        .where('flatId', isEqualTo: flatId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => ComplaintModel.fromSnapshot(doc)).toList());
  }

  // ============================================================================
  // HELPER METHODS
  // ============================================================================

  /// Get user-friendly error message
  String _getErrorMessage(String errorCode) {
    switch (errorCode) {
      case 'permission-denied':
        return 'You don\'t have permission to perform this action';
      case 'not-found':
        return 'The requested document was not found';
      case 'already-exists':
        return 'A document with this ID already exists';
      case 'unavailable':
        return 'Service is currently unavailable. Please try again later';
      case 'deadline-exceeded':
        return 'Operation timed out. Please try again';
      default:
        return 'An error occurred. Please try again';
    }
  }
}

// Extension methods for copyWith on models
extension BillModelCopyWith on BillModel {
  BillModel copyWith({String? id}) {
    return BillModel(
      id: id ?? this.id,
      flatId: flatId,
      type: type,
      amount: amount,
      dueDate: dueDate,
      billingPeriodStart: billingPeriodStart,
      billingPeriodEnd: billingPeriodEnd,
      status: status,
      description: description,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}

extension PaymentModelCopyWith on PaymentModel {
  PaymentModel copyWith({String? id}) {
    return PaymentModel(
      id: id ?? this.id,
      billId: billId,
      flatId: flatId,
      userId: userId,
      amount: amount,
      method: method,
      status: status,
      transactionId: transactionId,
      receiptUrl: receiptUrl,
      paymentDate: paymentDate,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}

extension VisitorModelCopyWith on VisitorModel {
  VisitorModel copyWith({String? id}) {
    return VisitorModel(
      id: id ?? this.id,
      flatId: flatId,
      hostUserId: hostUserId,
      visitorName: visitorName,
      visitorPhone: visitorPhone,
      purpose: purpose,
      expectedArrival: expectedArrival,
      actualArrival: actualArrival,
      departure: departure,
      status: status,
      vehicleNumber: vehicleNumber,
      photoUrl: photoUrl,
      approvedBy: approvedBy,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}

extension NoticeModelCopyWith on NoticeModel {
  NoticeModel copyWith({String? id}) {
    return NoticeModel(
      id: id ?? this.id,
      title: title,
      content: content,
      category: category,
      priority: priority,
      authorId: authorId,
      authorName: authorName,
      attachments: attachments,
      publishDate: publishDate,
      expiryDate: expiryDate,
      isActive: isActive,
      targetFlats: targetFlats,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}

extension ComplaintModelCopyWith on ComplaintModel {
  ComplaintModel copyWith({String? id}) {
    return ComplaintModel(
      id: id ?? this.id,
      flatId: flatId,
      userId: userId,
      title: title,
      description: description,
      category: category,
      priority: priority,
      status: status,
      attachments: attachments,
      assignedTo: assignedTo,
      resolution: resolution,
      resolvedAt: resolvedAt,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
