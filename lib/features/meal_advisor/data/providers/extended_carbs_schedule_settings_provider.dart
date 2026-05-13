import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/data/provider/shared_prefs_provider.dart';
import '../../domain/utils/extended_carbs_schedule_settings.dart';

const _delayMinutesKey = 'meal_advisor_extended_carbs_delay_minutes';
const _durationMinutesKey = 'meal_advisor_extended_carbs_duration_minutes';

final extendedCarbsScheduleSettingsProvider =
    FutureProvider<ExtendedCarbsScheduleSettings>((ref) async {
      final prefs = await ref.watch(sharedPrefsProvider.future);
      const defaults = ExtendedCarbsScheduleSettings.defaults();

      return ExtendedCarbsScheduleSettings(
        delayMinutes: prefs.getInt(_delayMinutesKey) ?? defaults.delayMinutes,
        durationMinutes:
            prefs.getInt(_durationMinutesKey) ?? defaults.durationMinutes,
      );
    });

final extendedCarbsScheduleSettingsControllerProvider =
    Provider<ExtendedCarbsScheduleSettingsController>((ref) {
      return ExtendedCarbsScheduleSettingsController(ref);
    });

class ExtendedCarbsScheduleSettingsController {
  final Ref ref;

  const ExtendedCarbsScheduleSettingsController(this.ref);

  Future<void> save(ExtendedCarbsScheduleSettings settings) async {
    final prefs = await ref.read(sharedPrefsProvider.future);
    await prefs.setInt(_delayMinutesKey, settings.delayMinutes);
    await prefs.setInt(_durationMinutesKey, settings.durationMinutes);
    ref.invalidate(extendedCarbsScheduleSettingsProvider);
  }
}
