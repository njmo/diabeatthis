import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'ai_credential_store.dart';

class SecureAiCredentialStore implements AiCredentialStore {
  const SecureAiCredentialStore({
    this.storage = const FlutterSecureStorage(
      iOptions: IOSOptions(
        accessibility: KeychainAccessibility.first_unlock_this_device,
      ),
    ),
  });

  final FlutterSecureStorage storage;

  @override
  Future<String?> read(String key) => storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => storage.delete(key: key);
}
