import 'package:admin_app/models/community_invite.dart';
import 'package:admin_app/services/community_invite_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('normalization exactly matches resident Phase 2B', () {
    expect(
      CommunityInviteService.normalizeInviteCode('  home-2026 '),
      'HOME-2026',
    );
    expect(
      CommunityInviteService.normalizeInviteCode(' Society 42! '),
      'SOCIETY42',
    );
    expect(CommunityInviteService.normalizeInviteCode('tower_a'), 'TOWER_A');
  });

  test('community slug is normalized to lowercase kebab-case', () {
    expect(
      CommunityInviteService.normalizeSlug('  Green Valley Phase 1! '),
      'green-valley-phase-1',
    );
    expect(CommunityInviteService.normalizeSlug('---'), isEmpty);
  });

  test('trusted community payload contains only normalized form fields', () {
    expect(
      CommunityInviteService.communityCreationPayload(
        communityId: ' gv 0701 ',
        name: ' Green Valley ',
        slug: 'Green Valley',
      ),
      {
        'communityId': 'GV-0701',
        'name': 'Green Valley',
        'slug': 'green-valley',
      },
    );
  });

  test('resident useCount field takes precedence over compatibility alias', () {
    final invite = CommunityInvite.fromMap('CODE', {
      'communityId': 'community-a',
      'isActive': true,
      'useCount': 3,
      'usedCount': 2,
      'maxUses': 3,
    });
    expect(invite.useCount, 3);
    expect(invite.isExhausted, isTrue);
  });

  test('callable millisecond timestamps are decoded', () {
    final invite = CommunityInvite.fromMap('CODE', {
      'communityId': 'community-a',
      'isActive': true,
      'useCount': 0,
      'createdAt': 1735689600000,
    });
    expect(
      invite.createdAt,
      DateTime.fromMillisecondsSinceEpoch(1735689600000),
    );
  });
}
