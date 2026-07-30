import 'package:get/get.dart';

class SearchHubController extends GetxController {
  final RxString searchQuery = ''.obs;
  final RxBool isLoading = false.obs;

  final RxList<String> recentSearches = <String>[].obs;
  final RxList<String> trendingSearches = <String>[].obs;
  final RxList<String> suggestions = <String>[].obs;

  @override
  void onInit() {
    super.onInit();
    _loadSearchData();
  }

  void _loadSearchData() {
    trendingSearches.assignAll([
      'Action Movies',
      'Live Sports',
      'New Series',
      'Documentaries',
      'Kids Shows',
      'News Channels',
      'International',
    ]);

    suggestions.assignAll([
      'Popular',
      'Trending',
      'Recently Added',
      'Favorites',
      'Continue Watching',
    ]);
  }

  void addRecentSearch(String query) {
    if (query.trim().isEmpty) return;
    recentSearches.remove(query.trim());
    recentSearches.insert(0, query.trim());
    if (recentSearches.length > 10) {
      recentSearches.removeLast();
    }
  }

  void clearRecentSearches() {
    recentSearches.clear();
  }
}