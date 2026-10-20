import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resident_app/src/services/post_firestore_service.dart';

void main() {
  Map<String, dynamic>? update({
    String uid = 'resident',
    bool liked = true,
    Map<String, dynamic>? post,
    String community = 'A',
  }) => buildCommunityWallLikeUpdate(
    residentId: uid,
    post: post ?? {'communityId': 'A', 'likes': 0, 'likedBy': <String>[]},
    profile: {'communityId': community},
    liked: liked,
  );

  test('like writes only the current UID, exact count and server time', () {
    final data = update()!;
    expect(data.keys.toSet(), {'likes', 'likedBy', 'updatedAt'});
    expect(data['likedBy'], FieldValue.arrayUnion(['resident']));
    expect(data['likes'], FieldValue.increment(1));
    expect(data['updatedAt'], isA<FieldValue>());
  });
  test('unlike preserves other residents and decrements once', () {
    final data = update(
      liked: false,
      post: {
        'communityId': 'A',
        'likes': 2,
        'likedBy': ['other', 'resident'],
      },
    )!;
    expect(data['likedBy'], FieldValue.arrayRemove(['resident']));
    expect(data['likes'], FieldValue.increment(-1));
  });
  test('duplicate like and unlike are no-ops', () {
    expect(update(liked: false), isNull);
    expect(
      update(
        post: {
          'communityId': 'A',
          'likes': 1,
          'likedBy': ['resident'],
        },
      ),
      isNull,
    );
  });
  test('retry emits only the current UID transform and preserves peers', () {
    final retried = update(
      post: {
        'communityId': 'A',
        'likes': 1,
        'likedBy': ['other'],
      },
    )!;
    expect(retried['likedBy'], FieldValue.arrayUnion(['resident']));
    expect(retried['likes'], FieldValue.increment(1));
    expect(
      update(
        post: {
          'communityId': 'A',
          'likes': 2,
          'likedBy': ['other', 'resident'],
        },
      ),
      isNull,
    );
  });
  test(
    'legacy missing reaction fields initialize without mutating the input',
    () {
      final post = <String, dynamic>{'communityId': 'A'};
      expect(update(post: post)!['likes'], FieldValue.increment(1));
      expect(post, {'communityId': 'A'});
    },
  );
  test('rejects wrong community, missing identity and inactive post', () {
    expect(() => update(community: 'B'), throwsStateError);
    expect(() => update(uid: ''), throwsStateError);
    expect(
      () => update(post: {'communityId': 'A', 'status': 'deleted'}),
      throwsStateError,
    );
    expect(() => update(post: {'likes': 0}), throwsStateError);
  });
  test('rejects missing profile and parent post', () {
    for (final missingPost in [true, false]) {
      expect(
        () => buildCommunityWallLikeUpdate(
          residentId: 'resident',
          liked: true,
          post: missingPost ? null : {'communityId': 'A'},
          profile: missingPost ? {'communityId': 'A'} : null,
        ),
        throwsStateError,
      );
    }
  });
  test(
    'does not repair malformed, duplicate or inconsistent reaction state',
    () {
      for (final fields in [
        {'likes': -1, 'likedBy': []},
        {'likes': 1.5, 'likedBy': []},
        {
          'likes': 8,
          'likedBy': ['other'],
        },
        {
          'likes': 2,
          'likedBy': ['other', 'other'],
        },
        {
          'likes': 1,
          'likedBy': [42],
        },
        {'likes': 0, 'likedBy': null},
        {'likes': null, 'likedBy': []},
      ]) {
        expect(
          () => update(post: {'communityId': 'A', ...fields}),
          throwsFormatException,
        );
      }
    },
  );

  test('a racing duplicate re-reads once and becomes a no-op', () async {
    var attempts = 0;
    await retryCommunityWallLikeTransaction(() async {
      if (++attempts == 1) {
        throw FirebaseException(
          plugin: 'cloud_firestore',
          code: 'permission-denied',
        );
      }
      expect(
        update(
          post: {
            'communityId': 'A',
            'likes': 1,
            'likedBy': ['resident'],
          },
        ),
        isNull,
      );
    });
    expect(attempts, 2);
  });
  test('persistent permission denial fails closed after one retry', () async {
    var attempts = 0;
    await expectLater(
      retryCommunityWallLikeTransaction(() async {
        attempts++;
        throw FirebaseException(
          plugin: 'cloud_firestore',
          code: 'permission-denied',
        );
      }),
      throwsA(isA<FirebaseException>()),
    );
    expect(attempts, 2);
  });
  test('authentication and availability errors are not retried', () async {
    for (final code in ['unauthenticated', 'unavailable']) {
      var attempts = 0;
      await expectLater(
        retryCommunityWallLikeTransaction(() async {
          attempts++;
          throw FirebaseException(plugin: 'cloud_firestore', code: code);
        }),
        throwsA(isA<FirebaseException>()),
      );
      expect(attempts, 1);
    }
  });
  test('non-Firebase errors are not retried', () async {
    var attempts = 0;
    await expectLater(
      retryCommunityWallLikeTransaction(() async {
        attempts++;
        throw StateError('Invalid reaction');
      }),
      throwsStateError,
    );
    expect(attempts, 1);
  });
}
