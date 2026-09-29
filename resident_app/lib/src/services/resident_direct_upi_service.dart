import 'dart:math';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

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
  paymentProofAlreadyPending,
  paymentProofStatusUnavailable,
  billRevisionChanged,
  v2ProofSubmissionRequired,
  receiptInvalid,
  proofPreparationFailed,
  proofUploadFailed,
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
    ResidentDirectUpiFailure.paymentProofAlreadyPending =>
      'A payment proof for this bill is already awaiting administrator review.',
    ResidentDirectUpiFailure.billRevisionChanged =>
      'This bill has changed. Refresh it before submitting payment proof.',
    ResidentDirectUpiFailure.v2ProofSubmissionRequired =>
      'This bill requires the V2 payment proof flow.',
    ResidentDirectUpiFailure.receiptInvalid =>
      'Choose a supported receipt image smaller than 10 MB.',
    ResidentDirectUpiFailure.proofPreparationFailed =>
      'Payment proof preparation could not be confirmed. Retry the same attempt.',
    ResidentDirectUpiFailure.proofUploadFailed =>
      'Receipt upload could not be confirmed. Retry this attempt. Your payment has not been verified.',
    ResidentDirectUpiFailure.paymentProofStatusUnavailable =>
      'Payment proof status could not be checked. Please try again.',
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
typedef ResidentDirectUpiPaymentProofLoader =
    Future<List<Map<String, dynamic>>> Function({
      required String communityId,
      required String flatId,
      required String billId,
      required String userId,
    });

typedef ResidentDirectUpiV2ProofLoader =
    Future<List<Map<String, dynamic>>> Function({
      required String communityId,
      required String billId,
      required String residentId,
    });
typedef ResidentDirectUpiPrepareProof =
    Future<Map<String, dynamic>> Function(Map<String, dynamic> payload);
typedef ResidentDirectUpiReceiptUploader =
    Future<void> Function({
      required String receiptPath,
      required Uint8List bytes,
      required String contentType,
      required Map<String, String> customMetadata,
    });
typedef ResidentDirectUpiReceiptMetadataLoader =
    Future<Map<String, dynamic>?> Function(String receiptPath);

/// Retain this object for retries of the same intent, including ambiguous
/// callable/upload failures. Never create a new key just because upload failed.
class ResidentV2ProofSubmissionAttempt {
  ResidentV2ProofSubmissionAttempt._(
    this.preparation,
    this.idempotencyKey,
    this.receiptExtension,
    this.paymentReference,
    Uint8List bytes,
  ) : _bytes = Uint8List.fromList(bytes);
  final DirectUpiPaymentPreparation preparation;
  final String idempotencyKey;
  final String receiptExtension;
  final String? paymentReference;
  final Uint8List _bytes;
  bool _reservationRequested = false;
  Future<ResidentV2ProofSubmission>? _inFlight;
  ResidentV2ProofSubmission? _uploaded;
}

/// Confirms receipt upload only; settlement still requires Admin verification.
class ResidentV2ProofSubmission {
  const ResidentV2ProofSubmission({
    required this.paymentId,
    required this.receiptPath,
  });
  final String paymentId;
  final String receiptPath;
}

class DirectUpiPaymentPreparation {
  const DirectUpiPaymentPreparation({
    required this.billId,
    required this.communityId,
    required this.amount,
    required this.vpa,
    required this.payeeName,
    required this.paymentUri,
    this.schemaVersion,
    this.residentId,
    this.amountMinor,
    this.outstandingAmountMinor,
    this.currentRevisionId,
  });

  final String billId;
  final String communityId;
  final double amount;
  final String vpa;
  final String payeeName;
  final Uri paymentUri;
  final int? schemaVersion;
  final String? residentId;
  final int? amountMinor;
  final int? outstandingAmountMinor;
  final String? currentRevisionId;
  bool get isV2 => schemaVersion == 2;
}

class ResidentDirectUpiService {
  ResidentDirectUpiService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    ResidentDirectUpiScopeLoader? scopeLoader,
    ResidentDirectUpiDocumentLoader? billLoader,
    ResidentDirectUpiDocumentLoader? paymentConfigLoader,
    ResidentDirectUpiPaymentProofLoader? paymentProofLoader,
    ResidentDirectUpiV2ProofLoader? v2ProofLoader,
    ResidentDirectUpiPrepareProof? prepareProof,
    ResidentDirectUpiReceiptUploader? receiptUploader,
    ResidentDirectUpiReceiptMetadataLoader? receiptMetadataLoader,
    FirebaseFunctions? functions,
    FirebaseStorage? storage,
  }) : _auth = auth,
       _firestore = firestore,
       _scopeLoader = scopeLoader,
       _billLoader = billLoader,
       _paymentConfigLoader = paymentConfigLoader,
       _paymentProofLoader = paymentProofLoader,
       _v2ProofLoader = v2ProofLoader,
       _prepareProof = prepareProof,
       _receiptUploader = receiptUploader,
       _receiptMetadataLoader = receiptMetadataLoader,
       _functions = functions,
       _storage = storage;

  final FirebaseAuth? _auth;
  final FirebaseFirestore? _firestore;
  final ResidentDirectUpiScopeLoader? _scopeLoader;
  final ResidentDirectUpiDocumentLoader? _billLoader;
  final ResidentDirectUpiDocumentLoader? _paymentConfigLoader;
  final ResidentDirectUpiPaymentProofLoader? _paymentProofLoader;
  final ResidentDirectUpiV2ProofLoader? _v2ProofLoader;
  final ResidentDirectUpiPrepareProof? _prepareProof;
  final ResidentDirectUpiReceiptUploader? _receiptUploader;
  final ResidentDirectUpiReceiptMetadataLoader? _receiptMetadataLoader;
  final FirebaseFunctions? _functions;
  final FirebaseStorage? _storage;

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
    await _ensureNoPendingProof(scope, id, isV2: bill['schemaVersion'] == 2);

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

    final isV2 = bill['schemaVersion'] == 2;
    final outstanding = isV2 ? bill['outstandingAmountMinor'] as int : null;
    // The decimal double is compatibility display data only. URI/payload money
    // is derived from integer paise, without floating-point rounding.
    final amount = isV2
        ? outstanding! / 100
        : (bill['amount'] as num).toDouble();
    final amountText = isV2
        ? _inrText(outstanding!)
        : amount.toStringAsFixed(2);
    final vpa = config.directUpi.vpa!;
    final payeeName = config.directUpi.payeeName!;
    final paymentUri = Uri(
      scheme: 'upi',
      host: 'pay',
      queryParameters: {
        'pa': vpa,
        'pn': payeeName,
        'am': amountText,
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
      schemaVersion: isV2 ? 2 : null,
      residentId: isV2 ? scope.uid : null,
      amountMinor: isV2 ? bill['amountMinor'] as int : null,
      outstandingAmountMinor: outstanding,
      currentRevisionId: isV2 ? bill['currentRevisionId'] as String : null,
    );
  }

  /// Rechecks an authoritative bill and payment scope before proof upload.
  Future<void> ensureNoPendingProofForBill(String billId) async {
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
    final isV2 = bill['schemaVersion'] == 2;
    await _ensureNoPendingProof(scope, id, isV2: isV2);
    // The existing screen calls this guard before its V1 Firestore writer.
    // V2 must use submitV2PaymentProof, never that legacy writer.
    if (isV2) {
      throw const ResidentDirectUpiException(
        ResidentDirectUpiFailure.v2ProofSubmissionRequired,
      );
    }
  }

  Future<void> _ensureNoPendingProof(
    ResidentDirectUpiScope scope,
    String billId, {
    bool isV2 = false,
  }) async {
    try {
      if (isV2) {
        final loader = _v2ProofLoader;
        final proofs = loader != null
            ? await loader(
                communityId: scope.communityId,
                billId: billId,
                residentId: scope.uid,
              )
            : (await (_firestore ?? FirebaseFirestore.instance)
                      .collection('paymentProofsV2')
                      .where('communityId', isEqualTo: scope.communityId)
                      .where('residentId', isEqualTo: scope.uid)
                      .where('billId', isEqualTo: billId)
                      .get(const GetOptions(source: Source.server)))
                  .docs
                  .map((doc) => doc.data())
                  .toList();
        if (proofs.any(
          (proof) =>
              proof['communityId'] == scope.communityId &&
              proof['residentId'] == scope.uid &&
              proof['billId'] == billId &&
              proof['status'] == 'pending',
        )) {
          throw const ResidentDirectUpiException(
            ResidentDirectUpiFailure.paymentProofAlreadyPending,
          );
        }
        return;
      }
      final loader = _paymentProofLoader;
      final proofs = loader != null
          ? await loader(
              communityId: scope.communityId,
              flatId: scope.flatId,
              billId: billId,
              userId: scope.uid,
            )
          : (await (_firestore ?? FirebaseFirestore.instance)
                    .collection('payments')
                    .where('communityId', isEqualTo: scope.communityId)
                    .where('flatId', isEqualTo: scope.flatId)
                    .where('billId', isEqualTo: billId)
                    .where('userId', isEqualTo: scope.uid)
                    .get(const GetOptions(source: Source.server)))
                .docs
                .map((document) => document.data())
                .toList();

      final hasPendingProof = proofs.any(
        (proof) =>
            proof['communityId'] == scope.communityId &&
            proof['flatId'] == scope.flatId &&
            proof['billId'] == billId &&
            proof['userId'] == scope.uid &&
            proof['status'] == 'pending',
      );
      if (hasPendingProof) {
        throw const ResidentDirectUpiException(
          ResidentDirectUpiFailure.paymentProofAlreadyPending,
        );
      }
    } on ResidentDirectUpiException {
      rethrow;
    } catch (_) {
      throw const ResidentDirectUpiException(
        ResidentDirectUpiFailure.paymentProofStatusUnavailable,
      );
    }
  }

  ResidentV2ProofSubmissionAttempt createV2ProofSubmissionAttempt({
    required DirectUpiPaymentPreparation preparation,
    required Uint8List receiptBytes,
    required String receiptExtension,
    String? paymentReference,
  }) {
    if (!preparation.isV2 ||
        !_safeMinor(preparation.outstandingAmountMinor) ||
        preparation.outstandingAmountMinor == 0 ||
        !_validId(preparation.currentRevisionId) ||
        !_validId(preparation.residentId) ||
        !_validId(preparation.communityId) ||
        !_validId(preparation.billId)) {
      throw const ResidentDirectUpiException(
        ResidentDirectUpiFailure.billUnavailable,
      );
    }
    final reference = paymentReference?.trim();
    if (!['jpg', 'jpeg', 'png', 'heic', 'heif'].contains(receiptExtension) ||
        receiptBytes.isEmpty ||
        receiptBytes.length >= 10 * 1024 * 1024 ||
        (reference != null && reference.length > 200)) {
      throw const ResidentDirectUpiException(
        ResidentDirectUpiFailure.receiptInvalid,
      );
    }
    final random = Random.secure();
    final key = List.generate(
      24,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    return ResidentV2ProofSubmissionAttempt._(
      preparation,
      key,
      receiptExtension,
      reference == null || reference.isEmpty ? null : reference,
      receiptBytes,
    );
  }

  Future<ResidentV2ProofSubmission> submitV2PaymentProof(
    ResidentV2ProofSubmissionAttempt attempt,
  ) {
    return attempt._inFlight ??= _submitV2PaymentProof(
      attempt,
    ).whenComplete(() => attempt._inFlight = null);
  }

  Future<ResidentV2ProofSubmission> _submitV2PaymentProof(
    ResidentV2ProofSubmissionAttempt attempt,
  ) async {
    final preparation = attempt.preparation;
    final scope = await _loadScope();
    if (scope.uid != preparation.residentId ||
        scope.communityId != preparation.communityId) {
      throw const ResidentDirectUpiException(
        ResidentDirectUpiFailure.billOwnershipMismatch,
      );
    }
    if (attempt._uploaded != null) return attempt._uploaded!;
    if (!attempt._reservationRequested) {
      // Refresh terms, pending proofs and community UPI settings immediately
      // before reserving. Once requested, retain the original submitted intent
      // on retry: the backend may already have created its pending proof.
      final fresh = await preparePayment(preparation.billId);
      if (!fresh.isV2 ||
          fresh.residentId != preparation.residentId ||
          fresh.communityId != preparation.communityId ||
          fresh.currentRevisionId != preparation.currentRevisionId ||
          fresh.outstandingAmountMinor != preparation.outstandingAmountMinor ||
          fresh.amountMinor != preparation.amountMinor ||
          fresh.vpa != preparation.vpa ||
          fresh.payeeName != preparation.payeeName) {
        throw const ResidentDirectUpiException(
          ResidentDirectUpiFailure.billRevisionChanged,
        );
      }
    }
    final payload = <String, dynamic>{
      'billId': preparation.billId,
      'submittedAmountMinor': preparation.outstandingAmountMinor,
      'submittedBillRevisionId': preparation.currentRevisionId,
      'idempotencyKey': attempt.idempotencyKey,
      'receiptExtension': attempt.receiptExtension,
      'paymentReference': attempt.paymentReference,
    };
    Map<String, dynamic> response;
    attempt._reservationRequested = true;
    try {
      final call = _prepareProof;
      if (call != null) {
        response = await call(payload);
      } else {
        final functions =
            _functions ??
            FirebaseFunctions.instanceFor(region: 'asia-southeast1');
        final result = await functions
            .httpsCallable('preparePaymentProofV2')
            .call<dynamic>(payload);
        response = Map<String, dynamic>.from(result.data as Map);
      }
    } catch (_) {
      throw const ResidentDirectUpiException(
        ResidentDirectUpiFailure.proofPreparationFailed,
      );
    }
    final paymentId = response['paymentId'],
        receiptPath = response['receiptPath'];
    if (!_validId(paymentId) ||
        response['status'] != 'pending' ||
        receiptPath !=
            'payment_receipts/${preparation.communityId}/${preparation.billId}/${scope.uid}/$paymentId.${attempt.receiptExtension}') {
      throw const ResidentDirectUpiException(
        ResidentDirectUpiFailure.proofPreparationFailed,
      );
    }
    final customMetadata = <String, String>{
      'paymentId': paymentId as String,
      'billId': preparation.billId,
      'communityId': preparation.communityId,
      'residentUid': scope.uid,
    };
    final contentType = ['jpg', 'jpeg'].contains(attempt.receiptExtension)
        ? 'image/jpeg'
        : 'image/${attempt.receiptExtension}';
    await _uploadReceipt(
      receiptPath: receiptPath as String,
      bytes: attempt._bytes,
      contentType: contentType,
      customMetadata: customMetadata,
    );
    return attempt._uploaded = ResidentV2ProofSubmission(
      paymentId: paymentId,
      receiptPath: receiptPath,
    );
  }

  /// Completes a proof whose backend reservation survived an app restart.
  /// It reuses the proof's server-authored receiptPath and never prepares a
  /// second proof. Existing matching evidence is treated as an already-finished
  /// upload, making retries safe after an ambiguous client failure.
  Future<ResidentV2ProofSubmission> resumeV2PaymentProofUpload({
    required Map<String, dynamic> proof,
    required Uint8List receiptBytes,
    required String receiptExtension,
  }) async {
    final scope = await _loadScope();
    final context = _existingProofContext(proof, scope);
    final paymentId = context.paymentId;
    final receiptPath = context.receiptPath;
    if (!['jpg', 'jpeg', 'png', 'heic', 'heif'].contains(receiptExtension) ||
        receiptBytes.isEmpty ||
        receiptBytes.length >= 10 * 1024 * 1024) {
      throw const ResidentDirectUpiException(
        ResidentDirectUpiFailure.receiptInvalid,
      );
    }

    final existing = await _readExistingReceipt(receiptPath);
    if (existing != null) {
      _requireMatchingReceipt(existing, context);
      return ResidentV2ProofSubmission(
        paymentId: paymentId,
        receiptPath: receiptPath,
      );
    }

    final contentType = ['jpg', 'jpeg'].contains(receiptExtension)
        ? 'image/jpeg'
        : 'image/$receiptExtension';
    await _uploadReceipt(
      receiptPath: receiptPath,
      bytes: receiptBytes,
      contentType: contentType,
      customMetadata: context.customMetadata,
    );
    return ResidentV2ProofSubmission(
      paymentId: paymentId,
      receiptPath: receiptPath,
    );
  }

  /// Used on the restart recovery screen to avoid asking for a duplicate
  /// receipt when the existing pending proof already has its evidence object.
  Future<bool> isV2ProofReceiptUploaded(Map<String, dynamic> proof) async {
    final scope = await _loadScope();
    final context = _existingProofContext(proof, scope);
    final existing = await _readExistingReceipt(context.receiptPath);
    if (existing == null) return false;
    _requireMatchingReceipt(existing, context);
    return true;
  }

  ({
    String paymentId,
    String billId,
    String receiptPath,
    Map<String, String> customMetadata,
  })
  _existingProofContext(
    Map<String, dynamic> proof,
    ResidentDirectUpiScope scope,
  ) {
    final paymentId = proof['id'];
    final billId = proof['billId'];
    final receiptPath = proof['receiptPath'];
    if (proof['schemaVersion'] != 2 ||
        proof['status'] != 'pending' ||
        !_validId(paymentId) ||
        !_validId(billId) ||
        proof['communityId'] != scope.communityId ||
        proof['residentId'] != scope.uid ||
        proof['userId'] != scope.uid ||
        !_safeMinor(proof['submittedAmountMinor']) ||
        proof['submittedAmountMinor'] == 0 ||
        !_validId(proof['submittedBillRevisionId']) ||
        receiptPath is! String ||
        !_validProofReceiptPath(
          receiptPath,
          communityId: scope.communityId,
          billId: billId as String,
          residentId: scope.uid,
          paymentId: paymentId as String,
        )) {
      throw const ResidentDirectUpiException(
        ResidentDirectUpiFailure.proofPreparationFailed,
      );
    }
    return (
      paymentId: paymentId,
      billId: billId,
      receiptPath: receiptPath,
      customMetadata: {
        'paymentId': paymentId,
        'billId': billId,
        'communityId': scope.communityId,
        'residentUid': scope.uid,
      },
    );
  }

  void _requireMatchingReceipt(
    Map<String, dynamic> existing,
    ({
      String paymentId,
      String billId,
      String receiptPath,
      Map<String, String> customMetadata,
    })
    context,
  ) {
    final metadata = existing['customMetadata'];
    final custom = metadata is Map ? metadata : const <String, dynamic>{};
    final size = int.tryParse(existing['size']?.toString() ?? '');
    final contentType = existing['contentType']?.toString() ?? '';
    if ((existing['fullPath'] ?? existing['name']) != context.receiptPath ||
        size == null ||
        size <= 0 ||
        size >= 10 * 1024 * 1024 ||
        !RegExp(r'^image/(jpeg|jpg|png|heic|heif)$').hasMatch(contentType) ||
        context.customMetadata.entries.any(
          (entry) => custom[entry.key] != entry.value,
        )) {
      throw const ResidentDirectUpiException(
        ResidentDirectUpiFailure.proofUploadFailed,
      );
    }
  }

  Future<Map<String, dynamic>?> _readExistingReceipt(String receiptPath) async {
    try {
      final loader = _receiptMetadataLoader;
      if (loader != null) return await loader(receiptPath);
      final metadata = await (_storage ?? FirebaseStorage.instance)
          .ref(receiptPath)
          .getMetadata();
      return {
        'fullPath': metadata.fullPath,
        'size': metadata.size,
        'contentType': metadata.contentType,
        'customMetadata': metadata.customMetadata,
      };
    } on FirebaseException catch (error) {
      if (error.code == 'object-not-found' || error.code == 'not-found') {
        return null;
      }
      throw const ResidentDirectUpiException(
        ResidentDirectUpiFailure.proofUploadFailed,
      );
    } catch (_) {
      throw const ResidentDirectUpiException(
        ResidentDirectUpiFailure.proofUploadFailed,
      );
    }
  }

  Future<void> _uploadReceipt({
    required String receiptPath,
    required Uint8List bytes,
    required String contentType,
    required Map<String, String> customMetadata,
  }) async {
    try {
      final upload = _receiptUploader;
      if (upload != null) {
        await upload(
          receiptPath: receiptPath,
          bytes: Uint8List.fromList(bytes),
          contentType: contentType,
          customMetadata: customMetadata,
        );
      } else {
        await (_storage ?? FirebaseStorage.instance)
            .ref(receiptPath)
            .putData(
              bytes,
              SettableMetadata(
                contentType: contentType,
                customMetadata: customMetadata,
              ),
            );
      }
    } catch (_) {
      // Keep the reservation intact so the same proof can be resumed safely.
      throw const ResidentDirectUpiException(
        ResidentDirectUpiFailure.proofUploadFailed,
      );
    }
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
    if (bill['schemaVersion'] == 2) {
      if (bill['communityId'] != scope.communityId ||
          bill['residentId'] != scope.uid ||
          (bill.containsKey('userId') && bill['userId'] != scope.uid)) {
        throw const ResidentDirectUpiException(
          ResidentDirectUpiFailure.billOwnershipMismatch,
        );
      }
      if (!_validId(bill['currentRevisionId'])) {
        throw const ResidentDirectUpiException(
          ResidentDirectUpiFailure.billRevisionChanged,
        );
      }
      final total = bill['amountMinor'],
          outstanding = bill['outstandingAmountMinor'];
      if (bill['currency'] != 'INR' ||
          !_safeMinor(total) ||
          total <= 0 ||
          !_safeMinor(outstanding) ||
          outstanding > total) {
        throw const ResidentDirectUpiException(
          ResidentDirectUpiFailure.billUnavailable,
        );
      }
      if (outstanding == 0 ||
          !['pending', 'overdue', 'partially_paid'].contains(bill['status'])) {
        throw const ResidentDirectUpiException(
          ResidentDirectUpiFailure.billSettled,
        );
      }
      return bill;
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

// Match the backend's safe integer money range. Never round malformed paise.
bool _safeMinor(dynamic value) =>
    value is int && value >= 0 && value <= 9007199254740991;
String _inrText(int paise) =>
    '${paise ~/ 100}.${(paise % 100).toString().padLeft(2, '0')}';
bool _validId(dynamic value) =>
    value is String &&
    value.isNotEmpty &&
    value == value.trim() &&
    value.length <= 128 &&
    !value.contains(RegExp(r'[/\x00-\x1f\x7f]')) &&
    value != '.' &&
    value != '..' &&
    !RegExp(r'^__.*__$').hasMatch(value);
bool _validProofReceiptPath(
  String path, {
  required String communityId,
  required String billId,
  required String residentId,
  required String paymentId,
}) {
  final prefix = 'payment_receipts/$communityId/$billId/$residentId/$paymentId';
  return [
    'jpg',
    'jpeg',
    'png',
    'heic',
    'heif',
  ].any((extension) => path == '$prefix.$extension');
}
