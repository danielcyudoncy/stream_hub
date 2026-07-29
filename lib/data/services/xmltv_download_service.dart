import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:stream_hub/core/errors/exceptions.dart';
import 'package:stream_hub/core/logging/logging_service.dart';
import 'package:stream_hub/data/models/xmltv_models.dart';

class DownloadProgress {
  final double progress;
  final int downloadedBytes;
  final int totalBytes;
  final bool isComplete;

  const DownloadProgress({
    required this.progress,
    required this.downloadedBytes,
    this.totalBytes = 0,
    this.isComplete = false,
  });
}

class CancellationToken {
  bool _isCancelled = false;
  final List<void Function()> _callbacks = [];

  bool get isCancelled => _isCancelled;

  void cancel() {
    _isCancelled = true;
    for (final callback in _callbacks) {
      callback();
    }
    _callbacks.clear();
  }

  void attach(void Function() callback) {
    if (!_isCancelled) {
      _callbacks.add(callback);
    }
  }
}

class XMLTVDownloadService {
  final LoggingService _logger;
  final HttpClient _client = HttpClient();

  XMLTVDownloadService(this._logger);

  Future<XMLTVDownloadResult> download({
    required XMLTVConfig config,
    StreamController<DownloadProgress>? progressController,
    CancellationToken? cancellationToken,
  }) async {
    final sourceUrl = config.localPath ?? config.sourceUrl;

    if (sourceUrl.isEmpty) {
      throw ValidationException(
        message: 'No XMLTV source URL or local file path provided',
        code: 'MISSING_SOURCE',
      );
    }

    if (config.localPath != null) {
      return _loadLocalFile(config.localPath!, cancellationToken);
    }

    return _downloadRemote(sourceUrl, config, progressController, cancellationToken);
  }

  XMLTVDownloadResult _loadLocalFile(
    String path,
    CancellationToken? cancellationToken,
  ) {
    if (cancellationToken?.isCancelled == true) {
      throw NetworkException(
        message: 'Download cancelled',
        code: 'CANCELLED',
      );
    }

    final file = File(path);
    if (!file.existsSync()) {
      throw NetworkException(
        message: 'Local XMLTV file not found',
        code: 'FILE_NOT_FOUND',
      );
    }

    final bytes = file.readAsBytesSync();
    final fileName = path.toLowerCase();

    String content;
    String? encoding;
    int? sizeBytes;

    if (fileName.endsWith('.gz') || fileName.endsWith('.xml.gz')) {
      sizeBytes = bytes.length;
      final decoded = gzip.decode(bytes);
      content = utf8.decode(decoded, allowMalformed: true);
      encoding = 'utf-8';
    } else if (fileName.endsWith('.xml')) {
      sizeBytes = bytes.length;
      content = utf8.decode(bytes, allowMalformed: true);
      encoding = _detectEncoding(bytes);
    } else {
      sizeBytes = bytes.length;
      content = utf8.decode(bytes, allowMalformed: true);
      encoding = 'utf-8';
    }

    _logger.info(
      'Loaded local XMLTV file: $path (${bytes.length} bytes, encoding: $encoding)',
      tag: 'XMLTVDownloadService',
    );

    return XMLTVDownloadResult(
      content: content,
      sizeBytes: sizeBytes,
      encoding: encoding,
      isCompressed: fileName.endsWith('.gz') || fileName.endsWith('.xml.gz'),
      source: path,
    );
  }

  Future<XMLTVDownloadResult> _downloadRemote(
    String urlString,
    XMLTVConfig config,
    StreamController<DownloadProgress>? progressController,
    CancellationToken? cancellationToken,
  ) async {
    final uri = Uri.parse(urlString);
    var remainingRetries = config.maxRetries;
    Exception? lastException;

    while (remainingRetries > 0) {
      try {
        if (cancellationToken?.isCancelled == true) {
          throw NetworkException(
            message: 'Download cancelled',
            code: 'CANCELLED',
          );
        }

        return await _performRequest(
          uri,
          config,
          progressController,
          cancellationToken,
        );
      } on SocketException catch (e) {
        lastException = NetworkException(
          message: 'Network error: ${e.message}',
          code: 'NETWORK_ERROR',
          originalError: e,
        );
      } on HttpException catch (e) {
        lastException = NetworkException(
          message: 'HTTP error: ${e.message}',
          code: 'HTTP_ERROR',
          originalError: e,
        );
      } on HandshakeException catch (e) {
        lastException = NetworkException(
          message: 'SSL/TLS error: ${e.message}',
          code: 'SSL_ERROR',
          originalError: e,
        );
      } on TimeoutException catch (e) {
        lastException = NetworkException(
          message: 'Request timed out',
          code: 'TIMEOUT',
          originalError: e,
        );
      } on FormatException catch (e) {
        lastException = NetworkException(
          message: 'Invalid URL format: ${e.message}',
          code: 'INVALID_URL',
          originalError: e,
        );
      } catch (e) {
        lastException = NetworkException(
          message: 'Unexpected error: $e',
          code: 'UNKNOWN_ERROR',
          originalError: e,
        );
      }

      remainingRetries--;
      if (remainingRetries > 0) {
        _logger.warning(
          'XMLTV download failed, retrying in ${config.retryDelay.inSeconds}s...',
          tag: 'XMLTVDownloadService',
          error: lastException,
        );
        await Future.delayed(config.retryDelay);
      }
    }

    _logger.error(
      'XMLTV download failed after ${config.maxRetries} retries',
      tag: 'XMLTVDownloadService',
      error: lastException,
    );
    throw lastException!;
  }

  Future<XMLTVDownloadResult> _performRequest(
    Uri uri,
    XMLTVConfig config,
    StreamController<DownloadProgress>? progressController,
    CancellationToken? cancellationToken,
  ) async {
    final request = await _client.getUrl(uri);

    _applyAuth(request, config);
    _applyHeaders(request, config);

    request.followRedirects = config.followRedirects;
    request.maxRedirects = config.maxRedirects;

    if (cancellationToken != null) {
      cancellationToken.attach(() {
        request.abort();
      });
    }

    final stopwatch = Stopwatch()..start();
    final response = await request.close();
    stopwatch.stop();

    _logger.info(
      'XMLTV download response: ${response.statusCode} (${stopwatch.elapsedMilliseconds}ms)',
      tag: 'XMLTVDownloadService',
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      if (response.statusCode == 401) {
        throw AuthenticationException(
          message: 'Authentication required. Please check your credentials.',
          code: 'AUTH_REQUIRED',
        );
      }
      if (response.statusCode == 403) {
        throw AuthenticationException(
          message: 'Access denied. Please check your credentials.',
          code: 'ACCESS_DENIED',
        );
      }
      if (response.statusCode == 404) {
        throw NetworkException(
          message: 'XMLTV guide not found (404). Please verify the URL.',
          code: 'NOT_FOUND',
        );
      }
      throw NetworkException(
        message: 'HTTP ${response.statusCode}: ${response.reasonPhrase}',
        code: 'HTTP_ERROR',
      );
    }

    final contentEncoding = response.headers.value(HttpHeaders.contentEncodingHeader);
    final contentLength = response.contentLength;

    final bytes = <int>[];
    int downloaded = 0;

    await for (final chunk in response) {
      if (cancellationToken?.isCancelled == true) {
        throw NetworkException(
          message: 'Download cancelled',
          code: 'CANCELLED',
        );
      }

      bytes.addAll(chunk);
      downloaded += chunk.length;

      if (progressController != null && !progressController.isClosed) {
        final progress = contentLength > 0 ? downloaded / contentLength : 0.0;
        progressController.add(DownloadProgress(
          progress: progress.clamp(0.0, 1.0),
          downloadedBytes: downloaded,
          totalBytes: contentLength > 0 ? contentLength : downloaded,
          isComplete: false,
        ));
      }
    }

    if (progressController != null && !progressController.isClosed) {
      progressController.add(const DownloadProgress(
        progress: 1.0,
        downloadedBytes: 0,
        totalBytes: 0,
        isComplete: true,
      ));
    }

    String content;
    String? encoding;
    bool isCompressed = false;

    try {
      if (contentEncoding != null) {
        final enc = contentEncoding.toLowerCase();
        if (enc.contains('gzip')) {
          content = utf8.decode(gzip.decode(bytes), allowMalformed: true);
          isCompressed = true;
          encoding = 'utf-8';
        } else if (enc.contains('deflate')) {
          content = utf8.decode(zlib.decode(bytes), allowMalformed: true);
          isCompressed = true;
          encoding = 'utf-8';
        } else {
          content = utf8.decode(bytes, allowMalformed: true);
          encoding = _detectEncoding(bytes);
        }
      } else {
        final fileName = uri.path.toLowerCase();
        if (fileName.endsWith('.gz') || fileName.endsWith('.xml.gz')) {
          content = utf8.decode(gzip.decode(bytes), allowMalformed: true);
          isCompressed = true;
          encoding = 'utf-8';
        } else {
          content = utf8.decode(bytes, allowMalformed: true);
          encoding = _detectEncoding(bytes);
        }
      }
    } on FormatException catch (e) {
      throw ParsingException(
        message: 'Failed to decode XMLTV guide. Invalid encoding.',
        code: 'DECODE_ERROR',
        originalError: e,
      );
    }

    return XMLTVDownloadResult(
      content: content,
      sizeBytes: bytes.length,
      encoding: encoding,
      isCompressed: isCompressed,
      source: uri.toString(),
    );
  }

  void _applyAuth(HttpClientRequest request, XMLTVConfig config) {
    if (config.username != null && config.password != null) {
      final credentials = base64.encode('${config.username}:${config.password}'.codeUnits);
      request.headers.set(HttpHeaders.authorizationHeader, 'Basic $credentials');
      return;
    }

    try {
      final uri = Uri.parse(config.sourceUrl);
      final userInfo = uri.userInfo;
      if (userInfo.isNotEmpty) {
        final credentials = base64.encode(userInfo.codeUnits);
        request.headers.set(HttpHeaders.authorizationHeader, 'Basic $credentials');
      }
    } on FormatException {
      // ignore invalid URL in auth check
    }
  }

  void _applyHeaders(HttpClientRequest request, XMLTVConfig config) {
    request.headers.set(HttpHeaders.acceptHeader, '*/*');
    request.headers.set(HttpHeaders.userAgentHeader, 'StreamHubPro/1.0');

    for (final entry in config.headers.entries) {
      request.headers.set(entry.key, entry.value);
    }
  }

  String _detectEncoding(List<int> bytes) {
    if (bytes.length >= 2) {
      if (bytes[0] == 0xFF && bytes[1] == 0xFE) return 'utf-16-le';
      if (bytes[0] == 0xFE && bytes[1] == 0xFF) return 'utf-16-be';
    }
    if (bytes.length >= 3 && bytes[0] == 0xEF && bytes[1] == 0xBB && bytes[2] == 0xBF) {
      return 'utf-8';
    }
    return 'utf-8';
  }

  void dispose() {
    _client.close(force: true);
  }
}

class XMLTVDownloadResult {
  final String content;
  final int? sizeBytes;
  final String? encoding;
  final bool isCompressed;
  final String source;

  const XMLTVDownloadResult({
    required this.content,
    this.sizeBytes,
    this.encoding,
    this.isCompressed = false,
    required this.source,
  });
}