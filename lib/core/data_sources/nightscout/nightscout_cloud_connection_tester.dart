import 'repository/nightscout_repository_impl.dart';

class NightscoutCloudConnectionTester {
  const NightscoutCloudConnectionTester(this._repository);

  final NightscoutRepositoryImpl _repository;

  Future<void> testConnection() async {
    await _repository.fetchStatus();
  }
}
