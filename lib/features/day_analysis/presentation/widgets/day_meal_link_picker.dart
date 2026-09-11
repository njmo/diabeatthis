import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../meals/common/models/meal_wizard_relation_type.dart';
import '../../../meals/presentation/helpers/meal_wizard_relation_label.dart';
import '../../data/providers/day_meal_review_provider.dart';

class DayMealLinkPicker extends ConsumerStatefulWidget {
  final DateTime date;
  const DayMealLinkPicker({super.key, required this.date});

  @override
  ConsumerState<DayMealLinkPicker> createState() => DayMealLinkPickerState();
}

class DayMealLinkPickerState extends ConsumerState<DayMealLinkPicker> {
  MealWizardRelationType type = MealWizardRelationType.initial;

  @override
  Widget build(BuildContext context) {
    final provider = dayMealCandidatesProvider(widget.date);
    final meals = ref.watch(provider);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Połącz z posiłkiem',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text(
              'Posiłki z wybranego dnia, także zaplanowane i pominięte. Wybierz, czego dotyczył ten wpis kalkulatora.',
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<MealWizardRelationType>(
              initialValue: type,
              decoration: const InputDecoration(labelText: 'Rodzaj wpisu'),
              items: MealWizardRelationType.values
                  .map(
                    (value) => DropdownMenuItem(
                      value: value,
                      child: Text(value.label),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) setState(() => type = value);
              },
            ),
            const SizedBox(height: 12),
            Flexible(
              child: meals.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, _) => TextButton(
                  onPressed: () => ref.invalidate(provider),
                  child: const Text(
                    'Nie udało się pobrać posiłków. Spróbuj ponownie',
                  ),
                ),
                data: (items) => items.isEmpty
                    ? const Text(
                        'Brak zapisanych posiłków. Możesz dodać posiłek wstecz.',
                      )
                    : ListView(
                        shrinkWrap: true,
                        children: [
                          ...items.reversed.map(
                            (meal) => ListTile(
                              title: Text(meal.name),
                              subtitle: Text(
                                DateFormat('dd.MM HH:mm').format(meal.eatenAt),
                              ),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () => Navigator.of(context).pop((
                                mealId: meal.id,
                                type: type,
                                requiresCompletion: meal.requiresCompletion,
                              )),
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
