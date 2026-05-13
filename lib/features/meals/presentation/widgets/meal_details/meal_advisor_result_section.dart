import 'package:flutter/material.dart';
import '../../../../meal_advisor/domain/utils/extended_carbs_schedule_formatter.dart';
import '../../../../meal_advisor/domain/utils/extended_carbs_schedule_settings.dart';
import '../../../data/models/meal_details_data.dart';
import 'meal_detail_components.dart';
import 'meal_detail_formatters.dart';

class MealAdvisorResultSection extends StatelessWidget {
  final MealDetailsData details;

  const MealAdvisorResultSection({super.key, required this.details});

  @override
  Widget build(BuildContext context) {
    final decision = details.advisorDecision;

    return MealSectionTile(
      title: 'Decyzja Meal Advisora',
      children: [
        if (decision == null)
          const MealInfoRow(label: 'Wynik', value: '-')
        else ...[
          MealInfoRow(label: 'Wynik', value: decision.result),
          MealInfoRow(
            label: 'Początkowe czekanie',
            value: '${decision.initialWaitTime} min',
          ),
          MealInfoRow(
            label: 'Finalne czekanie',
            value: '${decision.finalWaitTime} min',
          ),
          MealInfoRow(
            label: 'Czekanie pominięte',
            value: decision.waitTimeIgnored ? 'tak' : 'nie',
          ),
          MealInfoRow(
            label: 'Rodzaj obsługi WBT',
            value: _wbtDeliveryModeValue(decision),
          ),
          MealInfoRow(
            label: 'Czas do startu uwalniania',
            value: _wbtReleaseStartValue(decision),
          ),
          MealInfoRow(
            label: 'Czas trwania uwalniania',
            value: _wbtReleaseDurationValue(decision),
          ),
          MealInfoRow(label: 'Wersja', value: decision.version.toString()),
          MealInfoRow(
            label: 'Utworzono',
            value: mealDateTime(decision.createdAt),
          ),
          MealInfoRow(
            label: 'Zaktualizowano',
            value: mealDateTime(decision.updatedAt),
          ),
        ],
      ],
    );
  }

  String _wbtDeliveryModeValue(MealAdvisorDecisionData decision) {
    if (decision.extendedCarbsGrams <= 0) return 'Brak';

    return switch (_scheduleSettings(decision)?.deliveryMode) {
      ExtendedCarbsDeliveryMode.extendedCarbs => 'Extended carbs',
      ExtendedCarbsDeliveryMode.extraBolus => 'Dodatkowy bolus',
      null => 'Brak konfiguracji',
    };
  }

  String _wbtReleaseStartValue(MealAdvisorDecisionData decision) {
    if (decision.extendedCarbsGrams <= 0) return '-';
    final scheduleSettings = _scheduleSettings(decision);
    if (scheduleSettings == null) return '-';

    return formatExtendedCarbsScheduleMinutes(scheduleSettings.delayMinutes);
  }

  String _wbtReleaseDurationValue(MealAdvisorDecisionData decision) {
    if (decision.extendedCarbsGrams <= 0) return '-';
    final scheduleSettings = _scheduleSettings(decision);
    if (scheduleSettings == null ||
        scheduleSettings.deliveryMode == ExtendedCarbsDeliveryMode.extraBolus) {
      return '-';
    }

    return formatExtendedCarbsScheduleMinutes(scheduleSettings.durationMinutes);
  }

  ExtendedCarbsScheduleSettings? _scheduleSettings(
    MealAdvisorDecisionData decision,
  ) {
    final deliveryMode = decision.extendedCarbsDeliveryMode;
    final delayMinutes = decision.extendedCarbsDelayMinutes;
    final durationMinutes = decision.extendedCarbsDurationMinutes;

    if (deliveryMode == null ||
        delayMinutes == null ||
        durationMinutes == null) {
      return null;
    }

    return ExtendedCarbsScheduleSettings(
      deliveryMode: ExtendedCarbsDeliveryMode.values.firstWhere(
        (mode) => mode.name == deliveryMode,
        orElse: () => ExtendedCarbsDeliveryMode.extendedCarbs,
      ),
      delayMinutes: delayMinutes,
      durationMinutes: durationMinutes,
    );
  }
}
