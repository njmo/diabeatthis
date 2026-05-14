import 'package:clock/clock.dart';

import '../../domain/model/treatment_base.dart';
import '../domain/treatment_source_repository.dart';
import '../nightscout/repository/nightscout_repository.dart';
import 'nightscout_temporary_target_monitor.dart';

class CloudTreatmentSourceRepository implements TreatmentSourceRepository {
  CloudTreatmentSourceRepository(this._nightscoutRepository)
    : _lastPollAt = clock.now(),
      _temporaryTargetMonitor = NightscoutTemporaryTargetMonitor(
        _nightscoutRepository,
      );

  final NightscoutRepository _nightscoutRepository;
  final NightscoutTemporaryTargetMonitor _temporaryTargetMonitor;
  DateTime _lastPollAt;

  @override
  Future<List<Treatment>> pollTreatments() async {
    final polledTreatments = <Treatment>[
      ...await _temporaryTargetMonitor.pollUpdates(),
    ];

    final treatments = await _nightscoutRepository.fetchTreatmentsAfter(
      _lastPollAt,
    );
    _temporaryTargetMonitor.trackFromTreatments(treatments);

    if (treatments.isEmpty && polledTreatments.isEmpty) return treatments;

    final ordered = [...polledTreatments, ...treatments]
      ..sort((a, b) {
        final aCreatedAt =
            a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bCreatedAt =
            b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return aCreatedAt.compareTo(bCreatedAt);
      });
    final newestCreatedAt = treatments
        .map((treatment) => treatment.createdAt)
        .whereType<DateTime>()
        .fold<DateTime?>(null, (newest, createdAt) {
          if (newest == null || createdAt.isAfter(newest)) return createdAt;
          return newest;
        });
    if (newestCreatedAt != null) {
      _lastPollAt = newestCreatedAt.add(const Duration(seconds: 5));
    }

    return ordered;
  }
}
