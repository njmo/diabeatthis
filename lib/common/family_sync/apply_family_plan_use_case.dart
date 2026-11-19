import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart' show SqliteException;

import '../../core/drift/database_impl.dart';
import '../../core/drift/family_sync/family_mirror_outbox.dart';
import '../../core/drift/family_sync/load_family_plan_rows.dart';
import '../../core/drift/mappers/activity_drift_mapper.dart';
import '../../core/drift/mappers/ingredient_drift_mapper.dart';
import '../../features/activity/data/drafts/activity_draft.dart';
import '../../features/activity/data/mappers/activity_draft_mapper.dart';
import '../../features/activity/data/services/activity_schedule_service.dart';
import '../../features/ingredients/data/drafts/ingredient_draft_validation.dart';
import '../../features/ingredients/data/mappers/ingredient_draft_mapper.dart';
import '../../features/meals/data/providers/meal_ingredients_list_provider.dart';
import '../activity/activity_definition_edit_guard.dart';
import '../activity/activity_occurrence_preparation.dart';
import '../activity/insert_activity_session.dart';
import '../ingredient_catalog/catalog_ingredient.dart';
import '../ingredient_catalog/drift_selected_catalog_ingredient_store.dart';
import '../planning/activity_schedule_values.dart';
import 'family_plan_scope.dart';
import 'family_workflow_guard.dart';
import 'resolve_family_activity.dart';

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
    final cancelIds = <int>{};
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
          final scheduleAffectedIds =
              plan['type'] == 'setActivityScheduleEnabled'
              ? scope
                    .where(
                      (r) =>
                          r['kind'] == 'activityOccurrences' &&
                          ((r['payload'] as Map)['started_at'] as int) >
                              clock.now().millisecondsSinceEpoch,
                    )
                    .map((r) => int.parse(r['id'] as String))
                    .toSet()
              : null;
          if (await monitored(
            plan,
            originalRows: scope,
            affectedOccurrenceIds: scheduleAffectedIds,
          )) {
            throw StateError('Workflow is monitored');
          }
          final affected =
              plan['type'] == 'setActivityScheduleEnabled' &&
                  (plan['values'] as Map)['enabled'] == false
              ? await (db.select(db.activityOccurrence)..where(
                      (r) =>
                          r.scheduleId.equals(plan['targetId'] as int) &
                          r.startedAt.isBiggerThanValue(
                            clock.now().millisecondsSinceEpoch,
                          ),
                    ))
                    .get()
              : <ActivityOccurrenceData>[];
          final result = await applyDomainPlan(plan, catalogIngredients);
          cancelIds.addAll(affected.map((r) => r.id));
          if (await monitored(
            plan,
            originalRows: scope,
            affectedOccurrenceIds: scheduleAffectedIds,
          )) {
            throw StateError('Workflow is monitored');
          }
          return result;
        });
      } on ArgumentError {
        outcome = 'rejected';
        reason = 'ineligible';
      } on StateError catch (error) {
        outcome = 'rejected';
        reason = error.message == 'An activity is already in progress'
            ? 'activity-running'
            : 'ineligible';
      } on SqliteException catch (error) {
        if (error.resultCode != 19) rethrow;
        outcome = 'rejected';
        reason = 'ineligible';
      }
    }
    if (outcome == 'applied') {
      for (final id in cancelIds) {
        await db.customStatement(
          'INSERT OR IGNORE INTO family_plan_notification_cancellations(operation_id,occurrence_id) VALUES(?,?)',
          [plan['id'], id],
        );
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
      'INSERT INTO family_plan_journal(operation_id,claim_token,owner_uid,source_id,outcome,reason,result_id,required_revisions,cancel_occurrence_id,result_bound) VALUES(?,?,?,?,?,?,?,?,?,?)',
      [
        plan['id'],
        plan['claimToken'],
        uid,
        source,
        outcome,
        reason,
        resultId,
        jsonEncode(required),
        [
                  'moveActivity',
                  'confirmActivity',
                  'skipActivity',
                ].contains(plan['type']) &&
                outcome == 'applied'
            ? plan['targetId']
            : null,
        plan['type'] == 'replaceQuickTreatmentItems' ? 1 : 0,
      ],
    );
  });

  Future<bool> monitored(
    Map<String, dynamic> plan, {
    List<Map<String, dynamic>> originalRows = const [],
    Set<int>? affectedOccurrenceIds,
  }) async {
    if (plan['type'] == 'setActivityScheduleEnabled') {
      if ((plan['values'] as Map)['enabled'] == true) return false;
      final sessions =
          await (db.select(db.activityOccurrence)..where(
                (r) =>
                    r.scheduleId.equals(plan['targetId'] as int) &
                    r.startedAt.isBiggerThanValue(
                      clock.now().millisecondsSinceEpoch,
                    ),
              ))
              .get();
      final originals = originalRows
          .where(
            (r) =>
                r['kind'] == 'activityOccurrences' &&
                (r['payload'] as Map)['schedule_id'] == plan['targetId'] &&
                ((r['payload'] as Map)['started_at'] as int) >
                    clock.now().millisecondsSinceEpoch,
          )
          .map((r) => r['id'] as String)
          .toSet();
      final ids =
          affectedOccurrenceIds ??
          {...sessions.map((r) => r.id), ...originals.map(int.parse)};
      for (final id in ids) {
        if (await monitored({
          'type': 'skipActivity',
          'targetId': id,
        }, originalRows: originalRows)) {
          return true;
        }
      }
      return false;
    }
    if (plan['type'] == 'updateActivity') {
      final id = plan['targetId'] as int;
      final now = clock.now().millisecondsSinceEpoch;
      final logs = await (db.select(
        db.activityLog,
      )..where((r) => r.activityId.equals(id))).get();
      for (final log in logs) {
        if (workflowGuard?.contains('activity', log.id) == true ||
            await FamilyWorkflowGuard(db).persisted('activity', log.id)) {
          return true;
        }
        if (activityDefinitionLogBlocksEdit(log.startedAt, log.endedAt, now)) {
          return true;
        }
      }
      final occurrences = await (db.select(
        db.activityOccurrence,
      )..where((r) => r.activityId.equals(id))).get();
      if (occurrences.any(
        (r) => activityDefinitionOccurrenceBlocksEdit(
          startedAt: r.startedAt,
          status: r.status,
          targetRequestedAt: r.targetRequestedAt,
          now: now,
        ),
      )) {
        return true;
      }
      return false;
    }
    if (plan['type'] == 'startActivity') {
      if (workflowGuard?.blocked.containsKey('activity') == true) {
        throw StateError('An activity is already in progress');
      }
      return false;
    }
    if (plan['type'] == 'updateMeal') {
      final id = plan['targetId'] as int;
      return workflowGuard?.contains('meal', id) == true ||
          await FamilyWorkflowGuard(db).persisted('meal', id);
    }
    if ([
      'confirmActivity',
      'moveActivity',
      'skipActivity',
    ].contains(plan['type'])) {
      final row = await (db.select(
        db.activityOccurrence,
      )..where((r) => r.id.equals(plan['targetId'] as int))).getSingleOrNull();
      if (row != null &&
          activityOccurrencePreparationStarted(
            startedAt: row.startedAt,
            targetRequestedAt: row.targetRequestedAt,
            now: clock.now().millisecondsSinceEpoch,
          )) {
        return true;
      }
      final original =
          originalRows
                  .where(
                    (r) =>
                        r['kind'] == 'activityOccurrences' &&
                        r['id'] == '${plan['targetId']}',
                  )
                  .firstOrNull?['payload']
              as Map?;
      if (original != null &&
          activityOccurrencePreparationStarted(
            startedAt: original['started_at'] as int,
            targetRequestedAt: original['target_requested_at'] as int?,
            now: clock.now().millisecondsSinceEpoch,
          )) {
        return true;
      }
      final originalId = original?['activity_log_id'] as int?;
      if (originalId != null) {
        final log =
            originalRows
                    .where(
                      (r) =>
                          r['kind'] == 'activityLogs' &&
                          r['id'] == '$originalId',
                    )
                    .firstOrNull?['payload']
                as Map?;
        if (log != null &&
            ((log['started_at'] as int) <= clock.now().millisecondsSinceEpoch ||
                log['ended_at'] != null)) {
          return true;
        }
        if (workflowGuard?.contains('activity', originalId) == true ||
            await FamilyWorkflowGuard(db).persisted('activity', originalId)) {
          return true;
        }
      }
      if (row?.activityLogId != null) {
        final log = await db.activityDao.getActivityLogByIdOrNull(
          row!.activityLogId!,
        );
        if (log != null &&
            (log.startedAt <= clock.now().millisecondsSinceEpoch ||
                log.endedAt != null)) {
          return true;
        }
      }
      final log = row?.activityLogId;
      return log != null &&
          (workflowGuard?.contains('activity', log) == true ||
              await FamilyWorkflowGuard(db).persisted('activity', log));
    }
    return false;
  }

  Future<void> applyInlineSchedule(
    ActivityScheduleService service,
    int activityId,
    Map values,
  ) async {
    if (values['schedule'] == null) return;
    final v = values['schedule'] as Map;
    final draft = activityScheduleFromValues(v);
    await service.save(
      activityId: activityId,
      weekdays: draft.weekdays,
      startMinute: draft.startMinute,
      durationMinutes: v['durationMinutes'] as int?,
      mode: draft.confirmationMode,
      previousDayMinute: draft.previousDayMinute,
      validFrom: draft.validFrom,
      validUntil: draft.validUntil,
    );
  }

  Future<void> _replaceQuickTreatmentItems(List items) async {
    final existing = await db.select(db.quickLowTreatmentItem).get();
    final retained = <int>{};
    for (final (index, raw) in items.indexed) {
      final item = raw as Map;
      final id = item['id'] as int?;
      final ingredientId = item['ingredientId'] as int;
      final portionId = item['portionId'] as int?;
      final ingredient = await (db.select(
        db.ingredient,
      )..where((row) => row.id.equals(ingredientId))).getSingleOrNull();
      if (ingredient == null) throw StateError('Shortcut ingredient missing');
      if (portionId == null &&
          ingredient.isReference != 1 &&
          !existing.any(
            (row) =>
                row.id == id &&
                row.ingredientId == ingredientId &&
                row.portionId == null,
          )) {
        throw StateError('Shortcut requires a portion');
      }
      if (portionId != null) {
        final link =
            await (db.select(db.ingredientPortions)..where(
                  (row) =>
                      row.ingredientId.equals(ingredientId) &
                      row.portionId.equals(portionId),
                ))
                .getSingleOrNull();
        if (link == null ||
            !link.gramsPerPortion.isFinite ||
            link.gramsPerPortion <= 0) {
          throw StateError('Shortcut portion has no weight');
        }
      }
      final shortcut = QuickLowTreatmentItemCompanion.insert(
        ingredientId: ingredientId,
        portionId: Value(portionId),
        name: item['name'] as String,
        amount: (item['amount'] as num).toDouble(),
        sortOrder: Value(index + 1),
      );
      if (id == null) {
        await db.into(db.quickLowTreatmentItem).insert(shortcut);
      } else {
        if (!existing.any((row) => row.id == id) || !retained.add(id)) {
          throw StateError('Shortcut changed');
        }
        await (db.update(
          db.quickLowTreatmentItem,
        )..where((row) => row.id.equals(id))).write(shortcut);
      }
    }
    for (final row in existing.where((row) => !retained.contains(row.id))) {
      await db.quickLowTreatmentItemDao.deleteQuickLowTreatmentItem(row.id);
    }
  }

  Future<int?> applyDomainPlan(
    Map<String, dynamic> plan,
    Map<String, CatalogIngredient> catalogIngredients,
  ) async {
    final v = plan['values'] as Map;
    final type = plan['type'];
    if (type == 'replaceQuickTreatmentItems') {
      await _replaceQuickTreatmentItems(v['items'] as List);
      return null;
    }
    final now = clock.now().millisecondsSinceEpoch;
    final service = ActivityScheduleService(db);
    if (type == 'setActivityScheduleEnabled') {
      if ((v['effectiveFrom'] as int) > now) {
        throw StateError('Schedule cutoff is ahead of child clock');
      }
      final rule = await (db.select(
        db.activitySchedule,
      )..where((r) => r.id.equals(plan['targetId'] as int))).getSingle();
      await service.setEnabled(rule, v['enabled'] as bool);
      return rule.id;
    }
    if ([
      'createActivity',
      'updateActivity',
      'createActivitySchedule',
    ].contains(type)) {
      final target = plan['targetId'] as int?;
      int activityId;
      if (type == 'createActivity') {
        activityId = await resolveFamilyActivity(db, {
          'activityId': null,
          'activity': v['activity'],
        });
      } else {
        if (target == null ||
            (await (db.select(
                  db.activity,
                )..where((r) => r.id.equals(target))).getSingleOrNull()) ==
                null) {
          throw StateError('Activity missing');
        }
        activityId = target;
        if (type == 'updateActivity') {
          final a = v['activity'] as Map;
          await db.activityDao.updateActivity(
            ActivityDraft.existing(
              id: target,
              name: a['name'] as String,
              percentagePre: a['percentagePre'] as int,
              percentagePost: a['percentagePost'] as int,
              durationMinutes: a['durationMinutes'] as int?,
            ).toDomain().toCompanion(),
          );
        }
      }
      if (v['schedule'] != null) {
        final values = v['schedule'] as Map;
        final schedule = activityScheduleFromValues(values);
        await service.save(
          activityId: activityId,
          weekdays: schedule.weekdays,
          startMinute: schedule.startMinute,
          durationMinutes: values['durationMinutes'] as int?,
          mode: schedule.confirmationMode,
          previousDayMinute: schedule.previousDayMinute,
          validFrom: schedule.validFrom,
          validUntil: schedule.validUntil,
        );
        if (type == 'createActivitySchedule') {
          return (await (db.select(db.activitySchedule)
                    ..where((r) => r.activityId.equals(activityId))
                    ..orderBy([(r) => OrderingTerm.desc(r.id)])
                    ..limit(1))
                  .getSingle())
              .id;
        }
      }
      return activityId;
    }
    if (type == 'createMeal' || type == 'updateMeal') {
      final plannedAt = v['plannedAt'] as int?;
      final plannedDay = v['plannedDay'] as String?;
      final today = DateTime.fromMillisecondsSinceEpoch(
        now,
      ).toIso8601String().split('T').first;
      if ((plannedAt == null ? plannedDay != today : plannedAt <= now) ||
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
            plannedAt: Value(plannedAt),
            plannedDay: Value(plannedDay),
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
                plannedAt: Value(plannedAt),
                plannedDay: Value(plannedDay),
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
    if (['startActivity', 'logActivity'].contains(type)) {
      final requested = DateTime.fromMillisecondsSinceEpoch(
        v['startedAt'] as int,
      );
      final immediate = type == 'startActivity';
      if (immediate &&
          (clock.now().difference(requested).inMinutes >= 5 ||
              requested.isAfter(
                clock.now().add(const Duration(seconds: 30)),
              ))) {
        throw StateError('Activity start request expired');
      }
      if (immediate && workflowGuard?.blocked.containsKey('activity') == true) {
        throw StateError('An activity is already in progress');
      }
      final activityId = await resolveFamilyActivity(db, v);
      await applyInlineSchedule(service, activityId, v);
      final row = await insertActivitySession(
        db,
        activityId: activityId,
        start: immediate ? clock.now() : requested,
        end: immediate
            ? null
            : DateTime.fromMillisecondsSinceEpoch(v['endedAt'] as int),
      );
      if (immediate && workflowGuard?.blocked.containsKey('activity') == true) {
        throw StateError('An activity is already in progress');
      }
      return row.id;
    }
    if (type == 'planActivity') {
      final activityId = await resolveFamilyActivity(db, v);
      await applyInlineSchedule(service, activityId, v);
      await service.planOnce(
        activityId: activityId,
        start: DateTime.fromMillisecondsSinceEpoch(v['startedAt'] as int),
        durationMinutes: v['durationMinutes'] as int,
      );
      final row =
          await (db.select(db.activityOccurrence)
                ..where(
                  (r) =>
                      r.activityId.equals(activityId) &
                      r.startedAt.equals(v['startedAt'] as int),
                )
                ..orderBy([(r) => OrderingTerm.desc(r.id)])
                ..limit(1))
              .getSingle();
      return row.id;
    }
    final id = plan['targetId'] as int;
    if (type == 'skipActivity') {
      final row = await (db.select(
        db.activityOccurrence,
      )..where((r) => r.id.equals(id))).getSingleOrNull();
      if (row == null ||
          !['pending', 'planned'].contains(row.status) ||
          row.startedAt <= now) {
        throw StateError('Activity no longer eligible');
      }
      await service.skip(id);
      if ((await (db.select(
            db.activityOccurrence,
          )..where((r) => r.id.equals(id))).getSingle()).status !=
          'skipped') {
        throw StateError('Activity no longer eligible');
      }
      return id;
    }
    if (type == 'confirmActivity') {
      if (await service.confirm(id) == null) {
        throw StateError('Activity no longer eligible');
      }
      return id;
    }
    if (type == 'moveActivity') {
      await service.move(
        id,
        DateTime.fromMillisecondsSinceEpoch(v['startedAt'] as int),
      );
      return id;
    }
    throw ArgumentError('Unsupported family operation');
  }
}
