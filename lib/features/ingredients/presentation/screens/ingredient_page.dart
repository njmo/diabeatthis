import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controllers/ingredient_details_controller.dart';

@RoutePage()
class IngredientPage extends ConsumerWidget {
  final int ingredientId;

  const IngredientPage({super.key, required this.ingredientId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(ingredientDetailsControllerProvider(ingredientId));

    return Scaffold(
      appBar: AppBar(title: Text('Składnik $ingredientId')),
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('error: $e')),
        data: (s) => SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                s.data.ingredient.name,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 4),
              Text(
                s.data.ingredient.brand ?? 'Bez marki',
                style: Theme.of(context).textTheme.bodyMedium,
              ),

              const SizedBox(height: 16),

              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      ListTile(
                        dense: true,
                        title: const Text('Kalorie'),
                        trailing: Text('${s.data.ingredient.kcalPer100g} kcal'),
                      ),
                      ListTile(
                        dense: true,
                        title: const Text('WBT'),
                        trailing: Text(
                          '${s.data.ingredient.wbtKcalPer100g} kcal',
                        ),
                      ),
                      ListTile(
                        dense: true,
                        title: const Text('Net'),
                        trailing: Text(
                          '${s.data.ingredient.netKcalPer100g} kcal',
                        ),
                      ),
                      const Divider(),
                      ListTile(
                        dense: true,
                        title: const Text('Węglowodany'),
                        trailing: Text('${s.data.ingredient.carbsPer100g} g'),
                      ),
                      ListTile(
                        dense: true,
                        title: const Text('Tłuszcz'),
                        trailing: Text('${s.data.ingredient.fatPer100g} g'),
                      ),
                      ListTile(
                        dense: true,
                        title: const Text('Błonnik'),
                        trailing: Text('${s.data.ingredient.fiberPer100g} g'),
                      ),
                      ListTile(
                        dense: true,
                        title: const Text('Białko'),
                        trailing: Text('${s.data.ingredient.proteinPer100g} g'),
                      ),
                      const Divider(),
                      ListTile(
                        dense: true,
                        title: const Text('IG'),
                        trailing: Text('${s.data.ingredient.ig ?? '-'}'),
                      ),
                      ListTile(
                        dense: true,
                        title: const Text('Przygotowanie'),
                        trailing: Text(s.data.ingredient.preparation ?? '-'),
                      ),
                      ListTile(
                        dense: true,
                        title: const Text('Confidence'),
                        trailing: Text(
                          '${s.data.ingredient.nutritionConfidence}',
                        ),
                      ),
                      ListTile(
                        dense: true,
                        title: const Text('Referencyjny'),
                        trailing: Text(
                          s.data.ingredient.isReference ? 'Tak' : 'Nie',
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),
              Text(
                'Zdefiniowane porcje',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),

              if (s.data.portions.isEmpty)
                const Card(
                  child: ListTile(title: Text('Brak zdefiniowanych porcji')),
                )
              else
                ...s.data.portions.map((portion) {
                  return Card(
                    child: ListTile(
                      title: Text(portion.name),
                      subtitle: Text(portion.unitHint),
                      trailing: Text(
                        '${portion.gramsPerPortion.toStringAsFixed(2)} g',
                      ),
                    ),
                  );
                }),

              const SizedBox(height: 24),
              Text(
                'Użyty w posiłkach',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),

              if (s.data.usages.isEmpty)
                const Card(
                  child: ListTile(
                    title: Text('Nie użyto jeszcze w żadnym posiłku'),
                  ),
                )
              else
                ...s.data.usages.map((meal) {
                  return Card(
                    child: ListTile(
                      title: Text(meal.name),
                      subtitle: Text(meal.description),
                      trailing: Text(
                        '${meal.plannedAt.day}.${meal.plannedAt.month}.${meal.plannedAt.year}',
                      ),
                    ),
                  );
                }),
            ],
          ),
        ),
      ),
    );
  }
}
