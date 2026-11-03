import 'dart:io';
import 'dart:typed_data';

import 'package:diabeatthis/common/profile/profile_photo_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory directory;
  late SharedPreferences preferences;
  late ProfilePhotoStore store;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    preferences = await SharedPreferences.getInstance();
    directory = await Directory.systemTemp.createTemp('profile_photo_test_');
    store = ProfilePhotoStore(preferences, directory);
  });

  tearDown(() async {
    await directory.delete(recursive: true);
  });

  Uint8List photo() =>
      Uint8List.fromList(img.encodePng(img.Image(width: 80, height: 120)));

  test(
    'photo survives a new store and replacement removes the previous file',
    () async {
      final first = await store.save(photo());
      final restored = ProfilePhotoStore(preferences, directory);
      expect(await restored.load(), first);
      final decoded = img.decodeJpg(await File(first).readAsBytes())!;
      expect(decoded.width, 512);
      expect(decoded.height, 512);

      final second = await restored.save(photo());
      expect(await store.load(), second);
      expect(await File(first).exists(), isFalse);
      expect(await File(second).exists(), isTrue);
    },
  );

  test('invalid image preserves the previously saved photo', () async {
    final previous = await store.save(photo());
    await expectLater(
      store.save(Uint8List.fromList([1, 2, 3])),
      throwsFormatException,
    );
    expect(await store.load(), previous);
    expect(await File(previous).exists(), isTrue);
  });

  test('removing photo clears preference and stored image', () async {
    final previous = await store.save(photo());
    await store.remove();
    expect(await store.load(), isNull);
    expect(preferences.containsKey(profilePhotoFileKey), isFalse);
    expect(await File(previous).exists(), isFalse);
  });

  test('missing image falls back to no photo', () async {
    final previous = await store.save(photo());
    await File(previous).delete();
    expect(await store.load(), isNull);
  });
}
