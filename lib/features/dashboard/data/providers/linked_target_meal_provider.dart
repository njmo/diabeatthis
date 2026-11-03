import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../common/temporary_targets/temp_target_operation.dart';
import '../../../../core/data/provider/shared_prefs_provider.dart';
import '../../../../core/data_sources/nightscout/nightscout_storage_keys.dart';
import '../../../../core/data_sources/nightscout/temporary_targets/temp_target_operation_repository.dart';
import '../../../../core/domain/model/temporary_target.dart';
import '../../../../core/drift/database_impl.dart' show MealData;
import '../../../../core/drift/providers/database_provider.dart';
import '../../common/temporary_targets/meal_target_links.dart';
import '../../domain/use_cases/resolve_meal_target_link_use_case.dart';

final linkedTargetMealProvider = StreamProvider.autoDispose
    .family<MealData?, TemporaryTarget>((ref, target) {
      final preferences = ref.watch(sharedPrefsProvider).asData?.value;
      if (preferences == null) return Stream.value(null);
      final source = preferences.getString(nightscoutUrlKey)?.trim() ?? '';
      if (source.isEmpty) return Stream.value(null);
      final db = ref.watch(databaseProvider);
      return db
          .customSelect(
            'SELECT 1',
            readsFrom: {db.meal, db.tempTargetOperation},
          )
          .watch()
          .asyncMap((_) async {
            final manualId = MealTargetLinks(
              preferences,
            ).mealId(source, target);
            final operations = manualId == null
                ? await TempTargetOperationRepository(db).list()
                : <TempTargetOperation>[];
            final id = const ResolveMealTargetLinkUseCase()(
              source: source,
              target: target,
              manualMealId: manualId,
              operations: operations,
            );
            if (id == null) return null;
            final meal = await db.mealDao.getMealById(id);
            return meal?.purpose == 'meal' ? meal : null;
          });
    });
