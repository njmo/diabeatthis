import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../core/llm/local_llm_client.dart';
import '../../../../core/media/providers/camera_permission_service_provider.dart';
import '../../../meal_advisor/data/models/ingredient_photo_scan_input.dart';
import '../../../meal_advisor/data/models/ingredient_scan_result.dart';
import '../../../meal_advisor/data/providers/ingredient_photo_scan_capture_provider.dart';
import '../../../meal_advisor/presentation/controllers/ingredient_photo_scan_controller.dart';

class IngredientPhotoScan extends ConsumerWidget {
  const IngredientPhotoScan({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scanState = ref.watch(ingredientPhotoScanControllerProvider);
    final scanResult = scanState.value;
    final scanError = scanState.whenOrNull(error: (error, _) => error);
    final scanInput = ref.watch(ingredientPhotoScanCaptureControllerProvider);
    final retakeRequest = scanResult?.retakeRequest;
    final isScanning = scanState.isLoading;

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
          if (isScanning) ...[
            const IngredientPhotoScanProgressMessage(),
            const SizedBox(height: 12),
          ],
          if (retakeRequest != null) ...[
            IngredientPhotoRetakeMessage(request: retakeRequest),
            const SizedBox(height: 12),
          ],
          if (scanError != null) ...[
            IngredientPhotoScanErrorMessage(
              message: _scanErrorMessage(scanError),
            ),
            const SizedBox(height: 12),
          ],
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

class IngredientPhotoScanProgressMessage extends StatelessWidget {
  const IngredientPhotoScanProgressMessage({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: colors.onPrimaryContainer,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Odczytuję dane ze zdjęć. To może potrwać kilkanaście sekund.',
                style: TextStyle(color: colors.onPrimaryContainer),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _scanErrorMessage(Object error) {
  if (error is LlmRequestException) {
    return switch (error.failure) {
      LlmRequestFailure.network =>
        'Brak połączenia z AI. Sprawdź internet i spróbuj ponownie.',
      LlmRequestFailure.unauthorized =>
        'Nie udało się potwierdzić aplikacji w Firebase. Spróbuj ponownie po konfiguracji App Check.',
      LlmRequestFailure.quotaExceeded =>
        'Limit odczytów AI został wyczerpany. Spróbuj później.',
      LlmRequestFailure.timeout => 'Odczyt trwał zbyt długo. Spróbuj ponownie.',
      LlmRequestFailure.unavailable =>
        'AI jest chwilowo niedostępne. Spróbuj ponownie.',
    };
  }
  if (error is LocalLlmUnavailableException) {
    return 'Lokalny model nie jest jeszcze skonfigurowany.';
  }
  if (error is FormatException) {
    return 'Nie udało się odczytać odpowiedzi modelu. Spróbuj ponownie.';
  }
  return 'Nie udało się odczytać danych ze zdjęć. Spróbuj ponownie.';
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

class IngredientPhotoScanErrorMessage extends StatelessWidget {
  final String message;

  const IngredientPhotoScanErrorMessage({required this.message, super.key});

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
            Icon(Icons.error_outline, color: colors.onErrorContainer),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
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
