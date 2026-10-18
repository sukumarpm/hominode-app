/// Display compatibility only. Authentication always requires canonical phoneNumber.
String residentDisplayPhone(Map<String, dynamic>? data) {
  final canonical = data?['phoneNumber'];
  if (canonical is String && canonical.isNotEmpty) return canonical;
  final legacy = data?['phone'];
  return legacy is String ? legacy : '';
}
