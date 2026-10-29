import 'dart:math';

class TempTargetRequestId {
  const TempTargetRequestId._();

  static String create(String type, int entityId, DateTime now) {
    final random = Random.secure();
    final suffix = List.generate(
      4,
      (_) => random.nextInt(65536).toRadixString(16).padLeft(4, '0'),
    ).join();
    return '${type}_${entityId}_${now.microsecondsSinceEpoch}_$suffix';
  }
}
