import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../clients/open_food_facts_product_client.dart';

part 'open_food_facts_product_client_provider.g.dart';

@riverpod
OpenFoodFactsProductClient openFoodFactsProductClient(Ref ref) {
  return OpenFoodFactsProductClient();
}
