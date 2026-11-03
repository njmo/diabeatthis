import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:diabeatthis/common/profile/profile_photo_controller.dart';
import 'package:diabeatthis/common/profile/profile_photo_source.dart';
import 'package:diabeatthis/common/profile/profile_photo_store.dart';
import 'package:diabeatthis/core/data/provider/shared_prefs_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late ProfilePhotoStore store;
  late ControlledProfilePhotoSource source;
  late ProviderContainer container;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    directory = await Directory.systemTemp.createTemp('profile_controller_');
    store = ProfilePhotoStore(preferences, directory);
    source = ControlledProfilePhotoSource();
    container = ProviderContainer(
      overrides: [
        sharedPrefsProvider.overrideWith((ref) async => preferences),
        profilePhotoStoreProvider.overrideWith((ref) async => store),
        profilePhotoSourceProvider.overrideWithValue(source),
      ],
    );
    await container.read(profilePhotoControllerProvider.future);
  });

  tearDown(() async {
    container.dispose();
    await directory.delete(recursive: true);
  });

  Uint8List photo() =>
      Uint8List.fromList(img.encodePng(img.Image(width: 20, height: 30)));

  test(
    'choosing a photo updates shared state and persists it through the use case',
    () async {
      source.result = photo();
      await container.read(profilePhotoControllerProvider.notifier).choose();
      final path = container.read(profilePhotoControllerProvider).requireValue;
      expect(path, await store.load());
      expect(await File(path!).exists(), isTrue);
    },
  );

  test('cancellation and invalid images preserve the current photo', () async {
    source.result = photo();
    final controller = container.read(profilePhotoControllerProvider.notifier);
    await controller.choose();
    final previous = container
        .read(profilePhotoControllerProvider)
        .requireValue;
    source.result = null;
    await controller.choose();
    expect(
      container.read(profilePhotoControllerProvider).requireValue,
      previous,
    );
    source.result = Uint8List.fromList([1, 2, 3]);
    await expectLater(controller.choose(), throwsFormatException);
    expect(
      container.read(profilePhotoControllerProvider).requireValue,
      previous,
    );
    expect(await store.load(), previous);
  });

  test('removing a photo updates both shared state and storage', () async {
    source.result = photo();
    final controller = container.read(profilePhotoControllerProvider.notifier);
    await controller.choose();
    await controller.remove();
    expect(container.read(profilePhotoControllerProvider).requireValue, isNull);
    expect(await store.load(), isNull);
  });

  test('pending selection prevents duplicate requests', () async {
    source.pending = Completer<Uint8List?>();
    final controller = container.read(profilePhotoControllerProvider.notifier);
    final selection = controller.choose();
    expect(container.read(profilePhotoControllerProvider).isLoading, isTrue);
    await controller.choose();
    expect(source.calls, 1);
    source.pending!.complete(null);
    await selection;
    expect(container.read(profilePhotoControllerProvider).isLoading, isFalse);
  });
}

class ControlledProfilePhotoSource extends ProfilePhotoSource {
  Uint8List? result;
  Completer<Uint8List?>? pending;
  int calls = 0;

  @override
  Future<Uint8List?> pick() async {
    calls++;
    return pending == null ? result : pending!.future;
  }
}
