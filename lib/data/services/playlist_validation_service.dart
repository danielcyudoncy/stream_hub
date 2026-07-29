import 'package:stream_hub/core/logging/logging_service.dart';
import 'package:stream_hub/data/models/m3u_models.dart';
import 'package:stream_hub/data/parsers/m3u_parser.dart';

class PlaylistValidationService {
  final LoggingService _logger;

  PlaylistValidationService(this._logger);

  M3UValidationResult validate(String content) {
    try {
      final parser = M3UParser();
      return parser.validate(content);
    } catch (e) {
      _logger.error(
        'Playlist validation failed',
        tag: 'PlaylistValidationService',
        error: e,
      );
      return M3UValidationResult(
        isValid: false,
        errors: ['Validation process failed: $e'],
      );
    }
  }

  List<String> getValidationSummary(M3UValidationResult result) {
    final summary = <String>[];

    if (result.isValid) {
      summary.add('Playlist is valid');
    } else {
      summary.add('Playlist is invalid');
    }

    if (result.hasValidHeader) {
      summary.add('Header is valid');
    } else {
      summary.add('Missing or invalid #EXTM3U header');
    }

    if (result.encoding != null) {
      summary.add('Encoding: ${result.encoding}');
    }

    if (result.duplicateCount > 0) {
      summary.add('Duplicates found: ${result.duplicateCount}');
    }

    if (result.missingUrlCount > 0) {
      summary.add('Missing URLs: ${result.missingUrlCount}');
    }

    if (result.malformedEntryCount > 0) {
      summary.add('Malformed entries: ${result.malformedEntryCount}');
    }

    for (final error in result.errors) {
      summary.add('Error: $error');
    }

    for (final warning in result.warnings) {
      summary.add('Warning: $warning');
    }

    return summary;
  }
}
