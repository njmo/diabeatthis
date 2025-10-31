import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'nightscout_url_provider.g.dart';

@riverpod
String nightscoutUrl(Ref ref) {
  return 'https://oliwier.eu.nightscoutpro.com';
}