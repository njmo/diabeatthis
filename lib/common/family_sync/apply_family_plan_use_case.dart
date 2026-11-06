import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart' show SqliteException;

import '../../core/drift/database_impl.dart';
import '../../core/drift/family_sync/family_mirror_outbox.dart';
import '../../core/drift/family_sync/load_family_plan_rows.dart';
import '../../core/drift/mappers/ingredient_drift_mapper.dart';
import '../../features/activity/data/services/activity_schedule_service.dart';
import '../../features/ingredients/data/drafts/ingredient_draft_validation.dart';
import '../../features/ingredients/data/mappers/ingredient_draft_mapper.dart';
import '../../features/meals/data/providers/meal_ingredients_list_provider.dart';
import '../ingredient_catalog/catalog_ingredient.dart';
import '../ingredient_catalog/drift_selected_catalog_ingredient_store.dart';
import 'family_plan_scope.dart';
import 'family_workflow_guard.dart';

class ApplyFamilyPlanUseCase {
  const ApplyFamilyPlanUseCase(this.db, {this.workflowGuard});
  final DatabaseImpl db;
  final FamilyWorkflowGuard? workflowGuard;

  Future<void> call(
    String uid,
    Map<String, dynamic> plan, {
    bool Function()? stillAuthorized,
    Map<String, CatalogIngredient> catalogIngredients = const {},
  }) => db.transaction(() async {
    final source = await FamilyMirrorOutbox(db).sourceForOwner(uid);
    final identity = await db
        .customSelect(
          'SELECT enabled,owner_uid FROM family_sync_identity WHERE singleton=1',
        )
        .getSingle();
    if (source != plan['sourceId'] ||
        identity.read<int>('enabled') != 1 ||
        identity.readNullable<String>('owner_uid') != uid) {
      throw StateError('Family identity changed');
    }
    final old = await db
        .customSelect(
          'SELECT operation_id FROM family_plan_journal WHERE operation_id=?',
          variables: [Variable(plan['id'] as String)],
        )
        .get();
    if (old.isNotEmpty) return;
    if ((plan['claimUntil'] as int) <= clock.now().millisecondsSinceEpoch ||
        stillAuthorized?.call() == false) {
      throw StateError('Expired plan claim');
    }
    var outcome = 'applied';
    String? reason;
    int? resultId;
    final before = await db
        .customSelect('SELECT kind,entity_id,revision FROM family_sync_outbox')
        .get();
    final beforeVersions = {
      for (final row in before)
        '${row.data['kind']}/${row.data['entity_id']}': row.read<int>(
          'revision',
        ),
    };
    final localRows = await loadFamilyPlanRows(db, plan);
    var scope = <Map<String, dynamic>>[];
    try {
      scope = familyPlanScope(localRows, plan);
      final expected =
          [
            for (final value in plan['expected'] as List)
              Map<String, dynamic>.from(value as Map),
          ]..sort(
            (a, b) =>
                '${a['kind']}/${a['id']}'.compareTo('${b['kind']}/${b['id']}'),
          );
      if (jsonEncode(familyPlanVersions(scope)) != jsonEncode(expected)) {
        reason = 'conflict';
      }
    } on StateError {
      reason = 'conflict';
    }
    for (final item
        in (plan['values'] as Map)['ingredients'] as List? ?? const []) {
      if (item['catalogId'] != null) {
        final catalog = catalogIngredients[item['catalogId']];
        if (catalog == null ||
            catalog.revision != item['catalogRevision'] ||
            await DriftSelectedCatalogIngredientStore(
                  db,
                ).findLocalId(catalog.identity) !=
                null) {
          reason = 'conflict';
        }
      }
    }
    if (plan['authorActive'] != true) reason = 'author-disconnected';
    if (reason != null) {
      outcome = 'rejected';
    } else {
      try {
        // A nested transaction/savepoint rolls back failed domain writes while
        // allowing a durable rejection journal in the outer transaction.
        resultId = await db.transaction(() async {
          if (await monitored(plan)) throw StateError('Workflow is monitored');
          final result = await applyDomainPlan(plan, catalogIngredients);
          if (await monitored(plan)) throw StateError('Workflow is monitored');
          return result;
        });
      } on ArgumentError {
        outcome = 'rejected';
        reason = 'ineligible';
      } on StateError {
        outcome = 'rejected';
        reason = 'ineligible';
      } on SqliteException catch (error) {
        if (error.resultCode != 19) rethrow;
        outcome = 'rejected';
        reason = 'ineligible';
      }
    }
    final after = await db
        .customSelect(
          'SELECT kind,entity_id,revision,acknowledged_revision FROM family_sync_outbox',
        )
        .get();
    final scopeKeys = {
      for (final row in localRows) '${row['kind']}/${row['id']}',
    };
    final required = [
      for (final row in after)
        if (row.read<int>('revision') >
                row.read<int>('acknowledged_revision') &&
            (beforeVersions['${row.data['kind']}/${row.data['entity_id']}'] !=
                    row.read<int>('revision') ||
                scopeKeys.contains(
                  '${row.data['kind']}/${row.data['entity_id']}',
                )))
          {
            'kind': row.data['kind'],
            'id': row.data['entity_id'],
            'revision': row.data['revision'],
          },
    ];
    if (stillAuthorized?.call() == false ||
        (plan['claimUntil'] as int) <= clock.now().millisecondsSinceEpoch) {
      throw StateError('Expired plan claim');
    }
    await db.customStatement(
      'INSERT INTO family_plan_journal(operation_id,claim_token,owner_uid,source_id,outcome,reason,result_id,required_revisions,cancel_occurrence_id) VALUES(?,?,?,?,?,?,?,?,?)',
      [
        plan['id'],
        plan['claimToken'],
        uid,
        source,
        outcome,
        reason,
        resultId,
        jsonEncode(required),
        ['moveActivity', 'confirmActivity'].contains(plan['type']) &&
                outcome == 'applied'
            ? plan['targetId']
            : null,
      ],
    );
  });

  Future<bool> monitored(Map<String, dynamic> plan) async {
    if (plan['type'] == 'updateMeal') {
      final id = plan['targetId'] as int;
      return workflowGuard?.contains('meal', id) == true ||
          await FamilyWorkflowGuard(db).persisted('meal', id);
    }
    if (['confirmActivity', 'moveActivity'].contains(plan['type'])) {
      final row = await (db.select(
        db.activityOccurrence,
      )..where((r) => r.id.equals(plan['targetId'] as int))).getSingleOrNull();
      if (row == null) return false;
      if (row.targetRequestedAt != null) return true;
      if (row.activityLogId != null) {
        final log = await db.activityDao.getActivityLogByIdOrNull(
          row.activityLogId!,
        );
        if (log != null &&
            (log.startedAt <= clock.now().millisecondsSinceEpoch ||
                log.endedAt != null)) {
          return true;
        }
      }
      final log = row.activityLogId;
      return log != null &&
          (workflowGuard?.contains('activity', log) == true ||
              await FamilyWorkflowGuard(db).persisted('activity', log));
    }
    return false;
  }

  Future<int?> applyDomainPlan(
    Map<String, dynamic> plan,
    Map<String, CatalogIngredient> catalogIngredients,
  ) async {
    final v = plan['values'] as Map;
    final type = plan['type'];
    final now = clock.now().millisecondsSinceEpoch;
    final service = ActivityScheduleService(db);
    if (type == 'createMeal' || type == 'updateMeal') {
      if ((v['plannedAt'] as int) <= now ||
          (v['ingredients'] as List).isEmpty) {
        throw StateError('Meal time expired');
      }
      int id;
      if (type == 'updateMeal') {
        id = plan['targetId'] as int;
        final row = await db.mealDao.getMealById(id);
        if (row == null || row.status != 'planned' || row.purpose != 'meal') {
          throw StateError('Meal is no longer editable');
        }
        await (db.update(db.meal)..where((r) => r.id.equals(id))).write(
          MealCompanion(
            category: Value(v['category'] as String),
            name: Value(v['name'] as String),
            notes: Value(v['notes'] as String),
            plannedAt: Value(v['plannedAt'] as int),
          ),
        );
        await (db.delete(
          db.mealIngredients,
        )..where((r) => r.mealId.equals(id))).go();
        await (db.delete(
          db.mealSnapshot,
        )..where((r) => r.mealId.equals(id))).go();
      } else {
        id = await db
            .into(db.meal)
            .insert(
              MealCompanion.insert(
                category: Value(v['category'] as String),
                name: v['name'] as String,
                plannedAt: v['plannedAt'] as int,
                notes: Value(v['notes'] as String),
              ),
            );
      }
      for (final item in v['ingredients'] as List) {
        final ingredientId =
            item['ingredientId'] as int? ??
            await DriftSelectedCatalogIngredientStore(
              db,
            ).mirror(catalogIngredients[item['catalogId']]!);
        final ingredient = await (db.select(
          db.ingredient,
        )..where((r) => r.id.equals(ingredientId))).getSingle();
        final draft = ingredient.toDomain().toDraft();
        draft.validateMacroRanges();
        if (!draft.hasEnergyMacros) {
          throw ArgumentError('Ingredient has no energy macros');
        }
        final grams = (item['grams'] as num).toDouble();
        if (!grams.isFinite || grams <= 0 || grams > 10000) {
          throw ArgumentError('Invalid amount');
        }
        // Reference ingredients use a 100 g unit; custom ingredients use grams.
        final unit = ingredient.isReference == 1 ? 100.0 : 1.0;
        await db
            .into(db.mealIngredients)
            .insert(
              MealIngredientsCompanion.insert(
                mealId: id,
                ingredientId: ingredient.id,
                quantityConfidence: 1,
                amount: Value(grams / unit),
                gramsPerPortionUsed: Value(unit),
              ),
            );
      }
      final totals = await db.ingredientDao.totalsForMeal(id);
      if (totals == null) throw StateError('Meal has no nutrition');
      final macros = macronutrientsFromSummary(totals);
      if (macros.netCarbsTotal <= 0 && macros.extendedCarbsTotal <= 0) {
        throw ArgumentError('Meal has no actionable carbohydrates');
      }
      return id;
    }
    if (type == 'planActivity') {
      await service.planOnce(
        activityId: v['activityId'] as int,
        start: DateTime.fromMillisecondsSinceEpoch(v['startedAt'] as int),
        durationMinutes: v['durationMinutes'] as int,
      );
      final row =
          await (db.select(db.activityOccurrence)
                ..where(
                  (r) =>
                      r.activityId.equals(v['activityId'] as int) &
                      r.startedAt.equals(v['startedAt'] as int),
                )
                ..orderBy([(r) => OrderingTerm.desc(r.id)])
                ..limit(1))
              .getSingle();
      return row.id;
    }
    final id = plan['targetId'] as int;
    if (type == 'confirmActivity') {
      if (await service.confirm(id) == null) {
        throw StateError('Activity no longer eligible');
      }
      return id;
    }
    if (type == 'moveActivity') {
      final old = await (db.select(
        db.activityOccurrence,
      )..where((r) => r.id.equals(id))).getSingle();
      await service.move(
        id,
        DateTime.fromMillisecondsSinceEpoch(v['startedAt'] as int),
      );
      return (await (db.select(db.activityOccurrence)
                ..where(
                  (r) =>
                      r.activityId.equals(old.activityId) &
                      r.startedAt.equals(v['startedAt'] as int),
                )
                ..orderBy([(r) => OrderingTerm.desc(r.id)])
                ..limit(1))
              .getSingle())
          .id;
    }
    throw ArgumentError('Unsupported family operation');
  }
}
