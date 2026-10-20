import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resident_app/src/models/event_model.dart';

// Isolated read-only DTO fixture; no replacement Firestore implementation ships.
// ignore: subtype_of_sealed_class
class _Event extends Fake implements DocumentSnapshot<Map<String, dynamic>> {
  _Event(this.value);
  final Map<String, dynamic> value;
  @override
  String get id => 'event';
  @override
  Map<String, dynamic> data() => value;
}

void main() {
  const first =
      'https://firebasestorage.googleapis.com/v0/b/demo/o/event_images%2FA%2Fevent%2Fone.jpg?alt=media';
  const second =
      'https://firebasestorage.googleapis.com/v0/b/demo/o/event_images%2FA%2Fevent%2Ftwo.jpg?alt=media';
  test(
    'Admin event URL contract is read in order without needing a device file',
    () {
      final model = EventModel.fromFirestore(
        _Event({
          'communityId': 'A',
          'type': 'event',
          'title': 'Gathering',
          'date': Timestamp.fromDate(DateTime(2026, 11, 1)),
          'imageUrl': first,
          'imageUrls': [first, second],
          'images': [
            {
              'url': first,
              'storagePath': 'event_images/A/event/one.jpg',
              'name': 'one.jpg',
            },
            {
              'url': second,
              'storagePath': 'event_images/A/event/two.jpg',
              'name': 'two.jpg',
            },
          ],
        }),
      );
      expect(model.imageUrls, [first, second]);
      expect(model.imageUrl, first);
      expect(model.eventDate, DateTime(2026, 11, 1));
    },
  );
  test('Web gallery objects and historical primary URLs remain readable', () {
    expect(
      EventModel.fromFirestore(
        _Event({
          'images': [
            {'url': first},
            {'url': second},
          ],
        }),
      ).imageUrls,
      [first, second],
    );
    const legacy = 'https://res.cloudinary.com/example/image/upload/legacy.jpg';
    expect(EventModel.fromFirestore(_Event({'imageUrl': legacy})).imageUrls, [
      legacy,
    ]);
  });
  test(
    'old local device paths alone do not become Resident image references',
    () {
      expect(
        EventModel.fromFirestore(
          _Event({'localImagePath': '/another-device/photo.jpg'}),
        ).imageUrls,
        isEmpty,
      );
    },
  );
}
