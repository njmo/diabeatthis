import 'dart:typed_data';

import 'package:diabeatthis/common/profile/profile_photo_controller.dart';
import 'package:diabeatthis/common/profile/profile_photo_source.dart';
import 'package:diabeatthis/common/profile/profile_photo_store.dart';
import 'package:diabeatthis/core/data/provider/shared_prefs_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/regression/scripted_profile_photo_store.dart';
import '../../helpers/regression/scripted_read.dart';
import 'profile_photo_controller_test.dart' show ControlledProfilePhotoSource;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'photo controller uses only the supplied store and reflects successful writes',
    () async {
      SharedPreferences.setMockInitialValues({profilePhotoFileKey: 'old.jpg'});
      final prefs = await SharedPreferences.getInstance();
      final bytes = Uint8List.fromList([1, 2, 3]);
      final source = ControlledProfilePhotoSource()..result = bytes;
      final loads = ScriptedRead<String?>('load photo', [
        (arguments: [], respond: () => 'old.jpg'),
      ]);
      final saves = ScriptedRead<String>('save photo', [
        (arguments: [bytes], respond: () => 'new.jpg'),
      ]);
      final removals = ScriptedRead<void>('remove photo', [
        (arguments: [], respond: () {}),
      ]);
      final container = ProviderContainer(
        overrides: [
          sharedPrefsProvider.overrideWith((ref) async => prefs),
          profilePhotoSourceProvider.overrideWithValue(source),
          profilePhotoStoreProvider.overrideWith(
            (ref) async => ScriptedProfilePhotoStore(
              loads: loads,
              saves: saves,
              removals: removals,
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      expect(
        await container.read(profilePhotoControllerProvider.future),
        'old.jpg',
      );
      final controller = container.read(
        profilePhotoControllerProvider.notifier,
      );
      await controller.choose();
      expect(container.read(profilePhotoControllerProvider).value, 'new.jpg');
      await controller.remove();
      expect(container.read(profilePhotoControllerProvider).value, isNull);
      loads.verifyComplete();
      saves.verifyComplete();
      removals.verifyComplete();
    },
  );

  test('failed replacement cannot publish an unsaved photo path', () async {
    SharedPreferences.setMockInitialValues({profilePhotoFileKey: 'old.jpg'});
    final prefs = await SharedPreferences.getInstance();
    final bytes = Uint8List.fromList([0]);
    final source = ControlledProfilePhotoSource()..result = bytes;
    final loads = ScriptedRead<String?>('load photo', [
      (arguments: [], respond: () => 'old.jpg'),
    ]);
    final saves = ScriptedRead<String>('save photo', [
      (arguments: [bytes], respond: () => throw StateError('Invalid image')),
    ]);
    final removals = ScriptedRead<void>('remove photo', []);
    final container = ProviderContainer(
      overrides: [
        sharedPrefsProvider.overrideWith((ref) async => prefs),
        profilePhotoSourceProvider.overrideWithValue(source),
        profilePhotoStoreProvider.overrideWith(
          (ref) async => ScriptedProfilePhotoStore(
            loads: loads,
            saves: saves,
            removals: removals,
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    await container.read(profilePhotoControllerProvider.future);
    await expectLater(
      container.read(profilePhotoControllerProvider.notifier).choose(),
      throwsStateError,
    );
    expect(container.read(profilePhotoControllerProvider).value, 'old.jpg');
    loads.verifyComplete();
    saves.verifyComplete();
    removals.verifyComplete();
  });
}
