import 'dart:async';

import 'package:flutter/material.dart';

import '../../l10n/language.dart';
import '../../widgets/responsive_bottom_sheet.dart';
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
  Future<void> Function(BuildContext)? onScanBarcode,
}) => showResponsiveBottomSheet<IngredientSearchItem>(
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
    onScanBarcode: onScanBarcode,
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
    this.onScanBarcode,
    this.queryDebounce = Duration.zero,
    super.key,
  });
  final bool includeReferenceIngredients;
  final String initialQuery;
  final IngredientSearchItem? selectedItem;
  final VoidCallback? onCreateReference;
  final String? referenceLabel;
  final String? ingredientName;
  final bool searchOnly;
  final Duration queryDebounce;
  final Future<void> Function(BuildContext)? onScanBarcode;
  @override
  State<IngredientCatalogPicker> createState() =>
      IngredientCatalogPickerState();
}

class IngredientCatalogPickerState extends State<IngredientCatalogPicker> {
  late String query;
  bool scanning = false;
  late final TextEditingController search;
  Timer? queryTimer;
  @override
  void initState() {
    super.initState();
    query = widget.initialQuery;
    search = TextEditingController(text: query);
  }

  @override
  void dispose() {
    queryTimer?.cancel();
    search.dispose();
    super.dispose();
  }

  void updateQuery(String value) {
    queryTimer?.cancel();
    if (widget.queryDebounce == Duration.zero ||
        value.trim().isEmpty ||
        value == query) {
      setState(() => query = value);
    } else {
      setState(() {
        queryTimer = Timer(
          widget.queryDebounce,
          () => setState(() => query = value),
        );
      });
    }
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
            Row(
              children: [
                Expanded(
                  child: TextField(
                    enabled: !scanning,
                    controller: search,
                    textInputAction: TextInputAction.search,
                    maxLength: 120,
                    onChanged: updateQuery,
                    decoration: InputDecoration(
                      labelText: context.lang.ingredientSearchLabel,
                      counterText: '',
                      prefixIcon: const Icon(Icons.search),
                    ),
                  ),
                ),
                if (widget.onScanBarcode != null) ...[
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    tooltip: context.lang.ingredientScanBarcodeTooltip,
                    onPressed: scanning
                        ? null
                        : () async {
                            FocusScope.of(context).unfocus();
                            setState(() => scanning = true);
                            try {
                              await widget.onScanBarcode!(context);
                            } finally {
                              if (mounted) setState(() => scanning = false);
                            }
                          },
                    icon: scanning
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.qr_code_scanner_rounded),
                  ),
                ],
              ],
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
                  queryTimer?.isActive == true ||
                      (widget.searchOnly &&
                          query.trim().isEmpty &&
                          widget.selectedItem == null)
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
