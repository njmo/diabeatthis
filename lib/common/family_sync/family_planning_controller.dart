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

bool familyPlannedMealIsOnDay(Map payload, DateTime day) {
  final timestamp = payload['planned_at'];
  final localDay = day.toLocal();
  if (timestamp is int) {
    final planned = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return planned.year == localDay.year &&
        planned.month == localDay.month &&
        planned.day == localDay.day;
  }
  return payload['planned_day'] == localDay.toIso8601String().split('T').first;
}

class FamilyPlanningController extends ChangeNotifier {
  FamilyPlanningController(
    this.transport,
    this.currentUid,
    this.submissions, {
    this.view,
    this.mealHistory = false,
  });
  final AuthenticatedCallableTransport transport;
  final FamilyPlanSubmissionStore submissions;
  final String? Function() currentUid;
  final Map<String, Object?> Function()? view;
  final bool mealHistory;
  bool _historyEndpointMissing = false;
  bool get pagedMealHistory => mealHistory && !_historyEndpointMissing;
  String _historyQuery = '';
  String? _historyCategory;
  String? _historyNext;
  int? _historyRevision;
  bool historyLoadingMore = false;
  bool historyMoreFailed = false;
  bool historyReady = false;
  bool get historyHasMore => _historyNext != null;
  Future<Map<String, dynamic>?>? _historyPrefetch;
  Future<void>? _historyPlansLoading;
  bool _historyPlansAgain = false;
  Timer? _historyFilterDelay;

  void setMealHistoryFilter(String query, String? category) {
    if (!pagedMealHistory) return;
    final normalized = query.trim();
    if (_historyQuery == normalized && _historyCategory == category) return;
    _historyQuery = normalized;
    _historyCategory = category;
    generation++;
    rows.clear();
    _resetMealHistory();
    _historyFilterDelay?.cancel();
    _historyFilterDelay = Timer(const Duration(milliseconds: 250), () {
      _historyFilterDelay = null;
      if (!disposed) unawaited(refresh());
    });
  }

  void _resetMealHistory() {
    _historyNext = null;
    _historyPrefetch = null;
    historyLoadingMore = false;
    historyMoreFailed = false;
    historyReady = false;
  }

  bool _isCurrentHistory(String account, int version) =>
      !disposed && currentUid() == account && generation == version;

  Future<Map<String, dynamic>?> _readMealHeaderPage(
    String account,
    int version,
    String? after, {
    int scanPages = 40,
  }) async {
    final query = _historyQuery;
    final category = _historyCategory;
    for (var scanned = 0; scanned < scanPages; scanned++) {
      if (!_isCurrentHistory(account, version)) return null;
      final response = await transport.call('fetchFamilyMealHeaders', {
        'query': query,
        'category': category,
        'cursor': after,
      }, expectedUid: account);
      if (!_isCurrentHistory(account, version)) return null;
      final items = response['records'] as List;
      final last = after;
      after = response['nextCursor'] as String?;
      if (items.isNotEmpty || after == null || scanned + 1 == scanPages) {
        return response;
      }
      if (after == last && response['initialHeadersComplete'] != false) {
        throw const FormatException('Invalid history cursor');
      }
    }
    return null;
  }

  void _applyMealHeaderPage(Map<String, dynamic> page, {required bool append}) {
    if (!append) {
      rows.clear();
      if (owner != page['ownerUid'] || source != page['sourceId']) plans = [];
      owner = page['ownerUid'] as String?;
      source = page['sourceId'] as String?;
    }
    for (final raw in page['records'] as List) {
      final row = Map<String, dynamic>.from(raw as Map);
      rows['meals/${row['id']}'] = row;
    }
    cursor = page['sequence'] as int;
    _historyRevision = page['mealHeadersRevision'] as int?;
    _historyNext = page['nextCursor'] as String?;
    historyReady = page['initialHeadersComplete'] == true;
  }

  void _prefetchMealHeaders(String account, int version) {
    final after = _historyNext;
    if (after == null || !_isCurrentHistory(account, version)) return;
    // A failed speculative read is retried only once the user reaches it.
    _historyPrefetch = _readMealHeaderPage(
      account,
      version,
      after,
      scanPages: 1,
    ).catchError((Object _) => null);
  }

  Future<void> loadMoreMealHeaders() async {
    final account = uid;
    final after = _historyNext;
    if (!pagedMealHistory ||
        account == null ||
        after == null ||
        busy ||
        historyLoadingMore ||
        failed) {
      return;
    }
    final version = generation;
    final prefetch = _historyPrefetch;
    _historyPrefetch = null;
    historyLoadingMore = true;
    historyMoreFailed = false;
    notifyListeners();
    try {
      var page = await prefetch;
      if (!_isCurrentHistory(account, version) || _historyNext != after) return;
      page ??= await _readMealHeaderPage(account, version, after);
      if (page == null || !_isCurrentHistory(account, version)) return;
      if (page['ownerUid'] != owner || page['sourceId'] != source) {
        markUnavailable();
        unawaited(refresh());
        return;
      }
      _applyMealHeaderPage(page, append: true);
      _prefetchMealHeaders(account, version);
    } on CallableFailure catch (error) {
      if (!_isCurrentHistory(account, version)) return;
      if (error.rejectionCode == 'failed-precondition') {
        unawaited(refresh());
      } else if (const {
        'permission-denied',
        'unauthenticated',
      }.contains(error.rejectionCode ?? error.code)) {
        markUnavailable();
      } else {
        historyMoreFailed = true;
      }
    } catch (_) {
      if (_isCurrentHistory(account, version)) historyMoreFailed = true;
    } finally {
      if (_isCurrentHistory(account, version)) {
        historyLoadingMore = false;
        notifyListeners();
      }
    }
  }

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
  DateTime? _retryScopedViewAfter;
  bool _usingScopedMirror = false;
  bool disposed = false;
  final disposal = StreamController<void>.broadcast();
  Stream<void> get whenDisposed => disposal.stream;
  bool again = false;
  Future<void>? _refreshing;
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

  Future<void> refresh({void Function(String, int)? timing}) {
    if (disposed) return Future.value();
    if (_refreshing != null) {
      again = true;
      return Future.value();
    }
    return refreshAndWait(timing: timing);
  }

  Future<void> refreshAndWait({
    void Function(String, int)? timing,
    bool mirrorOnly = false,
  }) {
    if (disposed) return Future.value();
    final running = _refreshing;
    if (running != null) return running;
    final completion = Completer<void>();
    _refreshing = completion.future;
    unawaited(
      _drainRefreshes(
        timing,
        mirrorOnly,
      ).then((_) => completion.complete(), onError: completion.completeError),
    );
    return completion.future;
  }

  Future<void> _drainRefreshes(
    void Function(String, int)? timing,
    bool mirrorOnly,
  ) async {
    try {
      do {
        again = false;
        await _refresh(timing: timing, mirrorOnly: mirrorOnly);
        mirrorOnly = false;
      } while (!disposed && again);
    } finally {
      _refreshing = null;
    }
  }

  bool hasMirrorSequence(Map<String, dynamic>? signal) =>
      !failed &&
      owner != null &&
      source != null &&
      signal?['ownerUid'] == owner &&
      signal?['sourceId'] == source &&
      (pagedMealHistory &&
              historyReady &&
              _historyRevision != null &&
              signal?['mealHeadersRevision'] == _historyRevision ||
          signal?['sequence'] is int && (signal!['sequence'] as int) <= cursor);

  Future<void> _refreshMealHeaders(String account, int version) async {
    final page = await _readMealHeaderPage(account, version, null);
    if (page == null) return;
    _applyMealHeaderPage(page, append: false);
    complete = source != null;
    busy = false;
    failed = false;
    notifyListeners();
    _prefetchMealHeaders(account, version);
    if (source == null) {
      plans = [];
      return;
    }
    await _refreshHistoryPlans(account, version);
  }

  Future<void> refreshPlanSignal() async {
    if (!pagedMealHistory) {
      await refresh();
      return;
    }
    if (!complete || uid == null) {
      if (_refreshing == null) await refresh();
      return;
    }
    if (_refreshing != null && busy) return;
    final version = generation;
    await _refreshHistoryPlans(uid!, version);
    if (!disposed && generation == version) notifyListeners();
  }

  Future<void> _refreshHistoryPlans(String account, int version) {
    final running = _historyPlansLoading;
    if (running != null) {
      _historyPlansAgain = true;
      return running;
    }
    final completion = Completer<void>();
    _historyPlansLoading = completion.future;
    Future<void> drain() async {
      try {
        var requestedVersion = version;
        do {
          _historyPlansAgain = false;
          if (_isCurrentHistory(account, requestedVersion) && complete) {
            await _fetchHistoryPlans(account, requestedVersion);
          }
          requestedVersion = generation;
        } while (_historyPlansAgain && !disposed && currentUid() == account);
      } finally {
        _historyPlansLoading = null;
      }
    }

    unawaited(
      drain().then(
        (_) => completion.complete(),
        onError: completion.completeError,
      ),
    );
    return completion.future;
  }

  Future<void> _fetchHistoryPlans(String account, int version) async {
    try {
      final response = await transport.call(
        'fetchFamilyPlans',
        {},
        expectedUid: account,
      );
      if (!_isCurrentHistory(account, version)) return;
      if (response['ownerUid'] != owner || response['sourceId'] != source) {
        markUnavailable();
        return;
      }
      plans = [
        for (final row in response['plans'] as List)
          Map<String, dynamic>.from(row as Map),
      ];
    } on CallableFailure catch (error) {
      if (_isCurrentHistory(account, version) &&
          const {
            'permission-denied',
            'unauthenticated',
          }.contains(error.rejectionCode ?? error.code)) {
        markUnavailable();
      }
    }
  }

  Future<void> refreshMirrorForSignal(Map<String, dynamic>? signal) async {
    if (disposed || hasMirrorSequence(signal)) return;
    if (pagedMealHistory &&
        owner != null &&
        signal?['ownerUid'] is String &&
        (signal?['ownerUid'] != owner || signal?['sourceId'] != source)) {
      markUnavailable();
    }
    await _refreshing;
    if (disposed || hasMirrorSequence(signal)) return;
    await refreshAndWait(mirrorOnly: true);
  }

  Future<void> _refresh({
    void Function(String, int)? timing,
    required bool mirrorOnly,
  }) async {
    if (disposed) return;
    final account = currentUid();
    if (account == null) {
      clear();
      notifyListeners();
      return;
    }
    if (uid != account) clear();
    uid = account;
    if (pagedMealHistory) {
      generation++;
      _resetMealHistory();
    }
    final previousOwner = owner;
    final previousSource = source;
    final hadCompleteMirror = complete;
    final version = generation;
    busy = true;
    notifyListeners();
    final clock = timing == null ? null : (Stopwatch()..start());
    try {
      if (pagedMealHistory) {
        try {
          await _refreshMealHeaders(account, version);
          return;
        } on CallableFailure catch (error) {
          if (error.code != 'endpoint-not-deployed') rethrow;
          if (!_isCurrentHistory(account, version)) return;
          _historyEndpointMissing = true;
        }
      }
      complete = false;
      final scopedView = mealHistory ? null : view?.call();
      final progressView = scopedView?['view'] == 'mealProgress';
      final mealView = scopedView?['view'] == 'meal' || progressView;
      final pending = mirrorOnly || mealView
          ? null
          : await submissions.pending(account);
      if (pending != null) await sendReserved(account, pending);
      timing?.call('pending.done', clock!.elapsedMilliseconds);
      clock?.reset();
      var pages = 0;
      Map<String, dynamic>? scopedResponse;
      final retryScopedViewAfter = _retryScopedViewAfter;
      if (progressView && scopedView != null) {
        try {
          scopedResponse = await transport.call('fetchFamilyMealProgress', {
            'mealId': scopedView['mealId'],
          }, expectedUid: account);
        } on CallableFailure catch (error) {
          if (error.code != 'endpoint-not-deployed') rethrow;
          scopedResponse = await transport.call('fetchFamilyMirrorView', {
            ...scopedView,
            'view': 'meal',
          }, expectedUid: account);
        }
      } else if (scopedView != null &&
          (retryScopedViewAfter == null ||
              DateTime.now().isAfter(retryScopedViewAfter))) {
        try {
          scopedResponse = await transport.call(
            'fetchFamilyMirrorView',
            scopedView,
            expectedUid: account,
          );
        } on CallableFailure catch (error) {
          if (error.code != 'endpoint-not-deployed') rethrow;
          _retryScopedViewAfter = DateTime.now().add(
            const Duration(minutes: 5),
          );
        }
      }
      if (disposed || currentUid() != account || version != generation) return;
      if (scopedResponse case final response?) {
        if (disposed || currentUid() != account || version != generation) {
          return;
        }
        final records = <String, Map<String, dynamic>>{};
        for (final raw in response['records'] as List) {
          final row = Map<String, dynamic>.from(raw as Map);
          records['${row['kind']}/${row['id']}'] = row;
        }
        owner = response['ownerUid'] as String?;
        source = response['sourceId'] as String?;
        rows
          ..clear()
          ..addAll(records);
        cursor = response['sequence'] as int;
        complete = true;
        _usingScopedMirror = true;
        pages = 1;
      } else if (_usingScopedMirror) {
        rows.clear();
        cursor = 0;
        _usingScopedMirror = false;
      }
      for (var page = 0; scopedResponse == null && page < 200; page++) {
        pages++;
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
      timing?.call('mirror.done pages=$pages', clock!.elapsedMilliseconds);
      if (mealView ||
          mirrorOnly &&
              hadCompleteMirror &&
              owner == previousOwner &&
              source == previousSource) {
        failed = false;
        return;
      }
      clock?.reset();
      final response = await transport.call(
        'fetchFamilyPlans',
        {},
        expectedUid: account,
      );
      if (disposed || currentUid() != account || version != generation) return;
      timing?.call('plans.done', clock!.elapsedMilliseconds);
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
      }
    }
  }

  void clear() {
    generation++;
    _resetMealHistory();
    rows.clear();
    plans = [];
    cursor = 0;
    _historyRevision = null;
    owner = null;
    source = null;
    complete = false;
    _usingScopedMirror = false;
  }

  void markUnavailable() {
    clear();
    failed = true;
    notifyListeners();
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
    if (pagedMealHistory ||
        currentUid() != expectedUid ||
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
    _historyFilterDelay?.cancel();
    disposal.add(null);
    unawaited(disposal.close());
    super.dispose();
  }
}
