import 'dart:typed_data';

abstract interface class AiImageClient {
  Future<Uint8List> generate(String prompt);
}
