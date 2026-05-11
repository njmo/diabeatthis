import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../data/model/copied_meal_type.dart';
import '../../data/providers/copied_meal_provider.dart';

class CopiedMealPicker extends HookConsumerWidget {
  const CopiedMealPicker({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = useState('');
    final templates = ref.watch(copiedFromMealByQueryProvider(query.value));
    final meals = ref.watch(copiedFromMealTemplateByQueryProvider(query.value));

    final copiedMeals = [...?templates.value, ...?meals.value];
    copiedMeals.sort((a, b) => b.date.compareTo(a.date));

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16,
        right: 16,
        top: 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            onChanged: (value) {
              query.value = value;
            },
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Nazwa posiłku lub szablonu',
              icon: Icon(Icons.search),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 300),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: copiedMeals.length,
              itemBuilder: (BuildContext context, int index) {
                final copiedMeal = copiedMeals[index];
                final name = copiedMeal is CopiedMealFromMeal
                    ? 'Posiłek - ${copiedMeal.name}'
                    : 'Szablon - ${copiedMeal.name}';
                return ListTile(
                  title: Text(name),
                  subtitle: Text(copiedMeal.date.toIso8601String()),
                  onTap: () {
                    Navigator.of(context).pop(copiedMeal);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
