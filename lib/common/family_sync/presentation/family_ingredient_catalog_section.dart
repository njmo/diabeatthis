import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/domain/model/carbs_label_mode.dart';
import '../../ingredient_catalog/ingredient_catalog_providers.dart';
import '../../l10n/language.dart';
import 'family_ingredient_details_dialog.dart';
import 'show_family_ingredient_picker.dart';

/// Read-only catalog: selection never writes patient data on the caregiver.
class FamilyIngredientCatalogSection extends ConsumerStatefulWidget {
  const FamilyIngredientCatalogSection({super.key, required this.rows});
  final List<Map<String, dynamic>> rows;
  @override
  ConsumerState<FamilyIngredientCatalogSection> createState() =>
      FamilyIngredientCatalogSectionState();
}

class FamilyIngredientCatalogSectionState
    extends ConsumerState<FamilyIngredientCatalogSection> {
  bool busy = false;
  bool failed = false;
  Future<void> preview(Map<String, dynamic> data) => showDialog<void>(
    context: context,
    builder: (_) => FamilyIngredientDetailsDialog(data: data),
  );
  Future<void> search() async {
    final catalog = ref.read(catalogRepositoryProvider);
    final language = Localizations.localeOf(context).languageCode;
    final item = await showFamilyIngredientPicker(
      context,
      rows: widget.rows,
      catalog: catalog,
    );
    if (item == null || !mounted) return;
    setState(() {
      busy = true;
      failed = false;
    });
    try {
      Map<String, dynamic> data;
      if (item.localIngredientId != null) {
        data = Map<String, dynamic>.from(
          widget.rows.singleWhere(
                (row) =>
                    row['kind'] == 'ingredients' &&
                    row['id'] == '${item.localIngredientId}',
              )['payload']
              as Map,
        );
      } else {
        final food = await catalog.get(item.identity, languageCode: language);
        data = {
          'name': food.name,
          'is_reference': 0,
          'carbs_label_mode': food.carbsLabelMode.storageValue,
          'carbs_per_100g': food.carbsPer100g,
          'fat_per_100g': food.fatPer100g,
          'protein_per_100g': food.proteinPer100g,
          'fiber_per_100g': food.fiberPer100g,
        };
      }
      if (!mounted) return;
      await preview(data);
    } catch (_) {
      if (mounted) setState(() => failed = true);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      OutlinedButton.icon(
        onPressed: busy ? null : search,
        icon: const Icon(Icons.search),
        label: Text(context.lang.catalogSearchTitle),
      ),
      if (failed) Text(context.lang.familyPlanFailed),
      for (final row in widget.rows.where(
        (r) => r['kind'] == 'ingredients' && r['deleted'] != true,
      ))
        ListTile(
          leading: const Icon(Icons.egg_alt_outlined),
          title: Text((row['payload'] as Map)['name'] as String),
          trailing: const Icon(Icons.chevron_right),
          onTap: () =>
              preview(Map<String, dynamic>.from(row['payload'] as Map)),
        ),
    ],
  );
}
