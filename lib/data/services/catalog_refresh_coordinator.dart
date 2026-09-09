import 'dart:async';

import 'package:get/get.dart';
import 'package:stream_hub/core/logging/logging_service.dart';
import 'package:stream_hub/data/repositories/catalog_repository.dart';

/// Single funnel for catalog-driven UI refreshes.
///
/// Raw catalog change notifications are debounced here so a burst of sync
/// completions results in exactly one refresh signal. Heavy refresh work is
/// serialized through [runCoalesced] so overlapping catalog events never
/// saturate the UI isolate with duplicate full-catalog refreshes.
class CatalogRefreshCoordinator extends GetxService {
  CatalogRefreshCoordinator({
    required CatalogRepository catalogRepository,
    LoggingService? logger,
  })  : _catalogRepository = catalogRepository,
        _logger = logger ?? LoggingService();

  final CatalogRepository _catalogRepository;
  final LoggingService _logger;

  static const Duration debounceDelay = Duration(milliseconds: 500);

  final StreamController<void> _signalController =
      StreamController<void>.broadcast();
  late final StreamSubscription<void> _catalogSubscription;

  Timer? _debounceTimer;
  Future<void> Function()? _pendingTask;
  bool _running = false;

  Stream<void> get refreshSignal => _signalController.stream;

  bool get isRunning => _running;

  @override
  void onInit() {
    super.onInit();
    _catalogSubscription = _catalogRepository.watchUpdates().listen((_) {
      _schedule();
    });
    _logger.info(
      'Catalog refresh coordinator started',
      tag: 'CatalogRefresh',
    );
  }

  void _schedule() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(debounceDelay, () {
      _debounceTimer = null;
      if (!_signalController.isClosed) {
        _signalController.add(null);
      }
    });
  }

  /// Runs [task] without overlapping other coalesced tasks. If fresh work is
  /// requested while a task is already running, it is collapsed into a single
  /// trailing execution after the running task completes.
  Future<void> runCoalesced(Future<void> Function() task) async {
    _pendingTask = task;
    if (_running) return;
    _running = true;
    try {
      while (_pendingTask != null) {
        final current = _pendingTask!;
        _pendingTask = null;
        await current();
      }
    } finally {
      _running = false;
    }
  }

  @override
  void onClose() {
    _debounceTimer?.cancel();
    _catalogSubscription.cancel();
    _signalController.close();
    super.onClose();
  }
}