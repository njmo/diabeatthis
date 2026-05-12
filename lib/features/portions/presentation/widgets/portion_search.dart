import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../common/widgets/forms.dart';
import '../../../../core/logger/logger.dart';
import '../../../meals/data/providers/add_ingredients_provider.dart';
import '../../data/drafts/portion_filter.dart';
import '../../data/mappers/portion_draft_mapper.dart';
import '../../data/providers/portion_provider.dart';

class PortionSearch extends HookConsumerWidget with Logging {
  const PortionSearch({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = useState('');
    final valuePicked = useState(-1);
    final filter = ref.watch(portionFilterProvider);
    final portions = filter.map(
      all: (_) => ref.watch(portionsProvider),
      byQuery: (_) => ref.watch(portionsByQueryProvider(query.value)),
      byQueryForIngredient: (filter) => ref.watch(
        portionsByIngredientByQueryProvider(filter.ingredientId, query.value),
      ),
      allUnassignedForIngredient: (filter) => ref.watch(
        portionsNotInIngredientByQueryProvider(
          filter.ingredientId,
          query.value,
        ),
      ),
    );
    logI("Filter : $filter");
    final draft = ref.watch(portionDraftProvider.notifier);
    final formKey = ref.watch(mealIngredientFormKeyProvider);
    final stage = ref.watch(addMealIngredientStageProvider);
    final mode = PortionSearchMode.fromStage(stage);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Form(
            key: formKey,
            autovalidateMode: AutovalidateMode.always,
            child: StringFormField(
              label: 'Nazwa',
              value: '',
              onChanged: (value) {
                query.value = value;
              },
              builder: (context, controller) {
                return TextFormField(
                  autofocus: true,
                  controller: controller,
                  maxLength: 30,
                  validator: (value) {
                    if (valuePicked.value < 0) {
                      return '';
                    }
                    return null;
                  },
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    labelText: 'Szukaj porcji',
                    counterText: '',
                    border: OutlineInputBorder(),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          portions.when(
            data: (data) {
              if (data.isEmpty) {
                return PortionSearchEmptyState(mode: mode);
              }

              return SizedBox(
                height: 240,
                child: ListView.separated(
                  itemBuilder: (context, index) {
                    final portion = data[index];
                    final selected = valuePicked.value == index;
                    return PortionSearchTile(
                      name: portion.name,
                      unitHint: portion.unitHint,
                      selected: selected,
                      onTap: () {
                        draft.overrideDraft(portion.toSelection());
                        valuePicked.value = index;
                      },
                    );
                  },
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemCount: data.length,
                ),
              );
            },
            error: (error, _) => PortionSearchErrorMessage(error: error),
            loading: () => const PortionSearchLoadingMessage(),
          ),
        ],
      ),
    );
  }
}

enum PortionSearchMode {
  existing,
  newAssignment;

  static PortionSearchMode fromStage(AddMealIngredientStage stage) {
    return switch (stage) {
      AddMealIngredientStage.definedPortionsSearch =>
        PortionSearchMode.existing,
      _ => PortionSearchMode.newAssignment,
    };
  }
}

class PortionSearchTile extends StatelessWidget {
  final String name;
  final String unitHint;
  final bool selected;
  final VoidCallback onTap;

  const PortionSearchTile({
    required this.name,
    required this.unitHint,
    required this.selected,
    required this.onTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: selected ? colorScheme.secondaryContainer : colorScheme.surface,
      shape: RoundedRectangleBorder(
        side: BorderSide(
          color: selected ? colorScheme.secondary : colorScheme.outlineVariant,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: selected
              ? colorScheme.secondary
              : colorScheme.surfaceContainerHighest,
          foregroundColor: selected
              ? colorScheme.onSecondary
              : colorScheme.onSurfaceVariant,
          child: const Icon(Icons.local_dining, size: 20),
        ),
        title: Text(
          name,
          style: TextStyle(
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
        subtitle: Text(unitHint.isEmpty ? 'bez jednostki' : unitHint),
        trailing: selected ? const Icon(Icons.check_circle) : null,
      ),
    );
  }
}

class PortionSearchEmptyState extends StatelessWidget {
  final PortionSearchMode mode;

  const PortionSearchEmptyState({required this.mode, super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final message = mode == PortionSearchMode.existing
        ? 'Ten składnik nie ma jeszcze pasującej porcji.'
        : 'Nie znaleziono pasującej porcji.';

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.search_off, color: colorScheme.onSurfaceVariant),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
  }
}

class PortionSearchLoadingMessage extends StatelessWidget {
  const PortionSearchLoadingMessage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 24),
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

class PortionSearchErrorMessage extends StatelessWidget {
  final Object error;

  const PortionSearchErrorMessage({required this.error, super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Text(
          'Nie udało się wczytać porcji: $error',
          style: TextStyle(color: colorScheme.onErrorContainer),
        ),
      ),
    );
  }
}
