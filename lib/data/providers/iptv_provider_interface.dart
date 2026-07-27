// Placeholder file for provider adapters directory.
// Each IPTV provider (M3U, Xtream, Stalker) will have its own adapter implementation.
// All adapters must conform to the IPTVProvider interface (defined in Phase 2).

abstract class IPTVProviderInterface {
  Future<List<Map<String, dynamic>>> getCategories();
  Future<List<Map<String, dynamic>>> getChannels();
  Future<List<Map<String, dynamic>>> getMovies();
  Future<List<Map<String, dynamic>>> getSeries();
  Future<List<Map<String, dynamic>>> getEPG();
  Future<String> getStreamUrl(String channelId);
}
