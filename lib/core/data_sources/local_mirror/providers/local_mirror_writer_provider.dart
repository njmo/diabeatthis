import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../drift/providers/database_provider.dart';
import '../services/local_mirror_writer.dart';

part 'local_mirror_writer_provider.g.dart';

@Riverpod(keepAlive: true)
LocalMirrorWriter localMirrorWriter(Ref ref) {
  final db = ref.watch(databaseProvider);
  return LocalMirrorWriter(db.localMirrorDao);
}
