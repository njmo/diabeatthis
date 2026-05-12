import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../meal_advisor/data/models/ingredient_scan_result.dart';
import '../../../meal_advisor/presentation/controllers/ingredient_photo_scan_controller.dart';

class IngredientPhotoScan extends ConsumerWidget {
  const IngredientPhotoScan({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scanResult = ref.watch(ingredientPhotoScanControllerProvider).value;
    final retakeRequest = scanResult?.retakeRequest;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PhotoStepTile(
            icon: Icons.inventory_2_outlined,
            title: 'Przód opakowania',
            subtitle: 'Nazwa produktu i producent',
          ),
          const SizedBox(height: 8),
          _PhotoStepTile(
            icon: Icons.table_chart_outlined,
            title: 'Tabela makro',
            subtitle: 'Wartości odżywcze na 100 g',
          ),
          const SizedBox(height: 12),
          if (retakeRequest != null) ...[
            IngredientPhotoRetakeMessage(request: retakeRequest),
            const SizedBox(height: 12),
          ],
          Text(
            'Na razie ten krok używa przykładowego odczytu.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class IngredientPhotoRetakeMessage extends StatelessWidget {
  final IngredientScanRetakeRequest request;

  const IngredientPhotoRetakeMessage({required this.request, super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.refresh_outlined, color: colors.onErrorContainer),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                request.message ?? _retakeFallbackMessage(request.photo),
                style: TextStyle(color: colors.onErrorContainer),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _retakeFallbackMessage(IngredientScanPhotoTarget photo) {
  return switch (photo) {
    IngredientScanPhotoTarget.front =>
      'Przód opakowania jest nieczytelny. Zrób zdjęcie jeszcze raz.',
    IngredientScanPhotoTarget.nutritionLabel =>
      'Tabela makro jest nieczytelna. Zrób zdjęcie jeszcze raz.',
    IngredientScanPhotoTarget.both =>
      'Zdjęcia są nieczytelne. Zrób je jeszcze raz.',
  };
}

class _PhotoStepTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _PhotoStepTile({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: colors.primary),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.pending_outlined),
    );
  }
}
