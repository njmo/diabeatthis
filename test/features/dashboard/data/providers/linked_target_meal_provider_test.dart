import 'package:diabeatthis/common/temporary_targets/owned_temp_target.dart';
import 'package:diabeatthis/common/temporary_targets/temp_target_proposal.dart';
import 'package:diabeatthis/core/data/provider/shared_prefs_provider.dart';
import 'package:diabeatthis/core/data_sources/nightscout/nightscout_storage_keys.dart';
import 'package:diabeatthis/core/data_sources/nightscout/temporary_targets/temp_target_operation_repository.dart';
import 'package:diabeatthis/core/domain/model/temporary_target.dart';
import 'package:diabeatthis/core/drift/database_impl.dart' show DatabaseImpl, MealCompanion, MealData;
import 'package:diabeatthis/core/drift/providers/database_provider.dart';
import 'package:diabeatthis/features/dashboard/common/temporary_targets/meal_target_links.dart';
import 'package:diabeatthis/features/dashboard/data/providers/linked_target_meal_provider.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const source = 'https://example.com';
  final start = DateTime(2026, 11, 3, 8);
  final target = TemporaryTarget(
    nightscoutId: 'meal-target', createdAt: start, durationInMiliseconds: 3600000,
    duration: 60, targetBottom: 110, targetTop: 110,
  );
  late DatabaseImpl db;
  late SharedPreferences prefs;
  late ProviderContainer container;
  late int mealId;

  setUp(() async {
    SharedPreferences.setMockInitialValues({nightscoutUrlKey: source});
    prefs = await SharedPreferences.getInstance();
    db = DatabaseImpl(NativeDatabase.memory());
    mealId = await db.into(db.meal).insert(MealCompanion.insert(
      name: 'Breakfast', plannedAt: start.millisecondsSinceEpoch,
    ));
    container = ProviderContainer(overrides: [
      sharedPrefsProvider.overrideWith((_) async => prefs),
      databaseProvider.overrideWithValue(db),
    ]);
    container.listen(sharedPrefsProvider, (_, _) {});
    await container.read(sharedPrefsProvider.future);
  });
  tearDown(() async { container.dispose(); await db.close(); });

  Future<MealData?> linked(TemporaryTarget selected) {
    final provider = linkedTargetMealProvider(selected);
    final subscription = container.listen(provider, (_, _) {});
    addTearDown(subscription.close);
    return container.read(provider.future);
  }

  test('nearby meal is not automatically associated with an external target', () async {
    expect(await linked(target), isNull);
  });

  test('manual association survives recreating the provider', () async {
    await MealTargetLinks(prefs).attach(source, target, mealId);
    expect((await linked(target))?.id, mealId);
    container.invalidate(linkedTargetMealProvider(target));
    expect((await linked(target))?.id, mealId);
    expect(await linked(target.copyWith(nightscoutId: 'replacement')), isNull);
  });

  test('confirmed exact target operation links its original meal', () async {
    final repository = TempTargetOperationRepository(db);
    final proposal = TempTargetProposal(
      id: 'meal-offer', entityId: mealId, targetType: 'meal', source: source,
      target: 110, durationMinutes: 60,
      expiresAt: start.add(const Duration(hours: 1)),
    );
    await repository.createOffer(proposal);
    final owned = OwnedTempTarget(
      entityId: mealId, targetType: 'meal', source: source, startedAt: start,
      until: start.add(const Duration(hours: 1)), target: 110,
      durationMinutes: 60, nightscoutId: 'meal-target',
    );
    await repository.claimStart(proposal.id, owned, now: start);
    await repository.markSent(proposal.id, confirmed: owned, now: start);
    expect((await linked(target))?.id, mealId);
  });
}
