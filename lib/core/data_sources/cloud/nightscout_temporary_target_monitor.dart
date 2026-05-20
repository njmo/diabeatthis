import '../../domain/model/temporary_target.dart';
import '../../domain/model/treatment_base.dart';
import '../nightscout/repository/nightscout_repository.dart';

class NightscoutTemporaryTargetMonitor {
  NightscoutTemporaryTargetMonitor(this._nightscoutRepository);

  final NightscoutRepository _nightscoutRepository;

  var _activeTemporaryTargetChecked = false;
  TemporaryTarget? _trackedTemporaryTarget;

  Future<List<TemporaryTarget>> pollUpdates() async {
    final updates = <TemporaryTarget>[];
    if (!_activeTemporaryTargetChecked) {
      _activeTemporaryTargetChecked = true;
      final target = await _fetchActiveTemporaryTarget();
      if (target != null) {
        updates.add(target);
        _trackedTemporaryTarget = target;
        return updates;
      }
    }

    await _appendTrackedUpdate(updates);
    return updates;
  }

  void trackFromTreatments(Iterable<Treatment> treatments) {
    final latest = treatments
        .whereType<TemporaryTarget>()
        .fold<TemporaryTarget?>(null, (current, target) {
          if (current == null) return target;
          return target.createdAt.isAfter(current.createdAt) ? target : current;
        });
    if (latest == null) return;

    _trackedTemporaryTarget = latest.isActive() ? latest : null;
  }

  Future<void> _appendTrackedUpdate(List<TemporaryTarget> updates) async {
    final tracked = _trackedTemporaryTarget;
    if (tracked == null) return;

    if (!tracked.isActive()) {
      updates.add(tracked);
      _trackedTemporaryTarget = null;
      return;
    }

    try {
      final trackedId = tracked.nightscoutId;
      if (trackedId == null) return;

      final current = await _nightscoutRepository.fetchLastTemporaryTargetById(
        trackedId,
      );
      if (current != tracked || !current.isActive()) {
        updates.add(current);
      }
      _trackedTemporaryTarget = current.isActive() ? current : null;
    } catch (_) {
      if (!tracked.isActive()) {
        updates.add(tracked);
        _trackedTemporaryTarget = null;
      }
    }
  }

  Future<TemporaryTarget?> _fetchActiveTemporaryTarget() async {
    try {
      final target = await _nightscoutRepository.fetchLastTemporaryTarget();
      if (!target.isActive()) return null;
      return target;
    } catch (_) {
      return null;
    }
  }
}
