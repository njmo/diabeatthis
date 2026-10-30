import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:diabeatthis/common/storage/local_image_edit_session.dart';
import 'package:diabeatthis/common/storage/local_image_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory directory;
  late LocalImageStore store;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('image-edit-session');
    store = LocalImageStore(directory: () async => directory);
  });
  tearDown(() => directory.delete(recursive: true));

  test(
    'discard removes all uncommitted selections and preserves used images',
    () async {
      final abandoned = await store.savePng(Uint8List.fromList([1]));
      final replacement = await store.savePng(Uint8List.fromList([2]));
      final shared = await store.savePng(Uint8List.fromList([3]));
      final session = LocalImageEditSession(
        store: store,
        isInUse: (path) async => path == shared.path,
      );
      for (final path in [
        abandoned.path,
        replacement.path,
        shared.path,
        'assets/icons/food/apple.png',
      ]) {
        session.track(path);
      }
      await session.discard();
      expect(await abandoned.file.exists(), isFalse);
      expect(await replacement.file.exists(), isFalse);
      expect(await shared.file.exists(), isTrue);
    },
  );

  test(
    'closing while saving waits for persistence before deleting files',
    () async {
      final selected = await store.savePng(Uint8List.fromList([1]));
      final write = Completer<void>();
      var persisted = false;
      final session = LocalImageEditSession(
        store: store,
        isInUse: (_) async => persisted,
      );
      session.track(selected.path);
      final saving = session.save(() async {
        await write.future;
        persisted = true;
      });
      final cleanup = session.discard();
      expect(await selected.file.exists(), isTrue);
      write.complete();
      await saving;
      await cleanup;
      expect(await selected.file.exists(), isTrue);
    },
  );

  test('a failed write retains the image for retry until cancel', () async {
    final selected = await store.savePng(Uint8List.fromList([1]));
    final session = LocalImageEditSession(
      store: store,
      isInUse: (_) async => false,
    );
    session.track(selected.path);
    await expectLater(
      session.save(() async => throw StateError('Failed write')),
      throwsStateError,
    );
    expect(await selected.file.exists(), isTrue);
    await session.discard();
    expect(await selected.file.exists(), isFalse);
  });

  test(
    'an unavailable reference check preserves the image for later cleanup',
    () async {
      final selected = await store.savePng(Uint8List.fromList([1]));
      var unavailable = true;
      final session = LocalImageEditSession(
        store: store,
        isInUse: (_) async {
          if (unavailable) throw StateError('Unavailable storage');
          return false;
        },
      );
      session.track(selected.path);
      await session.discard();
      expect(await selected.file.exists(), isTrue);
      unavailable = false;
      await session.cleanup();
      expect(await selected.file.exists(), isFalse);
    },
  );

  test('a result arriving after cancel is discarded', () async {
    final selected = await store.savePng(Uint8List.fromList([1]));
    final session = LocalImageEditSession(
      store: store,
      isInUse: (_) async => false,
    );
    await session.discard();
    session.track(selected.path);
    await session.cleanup();
    expect(await selected.file.exists(), isFalse);
  });
}
