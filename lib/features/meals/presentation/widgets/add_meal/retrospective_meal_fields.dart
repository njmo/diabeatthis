import 'package:flutter/material.dart';

import '../../../../../common/meal/meal_decision.dart';
import '../../../../../common/widgets/form_section.dart';
import '../../../../../common/widgets/manual_meal_decision_fields.dart';
import '../../../data/models/retrospective_meal_timing.dart';

class RetrospectiveMealFields extends StatelessWidget {
  final RetrospectiveMealTiming value;
  final ValueChanged<RetrospectiveMealTiming> onChanged;
  const RetrospectiveMealFields({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => FormSection(
    icon: Icons.history,
    title: 'Przebieg posiłku',
    subtitle:
        'Zjedzono całość zgodnie z planem, bez dokładki. Decyzja zostanie zapisana jako ręczna.',
    children: [
      TextFormField(
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(
          labelText: 'Jak długo trwało jedzenie? (min)',
        ),
        validator: (text) => (int.tryParse(text ?? '') ?? 0) > 0
            ? null
            : 'Podaj dodatnią liczbę minut.',
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
          decoration: const InputDecoration(
            labelText: 'Insulina: ile minut po rozpoczęciu jedzenia?',
          ),
          validator: (text) => (int.tryParse(text ?? '') ?? 0) <= 0
              ? 'Podaj dodatnią liczbę minut.'
              : null,
          onChanged: (text) => onChanged(
            value.copyWith(bolusAfterStartMinutes: int.tryParse(text) ?? 0),
          ),
        ),
      ],
    ],
  );
}
