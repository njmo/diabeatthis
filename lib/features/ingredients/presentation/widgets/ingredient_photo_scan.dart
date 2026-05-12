import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../core/media/providers/camera_permission_service_provider.dart';
import '../../../meal_advisor/data/clients/debug_ingredient_photo_scan_client.dart';
import '../../../meal_advisor/data/models/ingredient_photo_scan_input.dart';
import '../../../meal_advisor/data/models/ingredient_scan_result.dart';
import '../../../meal_advisor/data/providers/debug_ingredient_photo_scan_provider.dart';
import '../../../meal_advisor/data/providers/ingredient_photo_scan_capture_provider.dart';
import '../../../meal_advisor/presentation/controllers/ingredient_photo_scan_controller.dart';

class IngredientPhotoScan extends ConsumerWidget {
  const IngredientPhotoScan({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scanResult = ref.watch(ingredientPhotoScanControllerProvider).value;
    final scanInput = ref.watch(ingredientPhotoScanCaptureControllerProvider);
    final retakeRequest = scanResult?.retakeRequest;
    final debugScenario = ref.watch(
      debugIngredientPhotoScanScenarioControllerProvider,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IngredientPhotoStepTile(
            icon: Icons.inventory_2_outlined,
            title: 'Przód opakowania',
            subtitle: 'Nazwa produktu i producent',
            photoPath: scanInput.frontPhotoPath,
            onCapture: () =>
                _capturePhoto(context, ref, IngredientPhotoScanPhoto.front),
          ),
          const SizedBox(height: 8),
          IngredientPhotoStepTile(
            icon: Icons.table_chart_outlined,
            title: 'Tabela makro',
            subtitle: 'Wartości odżywcze na 100 g',
            photoPath: scanInput.nutritionLabelPhotoPath,
            onCapture: () => _capturePhoto(
              context,
              ref,
              IngredientPhotoScanPhoto.nutritionLabel,
            ),
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
          const SizedBox(height: 12),
          IngredientPhotoScanDebugScenarioPicker(
            scenario: debugScenario,
            onChanged: (scenario) {
              ref
                  .read(
                    debugIngredientPhotoScanScenarioControllerProvider.notifier,
                  )
                  .setScenario(scenario);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _capturePhoto(
    BuildContext context,
    WidgetRef ref,
    IngredientPhotoScanPhoto photo,
  ) async {
    final result = await ref
        .read(ingredientPhotoScanCaptureControllerProvider.notifier)
        .capture(photo);
    if (!context.mounted ||
        result.state == IngredientPhotoCaptureState.captured ||
        result.state == IngredientPhotoCaptureState.cancelled) {
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(_photoCaptureMessage(result.state)),
        action: result.canOpenSettings
            ? SnackBarAction(
                label: 'Ustawienia',
                onPressed: () {
                  ref.read(cameraPermissionServiceProvider).openSettings();
                },
              )
            : null,
      ),
    );
  }
}

String _photoCaptureMessage(IngredientPhotoCaptureState state) {
  return switch (state) {
    IngredientPhotoCaptureState.permissionDenied =>
      'Aparat jest potrzebny do zrobienia zdjęcia opakowania.',
    IngredientPhotoCaptureState.permissionPermanentlyDenied =>
      'Uprawnienie aparatu jest zablokowane. Włącz je w ustawieniach aplikacji.',
    IngredientPhotoCaptureState.permissionRestricted =>
      'Dostęp do aparatu jest ograniczony w ustawieniach urządzenia.',
    IngredientPhotoCaptureState.cameraUnavailable =>
      'Nie udało się uruchomić aparatu. Spróbuj ponownie.',
    IngredientPhotoCaptureState.captured ||
    IngredientPhotoCaptureState.cancelled => '',
  };
}

class IngredientPhotoScanDebugScenarioPicker extends StatelessWidget {
  final DebugIngredientPhotoScanScenario scenario;
  final ValueChanged<DebugIngredientPhotoScanScenario> onChanged;

  const IngredientPhotoScanDebugScenarioPicker({
    required this.scenario,
    required this.onChanged,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<DebugIngredientPhotoScanScenario>(
      segments: const [
        ButtonSegment(
          value: DebugIngredientPhotoScanScenario.recognized,
          label: Text('Pełny'),
          icon: Icon(Icons.check_circle_outline),
        ),
        ButtonSegment(
          value: DebugIngredientPhotoScanScenario.needsRetake,
          label: Text('Nieczytelne'),
          icon: Icon(Icons.refresh_outlined),
        ),
        ButtonSegment(
          value: DebugIngredientPhotoScanScenario.incompleteRecognized,
          label: Text('Niepełny'),
          icon: Icon(Icons.rule_outlined),
        ),
      ],
      selected: {scenario},
      onSelectionChanged: (selection) => onChanged(selection.first),
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

class IngredientPhotoStepTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? photoPath;
  final VoidCallback onCapture;

  const IngredientPhotoStepTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.photoPath,
    required this.onCapture,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    final isCaptured = photoPath != null;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: colors.primary),
      title: Text(title),
      subtitle: Text(isCaptured ? '$subtitle\nZdjęcie dodane' : subtitle),
      isThreeLine: isCaptured,
      onTap: onCapture,
      trailing: Icon(
        isCaptured ? Icons.check_circle_outline : Icons.add_a_photo_outlined,
        color: isCaptured ? colors.primary : null,
      ),
    );
  }
}
