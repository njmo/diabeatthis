import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/domain/model/carbs_label_mode.dart';
import '../../ingredient_catalog/ingredient_catalog_providers.dart';
import '../../l10n/language.dart';
import '../../presentation/widgets/ingredient_list_item.dart';
import '../family_access_scope.dart';
import '../family_planning_controller.dart';
import 'family_ingredient_details_dialog.dart';
import 'family_record_page.dart';
import 'family_scope_guard.dart';
import 'models/family_ingredient_view.dart';
import 'show_family_ingredient_picker.dart';

/// Read-only catalog: selection never writes patient data on the caregiver.
class FamilyIngredientCatalogSection extends ConsumerStatefulWidget {
  const FamilyIngredientCatalogSection({
    super.key,
    required this.rows,
    this.searchOnly = false,
    this.family,
  });
  final bool searchOnly;
  final FamilyPlanningController? family;
  final List<Map<String, dynamic>> rows;
  @override
  ConsumerState<FamilyIngredientCatalogSection> createState() =>
      FamilyIngredientCatalogSectionState();
}

class FamilyIngredientCatalogSectionState
    extends ConsumerState<FamilyIngredientCatalogSection> {
  bool busy = false;
  bool failed = false;
  Future<void> preview(
    Map<String, dynamic> data, {
    FamilyAccessScope? scope,
  }) async {
    if (scope != null) {
      if (!scope.isCurrent || !scope.family.complete) return;
      if (data['id'] != null) {
        await FamilyRecordPage.open(
          context,
          scope.family,
          'ingredients',
          data['id'] as int,
        );
        return;
      }
    }
    await showDialog<void>(
      context: context,
      builder: (_) {
        final view = FamilyIngredientDetailsDialog(data: data);
        return scope == null
            ? view
            : FamilyScopeGuard(scope: scope, child: view);
      },
    );
  }

  Future<void> search() async {
    final scope = widget.family == null
        ? null
        : FamilyAccessScope(widget.family!);
    if (scope != null && (!scope.isCurrent || !scope.family.complete)) return;
    final rows = List<Map<String, dynamic>>.of(widget.rows);
    final catalog = ref.read(catalogRepositoryProvider);
    final language = Localizations.localeOf(context).languageCode;
    setState(() {
      busy = true;
      failed = false;
    });
    try {
      final item = await showFamilyIngredientPicker(
        context,
        rows: rows,
        catalog: catalog,
        routeGuard: scope == null
            ? null
            : (child) => FamilyScopeGuard(scope: scope, child: child),
      );
      if (item == null || !mounted) return;
      scope?.requireCurrent();
      Map<String, dynamic> data;
      if (item.localIngredientId != null) {
        data = Map<String, dynamic>.from(
          rows.singleWhere(
                (row) =>
                    row['kind'] == 'ingredients' &&
                    row['id'] == '${item.localIngredientId}' &&
                    row['deleted'] != true,
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
          'confidence_is_assessed': false,
          'icon_asset_path': food.iconAssetPath,
          'kcal_per_100g': food.kcalPer100g,
        };
      }
      if (!mounted) return;
      scope?.requireCurrent();
      await preview(data, scope: scope);
    } catch (_) {
      if (mounted && (scope == null || scope.isCurrent)) {
        setState(() => failed = true);
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scope = widget.family == null
        ? null
        : FamilyAccessScope(widget.family!);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton.icon(
          onPressed: busy ? null : search,
          icon: const Icon(Icons.search),
          label: Text(context.lang.catalogSearchTitle),
        ),
        if (failed) Text(context.lang.familyPlanFailed),
        for (final row in widget.rows.where(
          (r) =>
              !widget.searchOnly &&
              r['kind'] == 'ingredients' &&
              r['deleted'] != true,
        ))
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: IngredientListItem(
              ingredient: familyIngredientView(row),
              onTap: () => preview(
                Map<String, dynamic>.from(row['payload'] as Map),
                scope: scope,
              ),
            ),
          ),
      ],
    );
  }
}
