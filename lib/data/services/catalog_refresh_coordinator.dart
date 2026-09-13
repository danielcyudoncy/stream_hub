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

  final Map<Object, Future<void> Function()> _pendingTasks = {};
  final Set<Object> _runningTasks = {};
  Timer? _debounceTimer;

  Stream<void> get refreshSignal => _signalController.stream;

  bool get isRunning => _runningTasks.isNotEmpty;

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

  /// Runs [task] without overlapping other coalesced tasks for the same caller [key].
  /// If fresh work is requested while a task is already running, it is collapsed
  /// into a single trailing execution after the running task completes.
  Future<void> runCoalesced(Future<void> Function() task, [Object? key]) async {
    final effectiveKey = key ?? task;
    _pendingTasks[effectiveKey] = task;
    if (_runningTasks.contains(effectiveKey)) return;
    _runningTasks.add(effectiveKey);
    try {
      while (_pendingTasks.containsKey(effectiveKey)) {
        final current = _pendingTasks.remove(effectiveKey)!;
        await current();
      }
    } finally {
      _runningTasks.remove(effectiveKey);
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