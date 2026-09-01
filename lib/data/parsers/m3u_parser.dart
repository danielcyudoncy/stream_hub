import 'dart:convert';

import 'package:stream_hub/data/models/m3u_models.dart';

class M3UParser {
  static const _extm3u = '#EXTM3U';
  static const _extinfPrefix = '#EXTINF:';
  static const _extinfTvgId = 'tvg-id';
  static const _extinfTvgName = 'tvg-name';
  static const _extinfTvgLogo = 'tvg-logo';
  static const _extinfGroupTitle = 'group-title';
  static const _extinfRadio = 'radio';
  static const _extinfCatchupDays = 'catchup-days';
  static const _extinfCatchupSource = 'catchup-source';
  static const _extinfLanguage = 'language';
  static const _extinfCountry = 'country';
  static const int kMaxPlaylistSizeBytes = 200 * 1024 * 1024; // 200MB

  M3UPlaylistResult parse(String content) {
    final warnings = <String>[];
    final channels = <M3UChannel>[];
    final groups = <String>{};
    final languages = <String>{};
    final countries = <String>{};
    var validEntries = 0;
    var invalidEntries = 0;
    var duplicateEntries = 0;
    final seenUrls = <String>{};

    String? encoding;
    bool hasValidHeader = false;
    String? epgUrl;

    // Strip UTF-8 BOM if present
    if (content.startsWith('﻿')) {
      content = content.substring(1);
    }

    if (content.length > kMaxPlaylistSizeBytes) {
      return M3UPlaylistResult(
        channels: const [],
        warnings: ['Playlist exceeds maximum size of ${kMaxPlaylistSizeBytes ~/ (1024 * 1024)}MB'],
        hasValidHeader: content.startsWith(_extm3u),
        epgUrl: epgUrl,
      );
    }

    if (content.startsWith(_extm3u)) {
      hasValidHeader = true;
      final headerLine = content.split('\n').first;
      final match = RegExp(r'#EXTM3U\s+(.*)').firstMatch(headerLine);
      if (match != null) {
        final header = match.group(1) ?? '';
        final encMatch = RegExp(r'charset="?([^"\s]+)"?').firstMatch(header);
        if (encMatch != null) {
          encoding = encMatch.group(1)?.toLowerCase();
        }
        final epgMatch = RegExp(r'(?:url-tvg|x-tvg-url)="?([^"\s]+)"?').firstMatch(header);
        if (epgMatch != null) {
          epgUrl = epgMatch.group(1);
        }
      }
    }

    String? currentTitle;
    String? currentStreamUrl;
    String? currentLogo;
    String? currentGroup;
    String? currentTvgId;
    String? currentTvgName;
    bool currentIsRadio = false;
    String? currentLanguage;
    String? currentCountry;
    final Map<String, String> currentCatchup = {};
    final Map<String, String> currentAttributes = {};
    final List<String> currentWarnings = <String>[];

    final lines = const LineSplitter().convert(content);
    int processedLines = 0;

    for (final rawLine in lines) {
      final line = rawLine.trim();
      processedLines++;

      if (line.isEmpty) continue;

      if (line.startsWith('#')) {
        if (line.startsWith(_extinfPrefix)) {
          _parseExtinf(
            line,
            title: (v) => currentTitle = v,
            streamUrl: (v) => currentStreamUrl = v,
            logo: (v) => currentLogo = v,
            group: (v) => currentGroup = v,
            tvgId: (v) => currentTvgId = v,
            tvgName: (v) => currentTvgName = v,
            isRadio: (v) => currentIsRadio = v,
            language: (v) => currentLanguage = v,
            country: (v) => currentCountry = v,
            catchup: currentCatchup,
            attributes: currentAttributes,
            warnings: currentWarnings,
          );
        } else if (line.startsWith('#EXT')) {
          _parseGenericExt(line, currentAttributes, currentWarnings);
        }
      } else {
        final trimmedUrl = line.trim();
        if (trimmedUrl.isEmpty) continue;

        currentStreamUrl ??= trimmedUrl;

        if (currentTitle != null && currentStreamUrl != null) {
          final id = _generateId(currentTvgId ?? '', currentTitle!, currentStreamUrl!);

          if (seenUrls.contains(currentStreamUrl)) {
            duplicateEntries++;
            warnings.add('Duplicate stream URL: $currentStreamUrl');
          } else {
            seenUrls.add(currentStreamUrl!);
          }

          if (currentGroup != null && currentGroup!.isNotEmpty) {
            groups.add(currentGroup!);
          }
          if (currentLanguage != null && currentLanguage!.isNotEmpty) {
            languages.add(currentLanguage!);
          }
          if (currentCountry != null && currentCountry!.isNotEmpty) {
            countries.add(currentCountry!);
          }

          channels.add(M3UChannel(
            id: id,
            title: currentTitle!,
            streamUrl: currentStreamUrl,
            logo: currentLogo,
            group: currentGroup,
            tvgId: currentTvgId,
            tvgName: currentTvgName,
            isRadio: currentIsRadio,
            language: currentLanguage,
            country: currentCountry,
            catchup: Map.unmodifiable(currentCatchup),
            attributes: Map.unmodifiable(currentAttributes),
            warnings: List.unmodifiable(currentWarnings),
          ));

          validEntries++;
        } else {
          invalidEntries++;
          warnings.add('Entry missing required metadata at line $processedLines');
        }

        currentTitle = null;
        currentStreamUrl = null;
        currentLogo = null;
        currentGroup = null;
        currentTvgId = null;
        currentTvgName = null;
        currentIsRadio = false;
        currentLanguage = null;
        currentCountry = null;
        currentCatchup.clear();
        currentAttributes.clear();
        currentWarnings.clear();
      }
    }

    return M3UPlaylistResult(
      channels: channels,
      groups: groups.toList(growable: false),
      languages: languages.toList(growable: false),
      countries: countries.toList(growable: false),
      totalEntries: validEntries + invalidEntries + duplicateEntries,
      validEntries: validEntries,
      invalidEntries: invalidEntries,
      duplicateEntries: duplicateEntries,
      warnings: warnings,
      encoding: encoding,
      hasValidHeader: hasValidHeader,
      epgUrl: epgUrl,
    );
  }

  void _parseExtinf(
    String line, {
    required void Function(String) title,
    required void Function(String) streamUrl,
    required void Function(String) logo,
    required void Function(String) group,
    required void Function(String) tvgId,
    required void Function(String) tvgName,
    required void Function(bool) isRadio,
    required void Function(String) language,
    required void Function(String) country,
    required Map<String, String> catchup,
    required Map<String, String> attributes,
    required List<String> warnings,
  }) {
    try {
      final commaIndex = line.lastIndexOf(',');
      if (commaIndex == -1) {
        warnings.add('Malformed EXTINF line: $line');
        return;
      }

      final namePart = line.substring(commaIndex + 1).trim();
      if (namePart.isEmpty) {
        warnings.add('Empty channel name in EXTINF line');
      }
      title(namePart);

      final attrPart = line.substring(_extinfPrefix.length, commaIndex).trim();
      final attrs = _parseAttributes(attrPart);

      if (attrs.containsKey(_extinfTvgId)) tvgId(attrs[_extinfTvgId]!);
      if (attrs.containsKey(_extinfTvgName)) tvgName(attrs[_extinfTvgName]!);
      if (attrs.containsKey(_extinfTvgLogo)) logo(attrs[_extinfTvgLogo]!);
      if (attrs.containsKey(_extinfGroupTitle)) group(attrs[_extinfGroupTitle]!);
      if (attrs.containsKey(_extinfRadio)) {
        isRadio(attrs[_extinfRadio]!.toLowerCase() == 'true');
      }
      if (attrs.containsKey(_extinfLanguage)) language(attrs[_extinfLanguage]!);
      if (attrs.containsKey(_extinfCountry)) country(attrs[_extinfCountry]!);

      final catchupDays = attrs[_extinfCatchupDays];
      final catchupSource = attrs[_extinfCatchupSource];
      if (catchupDays != null) catchup['days'] = catchupDays;
      if (catchupSource != null) catchup['source'] = catchupSource;

      attributes.addAll(attrs);
    } catch (e) {
      warnings.add('Failed to parse EXTINF: $e');
    }
  }

  void _parseGenericExt(
    String line,
    Map<String, String> attributes,
    List<String> warnings,
  ) {
    if (line.contains('=')) {
      try {
        final attrs = _parseAttributes(line);
        attributes.addAll(attrs);
      } catch (e) {
        warnings.add('Failed to parse extension line: $e');
      }
    }
  }

  Map<String, String> _parseAttributes(String input) {
    final result = <String, String>{};
    final regex = RegExp(r'([a-zA-Z0-9\-]+)="([^"]*)"');
    final matches = regex.allMatches(input);

    for (final match in matches) {
      final key = match.group(1)?.toLowerCase().trim();
      final value = match.group(2) ?? '';
      if (key != null && key.isNotEmpty) {
        result[key] = value;
      }
    }

    final unquoted = RegExp(r'([a-zA-Z0-9\-]+)=([^\s,]+)');
    final remaining = unquoted.allMatches(input);
    for (final match in remaining) {
      final key = match.group(1)?.toLowerCase().trim();
      final value = match.group(2) ?? '';
      if (key != null && key.isNotEmpty && !result.containsKey(key)) {
        result[key] = value;
      }
    }

    return result;
  }

  String _generateId(String? tvgId, String title, String streamUrl) {
    if (tvgId != null && tvgId.isNotEmpty) return 'tvg-$tvgId';
    final uri = Uri.tryParse(streamUrl);
    if (uri != null && uri.host.isNotEmpty) {
      final slug = title.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-');
      return '${uri.host}-$slug';
    }
    final slug = title.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-');
    return 'channel-$slug';
  }

  M3UValidationResult validate(String content) {
    final errors = <String>[];
    final warnings = <String>[];
    var duplicateCount = 0;
    var missingUrlCount = 0;
    var malformedEntryCount = 0;

    if (content.trim().isEmpty) {
      return const M3UValidationResult(
        isValid: false,
        errors: ['Playlist content is empty'],
      );
    }

    bool hasValidHeader = content.trim().startsWith(_extm3u);

    if (!hasValidHeader) {
      warnings.add('Missing #EXTM3U header');
    }

    if (content.length > kMaxPlaylistSizeBytes) {
      errors.add('Playlist exceeds maximum size of ${kMaxPlaylistSizeBytes ~/ (1024 * 1024)}MB');
      return M3UValidationResult(
        isValid: false,
        hasValidHeader: hasValidHeader,
        errors: errors,
        warnings: warnings,
        duplicateCount: 0,
        missingUrlCount: 0,
        malformedEntryCount: 0,
      );
    }

    final lines = const LineSplitter().convert(content);
    final seenUrls = <String>{};
    String? lastTitle;

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      if (trimmed.startsWith('#')) {
        if (trimmed.startsWith(_extinfPrefix)) {
          final commaIndex = trimmed.lastIndexOf(',');
          if (commaIndex != -1 && commaIndex + 1 < trimmed.length) {
            lastTitle = trimmed.substring(commaIndex + 1).trim();
          } else {
            lastTitle = '';
          }
        }
        continue;
      }

      if (lastTitle == null || lastTitle.isEmpty) {
        malformedEntryCount++;
        warnings.add('Stream URL without preceding metadata');
        continue;
      }

      if (trimmed.isEmpty) {
        missingUrlCount++;
        warnings.add('Empty stream URL');
        continue;
      }

      try {
        final uri = Uri.parse(trimmed);
        if (!uri.isAbsolute || (!uri.scheme.startsWith('http'))) {
          missingUrlCount++;
          warnings.add('Invalid stream URL: $trimmed');
          lastTitle = null;
          continue;
        }
      } on FormatException {
        missingUrlCount++;
        warnings.add('Invalid stream URL: $trimmed');
        lastTitle = null;
        continue;
      }

      if (seenUrls.contains(trimmed)) {
        duplicateCount++;
      } else {
        seenUrls.add(trimmed);
      }

      lastTitle = null;
    }

    return M3UValidationResult(
      isValid: errors.isEmpty,
      hasValidHeader: hasValidHeader,
      errors: errors,
      warnings: warnings,
      duplicateCount: duplicateCount,
      missingUrlCount: missingUrlCount,
      malformedEntryCount: malformedEntryCount,
    );
  }

  Future<M3UPlaylistResult> parseStream(Stream<List<int>> stream) async {
    final buffer = StringBuffer();
    await for (final chunk in stream) {
      buffer.write(utf8.decode(chunk));
    }
    return parse(buffer.toString());
  }
}
