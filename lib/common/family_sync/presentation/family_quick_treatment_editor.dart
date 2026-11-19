import 'package:flutter/material.dart';

import '../../../core/domain/model/quick_low_treatment_item.dart';
import '../../../features/ingredients/data/drafts/ingredient_draft.dart';
import '../../../features/meals/data/drafts/meal_draft.dart';
import '../../../features/portions/data/drafts/portion_draft.dart';
import '../../l10n/language.dart';
import '../../widgets/amount_entry_dialog.dart';

Future<List<Map<String, Object?>>?> showFamilyQuickTreatmentEditor(
  BuildContext context, {
  required List<Map<String, dynamic>> rows,
  required Future<MealIngredientsDraft?> Function(BuildContext) pickIngredient,
}) async {
  final items = [
    for (final row in rows)
      if (row['kind'] == 'quickLowTreatmentItems' && row['deleted'] != true)
        Map<String, Object?>.from(row['payload'] as Map),
  ]..sort((a, b) => (a['sort_order'] as int).compareTo(b['sort_order'] as int));
  var picking = false;
  return showModalBottomSheet<List<Map<String, Object?>>>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            height: MediaQuery.sizeOf(context).height * .55,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  context.lang.quickLowTreatmentItemsTitle,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ReorderableListView.builder(
                    itemCount: items.length,
                    onReorderItem: (oldIndex, newIndex) => setState(() {
                      items.insert(newIndex, items.removeAt(oldIndex));
                    }),
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return ListTile(
                        key: ObjectKey(item),
                        title: Text(item['name'] as String),
                        subtitle: Text('${item['amount']}'),
                        leading: IconButton(
                          tooltip: context.lang.ingredientEditAction,
                          icon: const Icon(Icons.edit_outlined),
                          onPressed: () async {
                            final amount = await showDialog<double>(
                              context: context,
                              builder: (_) => AmountEntryDialog(
                                value: (item['amount'] as num).toDouble(),
                                min: .001,
                              ),
                            );
                            if (context.mounted && amount != null) {
                              setState(() => item['amount'] = amount);
                            }
                          },
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline),
                          tooltip: MaterialLocalizations.of(
                            context,
                          ).deleteButtonTooltip,
                          onPressed: () =>
                              setState(() => items.removeAt(index)),
                        ),
                      );
                    },
                  ),
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.add),
                  label: Text(context.lang.lowTreatmentAddShortcut),
                  onPressed:
                      picking || items.length >= maxQuickLowTreatmentItems
                      ? null
                      : () async {
                          setState(() => picking = true);
                          MealIngredientsDraft? draft;
                          try {
                            draft = await pickIngredient(context);
                          } catch (_) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    context.lang.quickLowTreatmentSaveError,
                                  ),
                                ),
                              );
                            }
                          } finally {
                            if (context.mounted) {
                              setState(() => picking = false);
                            }
                          }
                          if (draft == null || !context.mounted) return;
                          final ingredient = draft.ingredient;
                          final amount = draft.amount;
                          final id = ingredient.getIngredientIdOrNull();
                          final portion = draft.ingredientPortion.portion
                              .maybeMap(
                                existing: (p) => p.id,
                                orElse: () => null,
                              );
                          if (id == null ||
                              (!ingredient.isReference && portion == null)) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  context
                                      .lang
                                      .familyQuickTreatmentChoosePortion,
                                ),
                              ),
                            );
                            return;
                          }
                          setState(
                            () => items.add({
                              'id': null,
                              'name': ingredient.name,
                              'ingredient_id': id,
                              'portion_id': portion,
                              'amount': amount,
                            }),
                          );
                        },
                ),
                FilledButton(
                  onPressed: picking
                      ? null
                      : () => Navigator.of(context).pop([
                          for (final item in items)
                            {
                              'id': item['id'],
                              'name': item['name'],
                              'ingredientId': item['ingredient_id'],
                              'portionId': item['portion_id'],
                              'amount': item['amount'],
                            },
                        ]),
                  child: Text(context.lang.commonDone),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
