import 'package:flutter/material.dart';
import '../../../../../common/l10n/language.dart';
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
      title: context.lang.mealAdvisorDecisionTitle,
      children: [
        if (decision == null)
          MealInfoRow(label: context.lang.mealAdvisorResultLabel, value: '-')
        else ...[
          MealInfoRow(
            label: context.lang.mealAdvisorResultLabel,
            value: decision.result,
          ),
          MealInfoRow(
            label: context.lang.mealAdvisorInitialWaitLabel,
            value: '${decision.initialWaitTime} min',
          ),
          MealInfoRow(
            label: context.lang.mealAdvisorFinalWaitLabel,
            value: '${decision.finalWaitTime} min',
          ),
          MealInfoRow(
            label: context.lang.mealAdvisorWaitIgnoredLabel,
            value: decision.waitTimeIgnored
                ? context.lang.commonYes
                : context.lang.commonNo,
          ),
          MealInfoRow(
            label: context.lang.mealAdvisorWbtModeLabel,
            value: _wbtDeliveryModeValue(context, decision),
          ),
          MealInfoRow(
            label: context.lang.mealAdvisorReleaseStartLabel,
            value: _wbtReleaseStartValue(decision),
          ),
          MealInfoRow(
            label: context.lang.mealAdvisorReleaseDurationLabel,
            value: _wbtReleaseDurationValue(decision),
          ),
          MealInfoRow(
            label: context.lang.mealAdvisorVersionLabel,
            value: decision.version.toString(),
          ),
          MealInfoRow(
            label: context.lang.mealAdvisorCreatedLabel,
            value: mealDateTime(decision.createdAt),
          ),
          MealInfoRow(
            label: context.lang.mealAdvisorUpdatedLabel,
            value: mealDateTime(decision.updatedAt),
          ),
        ],
      ],
    );
  }

  String _wbtDeliveryModeValue(
    BuildContext context,
    MealAdvisorDecisionData decision,
  ) {
    if (decision.extendedCarbsGrams <= 0) return context.lang.commonNone;

    return switch (_scheduleSettings(decision)?.deliveryMode) {
      ExtendedCarbsDeliveryMode.extendedCarbs => 'Extended carbs',
      ExtendedCarbsDeliveryMode.extraBolus =>
        context.lang.mealAdvisorExtraBolus,
      null => context.lang.mealAdvisorNoConfiguration,
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
