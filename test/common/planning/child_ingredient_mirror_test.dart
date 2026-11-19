import 'package:diabeatthis/common/backend/authenticated_callable_transport.dart';
import 'package:diabeatthis/common/family_sync/family_ingredient_search_repository.dart';
import 'package:diabeatthis/common/family_sync/load_child_ingredient_mirror.dart';
import 'package:flutter_test/flutter_test.dart';

class _MirrorTransport implements AuthenticatedCallableTransport {
  _MirrorTransport(this.pages);

  final List<Map<String, dynamic>> pages;
  final cursors = <Object?>[];

  @override
  Future<Map<String, dynamic>> call(
    String function,
    Map<String, Object?> data, {
    String? expectedUid,
    Future<bool> Function()? allowRequest,
  }) async {
    expect(function, 'fetchFamilyMirror');
    expect(expectedUid, 'caregiver');
    expect(await allowRequest!(), isTrue);
    cursors.add(data['after']);
    return pages[cursors.length - 1];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Map<String, dynamic> _ingredient(int id, String name, {bool deleted = false}) =>
    {
      'kind': 'ingredients',
      'id': '$id',
      'deleted': deleted,
      'payload': {'id': id, 'name': name},
    };

Map<String, dynamic> _page(
  List<Map<String, dynamic>> records, {
  String owner = 'child',
  bool hasMore = false,
}) => {
  'ownerUid': owner,
  'sourceId': 'source',
  'cursor': 3,
  'hasMore': hasMore,
  'records': records,
};

void main() {
  test(
    'a child who has not shared a mirror can still use catalog search',
    () async {
      final transport = _MirrorTransport([
        {..._page([]), 'sourceId': null, 'cursor': 0},
      ]);
      expect(
        await loadChildIngredientMirror(
          transport: transport,
          caregiverUid: 'caregiver',
          childUid: 'child',
          isCurrent: () => true,
        ),
        isEmpty,
      );
    },
  );

  test(
    'loads the selected child ingredients across pages and applies deletions',
    () async {
      final transport = _MirrorTransport([
        _page([_ingredient(1, 'Banana')], hasMore: true),
        _page([
          _ingredient(1, 'Banana', deleted: true),
          _ingredient(2, 'Apple'),
        ]),
      ]);
      final rows = await loadChildIngredientMirror(
        transport: transport,
        caregiverUid: 'caregiver',
        childUid: 'child',
        isCurrent: () => true,
      );
      final matches = await FamilyIngredientSearchRepository(rows).search('');
      expect(matches.map((item) => item.name), ['Apple']);
      expect(transport.cursors, [0, 3]);
    },
  );

  test('rejects a mirror for another child', () async {
    final transport = _MirrorTransport([_page([], owner: 'other-child')]);
    await expectLater(
      loadChildIngredientMirror(
        transport: transport,
        caregiverUid: 'caregiver',
        childUid: 'child',
        isCurrent: () => true,
      ),
      throwsStateError,
    );
  });
}
