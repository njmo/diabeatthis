import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

class LocalHistoryBlockedView extends StatelessWidget {
  const LocalHistoryBlockedView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.storage_outlined,
                size: 56,
                color: colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                'Historia lokalna nie jest jeszcze dostępna',
                style: theme.textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Zarządzanie i analizy wymagają teraz historii z chmury. '
                'Lokalny mirror zostanie podłączony w kolejnym etapie.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () => context.router.pushPath('/settings'),
                icon: const Icon(Icons.settings_outlined),
                label: const Text('Zmień źródło historii'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
