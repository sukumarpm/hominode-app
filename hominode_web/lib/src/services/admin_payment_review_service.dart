import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../session/web_session.dart';

class AdminPaymentProof {
  const AdminPaymentProof({
    required this.id,
    required this.communityId,
    required this.billId,
    required this.status,
    required this.receiptPath,
    required this.method,
    required this.transactionId,
    required this.createdAt,
  });

  final String id;
  final String communityId;
  final String billId;
  final String status;
  final String receiptPath;
  final String method;
  final String transactionId;
  final DateTime? createdAt;

  bool get isPending => status == 'pending';
  bool get isCompleted => status == 'completed';
  bool get isFailed => status == 'failed';
}

class AdminPaymentReviewException implements Exception {
  const AdminPaymentReviewException(this.message);

  final String message;

  @override
  String toString() => message;
}

class AdminPaymentReviewService {
  AdminPaymentReviewService({
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
    FirebaseFunctions? functions,
  }) : _db = firestore ?? FirebaseFirestore.instance,
       _storage = storage ?? FirebaseStorage.instance,
       _functions =
           functions ??
           FirebaseFunctions.instanceFor(region: 'asia-southeast1');

  static const int maxReceiptBytes = 10 * 1024 * 1024;
  static const Set<String> canonicalStatuses = {
    'pending',
    'completed',
    'failed',
  };
  static bool _didLogAppCheckDebugFallback = false;

  final FirebaseFirestore _db;
  final FirebaseStorage _storage;
  final FirebaseFunctions _functions;

  Stream<List<AdminPaymentProof>> watchCommunityPayments(WebSession session) {
    final communityId = _requireAdminCommunity(session);
    return _db
        .collection('payments')
        .where('communityId', isEqualTo: communityId)
        .snapshots()
        .map((snapshot) {
          final payments = <AdminPaymentProof>[];
          for (final document in snapshot.docs) {
            final payment = _parsePayment(document, communityId);
            if (payment != null) payments.add(payment);
          }
          return List.unmodifiable(payments);
        });
  }

  Map<String, AdminPaymentProof> latestProofByBill(
    List<AdminPaymentProof> payments,
  ) {
    final sorted = [...payments]
      ..sort(
        (a, b) =>
            _dateOrEpoch(b.createdAt).compareTo(_dateOrEpoch(a.createdAt)),
      );
    final latest = <String, AdminPaymentProof>{};
    for (final payment in sorted) {
      latest.putIfAbsent(payment.billId, () => payment);
    }
    return Map.unmodifiable(latest);
  }

  Future<Uint8List> loadPaymentReceipt({
    required WebSession session,
    required AdminPaymentProof payment,
  }) async {
    _requireActionablePayment(session, payment, requirePending: false);
    final freshDocument = await _db
        .collection('payments')
        .doc(payment.id)
        .get();
    if (!freshDocument.exists || freshDocument.data() == null) {
      throw const AdminPaymentReviewException(
        'Payment submission was not found.',
      );
    }
    final freshPayment = _parsePaymentDocument(
      id: freshDocument.id,
      data: freshDocument.data()!,
      communityId: payment.communityId,
    );
    if (freshPayment == null || freshPayment.billId != payment.billId) {
      throw const AdminPaymentReviewException(
        'Payment receipt scope is invalid.',
      );
    }
    if (freshPayment.receiptPath.isEmpty ||
        !freshPayment.receiptPath.startsWith(
          'payment_receipts/${freshPayment.communityId}/${freshPayment.billId}/',
        )) {
      throw const AdminPaymentReviewException(
        'Payment receipt path is missing or invalid.',
      );
    }
    final receiptReference = _storage.ref().child(freshPayment.receiptPath);
    final metadata = await receiptReference.getMetadata();
    final receiptSize = metadata.size;
    if (receiptSize == null || receiptSize > maxReceiptBytes) {
      throw const AdminPaymentReviewException(
        'Payment receipt exceeds the 10 MB review limit.',
      );
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.uid != session.uid) {
      throw const AdminPaymentReviewException(
        'The authenticated Admin session has changed.',
      );
    }
    final authToken = await user.getIdToken();
    if (authToken == null || authToken.isEmpty) {
      throw const AdminPaymentReviewException(
        'Admin authentication token is unavailable.',
      );
    }
    final app = Firebase.app();
    final bucket = app.options.storageBucket?.trim() ?? '';
    if (bucket.isEmpty) {
      throw const AdminPaymentReviewException(
        'Firebase Storage is not configured.',
      );
    }
    String? appCheckToken;
    try {
      appCheckToken = await FirebaseAppCheck.instance.getToken(false);
    } on FirebaseException catch (error) {
      if (!kIsWeb || !kDebugMode || error.code != 'fetch-status-error') {
        rethrow;
      }
      if (!_didLogAppCheckDebugFallback) {
        debugPrint(
          'App Check token unavailable in debug web; continuing receipt '
          'download with Firebase Auth only.',
        );
        _didLogAppCheckDebugFallback = true;
      }
    }
    final encodedPath = Uri.encodeComponent(freshPayment.receiptPath);
    final uri = Uri.parse(
      'https://firebasestorage.googleapis.com/v0/b/$bucket/o/'
      '$encodedPath?alt=media',
    );
    final response = await http.get(
      uri,
      headers: {
        'Authorization': 'Firebase $authToken',
        if (appCheckToken != null && appCheckToken.isNotEmpty)
          'X-Firebase-AppCheck': appCheckToken,
      },
    );
    if (response.statusCode != 200) {
      throw AdminPaymentReviewException(
        response.statusCode == 401 || response.statusCode == 403
            ? 'You are not authorized to view this receipt.'
            : 'Payment receipt could not be loaded '
                  '(Storage HTTP ${response.statusCode}).',
      );
    }
    if (response.bodyBytes.length > maxReceiptBytes) {
      throw const AdminPaymentReviewException(
        'Payment receipt exceeds the 10 MB review limit.',
      );
    }
    return response.bodyBytes;
  }

  Future<void> verifyPaymentProof({
    required WebSession session,
    required AdminPaymentProof payment,
  }) async {
    _requireActionablePayment(session, payment, requirePending: true);

    await _functions.httpsCallable('verifyPaymentProof').call({
      'paymentId': payment.id,
    });
  }

  Future<void> rejectPaymentProof({
    required WebSession session,
    required AdminPaymentProof payment,
    required String rejectionReason,
  }) async {
    _requireActionablePayment(session, payment, requirePending: true);
    final reason = rejectionReason.trim();
    if (reason.isEmpty) {
      throw const AdminPaymentReviewException(
        'A rejection reason is required.',
      );
    }
    await _functions.httpsCallable('rejectPaymentProof').call({
      'paymentId': payment.id,
      'rejectionReason': reason,
    });
  }

  String _requireAdminCommunity(WebSession session) {
    final communityId = session.activeTenant?.communityId.trim() ?? '';
    if (session.role != WebRole.admin || communityId.isEmpty) {
      throw const AdminPaymentReviewException(
        'An active Admin community is required.',
      );
    }
    return communityId;
  }

  void _requireActionablePayment(
    WebSession session,
    AdminPaymentProof payment, {
    required bool requirePending,
  }) {
    final communityId = _requireAdminCommunity(session);
    if (payment.id.isEmpty ||
        payment.billId.isEmpty ||
        payment.communityId != communityId ||
        !canonicalStatuses.contains(payment.status)) {
      throw const AdminPaymentReviewException(
        'This payment does not belong to the active Admin community.',
      );
    }
    if (requirePending && !payment.isPending) {
      throw const AdminPaymentReviewException(
        'Only pending payment proofs can be reviewed.',
      );
    }
  }

  AdminPaymentProof? _parsePayment(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
    String communityId,
  ) => _parsePaymentDocument(
    id: document.id,
    data: document.data(),
    communityId: communityId,
  );

  AdminPaymentProof? _parsePaymentDocument({
    required String id,
    required Map<String, dynamic> data,
    required String communityId,
  }) {
    final paymentCommunityId = _string(data['communityId']);
    final billId = _string(data['billId']);
    final status = _string(data['status']).toLowerCase();
    final receiptPath = _string(data['receiptPath']);
    final createdAt =
        _date(data['createdAt']) ??
        _date(data['paymentDate']) ??
        _date(data['updatedAt']);
    if (id.isEmpty ||
        paymentCommunityId != communityId ||
        billId.isEmpty ||
        !canonicalStatuses.contains(status) ||
        createdAt == null ||
        (status == 'pending' && receiptPath.isEmpty)) {
      return null;
    }
    return AdminPaymentProof(
      id: id,
      communityId: paymentCommunityId,
      billId: billId,
      status: status,
      receiptPath: receiptPath,
      method: _string(data['method']),
      transactionId: _string(data['transactionId']),
      createdAt: createdAt,
    );
  }
}

String _string(Object? value) => value?.toString().trim() ?? '';

DateTime? _date(Object? value) => switch (value) {
  Timestamp timestamp => timestamp.toDate(),
  DateTime date => date,
  String text => DateTime.tryParse(text),
  _ => null,
};

DateTime _dateOrEpoch(DateTime? value) =>
    value ?? DateTime.fromMillisecondsSinceEpoch(0);
