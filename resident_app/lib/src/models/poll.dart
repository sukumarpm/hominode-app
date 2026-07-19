// lib/src/models/poll.dart
// Data models for Poll feature with JSON serialization

import 'poll_option.dart';

/// Poll status enum
enum PollStatus { open, closed }

/// Represents a complete poll with question, options, and metadata
class Poll {
  final String id;
  final String question;
  final List<PollOption> options;
  final int totalVotes;
  final String? userVotedOptionId; // null if user hasn't voted
  final PollStatus status;
  final DateTime createdAt;
  final DateTime? expiresAt;

  Poll({
    required this.id,
    required this.question,
    required this.options,
    required this.totalVotes,
    this.userVotedOptionId,
    required this.status,
    required this.createdAt,
    this.expiresAt,
  });

  factory Poll.fromJson(Map<String, dynamic> json) {
    return Poll(
      id: json['id'] as String,
      question: json['question'] as String,
      options: (json['options'] as List)
          .map((opt) => PollOption.fromJson(opt as Map<String, dynamic>))
          .toList(),
      totalVotes: json['totalVotes'] as int? ?? 0,
      userVotedOptionId: json['userVotedOptionId'] as String?,
      status: json['status'] == 'closed' ? PollStatus.closed : PollStatus.open,
      createdAt: DateTime.parse(json['createdAt'] as String),
      expiresAt: json['expiresAt'] != null
          ? DateTime.parse(json['expiresAt'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'question': question,
      'options': options.map((opt) => opt.toJson()).toList(),
      'totalVotes': totalVotes,
      'userVotedOptionId': userVotedOptionId,
      'status': status == PollStatus.closed ? 'closed' : 'open',
      'createdAt': createdAt.toIso8601String(),
      'expiresAt': expiresAt?.toIso8601String(),
    };
  }

  Poll copyWith({
    String? id,
    String? question,
    List<PollOption>? options,
    int? totalVotes,
    String? userVotedOptionId,
    PollStatus? status,
    DateTime? createdAt,
    DateTime? expiresAt,
  }) {
    return Poll(
      id: id ?? this.id,
      question: question ?? this.question,
      options: options ?? this.options,
      totalVotes: totalVotes ?? this.totalVotes,
      userVotedOptionId: userVotedOptionId ?? this.userVotedOptionId,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
    );
  }

  /// Check if poll is closed (by status or expiry)
  bool get isClosed {
    if (status == PollStatus.closed) return true;
    if (expiresAt != null && DateTime.now().isAfter(expiresAt!)) return true;
    return false;
  }

  /// Check if user has voted
  bool get hasUserVoted => userVotedOptionId != null;
}

/// Event for realtime poll updates
class PollEvent {
  final String type; // 'vote', 'close', 'update'
  final String pollId;
  final String? optionId;
  final Map<String, int>? counts; // optionId -> vote count

  PollEvent({
    required this.type,
    required this.pollId,
    this.optionId,
    this.counts,
  });

  factory PollEvent.fromJson(Map<String, dynamic> json) {
    return PollEvent(
      type: json['type'] as String,
      pollId: json['pollId'] as String,
      optionId: json['optionId'] as String?,
      counts: json['counts'] != null
          ? Map<String, int>.from(json['counts'] as Map)
          : null,
    );
  }
}

/// Utility functions for poll calculations (unit-test friendly)

/// Calculate percentage for an option (0-100)
double calculatePercent(int votes, int total) {
  if (total == 0) return 0.0;
  return (votes / total) * 100;
}

/// Format percentage as string with 0 decimals
String formatPercent(double percent) {
  return '${percent.round()}%';
}
