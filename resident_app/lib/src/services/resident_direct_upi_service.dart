import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/community_payment_config.dart';

enum ResidentDirectUpiFailure {
  unauthenticated,
  scopeUnavailable,
  billUnavailable,
  billOwnershipMismatch,
  billSettled,
  directUpiNotConfigured,
  directUpiDisabled,
  paymentConfigInvalid,
  paymentConfigUnavailable,
}

class ResidentDirectUpiException implements Exception {
  const ResidentDirectUpiException(this.failure);

  final ResidentDirectUpiFailure failure;

  String get message => switch (failure) {
    ResidentDirectUpiFailure.unauthenticated => 'Please sign in again.',
    ResidentDirectUpiFailure.scopeUnavailable =>
      'Resident payment scope is unavailable.',
    ResidentDirectUpiFailure.billUnavailable => 'This bill is unavailable.',
    ResidentDirectUpiFailure.billOwnershipMismatch =>
      'This bill does not belong to this account.',
    ResidentDirectUpiFailure.billSettled => 'This bill is already settled.',
    ResidentDirectUpiFailure.directUpiNotConfigured =>
      'Direct UPI is not configured for this community.',
    ResidentDirectUpiFailure.directUpiDisabled =>
      'Direct UPI is currently disabled.',
    ResidentDirectUpiFailure.paymentConfigInvalid =>
      'Community payment configuration is invalid.',
    ResidentDirectUpiFailure.paymentConfigUnavailable =>
      'Community payment settings could not be loaded.',
  };

  @override
  String toString() => message;
}

class ResidentDirectUpiScope {
  const ResidentDirectUpiScope({
    required this.uid,
    required this.communityId,
    required this.flatId,
  });

  final String uid;
  final String communityId;
  final String flatId;
}

class ResidentDirectUpiDocument {
  const ResidentDirectUpiDocument({required this.exists, this.data});

  final bool exists;
  final Map<String, dynamic>? data;
}

typedef ResidentDirectUpiScopeLoader =
    Future<ResidentDirectUpiScope> Function();
typedef ResidentDirectUpiDocumentLoader =
    Future<ResidentDirectUpiDocument> Function(String documentId);

class DirectUpiPaymentPreparation {
  const DirectUpiPaymentPreparation({
    required this.billId,
    required this.communityId,
    required this.amount,
    required this.vpa,
    required this.payeeName,
    required this.paymentUri,
  });

  final String billId;
  final String communityId;
  final double amount;
  final String vpa;
  final String payeeName;
  final Uri paymentUri;
}

class ResidentDirectUpiService {
  ResidentDirectUpiService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    ResidentDirectUpiScopeLoader? scopeLoader,
    ResidentDirectUpiDocumentLoader? billLoader,
    ResidentDirectUpiDocumentLoader? paymentConfigLoader,
  }) : _auth = auth,
       _firestore = firestore,
       _scopeLoader = scopeLoader,
       _billLoader = billLoader,
       _paymentConfigLoader = paymentConfigLoader;

  final FirebaseAuth? _auth;
  final FirebaseFirestore? _firestore;
  final ResidentDirectUpiScopeLoader? _scopeLoader;
  final ResidentDirectUpiDocumentLoader? _billLoader;
  final ResidentDirectUpiDocumentLoader? _paymentConfigLoader;

  Future<DirectUpiPaymentPreparation> preparePayment(String billId) async {
    final id = billId.trim();
    if (id.isEmpty || id != billId || id.contains('/')) {
      throw const ResidentDirectUpiException(
        ResidentDirectUpiFailure.billUnavailable,
      );
    }

    final scope = await _loadScope();
    final billDocument = await _loadDocument(
      documentId: id,
      loader: _billLoader,
      collection: 'bills',
      failure: ResidentDirectUpiFailure.billUnavailable,
    );
    final bill = _requireBillForScope(billDocument, id, scope);

    final configDocument = await _loadDocument(
      documentId: scope.communityId,
      loader: _paymentConfigLoader,
      collection: 'communityPaymentConfigs',
      failure: ResidentDirectUpiFailure.paymentConfigUnavailable,
    );
    final config = _parsePaymentConfig(configDocument, scope.communityId);
    if (!config.configured) {
      throw const ResidentDirectUpiException(
        ResidentDirectUpiFailure.directUpiNotConfigured,
      );
    }
    if (!config.directUpi.enabled) {
      throw const ResidentDirectUpiException(
        ResidentDirectUpiFailure.directUpiDisabled,
      );
    }
    if (!config.directUpi.isUsable) {
      throw const ResidentDirectUpiException(
        ResidentDirectUpiFailure.paymentConfigInvalid,
      );
    }

    final amount = (bill['amount'] as num).toDouble();
    final vpa = config.directUpi.vpa!;
    final payeeName = config.directUpi.payeeName!;
    final paymentUri = Uri(
      scheme: 'upi',
      host: 'pay',
      queryParameters: {
        'pa': vpa,
        'pn': payeeName,
        'am': amount.toStringAsFixed(2),
        'cu': 'INR',
      },
    );

    return DirectUpiPaymentPreparation(
      billId: id,
      communityId: scope.communityId,
      amount: amount,
      vpa: vpa,
      payeeName: payeeName,
      paymentUri: paymentUri,
    );
  }

  Future<ResidentDirectUpiScope> _loadScope() async {
    final loader = _scopeLoader;
    if (loader != null) {
      try {
        return _validateScope(await loader());
      } on ResidentDirectUpiException {
        rethrow;
      } catch (_) {
        throw const ResidentDirectUpiException(
          ResidentDirectUpiFailure.scopeUnavailable,
        );
      }
    }

    final user = (_auth ?? FirebaseAuth.instance).currentUser;
    if (user == null || user.uid.trim().isEmpty) {
      throw const ResidentDirectUpiException(
        ResidentDirectUpiFailure.unauthenticated,
      );
    }

    try {
      final document = await (_firestore ?? FirebaseFirestore.instance)
          .collection('users')
          .doc(user.uid)
          .get(const GetOptions(source: Source.server));
      if (!document.exists) {
        throw const ResidentDirectUpiException(
          ResidentDirectUpiFailure.scopeUnavailable,
        );
      }
      final data = document.data();
      if (data == null ||
          data['role'] != 'resident' ||
          data['approvalStatus'] != 'approved' ||
          data['isActive'] != true ||
          (data.containsKey('status') && data['status'] != 'active') ||
          (data.containsKey('uid') && data['uid'] != user.uid)) {
        throw const ResidentDirectUpiException(
          ResidentDirectUpiFailure.scopeUnavailable,
        );
      }
      return _validateScope(
        ResidentDirectUpiScope(
          uid: user.uid,
          communityId: _requiredScopeId(data['communityId']),
          flatId: _requiredScopeId(data['flatId']),
        ),
      );
    } on ResidentDirectUpiException {
      rethrow;
    } catch (_) {
      throw const ResidentDirectUpiException(
        ResidentDirectUpiFailure.scopeUnavailable,
      );
    }
  }

  String _requiredScopeId(dynamic value) {
    if (value is! String || value.trim().isEmpty || value != value.trim()) {
      throw const ResidentDirectUpiException(
        ResidentDirectUpiFailure.scopeUnavailable,
      );
    }
    return value;
  }

  ResidentDirectUpiScope _validateScope(ResidentDirectUpiScope scope) {
    if (scope.uid.trim().isEmpty ||
        scope.communityId.trim().isEmpty ||
        scope.flatId.trim().isEmpty ||
        scope.uid != scope.uid.trim() ||
        scope.communityId != scope.communityId.trim() ||
        scope.flatId != scope.flatId.trim()) {
      throw const ResidentDirectUpiException(
        ResidentDirectUpiFailure.scopeUnavailable,
      );
    }
    return scope;
  }

  Future<ResidentDirectUpiDocument> _loadDocument({
    required String documentId,
    required ResidentDirectUpiDocumentLoader? loader,
    required String collection,
    required ResidentDirectUpiFailure failure,
  }) async {
    try {
      if (loader != null) return await loader(documentId);
      final snapshot = await (_firestore ?? FirebaseFirestore.instance)
          .collection(collection)
          .doc(documentId)
          .get(const GetOptions(source: Source.server));
      return ResidentDirectUpiDocument(
        exists: snapshot.exists,
        data: snapshot.data(),
      );
    } on ResidentDirectUpiException {
      rethrow;
    } catch (_) {
      throw ResidentDirectUpiException(failure);
    }
  }

  Map<String, dynamic> _requireBillForScope(
    ResidentDirectUpiDocument document,
    String billId,
    ResidentDirectUpiScope scope,
  ) {
    final bill = document.data;
    if (!document.exists || bill == null) {
      throw const ResidentDirectUpiException(
        ResidentDirectUpiFailure.billUnavailable,
      );
    }
    if (bill['communityId'] != scope.communityId ||
        bill['flatId'] != scope.flatId ||
        (bill.containsKey('residentId') && bill['residentId'] != scope.uid) ||
        (bill.containsKey('userId') && bill['userId'] != scope.uid)) {
      throw const ResidentDirectUpiException(
        ResidentDirectUpiFailure.billOwnershipMismatch,
      );
    }

    final status = bill['status'];
    final paidAmount = bill['paidAmount'];
    if ((status != 'pending' && status != 'overdue') ||
        bill['paymentId'] != null ||
        bill['paidAt'] != null ||
        (paidAmount != null && !(paidAmount is num && paidAmount == 0))) {
      throw const ResidentDirectUpiException(
        ResidentDirectUpiFailure.billSettled,
      );
    }

    final amount = bill['amount'];
    if (amount is! num ||
        !amount.isFinite ||
        amount <= 0 ||
        !_hasAtMostTwoDecimalPlaces(amount.toDouble())) {
      throw const ResidentDirectUpiException(
        ResidentDirectUpiFailure.billUnavailable,
      );
    }
    return bill;
  }

  CommunityPaymentConfig _parsePaymentConfig(
    ResidentDirectUpiDocument document,
    String communityId,
  ) {
    if (!document.exists) {
      return CommunityPaymentConfig.unconfigured(communityId);
    }
    final data = document.data;
    if (data == null) {
      throw const ResidentDirectUpiException(
        ResidentDirectUpiFailure.paymentConfigInvalid,
      );
    }
    try {
      return CommunityPaymentConfig.fromMap(communityId, data);
    } on FormatException {
      throw const ResidentDirectUpiException(
        ResidentDirectUpiFailure.paymentConfigInvalid,
      );
    } catch (_) {
      throw const ResidentDirectUpiException(
        ResidentDirectUpiFailure.paymentConfigInvalid,
      );
    }
  }
}

bool _hasAtMostTwoDecimalPlaces(double amount) {
  final normalized = double.tryParse(amount.toStringAsFixed(2));
  return normalized != null && normalized == amount;
}
