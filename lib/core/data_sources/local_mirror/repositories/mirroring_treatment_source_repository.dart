import '../../../domain/model/meal.dart';
import '../../../domain/model/temporary_target.dart';
import '../../../domain/model/treatment_base.dart';
import '../../../logger/logger.dart';
import '../../config/data_source_config.dart';
import '../../domain/treatment_source_repository.dart';
import '../services/local_mirror_writer.dart';

class MirroringTreatmentSourceRepository
    with Logging
    implements TreatmentSourceRepository {
  const MirroringTreatmentSourceRepository({
    required TreatmentSourceRepository delegate,
    required LocalMirrorWriter mirrorWriter,
    required EventSource source,
  }) : _delegate = delegate,
       _mirrorWriter = mirrorWriter,
       _source = source;

  final TreatmentSourceRepository _delegate;
  final LocalMirrorWriter _mirrorWriter;
  final EventSource _source;

  @override
  Future<TemporaryTarget> fetchLastTemporaryTarget() async {
    final target = await _delegate.fetchLastTemporaryTarget();
    await _mirror([target]);
    return target;
  }

  @override
  Future<TemporaryTarget> fetchLastTemporaryTargetById(String id) async {
    final target = await _delegate.fetchLastTemporaryTargetById(id);
    await _mirror([target]);
    return target;
  }

  @override
  Future<List<Meal>> fetchMealsAfter(DateTime after) async {
    final meals = await _delegate.fetchMealsAfter(after);
    await _mirror(meals);
    return meals;
  }

  @override
  Future<List<Meal>> fetchMealsOnDay(DateTime day) async {
    final meals = await _delegate.fetchMealsOnDay(day);
    await _mirror(meals);
    return meals;
  }

  @override
  Future<List<Treatment>> fetchTreatmentsAfter(DateTime after) async {
    final treatments = await _delegate.fetchTreatmentsAfter(after);
    await _mirror(treatments);
    return treatments;
  }

  @override
  Future<List<Treatment>> fetchTreatmentsBetween(
    DateTime start,
    DateTime end,
  ) async {
    final treatments = await _delegate.fetchTreatmentsBetween(start, end);
    await _mirror(treatments);
    return treatments;
  }

  @override
  Future<List<Treatment>> fetchTreatmentsOnDay(DateTime day) async {
    final treatments = await _delegate.fetchTreatmentsOnDay(day);
    await _mirror(treatments);
    return treatments;
  }

  Future<void> _mirror(Iterable<Treatment> treatments) async {
    try {
      await _mirrorWriter.mirrorTreatments(treatments, _source);
    } catch (e, st) {
      logW('Treatment local mirror write failed: $e\n$st');
    }
  }
}
