// lib/src/models/user_profile_model.dart
// User profile data model

class UserProfile {
  final String id;
  final String fullName;
  final String phone;
  final String? email;
  final String apartment;
  final String? avatarUrl;

  UserProfile({
    required this.id,
    required this.fullName,
    required this.phone,
    this.email,
    required this.apartment,
    this.avatarUrl,
  });

  UserProfile copyWith({
    String? id,
    String? fullName,
    String? phone,
    String? email,
    String? apartment,
    String? avatarUrl,
  }) {
    return UserProfile(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      apartment: apartment ?? this.apartment,
      avatarUrl: avatarUrl ?? this.avatarUrl,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fullName': fullName,
      'phone': phone,
      'email': email,
      'apartment': apartment,
      'avatarUrl': avatarUrl,
    };
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      fullName: json['fullName'] as String,
      phone: json['phone'] as String,
      email: json['email'] as String?,
      apartment: json['apartment'] as String,
      avatarUrl: json['avatarUrl'] as String?,
    );
  }

  // Mock data for testing
  static UserProfile mock() {
    return UserProfile(
      id: '1',
      fullName: 'Rahul Kumar',
      phone: '+91 98765 43210',
      email: 'rahul.kumar@example.com',
      apartment: 'Block A, Flat 301',
      avatarUrl: null,
    );
  }
}
