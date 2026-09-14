/// Additive domain types. Firestore `flats/{documentId}` remains canonical.
enum HousingUnitType {
  apartment('apartment', 'Apartment'),
  villa('villa', 'Villa'),
  rowHouse('row_house', 'Row House'),
  duplex('duplex', 'Duplex'),
  townhouse('townhouse', 'Townhouse'),
  other('other', 'Other');

  const HousingUnitType(this.value, this.label);
  final String value;
  final String label;
  static HousingUnitType fromValue(Object? value) => values.firstWhere(
    (type) => type.value == value,
    orElse: () => value == null ? apartment : other,
  );
}

enum HousingStructureType {
  apartmentBuilding(
    'apartment_building',
    'Apartment Building',
    HousingUnitType.apartment,
  ),
  villaCluster('villa_cluster', 'Villa Cluster', HousingUnitType.villa),
  rowHouseCluster(
    'row_house_cluster',
    'Row House Cluster',
    HousingUnitType.rowHouse,
  ),
  townhouseCluster(
    'townhouse_cluster',
    'Townhouse Cluster',
    HousingUnitType.townhouse,
  ),
  mixed('mixed', 'Mixed', HousingUnitType.other),
  other('other', 'Other', HousingUnitType.other);

  const HousingStructureType(this.value, this.label, this.defaultUnitType);
  final String value;
  final String label;
  final HousingUnitType defaultUnitType;
  bool get usesFloors => this == apartmentBuilding;
  String get countLabel => switch (this) {
    villaCluster => 'Number of Villas',
    rowHouseCluster => 'Number of Row Houses',
    townhouseCluster => 'Number of Townhouses',
    _ => 'Number of Units',
  };
  static HousingStructureType fromValue(Object? value) => values.firstWhere(
    (type) => type.value == value,
    orElse: () => value == null ? apartmentBuilding : other,
  );
}

String visibleUnitLabel(Map<String, dynamic> data, String documentId) {
  for (final key in ['flatLabel', 'flatId', 'unitId']) {
    final value = data[key];
    if (value is String && value.trim().isNotEmpty) return value.trim();
  }
  return documentId;
}
