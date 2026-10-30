import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../common/l10n/language.dart';
import '../../../../common/utils/normalize_search_text.dart';
import '../../../../common/widgets/action_choice_card.dart';
import '../../../../common/widgets/responsive_metric_list.dart';
import '../../../../common/widgets/search_text_field.dart';
import '../../data/icons/food_icon_assets.dart';
import '../../data/icons/ingredient_icon_provider.dart';
import 'food_icon_generation_dialog.dart';
import 'ingredient_icon_error_message.dart';
import 'ingredient_icon_option.dart';
import 'localized_food_icon_name.dart';

class IngredientIconPicker extends ConsumerStatefulWidget {
  const IngredientIconPicker({
    super.key,
    required this.name,
    this.brand,
    this.selectedAssetPath,
    this.onAbandonedSelection,
  });

  final String name;
  final String? brand;
  final String? selectedAssetPath;
  final ValueChanged<String>? onAbandonedSelection;

  @override
  ConsumerState<IngredientIconPicker> createState() =>
      IngredientIconPickerState();
}

class IngredientIconPickerState extends ConsumerState<IngredientIconPicker> {
  bool isLoading = false;
  bool failed = false;
  Object? failure;
  String query = '';
  final searchController = TextEditingController();

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> suggest() async {
    setState(() {
      isLoading = true;
      failed = false;
      failure = null;
    });
    final result = await ref
        .read(ingredientIconServiceProvider)
        .lookup(widget.name, widget.brand, refresh: true);
    final path = result.path;
    if (!mounted) return;
    if (path != null && path != FoodIconAssets.generic) {
      Navigator.of(context).pop(path);
    } else {
      setState(() {
        isLoading = false;
        failed = true;
        failure = result.error;
      });
    }
  }

  Future<void> generate() async {
    final path = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => FoodIconGenerationDialog(name: widget.name),
    );
    if (path == null) return;
    if (mounted) {
      Navigator.of(context).pop(path);
    } else {
      widget.onAbandonedSelection?.call(path);
    }
  }

  @override
  Widget build(BuildContext context) {
    final icons = FoodIconAssets.paths.entries.where((entry) {
      if (entry.value == FoodIconAssets.generic) return false;
      final searchText = normalizeSearchText(
        '${localizedFoodIconName(context.lang, entry.key)} ${FoodIconAssets.nameFor(entry.key)}',
      );
      return query.split(RegExp(r'\s+')).every(searchText.contains);
    }).toList();
    final theme = Theme.of(context);
    return SafeArea(
      child: CustomScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 32,
                      height: 4,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.outlineVariant,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          context.lang.ingredientChooseIcon,
                          style: theme.textTheme.titleLarge,
                        ),
                      ),
                      IconButton(
                        tooltip: context.lang.commonCloseTooltip,
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  if (widget.name.trim().isNotEmpty) ...[
                    Text(
                      widget.name,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 18),
                  ],
                  ResponsiveMetricList(
                    maxColumns: 2,
                    minimumWidth: 130,
                    children: [
                      ActionChoiceCard(
                        label: context.lang.ingredientSuggestIcon,
                        icon: Icons.auto_awesome_outlined,
                        loading: isLoading,
                        onPressed: isLoading ? null : suggest,
                      ),
                      ActionChoiceCard(
                        label: context.lang.ingredientGenerateIcon,
                        icon: Icons.add_photo_alternate_outlined,
                        onPressed: isLoading || widget.name.trim().isEmpty
                            ? null
                            : generate,
                      ),
                    ],
                  ),
                  if (failed)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        ingredientIconErrorMessage(context.lang, failure),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.error,
                        ),
                      ),
                    ),
                  const SizedBox(height: 18),
                  SearchTextField(
                    controller: searchController,
                    hintText: context.lang.ingredientSearchIcons,
                    onChanged: (value) =>
                        setState(() => query = normalizeSearchText(value)),
                  ),
                ],
              ),
            ),
          ),
          if (icons.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  context.lang.ingredientIconsEmpty,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              sliver: SliverGrid.builder(
                itemCount: icons.length,
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 88,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                ),
                itemBuilder: (context, index) {
                  final entry = icons[index];
                  return IngredientIconOption(
                    assetPath: entry.value,
                    label: localizedFoodIconName(context.lang, entry.key),
                    selected: entry.value == widget.selectedAssetPath,
                    onPressed: () => Navigator.of(context).pop(entry.value),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
