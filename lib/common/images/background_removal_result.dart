import 'dart:typed_data';

class BackgroundRemovalResult {
  const BackgroundRemovalResult({required this.bytes, required this.removed});

  final Uint8List bytes;
  final bool removed;
}
