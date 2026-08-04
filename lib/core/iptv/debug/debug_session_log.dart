import 'dart:async';
import 'package:stream_hub/core/iptv/models/debug_config.dart';

/// A single entry recorded in a [DebugSessionLog].
class DebugLogEntry {
  final DateTime timestamp;
  final DebugLogCategory category;
  final String message;
  final String? tag;

  const DebugLogEntry({
    required this.timestamp,
    required this.category,
    required this.message,
    this.tag,
  });
}

/// A chronological trace of every step taken while resolving and preparing a
/// stream. Used by the stream test tool and diagnostics screens so failures can
/// be attributed to a specific stage.
class DebugSessionLog {
  final String sessionId;
  final List<DebugLogEntry> _entries = [];
  final StreamController<DebugLogEntry> _controller;
  int _maxEntries;

  DebugSessionLog({
    required this.sessionId,
    int maxEntries = 200,
  }) : _controller = StreamController<DebugLogEntry>.broadcast(),
       _maxEntries = maxEntries;

  /// A reactive stream of entries as they are recorded.
  Stream<DebugLogEntry> get entries => _controller.stream;

  List<DebugLogEntry> get snapshot => List.unmodifiable(_entries);

  int get length => _entries.length;

  void record(
    DebugLogCategory category,
    String message, {
    String? tag,
  }) {
    final entry = DebugLogEntry(
      timestamp: DateTime.now(),
      category: category,
      message: message,
      tag: tag,
    );
    _entries.add(entry);
    if (_entries.length > _maxEntries) {
      _entries.removeAt(0);
    }
    _controller.add(entry);
  }

  void setMaxEntries(int maxEntries) {
    _maxEntries = maxEntries;
    while (_entries.length > _maxEntries) {
      _entries.removeAt(0);
    }
  }

  void clear() {
    _entries.clear();
  }

  void dispose() {
    _controller.close();
  }
}
