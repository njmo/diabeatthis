import 'package:flutter/material.dart';

import '../../../../../common/l10n/language.dart';
import '../../../../../common/meal/meal_decision.dart';
import '../../../../../common/widgets/form_section.dart';
import '../../../../../common/widgets/manual_meal_decision_fields.dart';
import '../../../data/models/retrospective_meal_timing.dart';

class RetrospectiveMealFields extends StatelessWidget {
  final String? subtitle;
  final RetrospectiveMealTiming value;
  final ValueChanged<RetrospectiveMealTiming> onChanged;
  const RetrospectiveMealFields({
    super.key,
    this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => FormSection(
    icon: Icons.history,
    title: context.lang.uiMealSequence,
    subtitle: subtitle ?? context.lang.mealRetrospectiveFullPortionNote,
    children: [
      TextFormField(
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          labelText: context.lang.uiHowLongDidEatingTakeMin,
        ),
        validator: (text) => (int.tryParse(text ?? '') ?? 0) > 0
            ? null
            : context.lang.uiEnterAPositiveNumberOfMinutes,
        onChanged: (text) =>
            onChanged(value.copyWith(eatingMinutes: int.tryParse(text) ?? 0)),
      ),
      const SizedBox(height: 12),
      ManualMealDecisionFields(
        value: value.choice,
        onChanged: (choice) => onChanged(value.copyWith(choice: choice)),
      ),
      if (value.choice.decision == MealDecision.eatNowBolusLater) ...[
        const SizedBox(height: 12),
        TextFormField(
          initialValue: value.bolusAfterStartMinutes == 0
              ? ''
              : '${value.bolusAfterStartMinutes}',
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: context.lang.uiInsulinHowManyMinutesAfterEatingStarted,
          ),
          validator: (text) => (int.tryParse(text ?? '') ?? 0) <= 0
              ? context.lang.uiEnterAPositiveNumberOfMinutes
              : null,
          onChanged: (text) => onChanged(
            value.copyWith(bolusAfterStartMinutes: int.tryParse(text) ?? 0),
          ),
        ),
      ],
    ],
  );
}
