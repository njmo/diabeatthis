import 'package:diabeatthis/core/data_sources/nightscout/repository/nightscout_repository_impl.dart';
import 'package:diabeatthis/core/data_sources/nightscout/services/nightscout_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('NightscoutRepositoryImpl', () {
    test('adds token query parameter when token is configured', () async {
      final service = _CapturingNightscoutService();
      final repository = NightscoutRepositoryImpl(
        nightscoutUrl: 'https://example-nightscout.com',
        nightscoutToken: 'secret-token',
        service: service,
      );

      await repository.fetchStatus();

      expect(
        service.requestedUrls.single.queryParameters['token'],
        'secret-token',
      );
    });

    test('keeps token query parameter from Nightscout URL', () async {
      final service = _CapturingNightscoutService();
      final repository = NightscoutRepositoryImpl(
        nightscoutUrl: 'https://example-nightscout.com?token=url-token',
        service: service,
      );

      await repository.fetchStatus();

      expect(
        service.requestedUrls.single.queryParameters['token'],
        'url-token',
      );
    });

    test(
      'uses configured token instead of token from Nightscout URL',
      () async {
        final service = _CapturingNightscoutService();
        final repository = NightscoutRepositoryImpl(
          nightscoutUrl: 'https://example-nightscout.com?token=url-token',
          nightscoutToken: 'configured-token',
          service: service,
        );

        await repository.fetchStatus();

        expect(
          service.requestedUrls.single.queryParameters['token'],
          'configured-token',
        );
      },
    );

    test('does not add token query parameter when token is empty', () async {
      final service = _CapturingNightscoutService();
      final repository = NightscoutRepositoryImpl(
        nightscoutUrl: 'https://example-nightscout.com',
        service: service,
      );

      await repository.fetchStatus();

      expect(
        service.requestedUrls.single.queryParameters,
        isNot(contains('token')),
      );
    });
  });
}

class _CapturingNightscoutService extends NightscoutService {
  _CapturingNightscoutService() : super(nightscoutUrl: '');

  final List<Uri> requestedUrls = [];

  @override
  Future<dynamic> fetchNightscoutData(Uri url) async {
    requestedUrls.add(url);
    return {};
  }
}
