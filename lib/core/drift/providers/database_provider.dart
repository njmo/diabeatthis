import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../database_impl.dart';

part 'database_provider.g.dart';

@Riverpod(keepAlive: true)
DatabaseImpl database(Ref ref) {
  final db = DatabaseImpl();
  
  ref.onDispose(() {
    db.close();
  });

  return db;
}