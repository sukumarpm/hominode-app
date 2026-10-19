import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resident_app/src/services/post_firestore_service.dart';

void main() {
  Map<String, dynamic> payload({
    String community = 'A',
    String text = ' Hello ',
  }) => buildCommunityWallComment(
    postId: 'post',
    authorId: 'resident',
    post: {'communityId': 'A'},
    profile: {'communityId': community, 'name': 'Resident'},
    comment: text,
  );

  test('comment carries canonical identity, tenant and server timestamp', () {
    final data = payload();
    expect(data['postId'], 'post');
    expect(data['communityId'], 'A');
    expect(data['authorId'], 'resident');
    expect(data['authorName'], 'Resident');
    expect(data['profileImage'], '');
    expect(data['comment'], 'Hello');
    expect(data['createdAt'], isA<FieldValue>());
  });
  test('rejects another community before preparing writes', () {
    expect(() => payload(community: 'B'), throwsArgumentError);
  });
  test('rejects empty comments', () {
    expect(() => payload(text: '   '), throwsArgumentError);
  });
  test('requires a current identity and an existing parent post', () {
    for (final uid in ['', 'resident']) {
      expect(
        () => buildCommunityWallComment(
          postId: 'post',
          authorId: uid,
          post: null,
          profile: {'communityId': 'A'},
          comment: 'Hello',
        ),
        throwsArgumentError,
      );
    }
  });
  test('preserves existing private profile image references', () {
    final data = buildCommunityWallComment(
      postId: 'post',
      authorId: 'resident',
      post: {'communityId': 'A'},
      profile: {'communityId': 'A', 'profileImage': 'private-asset:profile'},
      comment: 'Hello',
    );
    expect(data['profileImage'], 'private-asset:profile');
    expect(data['authorName'], 'Unknown User');
  });
}
