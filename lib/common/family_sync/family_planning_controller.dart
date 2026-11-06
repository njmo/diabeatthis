import 'dart:math';

import 'package:flutter/foundation.dart';

import '../backend/authenticated_callable_transport.dart';
import 'family_plan_scope.dart';
import 'family_plan_submission_store.dart';

class FamilyPlanningController extends ChangeNotifier {
  FamilyPlanningController(this.transport, this.currentUid, this.submissions);
  final AuthenticatedCallableTransport transport;
  final FamilyPlanSubmissionStore submissions;
  final String? Function() currentUid;
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
  bool again = false;
  int generation = 0;
  void invalidate() {
    generation++;
  }

  List<Map<String, dynamic>> ofKind(String kind) => rows.values
      .where((row) => row['kind'] == kind && row['deleted'] != true)
      .toList();
  bool locked(String kind, int id) =>
      monitored(kind, id) ||
      plans.any(
        (p) =>
            p['status'] == 'pending' &&
            (p['targetId'] == id || p['resultId'] == id) &&
            (kind == 'meals'
                ? (p['type'] as String).endsWith('Meal')
                : [
                    'planActivity',
                    'moveActivity',
                    'confirmActivity',
                  ].contains(p['type'])),
      );
  bool monitored(String kind, int id) {
    final row = rows['$kind/$id']?['payload'] as Map?;
    final entity = kind == 'meals' ? id : row?['activity_log_id'];
    final log = rows['activityLogs/$entity']?['payload'] as Map?;
    if (kind == 'activityOccurrences' &&
        log != null &&
        ((log['started_at'] as int) <= DateTime.now().millisecondsSinceEpoch ||
            log['ended_at'] != null)) {
      return true;
    }
    if (kind == 'activityOccurrences' && row?['target_requested_at'] != null) {
      return true;
    }
    return ofKind('workflowLocks').any((r) {
      final p = r['payload'] as Map;
      return p['active'] == 1 &&
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
    if (currentUid() != expectedUid ||
        uid != expectedUid ||
        source != expectedSource ||
        !complete ||
        failed) {
      throw StateError('Family changed');
    }
    final id = List.generate(
      16,
      (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    final plan = <String, dynamic>{
      'id': id,
      'sourceId': expectedSource,
      'type': type,
      'targetId': targetId,
      'values': values,
    };
    plan['expected'] = familyPlanVersions(familyPlanScope(baseRows, plan));
    final reserved = await submissions.reserve(expectedUid, plan);
    await sendReserved(expectedUid, reserved);
    await refresh();
  }

  Future<void> sendReserved(String account, Map<String, dynamic> plan) async {
    try {
      final result = await transport.call(
        'submitFamilyPlan',
        plan,
        expectedUid: account,
      );
      if (result['id'] != plan['id'] ||
          !['pending', 'applied', 'rejected'].contains(result['status'])) {
        throw StateError('Invalid submission receipt');
      }
      await submissions.clear(account, plan['id'] as String);
    } on CallableFailure catch (error) {
      if ([
        'invalid-argument',
        'permission-denied',
        'failed-precondition',
        'already-exists',
      ].contains(error.rejectionCode ?? error.code)) {
        await submissions.clear(account, plan['id'] as String);
      }
      rethrow;
    }
  }

  @override
  void dispose() {
    disposed = true;
    super.dispose();
  }
}
