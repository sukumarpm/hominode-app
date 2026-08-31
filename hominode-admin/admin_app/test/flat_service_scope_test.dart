import 'package:admin_app/services/flat_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('flat mutation scope accepts the selected community and building', () {
    expect(
      () => validateFlatMutationScope(
        flatData: {'communityId': 'community-a', 'buildingId': 'building-a'},
        expectedCommunityId: 'community-a',
        expectedBuildingId: 'building-a',
      ),
      returnsNormally,
    );
  });

  test('flat mutation scope rejects another community or building', () {
    expect(
      () => validateFlatMutationScope(
        flatData: {'communityId': 'community-b', 'buildingId': 'building-a'},
        expectedCommunityId: 'community-a',
        expectedBuildingId: 'building-a',
      ),
      throwsStateError,
    );
    expect(
      () => validateFlatMutationScope(
        flatData: {'communityId': 'community-a', 'buildingId': 'building-b'},
        expectedCommunityId: 'community-a',
        expectedBuildingId: 'building-a',
      ),
      throwsStateError,
    );
  });
}
