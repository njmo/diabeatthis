import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ingredient_catalog/ingredient_catalog_providers.dart';
import '../../ingredient_catalog/ingredient_identity.dart';
import '../../l10n/language.dart';
import '../../meal/meal_category.dart';
import 'family_plan_time_field.dart';
import 'show_family_ingredient_picker.dart';

class FamilyMealPlanForm extends ConsumerStatefulWidget {
  const FamilyMealPlanForm({
    super.key,
    required this.rows,
    required this.onSubmit,
    this.initial,
  });
  final List<Map<String, dynamic>> rows;
  final Map<String, dynamic>? initial;
  final Future<void> Function(Map<String, dynamic>) onSubmit;
  @override
  ConsumerState<FamilyMealPlanForm> createState() => FamilyMealPlanFormState();
}

class FamilyMealPlanFormState extends ConsumerState<FamilyMealPlanForm> {
  late final name = TextEditingController(
    text: widget.initial?['name'] as String? ?? '',
  );
  late final notes = TextEditingController(
    text: widget.initial?['notes'] as String? ?? '',
  );
  late DateTime planned = DateTime.fromMillisecondsSinceEpoch(
    widget.initial?['plannedAt'] as int? ??
        DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch,
  );
  late MealCategory category =
      MealCategory.fromStorage(widget.initial?['category'] as String?) ??
      MealCategory.lunch;
  final amounts = <String, TextEditingController>{};
  final items = <String, Map<String, dynamic>>{};
  final labels = <String, String>{};
  final reviewedCatalog = <String>{};
  final referenceKeys = <String>{};
  double grams(String key, String value) =>
      (double.tryParse(value.replaceAll(',', '.')) ?? 0.0) *
      (referenceKeys.contains(key) ? 100 : 1);
  bool busy = false;
  bool failed = false;
  @override
  void initState() {
    super.initState();
    for (final raw in widget.initial?['ingredients'] as List? ?? const []) {
      final item = Map<String, dynamic>.from(raw as Map);
      final key = item['ingredientId'] == null
          ? 'catalog:${item['catalogId']}'
          : 'local:${item['ingredientId']}';
      items[key] = {
        'ingredientId': item['ingredientId'],
        'catalogId': item['catalogId'],
        'catalogRevision': item['catalogRevision'],
      };
      if (widget.rows.any(
        (r) =>
            r['kind'] == 'ingredients' &&
            r['id'] == '${item['ingredientId']}' &&
            (r['payload'] as Map)['is_reference'] == 1,
      )) {
        referenceKeys.add(key);
      }
      amounts[key] = TextEditingController(
        text:
            '${(item['grams'] as num) / (referenceKeys.contains(key) ? 100 : 1)}',
      );
      labels[key] =
          widget.rows
              .where(
                (r) =>
                    r['kind'] == 'ingredients' &&
                    r['id'] == '${item['ingredientId']}',
              )
              .map((r) => (r['payload'] as Map)['name'] as String)
              .firstOrNull ??
          '${item['catalogId']}';
    }
  }

  @override
  void dispose() {
    name.dispose();
    notes.dispose();
    for (final c in amounts.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> addIngredient() async {
    final catalog = ref.read(catalogRepositoryProvider);
    final selected = await showFamilyIngredientPicker(
      context,
      rows: widget.rows,
      catalog: catalog,
    );
    if (selected == null || !mounted) return;
    setState(() => busy = true);
    try {
      final localId = selected.localIngredientId;
      final key = localId == null
          ? 'catalog:${selected.identity.sourceId}'
          : 'local:$localId';
      String? revision;
      if (localId == null) {
        if (selected.identity.source != IngredientSource.firebase) {
          throw StateError('Unsupported catalog source');
        }
        revision = (await catalog.get(
          selected.identity,
          languageCode: Localizations.localeOf(context).languageCode,
        )).revision;
      }
      if (!mounted) return;
      setState(() {
        if (localId == null) reviewedCatalog.add(key);
        items[key] = {
          'ingredientId': localId,
          'catalogId': localId == null ? selected.identity.sourceId : null,
          'catalogRevision': revision,
        };
        labels[key] = selected.name;
        if (selected.isReference) referenceKeys.add(key);
        amounts.putIfAbsent(
          key,
          () => TextEditingController(text: selected.isReference ? '1' : '100'),
        );
      });
    } catch (_) {
      if (mounted) setState(() => failed = true);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.all(20),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          context.lang.familyPlanMeal,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        TextField(
          controller: name,
          maxLength: 120,
          decoration: InputDecoration(labelText: context.lang.familyPlanName),
        ),
        DropdownButtonFormField<MealCategory>(
          initialValue: category,
          items: [
            for (final value in MealCategory.values)
              DropdownMenuItem(
                value: value,
                child: Text(value.label(context.lang)),
              ),
          ],
          onChanged: busy
              ? null
              : (value) {
                  if (value != null) setState(() => category = value);
                },
        ),
        FamilyPlanTimeField(
          value: planned,
          onChanged: (v) => setState(() => planned = v),
          label: context.lang.familyPlanTime,
        ),
        OutlinedButton.icon(
          onPressed: busy || amounts.length >= 30 ? null : addIngredient,
          icon: const Icon(Icons.add),
          label: Text(context.lang.familyPlanAddIngredient),
        ),
        for (final item in amounts.entries)
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: item.value,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: labels[item.key],
                    suffixText: referenceKeys.contains(item.key)
                        ? context.lang.mealPortionLabel
                        : 'g',
                  ),
                ),
              ),
              IconButton(
                onPressed: busy
                    ? null
                    : () {
                        setState(() {
                          amounts.remove(item.key)?.dispose();
                          items.remove(item.key);
                          labels.remove(item.key);
                        });
                      },
                icon: const Icon(Icons.close),
              ),
            ],
          ),
        TextField(
          controller: notes,
          maxLength: 2000,
          decoration: InputDecoration(labelText: context.lang.familyPlanNotes),
        ),
        if (items.entries.any(
          (entry) =>
              entry.value['catalogId'] != null &&
              !reviewedCatalog.contains(entry.key),
        ))
          Text(context.lang.familyPlanReviewCatalog),
        Text(context.lang.familyPlanPendingExplanation),
        if (failed)
          Text(
            context.lang.familyPlanFailed,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: busy
              ? null
              : () async {
                  final ingredients = [
                    for (final e in amounts.entries)
                      {...items[e.key]!, 'grams': grams(e.key, e.value.text)},
                  ];
                  if (name.text.trim().isEmpty ||
                      ingredients.isEmpty ||
                      items.entries.any(
                        (entry) =>
                            entry.value['catalogId'] != null &&
                            !reviewedCatalog.contains(entry.key),
                      ) ||
                      ingredients.any(
                        (r) =>
                            !(r['grams'] as double).isFinite ||
                            (r['grams'] as double) <= 0 ||
                            (r['grams'] as double) > 10000,
                      ) ||
                      !planned.isAfter(DateTime.now())) {
                    setState(() => failed = true);
                    return;
                  }
                  setState(() {
                    busy = true;
                    failed = false;
                  });
                  try {
                    await widget.onSubmit({
                      'name': name.text.trim(),
                      'category': category.name,
                      'plannedAt': planned.millisecondsSinceEpoch,
                      'notes': notes.text.trim(),
                      'ingredients': ingredients,
                    });
                    if (context.mounted) Navigator.of(context).pop();
                  } catch (_) {
                    if (mounted) setState(() => failed = true);
                  } finally {
                    if (mounted) setState(() => busy = false);
                  }
                },
          child: Text(context.lang.familyPlanSend),
        ),
      ],
    ),
  );
}
