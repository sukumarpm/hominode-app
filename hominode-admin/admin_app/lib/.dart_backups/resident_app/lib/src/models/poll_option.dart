// lib/src/models/poll_option.dart
// Poll option model

class PollOption {
  final String id;
  final String label;
  int votes;

  PollOption({
    required this.id,
    required this.label,
    required this.votes,
  });

  factory PollOption.fromJson(Map<String, dynamic> json) {
    return PollOption(
      id: json['id'] as String,
      label: json['label'] as String,
      votes: json['votes'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'label': label,
      'votes': votes,
    };
  }

  PollOption copyWith({String? id, String? label, int? votes}) {
    return PollOption(
      id: id ?? this.id,
      label: label ?? this.label,
      votes: votes ?? this.votes,
    );
  }
}
