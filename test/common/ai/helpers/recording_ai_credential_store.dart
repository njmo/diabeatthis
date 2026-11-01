import 'package:diabeatthis/common/ai/ai_credential_store.dart';

class RecordingAiCredentialStore implements AiCredentialStore {
  final values = <String, String>{};
  final reads = <String>[];
  final writes = <({String key, String value})>[];
  final deletions = <String>[];
  Object? readError;

  @override
  Future<String?> read(String key) async {
    reads.add(key);
    if (readError != null) throw readError!;
    return values[key];
  }

  @override
  Future<void> write(String key, String value) async {
    writes.add((key: key, value: value));
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    deletions.add(key);
    values.remove(key);
  }
}
