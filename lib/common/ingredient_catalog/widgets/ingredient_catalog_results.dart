import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/language.dart';
import '../ingredient_catalog_exception.dart';
import '../ingredient_catalog_providers.dart';
import '../ingredient_search_controller.dart';
import '../ingredient_search_item.dart';

class IngredientCatalogResults extends ConsumerStatefulWidget {
  const IngredientCatalogResults({
    required this.query,
    required this.onSelected,
    this.selectedLocalId,
    this.selectedItem,
    this.includeReferenceIngredients = true,
    super.key,
  });
  final String query;
  final int? selectedLocalId;
  final IngredientSearchItem? selectedItem;
  final bool includeReferenceIngredients;
  final Future<void> Function(IngredientSearchItem item) onSelected;
  @override
  ConsumerState<IngredientCatalogResults> createState() =>
      IngredientCatalogResultsState();
}

class IngredientCatalogResultsState
    extends ConsumerState<IngredientCatalogResults> {
  late final IngredientSearchController controller;
  String? requestedLanguage;
  String? selectingIdentity;
  bool selectionFailed = false;
  @override
  void initState() {
    super.initState();
    controller = IngredientSearchController(
      ref.read(unifiedIngredientSearchUseCaseProvider),
    );
    controller.addListener(changed);
  }

  void changed() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final language = Localizations.localeOf(context).languageCode;
    if (requestedLanguage != language) {
      requestedLanguage = language;
      controller.search(widget.query, languageCode: language);
    }
  }

  @override
  void didUpdateWidget(covariant IngredientCatalogResults oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.query != widget.query) {
      selectionFailed = false;
      controller.search(widget.query, languageCode: requestedLanguage ?? 'en');
    }
  }

  Future<void> select(IngredientSearchItem item) async {
    if (selectingIdentity != null) return;
    setState(() {
      selectingIdentity = item.identity.stableKey;
      selectionFailed = false;
    });
    try {
      await widget.onSelected(item);
    } catch (_) {
      if (mounted) setState(() => selectionFailed = true);
    } finally {
      if (mounted) setState(() => selectingIdentity = null);
    }
  }

  @override
  void dispose() {
    controller.removeListener(changed);
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = controller.state;
    final lang = context.lang;
    final selected = widget.selectedItem;
    final items =
        [
              if (selected != null) selected,
              ...state.items.where(
                (item) => item.identity != selected?.identity,
              ),
            ]
            .where(
              (item) => widget.includeReferenceIngredients || !item.isReference,
            )
            .toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (state.loadingLocal || state.loadingRemote)
          const LinearProgressIndicator(),
        if (state.localFailed) Text(lang.ingredientLoadError('')),
        if (state.remoteFailure != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              state.remoteFailure == IngredientCatalogFailure.unavailable
                  ? lang.catalogSearchUnavailable
                  : lang.catalogSearchFailed,
            ),
          ),
        if (selectionFailed) Text(lang.catalogSelectFailed),
        Expanded(
          child: ListView.separated(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 4),
            itemBuilder: (context, index) {
              final item = items[index];
              final tile = IngredientCatalogResultTile(
                item: item,
                plain: selected != null,
                selected:
                    (widget.selectedLocalId != null &&
                        widget.selectedLocalId == item.localIngredientId) ||
                    widget.selectedItem?.identity == item.identity,
                selecting: selectingIdentity == item.identity.stableKey,
                onTap: selectingIdentity == null ? () => select(item) : null,
              );
              if (index != 0 ||
                  selected == null ||
                  item.identity != selected.identity) {
                return tile;
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  tile,
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    child: Divider(),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    child: Text(
                      lang.catalogOtherResults,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  if (items.length == 1 &&
                      !state.loadingLocal &&
                      !state.loadingRemote)
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(lang.ingredientSearchEmpty),
                    ),
                ],
              );
            },
          ),
        ),
        if (!state.loadingLocal && !state.loadingRemote && items.isEmpty)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(lang.ingredientSearchEmpty),
          ),
        if (state.nextCursor != null)
          TextButton(
            onPressed: state.loadingRemote ? null : controller.loadMore,
            child: Text(lang.catalogLoadMore),
          ),
      ],
    );
  }
}

class IngredientCatalogResultTile extends StatelessWidget {
  const IngredientCatalogResultTile({
    required this.item,
    required this.selected,
    required this.selecting,
    required this.onTap,
    this.plain = false,
    super.key,
  });
  final IngredientSearchItem item;
  final bool selected;
  final bool selecting;
  final VoidCallback? onTap;
  final bool plain;
  @override
  Widget build(BuildContext context) {
    final tile = ListTile(
      onTap: onTap,
      selected: selected,
      leading: plain
          ? null
          : item.isRemote
          ? Tooltip(
              message: context.lang.catalogSourceLabel,
              child: const Icon(Icons.cloud_outlined),
            )
          : const Icon(Icons.kitchen_outlined),
      title: Text(item.name),
      subtitle: item.details.isEmpty ? null : Text(item.details),
      trailing: selecting
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : selected
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (plain) ...[
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      child: Text(
                        context.lang.catalogSelectedProduct,
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                const Icon(Icons.check_circle),
              ],
            )
          : null,
    );
    return plain ? tile : Card(child: tile);
  }
}
