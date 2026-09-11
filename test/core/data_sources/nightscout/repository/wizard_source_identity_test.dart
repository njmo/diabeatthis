import 'package:diabeatthis/core/data_sources/nightscout/repository/nightscout_repository_impl.dart';
import 'package:diabeatthis/core/data_sources/nightscout/services/nightscout_service.dart';
import 'package:diabeatthis/core/domain/model/bolus_wizard.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'Nightscout records carry their request source without tokens, including a URL without a scheme',
    () async {
      for (final url in ['https://example.com?token=secret', 'example.com']) {
        final repository = NightscoutRepositoryImpl(
          nightscoutUrl: url,
          service: WizardSourceService(),
        );
        final at = DateTime(2026, 9, 11);
        final records = [
          ...(await repository.fetchBolusWizardsOnDay(at)),
          ...(await repository.fetchBolusWizardsAfter(at)),
          ...(await repository.fetchTreatmentsOnDay(
            at,
          )).whereType<BolusWizard>(),
        ];
        expect(records, hasLength(3));
        expect(records.map((record) => record.remoteSource).toSet(), {
          'https://example.com',
        });
        expect(records.every((record) => record.localId == null), isTrue);
      }
    },
  );
}

class WizardSourceService extends NightscoutService {
  WizardSourceService() : super(nightscoutUrl: '');
  @override
  Future<dynamic> fetchNightscoutData(Uri url) async => [
    {
      '_id': 'ns1',
      'created_at': '2026-09-11T12:00:00Z',
      'glucose': 120,
      'eventType': 'Bolus Wizard',
      'bolusCalculatorResult': {'carbs': 20, 'totalInsulin': 2},
    },
  ];
}
