class FamilyMember {
  final String id;
  final String name;
  final String relation;
  final int age;
  final String? photoUrl;
  final bool isPrimary;

  FamilyMember({
    required this.id,
    required this.name,
    required this.relation,
    required this.age,
    this.photoUrl,
    this.isPrimary = false,
  });

  FamilyMember copyWith({
    String? id,
    String? name,
    String? relation,
    int? age,
    String? photoUrl,
    bool? isPrimary,
  }) {
    return FamilyMember(
      id: id ?? this.id,
      name: name ?? this.name,
      relation: relation ?? this.relation,
      age: age ?? this.age,
      photoUrl: photoUrl ?? this.photoUrl,
      isPrimary: isPrimary ?? this.isPrimary,
    );
  }

  /// Convert to JSON for API calls
  /// TODO: Replace with actual backend API integration
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'relation': relation,
      'age': age,
      'photoUrl': photoUrl,
      'isPrimary': isPrimary,
    };
  }

  /// Create from JSON response
  /// TODO: Adjust fields based on actual backend response
  factory FamilyMember.fromJson(Map<String, dynamic> json) {
    return FamilyMember(
      id: json['id'] as String,
      name: json['name'] as String,
      relation: json['relation'] as String,
      age: json['age'] as int,
      photoUrl: json['photoUrl'] as String?,
      isPrimary: json['isPrimary'] as bool? ?? false,
    );
  }

  static List<FamilyMember> mockList() {
    return [
      FamilyMember(
        id: '1',
        name: 'Rahul Kumar',
        relation: 'Self',
        age: 35,
        isPrimary: true,
      ),
      FamilyMember(
        id: '2',
        name: 'Priya Kumar',
        relation: 'Spouse',
        age: 32,
      ),
      FamilyMember(
        id: '3',
        name: 'Aarav Kumar',
        relation: 'Son',
        age: 8,
      ),
    ];
  }
}
