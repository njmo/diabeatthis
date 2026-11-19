import 'dart:convert';

import 'package:drift/drift.dart';

import '../../core/drift/database_impl.dart';
import '../../core/drift/family_sync/family_mirror_outbox.dart';
import '../backend/authenticated_callable_transport.dart';
import '../ingredient_catalog/catalog_ingredient.dart';
import '../ingredient_catalog/ingredient_catalog_repository.dart';
import '../ingredient_catalog/ingredient_identity.dart';
import '../notifications/clear_pending_activity_confirmations.dart';
import 'apply_family_plan_use_case.dart';
import 'call_family_activity_protocol.dart';
import 'family_workflow_guard.dart';
import 'publish_family_mirror_use_case.dart';

class SynchronizeFamilyPlansUseCase {
  const SynchronizeFamilyPlansUseCase({
    required this.db,
    required this.transport,
    required this.currentUid,
    this.catalog,
    this.languageCode = 'en',
    this.workflowGuard,
    this.cancelConfirmation,
  });
  final DatabaseImpl db;
  final String languageCode;
  final FamilyWorkflowGuard? workflowGuard;
  final Future<void> Function(int)? cancelConfirmation;
  final IngredientCatalogRepository? catalog;
  final AuthenticatedCallableTransport transport;
  final String? Function() currentUid;

  Future<void> drain(
    String uid,
    String source,
    FamilyMirrorOutbox queue,
    Future<bool> Function() allowed,
  ) async {
    final unbound = await db
        .customSelect(
          "SELECT * FROM family_plan_journal WHERE owner_uid=? AND source_id=? AND outcome='applied' AND acknowledged=0 AND result_bound=0",
          variables: [Variable(uid), Variable(source)],
        )
        .get();
    for (final row in unbound) {
      if (!await allowed()) return;
      final result = await transport.call(
        'acknowledgeFamilyPlan',
        {
          'id': row.read<String>('operation_id'),
          'claimToken': row.read<String>('claim_token'),
          'sourceId': source,
          'outcome': 'prepared',
          'reason': null,
          'resultId': row.readNullable<int>('result_id'),
        },
        expectedUid: uid,
        allowRequest: allowed,
      );
      if (!['pending', 'applied'].contains(result['status'])) {
        throw StateError('Plan result reservation failed');
      }
      await db.customStatement(
        'UPDATE family_plan_journal SET result_bound=1 WHERE operation_id=?',
        [row.read<String>('operation_id')],
      );
    }
    await PublishFamilyMirrorUseCase(
      outbox: queue,
      transport: transport,
      currentUid: currentUid,
      canSend: allowed,
    )();
    final journal = await db
        .customSelect(
          'SELECT * FROM family_plan_journal WHERE owner_uid=? AND source_id=? AND acknowledged=0',
          variables: [Variable(uid), Variable(source)],
        )
        .get();
    for (final row in journal) {
      if (!await allowed()) return;
      final cancelId = row.readNullable<int>('cancel_occurrence_id');
      if (cancelId != null && row.read<int>('notification_cleared') == 0) {
        if (cancelConfirmation == null) {
          throw StateError('Notification cancellation unavailable');
        }
        await clearPendingActivityConfirmations(
          db,
          cancelId,
          cancelConfirmation!,
        );
      }
      final cancellations = await db
          .customSelect(
            'SELECT occurrence_id FROM family_plan_notification_cancellations WHERE operation_id=? AND cleared=0',
            variables: [Variable(row.read<String>('operation_id'))],
          )
          .get();
      for (final cancellation in cancellations) {
        if (!await allowed()) return;
        if (cancelConfirmation == null) {
          throw StateError('Notification cancellation unavailable');
        }
        final id = cancellation.read<int>('occurrence_id');
        await clearPendingActivityConfirmations(db, id, cancelConfirmation!);
      }
      var ready = true;
      for (final required
          in jsonDecode(row.read<String>('required_revisions')) as List) {
        final receipt = await db
            .customSelect(
              'SELECT acknowledged_revision FROM family_sync_outbox WHERE kind=? AND entity_id=?',
              variables: [
                Variable(required['kind'] as String),
                Variable(required['id'] as String),
              ],
            )
            .getSingleOrNull();
        if (receipt == null ||
            receipt.read<int>('acknowledged_revision') <
                (required['revision'] as int)) {
          ready = false;
          break;
        }
      }
      if (!ready) continue;
      final result = await transport.call(
        'acknowledgeFamilyPlan',
        {
          'id': row.read<String>('operation_id'),
          'claimToken': row.read<String>('claim_token'),
          'sourceId': source,
          'outcome': row.read<String>('outcome'),
          'reason': row.readNullable<String>('reason'),
          'resultId': row.readNullable<int>('result_id'),
        },
        expectedUid: uid,
        allowRequest: allowed,
      );
      if (result['status'] != row.read<String>('outcome')) {
        throw StateError('Invalid plan acknowledgement');
      }
      await db.customStatement(
        'UPDATE family_plan_journal SET acknowledged=1 WHERE operation_id=? AND owner_uid=?',
        [row.read<String>('operation_id'), uid],
      );
    }
  }

  Future<bool> call() async {
    final uid = currentUid();
    if (uid == null) return false;
    final settings = await db
        .customSelect(
          'SELECT enabled,enabled_revision,owner_uid,source_id FROM family_sync_identity WHERE singleton=1',
        )
        .getSingle();
    if (settings.read<int>('enabled') != 1 ||
        settings.readNullable<String>('owner_uid') != uid) {
      return false;
    }
    final consent = settings.read<int>('enabled_revision');
    final source = settings.read<String>('source_id');
    final queue = FamilyMirrorOutbox(db);
    Future<bool> allowed() async =>
        currentUid() == uid && await queue.enabledAt(consent);
    if (!await allowed()) return false;
    await drain(uid, source, queue, allowed);
    final response = await callFamilyActivityProtocol(
      transport: transport,
      name: 'fetchFamilyPlans',
      activityCommandsVersion: familyPlanningProtocolVersion,
      data: {},
      uid: uid,
      permitted: allowed,
    );
    if (response['sourceId'] != source || response['ownerUid'] != uid) {
      throw StateError('Plan source changed');
    }
    var retry = false;
    for (final raw in response['plans'] as List) {
      try {
        if (!await allowed()) return false;
        final plan = Map<String, dynamic>.from(raw as Map);
        final existing = await db
            .customSelect(
              'SELECT operation_id FROM family_plan_journal WHERE operation_id=?',
              variables: [Variable(plan['id'] as String)],
            )
            .get();
        if (existing.isNotEmpty) continue;
        final catalogIngredients = <String, CatalogIngredient>{};
        for (final item
            in (plan['values'] as Map)['ingredients'] as List? ?? const []) {
          if (item['catalogId'] != null &&
              plan['catalogAvailable'] != false &&
              plan['authorActive'] != false) {
            if (catalog == null) throw StateError('Catalog unavailable');
            final ingredient = await catalog!.get(
              IngredientIdentity(
                source: IngredientSource.firebase,
                sourceId: item['catalogId'] as String,
              ),
            );
            catalogIngredients[ingredient.identity.sourceId] = ingredient;
          }
        }
        final claim = await callFamilyActivityProtocol(
          transport: transport,
          name: 'claimFamilyPlan',
          activityCommandsVersion: familyPlanningProtocolVersion,
          data: {'id': plan['id'], 'sourceId': source},
          uid: uid,
          permitted: allowed,
        );
        if (!await allowed()) return false;
        await ApplyFamilyPlanUseCase(db, workflowGuard: workflowGuard)(
          uid,
          claim,
          stillAuthorized: () => currentUid() == uid,
          catalogIngredients: catalogIngredients,
        );
      } catch (_) {
        retry = true;
      }
    }
    await drain(uid, source, queue, allowed);
    final remaining = await db
        .customSelect(
          'SELECT operation_id FROM family_plan_journal WHERE owner_uid=? AND source_id=? AND acknowledged=0 LIMIT 1',
          variables: [Variable(uid), Variable(source)],
        )
        .get();
    return retry ||
        remaining.isNotEmpty ||
        (response['plans'] as List).length >= 50;
  }
}
