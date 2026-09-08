import 'package:stream_hub/data/models/download_item.dart';

/// Repository interface for persisting and querying downloaded media items.
abstract class DownloadRepository {
  /// Fetches all recorded downloads.
  Future<List<DownloadItem>> getAllDownloads();

  /// Fetches a specific download item by its [id].
  Future<DownloadItem?> getDownload(String id);

  /// Saves or updates a download item.
  Future<void> saveDownload(DownloadItem item);

  /// Deletes a download record by [id].
  Future<void> deleteDownload(String id);

  /// Clears all download records from the database.
  Future<void> clearAll();

  /// Stream of updates to the list of downloads.
  Stream<List<DownloadItem>> watchDownloads();
}
