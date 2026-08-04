import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:stream_hub/core/streaming/errors/stream_exceptions.dart';
import 'package:stream_hub/core/streaming/network/dart_http_probe.dart';

/// A minimal raw-socket HTTP server that faithfully reproduces panel-style
/// behavior dart:io's [HttpServer] cannot: closing the connection on HEAD
/// without any response ("empty reply"), and streaming endless live bodies.
///
/// [handler] receives the request method and returns a [HttpScript] describing
/// what to write back.
class RawScriptServer {
  RawScriptServer._(this._socket, this.port);

  final ServerSocket _socket;
  final int port;

  Uri get url => Uri.parse('http://127.0.0.1:$port');

  static Future<RawScriptServer> start(
    Future<HttpScript> Function(String method, String path) handler,
  ) async {
    final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    socket.listen((client) {
      var buffer = '';
      client.listen(
        (data) {
          buffer += String.fromCharCodes(data);
          if (buffer.contains('\r\n\r\n')) {
            final method = buffer.split(' ').first;
            final path = buffer.split(' ')[1];
            handler(method, path).then((script) async {
              await script.run(client);
            }).catchError((Object _) {});
          }
        },
        onError: (Object _) {},
      );
    });
    return RawScriptServer._(socket, socket.port);
  }

  Future<void> close() => _socket.close();
}

/// Describes how the raw server should answer a request.
class HttpScript {
  final Future<void> Function(Socket client) run;

  HttpScript(this.run);

  /// Writes a full HTTP response then closes.
  factory HttpScript.response(int status, String contentType,
      {List<int> body = const []}) {
    return HttpScript((client) async {
      client.write('HTTP/1.1 $status OK\r\n'
          'Content-Type: $contentType\r\n'
          'Content-Length: ${body.length}\r\n'
          'Connection: close\r\n'
          '\r\n');
      if (body.isNotEmpty) client.add(body);
      await client.flush();
      client.destroy();
    });
  }

  /// Writes an HTTP response header then streams [chunkCount] chunks of
  /// [chunkSize] bytes (an endless live stream).
  factory HttpScript.endlessStream(int status, String contentType,
      {int chunkSize = 64 * 1024, Duration delay = const Duration(milliseconds: 5)}) {
    return HttpScript((client) async {
      client.write('HTTP/1.1 $status OK\r\n'
          'Content-Type: $contentType\r\n'
          'Transfer-Encoding: chunked\r\n'
          '\r\n');
      await client.flush();
      final chunk = List<int>.filled(chunkSize, 0);
      try {
        while (true) {
          client.add(chunk);
          await client.flush();
          await Future<void>.delayed(delay);
        }
      } catch (_) {
        // Client cancelled after the bounded read.
      }
    });
  }

  /// Closes the connection without writing any response (empty reply).
  factory HttpScript.emptyReply() {
    return HttpScript((client) async {
      client.destroy();
    });
  }

  /// Accepts the connection and never responds.
  factory HttpScript.neverRespond() {
    return HttpScript((client) async {
      await Completer<void>().future;
    });
  }
}

void main() {
  group('DartHttpProbe', () {
    test(
      'reads a bounded prefix of an endless live stream instead of draining',
      () async {
        final server = await RawScriptServer.start((method, path) async {
          if (method == 'HEAD') return HttpScript.emptyReply();
          return HttpScript.endlessStream(200, 'video/mp2t');
        });
        addTearDown(server.close);

        final probe = const DartHttpProbe();
        final stopwatch = Stopwatch()..start();
        final result = await probe.probe(
          server.url.resolve('/live.m2t').toString(),
          timeout: const Duration(seconds: 30),
        );
        stopwatch.stop();

        expect(result.statusCode, 200);
        expect(result.contentType, 'video/mp2t');
        // Returns well before the 30s timeout -> proves it did not drain.
        expect(stopwatch.elapsed, lessThan(const Duration(seconds: 10)));
      },
      timeout: const Timeout(Duration(seconds: 35)),
    );

    test('falls back to GET when the server closes the socket on HEAD',
        () async {
      var getCount = 0;
      final server = await RawScriptServer.start((method, path) async {
        if (method == 'HEAD') return HttpScript.emptyReply();
        getCount++;
        return HttpScript.response(200, 'video/mp2t');
      });
      addTearDown(server.close);

      final result = await const DartHttpProbe().probe(
        server.url.resolve('/stream').toString(),
      );
      expect(getCount, 1);
      expect(result.statusCode, 200);
      expect(result.contentType, 'video/mp2t');
    });

    test('returns the HEAD result directly when the server supports HEAD',
        () async {
      var getCount = 0;
      final server = await RawScriptServer.start((method, path) async {
        if (method == 'HEAD') {
          return HttpScript.response(200, 'video/mp2t');
        }
        getCount++;
        return HttpScript.response(200, 'video/mp2t');
      });
      addTearDown(server.close);

      final result = await const DartHttpProbe().probe(
        server.url.resolve('/stream').toString(),
      );
      expect(getCount, 0);
      expect(result.statusCode, 200);
      expect(result.contentType, 'video/mp2t');
    });

    test('does not fall back to GET when HEAD returns a non-2xx status',
        () async {
      var getCount = 0;
      final server = await RawScriptServer.start((method, path) async {
        if (method == 'HEAD') return HttpScript.response(403, 'text/html');
        getCount++;
        return HttpScript.response(200, 'video/mp2t');
      });
      addTearDown(server.close);

      final result = await const DartHttpProbe().probe(
        server.url.resolve('/stream').toString(),
      );
      expect(getCount, 0);
      expect(result.statusCode, 403);
    });

    test('propagates a timeout when the server never responds', () async {
      final server = await RawScriptServer.start(
        (method, path) async => HttpScript.neverRespond(),
      );
      addTearDown(server.close);

      await expectLater(
        const DartHttpProbe().probe(
          server.url.resolve('/stream').toString(),
          timeout: const Duration(milliseconds: 300),
        ),
        throwsA(
          isA<StreamTimeoutException>().having(
            (e) => e.message,
            'message',
            contains('Timed out'),
          ),
        ),
      );
    });
  });
}
