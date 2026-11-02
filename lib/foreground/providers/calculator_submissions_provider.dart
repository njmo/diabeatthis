import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../common/meal/meal_calculator_submission.dart';
import '../../common/treatments/calculator_submission.dart';
import '../../common/treatments/merge_calculator_submission_wizard.dart';
import '../../core/domain/model/bolus_wizard.dart';
import '../../core/domain/model/manual_bolus.dart';
import '../../core/domain/model/treat.dart';
import '../../core/domain/model/treatment_base.dart';

final calculatorSubmissionsProvider =
    NotifierProvider<CalculatorSubmissions, List<CalculatorSubmission>>(
      CalculatorSubmissions.new,
    );

class CalculatorSubmissions extends Notifier<List<CalculatorSubmission>> {
  final Map<(Type, int), Treatment> _records = {};
  static const retention = Duration(hours: 24);

  @override
  List<CalculatorSubmission> build() => const [];

  Iterable<Treatment> get records => List.unmodifiable([
    ..._records.values.where((record) => record is! BolusWizard),
    ...state.map((submission) => submission.wizard),
  ]);

  List<CalculatorSubmission> record(Treatment treatment) {
    final type = switch (treatment) {
      BolusWizard() => BolusWizard,
      ManualBolus() => ManualBolus,
      Treat() => Treat,
      _ => null,
    };
    final time = treatment.createdAt;
    if (type == null || time == null) return const [];
    final key = (type, time.millisecondsSinceEpoch);
    final previous = _records[key];
    var accepted = treatment;
    if (treatment is BolusWizard) {
      for (final known in _records.values.whereType<BolusWizard>()) {
        if (known.createdAt.isAtSameMomentAs(treatment.createdAt)) continue;
        final sameLocal =
            known.localId != null && known.localId == treatment.localId;
        final sameRemote =
            known.nightscoutObjectId != null &&
            known.nightscoutObjectId == treatment.nightscoutObjectId &&
            (known.remoteSource == null ||
                treatment.remoteSource == null ||
                known.remoteSource == treatment.remoteSource);
        if (sameLocal || sameRemote) return const [];
      }
      if (previous is BolusWizard) {
        final merged = mergeCalculatorSubmissionWizard(previous, treatment);
        if (merged == null) return const [];
        accepted = merged;
      }
    }
    _records[key] = accepted;
    final latest = _records.keys
        .map((key) => key.$2)
        .reduce((a, b) => a > b ? a : b);
    final earliest = latest - retention.inMilliseconds;
    _records.removeWhere((key, _) => key.$2 < earliest);
    final submissions =
        _records.values
            .whereType<BolusWizard>()
            .map(
              (wizard) =>
                  resolveMealCalculatorSubmission(wizard, _records.values),
            )
            .toList()
          ..sort((a, b) => a.key.compareTo(b.key));
    final changes = submissions.where((item) => !state.contains(item)).toList();
    if (changes.isNotEmpty || submissions.length != state.length) {
      state = List.unmodifiable(submissions);
    }
    return changes;
  }
}
