import 'package:flutter/material.dart';

import '../../l10n/language.dart';
import '../ingredient_search_item.dart';
import 'ingredient_catalog_results.dart';

Future<IngredientSearchItem?> showIngredientCatalogPicker(
  BuildContext context, {
  bool includeReferenceIngredients = true,
  String initialQuery = '',
  IngredientSearchItem? selectedItem,
  VoidCallback? onCreateReference,
  String? referenceLabel,
  String? ingredientName,
  bool searchOnly = false,
}) => showModalBottomSheet<IngredientSearchItem>(
  context: context,
  isScrollControlled: true,
  builder: (context) => IngredientCatalogPicker(
    includeReferenceIngredients: includeReferenceIngredients,
    initialQuery: initialQuery,
    selectedItem: selectedItem,
    onCreateReference: onCreateReference,
    referenceLabel: referenceLabel,
    ingredientName: ingredientName,
    searchOnly: searchOnly,
  ),
);

class IngredientCatalogPicker extends StatefulWidget {
  const IngredientCatalogPicker({
    this.includeReferenceIngredients = true,
    this.initialQuery = '',
    this.selectedItem,
    this.onCreateReference,
    this.referenceLabel,
    this.ingredientName,
    this.searchOnly = false,
    super.key,
  });
  final bool includeReferenceIngredients;
  final String initialQuery;
  final IngredientSearchItem? selectedItem;
  final VoidCallback? onCreateReference;
  final String? referenceLabel;
  final String? ingredientName;
  final bool searchOnly;
  @override
  State<IngredientCatalogPicker> createState() =>
      IngredientCatalogPickerState();
}

class IngredientCatalogPickerState extends State<IngredientCatalogPicker> {
  late String query;
  late final TextEditingController search;
  @override
  void initState() {
    super.initState();
    query = widget.initialQuery;
    search = TextEditingController(text: query);
  }

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        MediaQuery.viewInsetsOf(context).bottom + 16,
      ),
      child: SizedBox(
        height: (MediaQuery.sizeOf(context).height * .45).clamp(240.0, 420.0),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    context.lang.catalogSearchTitle,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            if (widget.ingredientName != null)
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  widget.ingredientName!,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            TextField(
              controller: search,
              textInputAction: TextInputAction.search,
              maxLength: 120,
              onChanged: (value) => setState(() => query = value),
              decoration: InputDecoration(
                labelText: context.lang.ingredientSearchLabel,
                counterText: '',
                prefixIcon: const Icon(Icons.search),
              ),
            ),
            if (widget.onCreateReference != null)
              TextButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  widget.onCreateReference!();
                },
                icon: const Icon(Icons.add),
                label: Text(
                  widget.referenceLabel ??
                      context.lang.ingredientReferenceDishTitle,
                ),
              ),
            Expanded(
              child:
                  widget.searchOnly &&
                      query.trim().isEmpty &&
                      widget.selectedItem == null
                  ? const SizedBox.expand()
                  : IngredientCatalogResults(
                      query: query,
                      selectedItem: widget.selectedItem,
                      includeReferenceIngredients:
                          widget.includeReferenceIngredients,
                      onSelected: (item) async => Navigator.pop(context, item),
                    ),
            ),
          ],
        ),
      ),
    ),
  );
}
