class BuildingDeletionCheck {
  const BuildingDeletionCheck({
    required this.canDelete,
    required this.buildingName,
    required this.unitCount,
    this.reasons = const [],
    this.conflictCount = 0,
  });

  final bool canDelete;
  final String buildingName;
  final int unitCount;
  final List<String> reasons;
  final int conflictCount;

  factory BuildingDeletionCheck.fromMap(Map<String, dynamic> data) =>
      BuildingDeletionCheck(
        canDelete: data['canDelete'] == true,
        buildingName: data['buildingName'] as String,
        unitCount: (data['unitCount'] as num).toInt(),
        reasons: List<String>.from(data['reasons'] as List? ?? const []),
        conflictCount: (data['conflictCount'] as num? ?? 0).toInt(),
      );
}
