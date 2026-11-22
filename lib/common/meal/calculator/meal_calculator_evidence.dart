import '../../../core/notifications/domain/events/aaps_bolus_suggestion_notification.dart';
import '../../../features/meal_advisor/domain/utils/extended_carbs_schedule_settings.dart';

/// Conservative matching: ambiguous or unsupported evidence keeps the card open.
class MealCalculatorEvidence {
  MealCalculatorEvidence({
    required this.event,
    required this.openedAt,
    this.allowPartialOrSurplus = true,
  });

  final AapsBolusSuggestionNotificationEvent event;
  final DateTime openedAt;
  final bool allowPartialOrSurplus;
  final Map<String, Map<String, dynamic>> _extended = {};
  List<Map<String, dynamic>> _submissions = const [];
  List<int> _mealWizardTimes = const [];

  bool update(Map<String, dynamic> payload) {
    _mealWizardTimes =
        (payload['mealWizardTimes'] as List?)?.whereType<int>().toList() ??
        const [];
    _submissions = (payload['submissions'] as List)
        .map((item) => Map<String, dynamic>.from(item as Map))
        .where(
          (row) =>
              row['at'] >= openedAt.millisecondsSinceEpoch &&
              row['at'] <=
                  openedAt
                      .add(const Duration(minutes: 20))
                      .millisecondsSinceEpoch &&
              row['carbs'] is num &&
              (row['carbs'] as num).isFinite &&
              (row['carbs'] as num) > 0,
        )
        .toList();
    final incoming = <Map>[
      ...?((payload['extendedCarbs'] as List?)?.cast<Map>()),
      if (payload['extendedCarb'] case final Map carb) carb,
    ];
    for (final carb in incoming) {
      final row = Map<String, dynamic>.from(carb);
      if (row['observedAt'] case final int observed) {
        if (observed < openedAt.millisecondsSinceEpoch) continue;
      }
      final id = row['id'];
      final at = row['at'];
      if (id != null) {
        // The same local record may later acquire its Nightscout ID.
        _extended.removeWhere(
          (_, known) => known['id'] == null && known['at'] == at,
        );
      }
      final existing = id == null
          ? _extended.entries.where((entry) => entry.value['at'] == at).toList()
          : const <MapEntry<String, Map<String, dynamic>>>[];
      final key =
          id?.toString() ??
          (existing.length == 1 ? existing.single.key : 'at:$at');
      if (id == null && existing.length == 1) {
        row['id'] = existing.single.value['id'];
      }
      _extended[key] = row;
    }
    bolusConfirmed = event.carbs == 0;
    carbsEntered = false;
    extendedCarbsConfirmed = event.extendedCarbs <= 0;
    extendedCarbsSurplus = false;
    if (event.carbs < 0) {
      // Negative corrections are carb entries, never bolus calculator results.
      bolusConfirmed =
          _extended.values
              .where(
                (row) =>
                    row['valid'] == true &&
                    row['carbs'] == event.carbs &&
                    row['duration'] == 0 &&
                    row['at'] >= openedAt.millisecondsSinceEpoch &&
                    row['at'] <=
                        openedAt
                            .add(const Duration(minutes: 20))
                            .millisecondsSinceEpoch,
              )
              .length ==
          1;
      return bolusConfirmed && extendedCarbsConfirmed;
    }
    if (event.carbs == 0 && event.extendedCarbs <= 0) {
      return false;
    }
    final started = openedAt.millisecondsSinceEpoch;
    final deadline = openedAt
        .add(const Duration(minutes: 20))
        .millisecondsSinceEpoch;
    final matching = _submissions
        .where(
          (row) =>
              row['at'] >= started &&
              row['at'] <= deadline &&
              row['valid'] == true,
        )
        .toList();
    final enteredCarbs = matching.fold<num>(
      0,
      (sum, row) => sum + (row['carbs'] as num),
    );
    final deliveredCarbs = matching
        .where((row) => row['complete'] == true)
        .fold<num>(0, (sum, row) => sum + (row['carbs'] as num));
    bool meets(num actual, num expected) => allowPartialOrSurplus
        ? actual >= expected - 0.001
        : (actual - expected).abs() <= 0.001;
    final unambiguousCalculator = allowPartialOrSurplus || matching.length == 1;
    carbsEntered =
        event.carbs > 0 &&
        unambiguousCalculator &&
        meets(enteredCarbs, event.carbs);
    bolusConfirmed =
        event.carbs == 0 ||
        (payload.containsKey('mealBolusConfirmed')
            ? payload['mealBolusConfirmed'] == true
            : unambiguousCalculator && meets(deliveredCarbs, event.carbs));
    if (event.extendedCarbs > 0 &&
        event.extendedCarbsDeliveryMode !=
            ExtendedCarbsDeliveryMode.extraBolus) {
      final delay = event.extendedCarbsDelayMinutes;
      final duration = event.extendedCarbsDurationMinutes;
      if (delay != null && duration != null) {
        final anchor =
            payload['mealWizardAt'] as int? ??
            (matching.isNotEmpty ? matching.first['at'] as int : started);
        final expectedStarts =
            (_mealWizardTimes.isEmpty ? [anchor] : _mealWizardTimes)
                .map((at) => at + Duration(minutes: delay).inMilliseconds)
                .toList();
        final scheduledRows = _extended.values
            .where(
              (row) =>
                  row['valid'] == true &&
                  row['carbs'] is num &&
                  (row['carbs'] as num).isFinite &&
                  (row['carbs'] as num) > 0 &&
                  row['duration'] ==
                      Duration(minutes: duration).inMilliseconds &&
                  expectedStarts.any(
                    (expected) =>
                        ((row['at'] as int) - expected).abs() <=
                        const Duration(minutes: 2).inMilliseconds,
                  ),
            )
            .toList();
        final uniqueStarts = scheduledRows.map((row) => row['at']).toSet();
        if (uniqueStarts.length != scheduledRows.length) return false;
        final scheduledCarbs = scheduledRows.fold<num>(
          0,
          (sum, row) => sum + (row['carbs'] as num),
        );
        extendedCarbsConfirmed = meets(scheduledCarbs, event.extendedCarbs);
        extendedCarbsSurplus = scheduledCarbs > event.extendedCarbs + 0.001;
      }
    }
    return bolusConfirmed && extendedCarbsConfirmed;
  }

  bool bolusConfirmed = false;
  bool carbsEntered = false;
  bool extendedCarbsConfirmed = false;
  bool extendedCarbsSurplus = false;

  Map<String, dynamic> get evidence => {
    'submissions': _submissions,
    'extendedCarbs': _extended.values.toList(),
    if (_mealWizardTimes.isNotEmpty) 'mealWizardTimes': _mealWizardTimes,
  };
}
