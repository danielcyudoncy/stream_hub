import 'dart:async';
import 'dart:convert';

import 'package:stream_hub/core/errors/exceptions.dart';
import 'package:stream_hub/core/logging/logging_service.dart';
import 'package:stream_hub/data/models/xmltv_models.dart';
import 'package:xml/xml.dart';

class XMLTVParser {
  final LoggingService _logger;

  static const int kMaxGuideSizeBytes = 500 * 1024 * 1024;

  XMLTVParser({LoggingService? logger}) : _logger = logger ?? LoggingService();

  XMLTVGuide parse(String content, {String? sourceId}) {
    return _parseContent(content, sourceId: sourceId);
  }

  Future<XMLTVGuide> parseStream(Stream<List<int>> stream, {String? sourceId}) async {
    final buffer = StringBuffer();
    int totalBytes = 0;

    await for (final chunk in stream) {
      totalBytes += chunk.length;
      if (totalBytes > kMaxGuideSizeBytes) {
        throw ParsingException(
          message: 'XMLTV guide exceeds maximum size of ${kMaxGuideSizeBytes ~/ (1024 * 1024)}MB',
          code: 'GUIDE_TOO_LARGE',
        );
      }
      buffer.write(utf8.decode(chunk, allowMalformed: true));
    }

    return _parseContent(buffer.toString(), sourceId: sourceId, sizeBytes: totalBytes);
  }

  XMLTVGuide _parseContent(
    String content, {
    String? sourceId,
    int? sizeBytes,
  }) {
    final channels = <XMLTVChannel>[];
    final programs = <XMLTVProgram>[];
    final channelMap = <String, XMLTVChannel>{};

    String? version;
    String? encoding;

    try {
      final document = XmlDocument.parse(content);
      final tvElement = document.rootElement;

      version = tvElement.getAttribute('generator-info-name');

      for (final child in tvElement.children.whereType<XmlElement>()) {
        if (child.name.qualified == 'channel') {
          final channel = _parseChannelElement(child);
          if (channel != null) {
            channels.add(channel);
            channelMap[channel.id] = channel;
          }
        } else if (child.name.qualified == 'programme') {
          final program = _parseProgrammeElement(child, channelMap);
          if (program != null) {
            programs.add(program);
          }
        }
      }
    } on XmlException catch (e) {
      _logger.warning(
        'XMLTV parsing error: ${e.message}. Attempting recovery.',
        tag: 'XMLTVParser',
      );
    } on FormatException catch (e) {
      _logger.error(
        'XMLTV format error: $e',
        tag: 'XMLTVParser',
        error: e,
      );
      throw ParsingException(
        message: 'Failed to parse XMLTV guide: ${e.message}',
        code: 'PARSE_ERROR',
        originalError: e,
      );
    }

    return XMLTVGuide(
      sourceId: sourceId ?? 'unknown',
      channels: channels,
      programs: programs,
      generatedAt: DateTime.now(),
      version: version,
      sizeBytes: sizeBytes,
      encoding: encoding,
    );
  }

  XMLTVChannel? _parseChannelElement(XmlElement element) {
    final channelId = element.getAttribute('id') ?? '';
    if (channelId.isEmpty) {
      _logger.warning('Channel element missing id attribute', tag: 'XMLTVParser');
      return null;
    }

    String? displayName;
    String? iconUrl;
    String? language;
    String? country;
    final aliases = <String>[];
    final metadata = <String, dynamic>{};

    for (final child in element.children.whereType<XmlElement>()) {
      switch (child.name.qualified) {
        case 'display-name':
          displayName = child.innerText;
          break;
        case 'icon':
          iconUrl = child.getAttribute('src');
          break;
        case 'language':
          language = child.innerText;
          break;
        case 'country':
          country = child.innerText;
          break;
        case 'alias':
          aliases.add(child.getAttribute('name') ?? '');
          break;
        default:
          break;
      }
    }

    if (displayName == null || displayName.isEmpty) {
      displayName = channelId;
    }

    return XMLTVChannel(
      id: channelId,
      displayName: displayName,
      iconUrl: iconUrl,
      language: language,
      country: country,
      aliases: aliases,
      metadata: metadata,
    );
  }

  XMLTVProgram? _parseProgrammeElement(
    XmlElement element,
    Map<String, XMLTVChannel> channelMap,
  ) {
    final channelId = element.getAttribute('channel');
    final startStr = element.getAttribute('start');
    final stopStr = element.getAttribute('stop');

    if (channelId == null || channelId.isEmpty) {
      _logger.warning('Programme element missing channel attribute', tag: 'XMLTVParser');
      return null;
    }

    final start = _parseXmltvDateTime(startStr);
    final end = _parseXmltvDateTime(stopStr);
    final duration = (start != null && end != null) ? end.difference(start) : Duration.zero;

    String? title;
    String? subtitle;
    String? description;
    final categories = <String>[];
    String? language;
    String? country;
    String? episodeNum;
    String? season;
    String? episodeTitle;
    double? rating;
    final cast = <String>[];
    final directors = <String>[];
    final writers = <String>[];
    final producers = <String>[];
    final presenters = <String>[];
    final guests = <String>[];
    String? poster;
    bool isLive = false;
    bool isNew = false;
    bool isPremiere = false;
    bool isPreviouslyShown = false;
    final subtitleLanguages = <String>[];
    final metadata = <String, dynamic>{};

    for (final child in element.children.whereType<XmlElement>()) {
      switch (child.name.qualified) {
        case 'title':
          title = child.innerText;
          break;
        case 'sub-title':
          subtitle = child.innerText;
          break;
        case 'desc':
          description = child.innerText;
          break;
        case 'category':
          final cat = child.innerText;
          if (cat.isNotEmpty) categories.add(cat);
          break;
        case 'language':
          language = child.innerText;
          break;
        case 'country':
          country = child.innerText;
          break;
        case 'episode-num':
          episodeNum = child.innerText;
          final system = child.getAttribute('system');
          if (system == 'xmltv_ns' && episodeNum.isNotEmpty) {
            final parts = episodeNum.split('.');
          if (parts.isNotEmpty) season = parts[0];
          if (parts.length >= 2) episodeTitle = parts.sublist(1).join('.');
          }
          break;
        case 'date':
          final dateStr = child.innerText;
          metadata['date'] = dateStr;
          break;
        case 'rating':
          final ratingValue = _parseRating(child);
          if (ratingValue != null) rating = ratingValue;
          break;
        case 'credits':
          _parseCredits(child, directors, writers, cast, producers, presenters, guests);
          break;
        case 'icon':
          poster = child.getAttribute('src');
          break;
        case 'new':
          isNew = true;
          break;
        case 'premiere':
          isPremiere = true;
          break;
        case 'last-chance':
          isPreviouslyShown = true;
          break;
        case 'previously-shown':
          isPreviouslyShown = true;
          break;
        case 'video':
          _parseVideoElement(child, metadata);
          break;
        case 'audio':
          _parseAudioElement(child, metadata);
          break;
        case 'subtitles':
          _parseSubtitlesElement(child, subtitleLanguages, metadata);
          break;
        case 'star-rating':
          final starRating = _parseStarRating(child);
          if (starRating != null) rating = starRating;
          break;
        default:
          break;
      }
    }

    if (title == null || title.isEmpty) {
      return null;
    }

    final safeTitle = title.replaceAll(RegExp(r'[^\w\s\-.]'), '').trim();
    final safeChannelId = channelId.replaceAll(RegExp(r'[^\w\-.]'), '_');
    final id = 'xmltv-program-$safeChannelId-${start?.millisecondsSinceEpoch ?? DateTime.now().millisecondsSinceEpoch}-${safeTitle.hashCode}';

    final now = DateTime.now();
    final resolvedVideoAspect = metadata['videoAspect'] as String?;
    final resolvedVideoQuality = metadata['videoQuality'] as String?;
    final resolvedVideoCodec = metadata['videoCodec'] as String?;
    final resolvedAudioStereo = metadata['audioStereo'] as String?;
    final resolvedAudioCodec = metadata['audioCodec'] as String?;
    final resolvedAudioChannels = metadata['audioChannels'] != null ? int.tryParse(metadata['audioChannels'].toString()) : null;

    return XMLTVProgram(
      id: id,
      channelId: channelId,
      title: title,
      subtitle: subtitle,
      description: description,
      categories: categories,
      language: language,
      country: country,
      start: start ?? now,
      end: end ?? start ?? now,
      duration: duration,
      episodeNum: episodeNum,
      season: season,
      episodeTitle: episodeTitle,
      rating: rating,
      cast: cast,
      directors: directors,
      writers: writers,
      producers: producers,
      presenters: presenters,
      guests: guests,
      poster: poster,
      isLive: isLive,
      isNew: isNew,
      isPremiere: isPremiere,
      isPreviouslyShown: isPreviouslyShown,
      videoAspect: resolvedVideoAspect,
      videoQuality: resolvedVideoQuality,
      videoCodec: resolvedVideoCodec,
      audioStereo: resolvedAudioStereo,
      audioCodec: resolvedAudioCodec,
      audioChannels: resolvedAudioChannels,
      subtitleLanguages: subtitleLanguages,
      metadata: metadata,
      createdAt: now,
      updatedAt: now,
    );
  }

  void _parseCredits(
    XmlElement element,
    List<String> directors,
    List<String> writers,
    List<String> cast,
    List<String> producers,
    List<String> presenters,
    List<String> guests,
  ) {
    for (final child in element.children.whereType<XmlElement>()) {
      final text = child.innerText;
      if (text.isNotEmpty) {
        switch (child.name.qualified) {
          case 'director':
            directors.add(text);
            break;
          case 'actor':
            cast.add(text);
            break;
          case 'writer':
            writers.add(text);
            break;
          case 'producer':
            producers.add(text);
            break;
          case 'presenter':
            presenters.add(text);
            break;
          case 'guest':
            guests.add(text);
            break;
        }
      }
    }
  }

  void _parseVideoElement(XmlElement element, Map<String, dynamic> metadata) {
    for (final child in element.children.whereType<XmlElement>()) {
      final text = child.innerText;
      if (text.isNotEmpty) {
        switch (child.name.qualified) {
          case 'aspect':
            metadata['videoAspect'] = text;
            break;
          case 'quality':
            metadata['videoQuality'] = text;
            break;
          case 'codec':
            metadata['videoCodec'] = text;
            break;
          case 'resolution':
            metadata['videoResolution'] = text;
            break;
          default:
            break;
        }
      }
    }
  }

  void _parseAudioElement(XmlElement element, Map<String, dynamic> metadata) {
    for (final child in element.children.whereType<XmlElement>()) {
      final text = child.innerText;
      if (text.isNotEmpty) {
        switch (child.name.qualified) {
          case 'stereo':
            metadata['audioStereo'] = text;
            break;
          case 'codec':
            metadata['audioCodec'] = text;
            break;
          case 'channels':
            metadata['audioChannels'] = text;
            break;
          default:
            break;
        }
      }
    }
  }

  void _parseSubtitlesElement(
    XmlElement element,
    List<String> subtitleLanguages,
    Map<String, dynamic> metadata,
  ) {
    for (final child in element.children.whereType<XmlElement>()) {
      switch (child.name.qualified) {
        case 'language':
          final lang = child.innerText;
          if (lang.isNotEmpty) subtitleLanguages.add(lang);
          break;
        case 'format':
          final fmt = child.innerText;
          if (fmt.isNotEmpty) metadata['subtitleFormat'] = fmt;
          break;
        default:
          break;
      }
    }
  }

  double? _parseRating(XmlElement element) {
    for (final child in element.children.whereType<XmlElement>()) {
      if (child.name.qualified == 'value') {
        return double.tryParse(child.innerText);
      }
    }
    return null;
  }

  double? _parseStarRating(XmlElement element) {
    for (final child in element.children.whereType<XmlElement>()) {
      if (child.name.qualified == 'value') {
        return double.tryParse(child.innerText);
      }
    }
    return null;
  }

  DateTime? _parseXmltvDateTime(String? value) {
    if (value == null || value.isEmpty) return null;

    try {
      final clean = value.replaceAll(RegExp(r'[+-]\d{4}$'), '');
      return DateTime.parse(clean);
    } on FormatException {
      _logger.warning('Failed to parse XMLTV datetime: $value', tag: 'XMLTVParser');
      return null;
    }
  }
}