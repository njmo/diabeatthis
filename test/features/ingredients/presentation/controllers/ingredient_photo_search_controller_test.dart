import 'package:diabeatthis/core/media/camera_permission_service.dart';
import 'package:diabeatthis/core/media/camera_photo_capture_result.dart';
import 'package:diabeatthis/core/media/providers/camera_permission_service_provider.dart';
import 'package:diabeatthis/features/ingredients/data/clients/ingredient_photo_search_client.dart';
import 'package:diabeatthis/features/ingredients/data/models/ingredient_photo_scan_input.dart';
import 'package:diabeatthis/features/ingredients/data/providers/ingredient_photo_search_client_provider.dart';
import 'package:diabeatthis/features/ingredients/presentation/controllers/ingredient_photo_search_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  late PhotoSearchClientSpy client;
  late ProviderContainer container;

  setUp(() {
    client = PhotoSearchClientSpy();
    container = ProviderContainer(
      overrides: [
        cameraPermissionServiceProvider.overrideWithValue(
          CameraPermissionService(
            getStatus: () async => PermissionStatus.granted,
          ),
        ),
        ingredientPhotoSearchClientProvider.overrideWithValue(client),
      ],
    );
  });
  tearDown(() => container.dispose());

  test('search sends the cropped front photo to AI', () async {
    await container
        .read(ingredientPhotoSearchControllerProvider.notifier)
        .captureAndSearch(
          capturePhoto: () async =>
              const CameraPhotoCaptureResult.captured('/tmp/cropped-front.jpg'),
        );
    expect(client.input?.frontPhotoPath, '/tmp/cropped-front.jpg');
    expect(client.input?.nutritionLabelPhotoPath, isNull);
    final state = container.read(ingredientPhotoSearchControllerProvider);
    expect(state.hasError, isFalse);
    expect(state.requireValue.captureError, isNull);
    expect(state.requireValue.result?.names, ['jogurt']);
  });

  test(
    'cancelling the framed camera does not call AI or show an error',
    () async {
      await container
          .read(ingredientPhotoSearchControllerProvider.notifier)
          .captureAndSearch(
            capturePhoto: () async =>
                const CameraPhotoCaptureResult.cancelled(),
          );
      expect(client.input, isNull);
      final state = container.read(ingredientPhotoSearchControllerProvider);
      expect(state.isLoading, isFalse);
      expect(state.requireValue.result, isNull);
      expect(state.requireValue.captureError, isNull);
    },
  );

  test('capture failures leave loading state and do not call AI', () async {
    await container
        .read(ingredientPhotoSearchControllerProvider.notifier)
        .captureAndSearch(
          capturePhoto: () async => throw StateError('Camera failed'),
        );
    expect(client.input, isNull);
    final state = container.read(ingredientPhotoSearchControllerProvider);
    expect(state.isLoading, isFalse);
    expect(state.error, isA<StateError>());
  });
}

class PhotoSearchClientSpy implements IngredientPhotoSearchClient {
  IngredientPhotoScanInput? input;

  @override
  Future<String> search(IngredientPhotoScanInput input) async {
    this.input = input;
    return '{"names":["jogurt"],"brand":null}';
  }
}
