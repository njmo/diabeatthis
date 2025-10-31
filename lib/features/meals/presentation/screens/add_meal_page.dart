import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../data/providers/meal_provider.dart';
import '../widgets/meal_ingredients_list_editor.dart';

@RoutePage()
class AddMealPage extends ConsumerWidget {
  const AddMealPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mealDraft = ref.watch(mealDraftProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Add Meal Page')),
      body: Column(
        children: [
          Center(
            child: SafeArea(
              child: Column(
                children: [
                  SingleChildScrollView(
                    child: MealIngredientsListEditor(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
