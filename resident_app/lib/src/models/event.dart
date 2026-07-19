// lib/src/models/event.dart
// Event model with JSON serialization

class Event {
  final String id;
  final String title;
  final String description;
  final String imageUrl;
  final DateTime date;
  final String startTime;
  final String endTime;
  final String location;
  int attendees;
  final int capacity;
  final bool isPast;
  bool isAttending;

  Event({
    required this.id,
    required this.title,
    required this.description,
    required this.imageUrl,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.location,
    required this.attendees,
    required this.capacity,
    this.isPast = false,
    this.isAttending = false,
  });

  factory Event.fromJson(Map<String, dynamic> json) {
    return Event(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      imageUrl: json['imageUrl'] as String,
      date: DateTime.parse(json['date'] as String),
      startTime: json['startTime'] as String,
      endTime: json['endTime'] as String,
      location: json['location'] as String,
      attendees: json['attendees'] as int,
      capacity: json['capacity'] as int,
      isPast: json['isPast'] as bool? ?? false,
      isAttending: json['isAttending'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'imageUrl': imageUrl,
      'date': date.toIso8601String(),
      'startTime': startTime,
      'endTime': endTime,
      'location': location,
      'attendees': attendees,
      'capacity': capacity,
      'isPast': isPast,
      'isAttending': isAttending,
    };
  }

  String get formattedDate {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  String get timeRange => '$startTime - $endTime';
}
