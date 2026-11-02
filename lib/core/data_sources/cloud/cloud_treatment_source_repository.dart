import 'package:clock/clock.dart';

import '../../domain/model/bg_check.dart';
import '../../domain/model/treatment_base.dart';
import '../domain/treatment_source_repository.dart';
import '../nightscout/repository/nightscout_repository.dart';
import 'nightscout_temporary_target_monitor.dart';

class CloudTreatmentSourceRepository implements TreatmentSourceRepository {
  CloudTreatmentSourceRepository(this._nightscoutRepository)
    : _startedAt = clock.now(),
      _lastPollAt = clock.now(),
      _temporaryTargetMonitor = NightscoutTemporaryTargetMonitor(
        _nightscoutRepository,
      );

  final NightscoutRepository _nightscoutRepository;
  final NightscoutTemporaryTargetMonitor _temporaryTargetMonitor;
  static const overlap = Duration(minutes: 5);
  static const maximumRememberedRecords = 2048;
  final DateTime _startedAt;
  final Map<(Type, DateTime?), Treatment> _lastSeen = {};
  DateTime _lastPollAt;

  @override
  Future<List<Treatment>> pollTreatments() async {
    final requestedAt = clock.now();
    final polledTreatments = <Treatment>[
      ...await _temporaryTargetMonitor.pollUpdates(),
    ];

    // A calculator and its actual delivery can reach Nightscout in different
    // uploads while retaining timestamps less than a second apart.
    final overlapStart = _lastPollAt.subtract(overlap);
    final queryStart = overlapStart.isBefore(_startedAt)
        ? _startedAt
        : overlapStart;
    final treatments = await _nightscoutRepository.fetchTreatmentsAfter(
      queryStart,
    );
    _temporaryTargetMonitor.trackFromTreatments(treatments);
    _lastSeen.removeWhere(
      (key, _) => key.$2 != null && key.$2!.isBefore(queryStart),
    );
    final changes = <Treatment>[...polledTreatments];
    // The monitor may emit an unchanged row when its target expires. Preserve
    // that notification, while suppressing the same row in the history response.
    for (final treatment in polledTreatments) {
      _remember(treatment);
    }
    for (final treatment in treatments) {
      final key = (treatment.runtimeType, treatment.createdAt);
      if (!_sameVersion(_lastSeen[key], treatment)) changes.add(treatment);
      _remember(treatment);
    }
    if (requestedAt.isAfter(_lastPollAt)) _lastPollAt = requestedAt;

    final ordered = changes
      ..sort((a, b) {
        final aCreatedAt =
            a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bCreatedAt =
            b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return aCreatedAt.compareTo(bCreatedAt);
      });
    return ordered;
  }

  void _remember(Treatment treatment) {
    final key = (treatment.runtimeType, treatment.createdAt);
    _lastSeen.remove(key);
    _lastSeen[key] = treatment;
    while (_lastSeen.length > maximumRememberedRecords) {
      _lastSeen.remove(_lastSeen.keys.first);
    }
  }

  bool _sameVersion(Treatment? previous, Treatment current) =>
      previous is BgCheck && current is BgCheck
      ? previous.reading == current.reading &&
            previous.isValid == current.isValid
      : previous == current;
}
