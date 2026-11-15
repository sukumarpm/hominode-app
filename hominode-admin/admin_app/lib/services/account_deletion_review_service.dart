import 'package:cloud_functions/cloud_functions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CommunityDeletionRequest {
  const CommunityDeletionRequest({
    required this.requestId,
    required this.financialReviewStatus,
    required this.reviewStatus,
    this.financialEvidence,
    this.status = 'unknown',
    this.residentName,
    this.residentPhone,
    this.residentUnit,
    this.residentProfileStatus = 'unverified_or_missing',
    this.reviewFinding,
    this.reviewNote,
    this.reviewedAt,
    this.unresolvedDependencies = const [],
    this.createdAt,
    this.reviewDueAt,
    this.completedAt,
    this.financialReviewRequired = false,
    this.communityId,
    this.communityName,
    this.residentType,
    this.sourceApp,
    this.verificationStatus,
    this.intakeDigest,
    this.assistedIntake,
  });

  final Map<String, dynamic>? financialEvidence;
  final String requestId;
  final String financialReviewStatus;
  final String reviewStatus;
  final String status;
  final String? residentName;
  final String? residentPhone;
  final String? residentUnit;
  final String residentProfileStatus;
  final String? reviewFinding;
  final String? reviewNote;
  final DateTime? reviewedAt;
  final List<String> unresolvedDependencies;
  final DateTime? createdAt;
  final DateTime? reviewDueAt;
  final DateTime? completedAt;
  final bool financialReviewRequired;
  final String? communityId;
  final String? communityName;
  final String? residentType;
  final String? sourceApp, verificationStatus, intakeDigest;
  final Map<String, dynamic>? assistedIntake;
  bool get canVerifyAssisted => sourceApp == 'admin_assisted' && status == 'pending_assisted_verification' && verificationStatus == 'pending' && RegExp(r'^[a-f0-9]{64}$').hasMatch(intakeDigest ?? '');

  factory CommunityDeletionRequest.fromMap(Map<dynamic, dynamic> map) {
    String? optionalString(dynamic value) => value is String ? value : null;
    DateTime? parseDate(dynamic value) {
      if (value is DateTime) return value;
      if (value is Timestamp) return value.toDate();
      if (value is String) return DateTime.tryParse(value);
      if (value is Map) {
        final seconds = value['seconds'] ?? value['_seconds'];
        final nanoseconds = value['nanoseconds'] ?? value['_nanoseconds'] ?? 0;
        if (seconds is num && nanoseconds is num) {
          return DateTime.fromMillisecondsSinceEpoch(
            seconds.toInt() * 1000 + nanoseconds.toInt() ~/ 1000000,
            isUtc: true,
          );
        }
      }
      return null;
    }

    return CommunityDeletionRequest(
      sourceApp: optionalString(map['sourceApp']),
      verificationStatus: optionalString(map['verificationStatus']),
      intakeDigest: optionalString(map['intakeDigest']),
      assistedIntake: map['assistedIntake'] is Map ? Map<String, dynamic>.from(map['assistedIntake'] as Map) : null,
      financialEvidence: map['financialEvidence'] is Map
          ? Map<String, dynamic>.from(map['financialEvidence'] as Map)
          : null,
      requestId: map['requestId'] is String ? map['requestId'] as String : '',
      financialReviewStatus: map['financialReviewStatus'] is String
          ? map['financialReviewStatus'] as String
          : 'UNKNOWN_REQUIRES_REVIEW',
      reviewStatus: map['reviewStatus'] is String
          ? map['reviewStatus'] as String
          : 'unknown',
      createdAt: parseDate(map['createdAt']),
      reviewDueAt: parseDate(map['reviewDueAt']),
      completedAt: parseDate(map['completedAt']),
      financialReviewRequired: map['financialReviewRequired'] == true,
      communityId: optionalString(map['communityId']),
      communityName: optionalString(map['communityName']),
      status: map['status'] is String ? map['status'] as String : 'unknown',
      residentName: optionalString(
        map['resident'] is Map ? (map['resident'] as Map)['displayName'] : null,
      ),
      residentPhone: optionalString(
        map['resident'] is Map ? (map['resident'] as Map)['phoneNumber'] : null,
      ),
      residentType: optionalString(
        map['resident'] is Map
            ? (map['resident'] as Map)['residentType']
            : null,
      ),
      residentUnit: optionalString(
        map['resident'] is Map ? (map['resident'] as Map)['unit'] : null,
      ),
      residentProfileStatus: map['residentProfileStatus'] is String
          ? map['residentProfileStatus'] as String
          : 'unverified_or_missing',
      reviewFinding: optionalString(map['reviewFinding']),
      reviewNote: optionalString(map['reviewNote']),
      reviewedAt: parseDate(map['reviewedAt']),
      unresolvedDependencies: map['unresolvedDependencies'] is List
          ? (map['unresolvedDependencies'] as List).whereType<String>().toList()
          : const [],
    );
  }
}

abstract interface class AccountDeletionReviewGateway {
  Future<List<CommunityDeletionRequest>> list(String communityId);
  Future<Map<String, dynamic>> reassess({required String requestId});
  Future<void> recordFinding({
    required String requestId,
    required String finding,
    required String note,
    String? evidenceDigest,
    bool retainFinancialRecords = false,
  });
}

class AccountDeletionReviewService implements AccountDeletionReviewGateway {
  AccountDeletionReviewService({FirebaseFunctions? functions})
    : _functions =
          functions ?? FirebaseFunctions.instanceFor(region: 'asia-southeast1');

  final FirebaseFunctions _functions;

  @override
  Future<List<CommunityDeletionRequest>> list(String communityId) async {
    final result = await _functions
        .httpsCallable('listCommunityAccountDeletionRequests')
        .call({'communityId': communityId});
    final data = result.data;
    if (data is! Map || data['requests'] is! List) {
      throw StateError('The account-deletion queue returned invalid data.');
    }
    return (data['requests'] as List)
        .whereType<Map>()
        .map(CommunityDeletionRequest.fromMap)
        .where((request) => request.requestId.isNotEmpty)
        .toList(growable: false);
  }

  @override
  Future<Map<String, dynamic>> reassess({required String requestId}) async {
    final result = await _functions
        .httpsCallable('reassessAccountDeletionRequest')
        .call({'requestId': requestId});
    if (result.data is! Map) {
      throw StateError('The deletion reassessment returned invalid data.');
    }
    return Map<String, dynamic>.from(result.data as Map);
  }

  @override
  Future<void> recordFinding({
    required String requestId,
    required String finding,
    required String note,
    String? evidenceDigest,
    bool retainFinancialRecords = false,
  }) async {
    await _functions.httpsCallable('recordAccountDeletionFinancialReview').call(
      {
        'requestId': requestId,
        'finding': finding,
        'note': note,
        if (finding == 'verified_handover') ...{
          'evidenceDigest': evidenceDigest,
          'retainFinancialRecords': retainFinancialRecords,
        },
      },
    );
  }
}
