typedef ResidentDashboardSecondaryData = ({
  String organizationName,
  List<Map<String, dynamic>> bills,
  List<Map<String, dynamic>> visitors,
});

/// Loads dashboard data that is independent once the resident profile is read.
/// Community lookup remains best-effort; bill and visitor failures still reach
/// the dashboard's existing outer error handler.
Future<ResidentDashboardSecondaryData> loadResidentDashboardSecondaryData({
  required String? communityId,
  required String initialOrganizationName,
  required Future<String?> Function(String communityId) loadCommunityName,
  required Future<List<Map<String, dynamic>>> Function() loadBills,
  required Future<List<Map<String, dynamic>>> Function() loadVisitors,
  void Function(Object error)? onCommunityLookupError,
}) async {
  var organizationName = initialOrganizationName;
  late List<Map<String, dynamic>> bills;
  late List<Map<String, dynamic>> visitors;
  final normalizedCommunityId = communityId?.trim();

  await Future.wait<void>([
    (() async {
      if (normalizedCommunityId == null || normalizedCommunityId.isEmpty) {
        return;
      }
      try {
        final name = await loadCommunityName(normalizedCommunityId);
        if (name?.trim().isNotEmpty == true) organizationName = name!.trim();
      } catch (error) {
        onCommunityLookupError?.call(error);
      }
    })(),
    (() async {
      bills = await loadBills();
    })(),
    (() async {
      visitors = await loadVisitors();
    })(),
  ]);

  return (organizationName: organizationName, bills: bills, visitors: visitors);
}
