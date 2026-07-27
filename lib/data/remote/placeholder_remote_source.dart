// Placeholder file for remote data source layer.
// Handles HTTP requests to IPTV provider APIs (Xtream, Stalker, etc.)
class PlaceholderRemoteSource {
  final String baseUrl;

  PlaceholderRemoteSource({required this.baseUrl});

  Future<Map<String, dynamic>> fetch(String endpoint) async {
    // Remote API fetching logic will be implemented in Phase 2
    return {'status': 'ok', 'endpoint': endpoint};
  }
}
