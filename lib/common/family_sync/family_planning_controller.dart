import 'dart:async';

import 'package:flutter/foundation.dart';

import '../activity/activity_definition_edit_guard.dart';
import '../activity/activity_occurrence_preparation.dart';
import '../backend/authenticated_callable_transport.dart';
import 'family_plan_record_kind.dart';
import 'family_plan_scope.dart';
import 'family_plan_submission_store.dart';
import 'family_workflow_phase.dart';
import 'submit_family_plan_use_case.dart';

class FamilyPlanningController extends ChangeNotifier {
  FamilyPlanningController(this.transport, this.currentUid, this.submissions);
  final AuthenticatedCallableTransport transport;
  final FamilyPlanSubmissionStore submissions;
  final String? Function() currentUid;
  late final _submitPlan = SubmitFamilyPlanUseCase(
    transport,
    submissions,
    (uid) => !disposed && currentUid() == uid,
  );

  final rows = <String, Map<String, dynamic>>{};
  List<Map<String, dynamic>> plans = [];
  String? uid;
  String? owner;
  String? source;
  int cursor = 0;
  bool busy = false;
  bool failed = false;
  bool complete = false;
  bool disposed = false;
  final disposal = StreamController<void>.broadcast();
  Stream<void> get whenDisposed => disposal.stream;
  bool again = false;
  int generation = 0;
  void invalidate() {
    generation++;
  }

  List<Map<String, dynamic>> ofKind(String kind) => rows.values
      .where((row) => row['kind'] == kind && row['deleted'] != true)
      .toList();
  bool locked(String kind, int id) =>
      (kind == 'activityOccurrences' &&
          plans.any(
            (p) =>
                p['status'] == 'pending' &&
                p['type'] == 'setActivityScheduleEnabled' &&
                p['targetId'] ==
                    (rows['activityOccurrences/$id']?['payload']
                        as Map?)?['schedule_id'],
          )) ||
      monitored(kind, id) ||
      plans.any((p) => familyPlanLocksRecord(p, kind, id));
  bool monitored(String kind, int id) {
    if (kind == 'activitySchedules') {
      return ofKind('activityOccurrences').any((r) {
        final p = r['payload'] as Map;
        return p['schedule_id'] == id &&
            (p['started_at'] as int) > DateTime.now().millisecondsSinceEpoch &&
            monitored('activityOccurrences', p['id'] as int);
      });
    }
    if (kind == 'activities') {
      final now = DateTime.now().millisecondsSinceEpoch;
      if (ofKind('activityLogs').any((r) {
        final p = r['payload'] as Map;
        return p['activity_id'] == id &&
            activityDefinitionLogBlocksEdit(
              p['started_at'] as int,
              p['ended_at'] as int?,
              now,
            );
      })) {
        return true;
      }
      if (ofKind('activityOccurrences').any((r) {
        final p = r['payload'] as Map;
        return p['activity_id'] == id &&
            activityDefinitionOccurrenceBlocksEdit(
              startedAt: p['started_at'] as int,
              status: p['status'] as String,
              targetRequestedAt: p['target_requested_at'] as int?,
              now: now,
            );
      })) {
        return true;
      }
    }
    final row = rows['$kind/$id']?['payload'] as Map?;
    final entity = kind == 'meals' ? id : row?['activity_log_id'];
    final log = rows['activityLogs/$entity']?['payload'] as Map?;
    if (kind == 'activityOccurrences' &&
        log != null &&
        ((log['started_at'] as int) <= DateTime.now().millisecondsSinceEpoch ||
            log['ended_at'] != null)) {
      return true;
    }
    if (kind == 'activityOccurrences' &&
        row != null &&
        activityOccurrencePreparationStarted(
          startedAt: row['started_at'] as int,
          targetRequestedAt: row['target_requested_at'] as int?,
          now: DateTime.now().millisecondsSinceEpoch,
        )) {
      return true;
    }
    return ofKind('workflowLocks').any((r) {
      final p = r['payload'] as Map;
      return p['active'] == 1 &&
          familyWorkflowPhaseBlocks(
            p['kind'] as String,
            p['phase'] as String? ?? 'unknown',
          ) &&
          p['kind'] == (kind == 'meals' ? 'meal' : 'activity') &&
          p['entity_id'] == entity;
    });
  }

  Future<void> refresh() async {
    if (disposed) return;
    if (busy) {
      again = true;
      return;
    }
    final account = currentUid();
    if (account == null) {
      clear();
      notifyListeners();
      return;
    }
    if (uid != account) clear();
    uid = account;
    final version = generation;
    busy = true;
    notifyListeners();
    try {
      complete = false;
      final pending = await submissions.pending(account);
      if (pending != null) await sendReserved(account, pending);
      for (var page = 0; page < 200; page++) {
        final response = await transport.call('fetchFamilyMirror', {
          'after': cursor,
        }, expectedUid: account);
        if (disposed || currentUid() != account || version != generation) {
          return;
        }
        if (owner != response['ownerUid'] || source != response['sourceId']) {
          rows.clear();
          owner = response['ownerUid'] as String?;
          source = response['sourceId'] as String?;
          if (cursor != 0) {
            cursor = 0;
            continue;
          }
        }
        for (final raw in response['records'] as List) {
          final row = Map<String, dynamic>.from(raw as Map);
          rows['${row['kind']}/${row['id']}'] = row;
        }
        cursor = response['cursor'] as int;
        if (response['hasMore'] != true) {
          complete = true;
          break;
        }
      }
      final response = await transport.call(
        'fetchFamilyPlans',
        {},
        expectedUid: account,
      );
      if (disposed || currentUid() != account || version != generation) return;
      if (response['ownerUid'] != owner || response['sourceId'] != source) {
        throw StateError('Family changed');
      }
      plans = [
        for (final row in response['plans'] as List)
          Map<String, dynamic>.from(row as Map),
      ];
      failed = false;
    } catch (_) {
      if (version == generation) {
        clear();
        failed = true;
      }
    } finally {
      if (!disposed) {
        busy = false;
        notifyListeners();
        if (again) {
          again = false;
          await refresh();
        }
      }
    }
  }

  void clear() {
    generation++;
    rows.clear();
    plans = [];
    cursor = 0;
    owner = null;
    source = null;
    complete = false;
  }

  Future<void> submit({
    required String type,
    required int? targetId,
    required Map<String, dynamic> values,
    required List<Map<String, dynamic>> baseRows,
    required String expectedSource,
    required String expectedUid,
  }) async {
    if (disposed) throw StateError('Family controller is closed');
    if (currentUid() != expectedUid ||
        uid != expectedUid ||
        source != expectedSource ||
        !complete ||
        failed) {
      throw StateError('Family changed');
    }
    final (plan: reserved, :receipt) = await _submitPlan(
      type: type,
      targetId: targetId,
      values: values,
      baseRows: baseRows,
      expectedSource: expectedSource,
      expectedUid: expectedUid,
    );
    if (!disposed &&
        currentUid() == expectedUid &&
        uid == expectedUid &&
        source == expectedSource) {
      plans = [
        {
          ...reserved,
          'status': receipt['status'],
          'createdAt': DateTime.now().millisecondsSinceEpoch,
          'base': familyPlanScope(baseRows, reserved),
          'canonical': <Map<String, dynamic>>[],
          'reason': null,
        },
        ...plans.where((p) => p['id'] != reserved['id']),
      ];
      notifyListeners();
      unawaited(refresh());
    }
  }

  Future<Map<String, dynamic>> sendReserved(
    String account,
    Map<String, dynamic> plan,
  ) => _submitPlan.sendReserved(account, plan);

  @override
  void dispose() {
    disposed = true;
    disposal.add(null);
    unawaited(disposal.close());
    super.dispose();
  }
}
