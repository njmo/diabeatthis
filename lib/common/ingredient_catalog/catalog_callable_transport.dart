abstract interface class CatalogCallableTransport {
  Future<Map<String, dynamic>> call(String function, Map<String, Object?> data);
}
