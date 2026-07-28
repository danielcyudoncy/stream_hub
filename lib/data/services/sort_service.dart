import 'package:stream_hub/data/models/media_item.dart';

abstract class SortService {
  List<MediaItem> sort(List<MediaItem> items, String field, bool ascending);
}
