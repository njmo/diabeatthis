import 'repository/nightscout_repository_impl.dart';

class NightscoutCloudConnectionTester {
  const NightscoutCloudConnectionTester(this._repository);

  factory NightscoutCloudConnectionTester.fromUrl(String nightscoutUrl) {
    final url = nightscoutUrl.trim();
    if (url.isEmpty) {
      throw ArgumentError('Nightscout URL is required');
    }

    return NightscoutCloudConnectionTester(
      NightscoutRepositoryImpl(nightscoutUrl: url),
    );
  }

  final NightscoutRepositoryImpl _repository;

  Future<void> testConnection() async {
    await _repository.fetchStatus();
  }
}
