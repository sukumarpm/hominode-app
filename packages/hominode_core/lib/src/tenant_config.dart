class TenantConfig {
  const TenantConfig({
    required this.communityId,
    required this.name,
    required this.slug,
    required this.websitePath,
    required this.databaseId,
    required this.isActive,
    this.logoUrl,
    required this.brandName,
    this.primaryColor,
  });
  static const defaultDatabaseId = '(default)';
  final String communityId;
  final String name;
  final String slug;
  final String websitePath;
  final String databaseId;
  final bool isActive;
  final String? logoUrl;
  final String brandName;
  final String? primaryColor;

  factory TenantConfig.fromMap(String documentId, Map<String, dynamic> data) {
    final name = _string(data['name']);
    final slug = _string(data['slug']);
    final websitePath = _string(data['websitePath']);
    final databaseId = _string(data['databaseId']);
    final brandName = _string(data['brandName']);
    return TenantConfig(
      communityId: documentId,
      name: name,
      slug: slug,
      websitePath: websitePath.isEmpty ? slug : websitePath,
      databaseId: databaseId.isEmpty ? defaultDatabaseId : databaseId,
      isActive: data['isActive'] == true,
      logoUrl: _nullableString(data['logoUrl']),
      brandName: brandName.isEmpty ? name : brandName,
      primaryColor: _nullableString(data['primaryColor']),
    );
  }

  static String slugify(String value) => value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
}

String _string(Object? value) => value is String ? value.trim() : '';
String? _nullableString(Object? value) {
  final parsed = _string(value);
  return parsed.isEmpty ? null : parsed;
}
