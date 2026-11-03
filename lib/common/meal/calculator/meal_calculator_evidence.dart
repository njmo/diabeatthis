import '../../../core/notifications/domain/events/aaps_bolus_suggestion_notification.dart';
import '../../../features/meal_advisor/domain/utils/extended_carbs_schedule_settings.dart';

/// Conservative matching: ambiguous or unsupported evidence keeps the card open.
class MealCalculatorEvidence {
  MealCalculatorEvidence({required this.event, required this.openedAt});

  final AapsBolusSuggestionNotificationEvent event;
  final DateTime openedAt;
  final Map<String, Map<String, dynamic>> _extended = {};
  List<Map<String, dynamic>> _submissions = const [];

  bool update(Map<String, dynamic> payload) {
    _submissions = (payload['submissions'] as List)
        .map((item) => Map<String, dynamic>.from(item as Map))
        .where(
          (row) =>
              row['at'] >= openedAt.millisecondsSinceEpoch &&
              row['at'] <=
                  openedAt
                      .add(const Duration(minutes: 20))
                      .millisecondsSinceEpoch &&
              ((row['carbs'] as num) - event.carbs).abs() < 0.001,
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
    extendedCarbsConfirmed = event.extendedCarbs <= 0;
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
              row['valid'] == true &&
              ((row['carbs'] as num) - event.carbs).abs() < 0.001,
        )
        .toList();
    bolusConfirmed =
        event.carbs == 0 ||
        (payload.containsKey('mealBolusConfirmed')
            ? payload['mealBolusConfirmed'] == true
            : matching.length == 1 && matching.single['complete'] == true);
    if (event.extendedCarbs > 0 &&
        event.extendedCarbsDeliveryMode !=
            ExtendedCarbsDeliveryMode.extraBolus) {
      final delay = event.extendedCarbsDelayMinutes;
      final duration = event.extendedCarbsDurationMinutes;
      if (delay != null && duration != null) {
        final anchor =
            payload['mealWizardAt'] as int? ??
            (matching.length == 1 ? matching.single['at'] as int : started);
        final expectedStart = anchor + Duration(minutes: delay).inMilliseconds;
        extendedCarbsConfirmed =
            _extended.values
                .where(
                  (row) =>
                      row['valid'] == true &&
                      row['carbs'] == event.extendedCarbs &&
                      row['duration'] ==
                          Duration(minutes: duration).inMilliseconds &&
                      ((row['at'] as int) - expectedStart).abs() <=
                          const Duration(minutes: 2).inMilliseconds,
                )
                .length ==
            1;
      }
    }
    return bolusConfirmed && extendedCarbsConfirmed;
  }

  bool bolusConfirmed = false;
  bool extendedCarbsConfirmed = false;

  Map<String, dynamic> get evidence => {
    'submissions': _submissions,
    'extendedCarbs': _extended.values.toList(),
  };
}
