import '../../../../core/data_sources/nightscout/helpers/treatments_factory.dart';
import '../../../../core/domain/model/treatment_base.dart';

class LocalTreatmentsEvent {
  const LocalTreatmentsEvent({required this.data, required this.rawPayloads});

  final List<Treatment> data;
  final List<Map<String, dynamic>> rawPayloads;

  factory LocalTreatmentsEvent.fromJson(Map<String, dynamic> json) {
    final rawPayloads = _rawTreatmentPayloads(json);

    return LocalTreatmentsEvent(
      data: TreatmentFactory().parseTreatments(rawPayloads),
      rawPayloads: rawPayloads,
    );
  }

  Map<String, dynamic> toJson() {
    return {'data': rawPayloads};
  }

  static List<Map<String, dynamic>> _rawTreatmentPayloads(
    Map<String, dynamic> json,
  ) {
    final payload = json.containsKey('data') ? json['data'] : json;

    if (payload is List) {
      final treatments = <Map<String, dynamic>>[];
      for (final entry in payload) {
        final treatment = _rawTreatmentPayload(entry);
        if (treatment == null) {
          throw FormatException(
            'Invalid local treatments event payload: $json',
          );
        }
        treatments.add(treatment);
      }
      return treatments;
    }

    final treatment = _rawTreatmentPayload(payload);
    if (treatment == null) {
      throw FormatException('Invalid local treatments event payload: $json');
    }

    return [treatment];
  }

  static Map<String, dynamic>? _rawTreatmentPayload(Object? payload) {
    if (payload is Map<String, dynamic>) return payload;
    if (payload is Map) return Map<String, dynamic>.from(payload);
    return null;
  }
}
