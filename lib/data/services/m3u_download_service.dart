import 'dart:async';
import 'dart:convert';
import 'dart:io';


import 'package:stream_hub/core/errors/exceptions.dart';
import 'package:stream_hub/core/logging/logging_service.dart';
import 'package:stream_hub/core/network/doh_http_client.dart';
import 'package:stream_hub/data/models/m3u_models.dart';

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

class M3UDownloadService {
  final LoggingService _logger;
  final HttpClient _client = createDohAwareHttpClient();

  M3UDownloadService(this._logger);

  Future<String> download({
    required M3UConfig config,
    StreamController<DownloadProgress>? progressController,
    CancellationToken? cancellationToken,
  }) async {
    final sourceUrl = config.localPath ?? config.sourceUrl;

    if (sourceUrl.isEmpty) {
      throw ValidationException(
        message: 'No source URL or local file path provided',
        code: 'MISSING_SOURCE',
      );
    }

    if (config.localPath != null) {
      return _loadLocalFile(config.localPath!, cancellationToken);
    }

    return _downloadRemote(sourceUrl, config, progressController, cancellationToken);
  }

  Future<String> _loadLocalFile(
    String path,
    CancellationToken? cancellationToken,
  ) async {
    if (cancellationToken?.isCancelled == true) {
      throw NetworkException(
        message: 'Download cancelled',
        code: 'CANCELLED',
      );
    }

    final file = File(path);
    if (!await file.exists()) {
      throw NetworkException(
        message: 'Local file not found',
        code: 'FILE_NOT_FOUND',
      );
    }

    return await file.readAsString();
  }

  Future<String> _downloadRemote(
    String urlString,
    M3UConfig config,
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

        return await _performRequest(uri, config, progressController, cancellationToken);
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
          'Download failed, retrying in ${config.retryDelay.inSeconds}s...',
          tag: 'M3UDownloadService',
          error: lastException,
        );
        await Future.delayed(config.retryDelay);
      }
    }

    _logger.error(
      'Download failed after ${config.maxRetries} retries',
      tag: 'M3UDownloadService',
      error: lastException,
    );
    throw lastException!;
  }

  Future<String> _performRequest(
    Uri uri,
    M3UConfig config,
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
      'M3U download response: ${response.statusCode} (${stopwatch.elapsedMilliseconds}ms)',
      tag: 'M3UDownloadService',
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
          message: 'Playlist not found (404). Please verify the URL.',
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
    try {
      if (contentEncoding != null) {
        final encoding = contentEncoding.toLowerCase();
        if (encoding.contains('gzip')) {
          content = utf8.decode(gzip.decode(bytes));
        } else if (encoding.contains('deflate')) {
          content = utf8.decode(zlib.decode(bytes));
        } else {
          content = utf8.decode(bytes);
        }
      } else {
        content = utf8.decode(bytes);
      }
    } on FormatException catch (e) {
      throw ParsingException(
        message: 'Failed to decode playlist. Invalid encoding.',
        code: 'DECODE_ERROR',
        originalError: e,
      );
    }

    return content;
  }

  void _applyAuth(HttpClientRequest request, M3UConfig config) {
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

  void _applyHeaders(HttpClientRequest request, M3UConfig config) {
    request.headers.set(HttpHeaders.acceptHeader, '*/*');
    request.headers.set(HttpHeaders.userAgentHeader, 'StreamHubPro/1.0');

    for (final entry in config.headers.entries) {
      request.headers.set(entry.key, entry.value);
    }
  }

  void dispose() {
    _client.close(force: true);
  }
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
