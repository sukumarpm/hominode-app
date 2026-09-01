import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

import '../session/web_session.dart';

class ResidentBill {
  const ResidentBill({
    required this.id,
    required this.communityId,
    required this.flatId,
    required this.amount,
    required this.status,
    required this.title,
    required this.subtitle,
    this.dueDate,
  });

  final String id;
  final String communityId;
  final String flatId;
  final double amount;
  final String status;
  final String title;
  final String subtitle;
  final DateTime? dueDate;

  bool get canSubmitProof => status == 'pending' && amount > 0;
}

class ResidentPaymentProof {
  const ResidentPaymentProof({
    required this.id,
    required this.billId,
    required this.status,
    this.rejectionReason,
    this.createdAt,
  });

  final String id;
  final String billId;
  final String status;
  final String? rejectionReason;
  final DateTime? createdAt;

  bool get isPending => status == 'pending';
  bool get isCompleted => status == 'completed';
  bool get isFailed => status == 'failed';
}

class ResidentBillingData {
  const ResidentBillingData({
    required this.bills,
    required this.latestProofByBill,
  });

  final List<ResidentBill> bills;
  final Map<String, ResidentPaymentProof> latestProofByBill;

  List<ResidentBill> get pendingBills =>
      bills.where((bill) => bill.status == 'pending').toList(growable: false);

  double get pendingAmount =>
      pendingBills.fold(0, (total, bill) => total + bill.amount);
}

class ResidentReceiptFile {
  const ResidentReceiptFile({required this.name, required this.bytes});

  final String name;
  final Uint8List bytes;
}

class ResidentPaymentException implements Exception {
  const ResidentPaymentException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ResidentPaymentService {
  ResidentPaymentService({
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
  }) : _db = firestore ?? FirebaseFirestore.instance,
       _storage = storage ?? FirebaseStorage.instance;

  static const int maxReceiptBytes = 10 * 1024 * 1024;
  static const Set<String> allowedReceiptExtensions = {
    'jpg',
    'jpeg',
    'png',
    'heic',
    'heif',
  };

  final FirebaseFirestore _db;
  final FirebaseStorage _storage;

  Future<ResidentBillingData> load(WebSession session) async {
    final scope = _requireScope(session);
    final results = await Future.wait([
      _db
          .collection('bills')
          .where('communityId', isEqualTo: scope.communityId)
          .where('flatId', isEqualTo: scope.flatId)
          .get(),
      _db
          .collection('payments')
          .where('communityId', isEqualTo: scope.communityId)
          .where('flatId', isEqualTo: scope.flatId)
          .where('userId', isEqualTo: session.uid)
          .get(),
    ]);

    final billSnapshot = results[0];
    final paymentSnapshot = results[1];
    final bills =
        billSnapshot.docs
            .where(
              (doc) =>
                  doc.data()['communityId'] == scope.communityId &&
                  doc.data()['flatId'] == scope.flatId,
            )
            .map(_billFromDocument)
            .toList()
          ..sort(
            (a, b) =>
                _dateOrEpoch(b.dueDate).compareTo(_dateOrEpoch(a.dueDate)),
          );

    final payments =
        paymentSnapshot.docs
            .where(
              (doc) =>
                  doc.data()['communityId'] == scope.communityId &&
                  doc.data()['flatId'] == scope.flatId &&
                  doc.data()['userId'] == session.uid,
            )
            .map(_paymentFromDocument)
            .toList()
          ..sort(
            (a, b) =>
                _dateOrEpoch(b.createdAt).compareTo(_dateOrEpoch(a.createdAt)),
          );

    final latestProofByBill = <String, ResidentPaymentProof>{};
    for (final payment in payments) {
      latestProofByBill.putIfAbsent(payment.billId, () => payment);
    }

    return ResidentBillingData(
      bills: List.unmodifiable(bills),
      latestProofByBill: Map.unmodifiable(latestProofByBill),
    );
  }

  Future<void> submitProof({
    required WebSession session,
    required String billId,
    required ResidentReceiptFile receipt,
  }) async {
    final scope = _requireScope(session);
    final extension = _validatedExtension(receipt);

    final billDocument = await _db.collection('bills').doc(billId).get();
    final billData = billDocument.data();
    if (!billDocument.exists || billData == null) {
      throw const ResidentPaymentException('This bill is no longer available.');
    }
    if (billData['communityId'] != scope.communityId ||
        billData['flatId'] != scope.flatId) {
      throw const ResidentPaymentException(
        'This bill does not belong to your resident account.',
      );
    }
    if (billData['status'] != 'pending') {
      throw const ResidentPaymentException(
        'Payment proof can only be submitted for a pending bill.',
      );
    }
    final amount = billData['amount'];
    if (amount is! num || amount <= 0) {
      throw const ResidentPaymentException('This bill has an invalid amount.');
    }

    final existing = await _db
        .collection('payments')
        .where('communityId', isEqualTo: scope.communityId)
        .where('flatId', isEqualTo: scope.flatId)
        .where('billId', isEqualTo: billId)
        .where('userId', isEqualTo: session.uid)
        .get();

    final hasPendingProof = existing.docs.any((doc) {
      final data = doc.data();
      return data['communityId'] == scope.communityId &&
          data['flatId'] == scope.flatId &&
          data['userId'] == session.uid &&
          data['billId'] == billId &&
          data['status'] == 'pending';
    });
    if (hasPendingProof) {
      throw const ResidentPaymentException(
        'A payment proof for this bill is already pending review.',
      );
    }

    final paymentRef = _db.collection('payments').doc();
    final storagePath =
        'payment_receipts/${scope.communityId}/$billId/'
        '${session.uid}/${paymentRef.id}.$extension';
    final receiptRef = _storage.ref(storagePath);

    await receiptRef.putData(
      receipt.bytes,
      SettableMetadata(
        contentType: _contentType(extension),
        customMetadata: {
          'paymentId': paymentRef.id,
          'billId': billId,
          'communityId': scope.communityId,
          'residentUid': session.uid,
        },
      ),
    );

    try {
      final now = Timestamp.now();
      await paymentRef.set({
        'id': paymentRef.id,
        'communityId': scope.communityId,
        'billId': billId,
        'flatId': scope.flatId,
        'userId': session.uid,
        'amount': amount,
        'method': 'external',
        'status': 'pending',
        'transactionId': null,
        'receiptPath': storagePath,
        'paymentDate': now,
        'createdAt': now,
        'updatedAt': now,
      });
    } catch (_) {
      try {
        await receiptRef.delete();
      } catch (_) {
        // Preserve the original Firestore error if cleanup also fails.
      }
      rethrow;
    }
  }

  _ResidentScope _requireScope(WebSession session) {
    final communityId = session.activeTenant?.communityId.trim() ?? '';
    final flatId = session.flatId?.trim() ?? '';
    if (session.role != WebRole.resident || communityId.isEmpty) {
      throw const ResidentPaymentException(
        'An authenticated resident community is required.',
      );
    }
    if (flatId.isEmpty) {
      throw const ResidentPaymentException(
        'Your resident profile has no unit assignment.',
      );
    }
    return _ResidentScope(communityId, flatId);
  }

  String _validatedExtension(ResidentReceiptFile receipt) {
    if (receipt.bytes.isEmpty) {
      throw const ResidentPaymentException('The selected receipt is empty.');
    }
    if (receipt.bytes.length > maxReceiptBytes) {
      throw const ResidentPaymentException(
        'The receipt must be 10 MB or smaller.',
      );
    }
    final extension = receipt.name.contains('.')
        ? receipt.name.split('.').last.toLowerCase()
        : '';
    if (!allowedReceiptExtensions.contains(extension)) {
      throw const ResidentPaymentException(
        'Choose a JPG, PNG, HEIC, or HEIF image.',
      );
    }
    return extension;
  }

  ResidentBill _billFromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();
    final amount = data['amount'];
    final title = _firstString(data, const [
      'title',
      'billTitle',
      'description',
      'billType',
    ]);
    final period = _firstString(data, const [
      'billingPeriod',
      'period',
      'month',
      'billMonth',
    ]);
    return ResidentBill(
      id: document.id,
      communityId: data['communityId']?.toString() ?? '',
      flatId: data['flatId']?.toString() ?? '',
      amount: amount is num ? amount.toDouble() : 0,
      status: data['status']?.toString().trim().toLowerCase() ?? 'pending',
      title: title ?? 'Bill ${document.id}',
      subtitle: period ?? 'Billing information',
      dueDate: _timestampDate(data['dueDate']),
    );
  }

  ResidentPaymentProof _paymentFromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();
    return ResidentPaymentProof(
      id: document.id,
      billId: data['billId']?.toString() ?? '',
      status: data['status']?.toString().trim().toLowerCase() ?? 'pending',
      rejectionReason: _firstString(data, const ['rejectionReason']),
      createdAt:
          _timestampDate(data['createdAt']) ??
          _timestampDate(data['paymentDate']),
    );
  }
}

class _ResidentScope {
  const _ResidentScope(this.communityId, this.flatId);

  final String communityId;
  final String flatId;
}

String? _firstString(Map<String, dynamic> data, List<String> keys) {
  for (final key in keys) {
    final value = data[key]?.toString().trim();
    if (value != null && value.isNotEmpty) return value;
  }
  return null;
}

DateTime? _timestampDate(Object? value) => switch (value) {
  Timestamp timestamp => timestamp.toDate(),
  DateTime date => date,
  String text => DateTime.tryParse(text),
  _ => null,
};

DateTime _dateOrEpoch(DateTime? value) =>
    value ?? DateTime.fromMillisecondsSinceEpoch(0);

String _contentType(String extension) => switch (extension) {
  'png' => 'image/png',
  'heic' => 'image/heic',
  'heif' => 'image/heif',
  _ => 'image/jpeg',
};
