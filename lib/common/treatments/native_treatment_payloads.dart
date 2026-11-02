/// Extracts raw AAPS records without invoking the treatment factory.
List<Map<String, dynamic>>? nativeTreatmentPayloads(
  Map<String, dynamic> event,
) {
  if (event['external_event'] != 'native_receiver') return null;
  final receiver = event['data'];
  if (receiver is! Map || receiver['kind'] != 'treatments') return null;
  final data = receiver['data'];
  final payload = data is Map && data.containsKey('data') ? data['data'] : data;
  if (payload is Map) return [Map<String, dynamic>.from(payload)];
  if (payload is List && payload.every((item) => item is Map)) {
    return payload
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }
  throw const FormatException('Invalid local treatment payload');
}
