// core/services/tv_navigation_service.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/constants/tv_navigation_constants.dart';

/// The logical type of a TV navigation focus region.
enum TvFocusRegionType {
  sidebar,
  hero,
  rail,
  grid,
  filterBar,
  player,
  dialog,
  content,
}

/// Snapshot of the last focused state within a specific TV navigation region.
class TvRegionMemory {
  final String regionId;
  final TvFocusRegionType type;
  FocusNode? lastFocusedNode;
  String? lastFocusedItemId;
  int? lastFocusedIndex;
  double? lastHorizontalRatio; // 0.0 (left) to 1.0 (right)
  DateTime lastUpdated;

  TvRegionMemory({
    required this.regionId,
    required this.type,
    this.lastFocusedNode,
    this.lastFocusedItemId,
    this.lastFocusedIndex,
    this.lastHorizontalRatio,
  }) : lastUpdated = DateTime.now();

  void update({
    FocusNode? node,
    String? itemId,
    int? index,
    double? horizontalRatio,
  }) {
    if (node != null) lastFocusedNode = node;
    if (itemId != null) lastFocusedItemId = itemId;
    if (index != null) lastFocusedIndex = index;
    if (horizontalRatio != null) lastHorizontalRatio = horizontalRatio;
    lastUpdated = DateTime.now();
  }
}

/// Central TV navigation service responsible for coordinating:
/// 1. Region-based focus tracking and focus memory.
/// 2. Preserving horizontal intent between vertically stacked carousels/rails.
/// 3. Deterministic boundary detection (e.g. content left edge -> sidebar).
/// 4. Viewport scrolling and lazy list virtualization coordination.
/// 5. Developer diagnostics and debug overlay state.
class TvNavigationService extends GetxService {
  static TvNavigationService get to => Get.find<TvNavigationService>();

  /// Whether TV navigation diagnostic logging and HUD are enabled.
  final RxBool debugMode = false.obs;

  /// Currently active focus region.
  final RxString currentRegionId = ''.obs;

  /// Currently focused item identifier.
  final RxString currentItemId = ''.obs;

  /// Last handled remote key event for diagnostics.
  final RxString lastKeyEvent = ''.obs;

  /// Focus memory mapped by regionId.
  final Map<String, TvRegionMemory> _regionMemory = <String, TvRegionMemory>{};

  /// Registered focus nodes per region.
  final Map<String, List<FocusNode>> _regionNodes = <String, List<FocusNode>>{};

  /// Maps item IDs to their most recently focused node, enabling
  /// focus restoration by stable identifier rather than a potentially
  /// stale FocusNode reference.
  final Map<String, FocusNode> _itemIdNodeMap = <String, FocusNode>{};

  /// Ordered list of registered rail region IDs (for vertical inter-rail
  /// navigation). Populated explicitly via [registerRailOrder] or as rails
  /// register. Explicit order takes precedence.
  final List<String> _railOrder = <String>[];

  /// Whether [registerRailOrder] has been called explicitly.
  bool _railOrderExplicit = false;

  /// The region that had focus immediately before the sidebar opened.
  String? _preSidebarRegion;

  /// Called when navigation targets a rail that has no registered nodes yet
  /// (a lazy/unbuilt rail). The callback should trigger the rail to build
  /// its items. Once built, the UI calls [restoreFocus] on the target region.
  VoidCallback? onLazyRailRequest;

  // Callback to trigger sidebar opening from boundary detection
  VoidCallback? onOpenSidebar;

  // Callback to close sidebar and return to content
  VoidCallback? onCloseSidebar;

  /// Logs a TV navigation event when [debugMode] is active.
  void logNav(String message) {
    if (debugMode.value || kDebugMode) {
      debugPrint('[TV-Nav] $message');
    }
  }

  /// Registers a logical focus region.
  void registerRegion(String regionId, TvFocusRegionType type) {
    if (!_regionMemory.containsKey(regionId)) {
      _regionMemory[regionId] = TvRegionMemory(regionId: regionId, type: type);
    }
    _regionNodes.putIfAbsent(regionId, () => <FocusNode>[]);

    if (type == TvFocusRegionType.rail &&
        !_railOrder.contains(regionId) &&
        !_railOrderExplicit) {
      _railOrder.add(regionId);
    }
    logNav('Registered region: $regionId ($type)');
  }

  /// Unregisters a logical focus region.
  void unregisterRegion(String regionId) {
    _regionNodes.remove(regionId);
    _railOrder.remove(regionId);
    logNav('Unregistered region: $regionId');
  }

  /// Explicitly sets the vertical order of rail regions for
  /// inter-rail navigation. Takes precedence over auto-detection.
  void registerRailOrder(List<String> railRegionIds) {
    _railOrder.clear();
    for (final id in railRegionIds) {
      if (!_railOrder.contains(id)) {
        _railOrder.add(id);
      }
    }
    _railOrderExplicit = true;
    logNav('Explicit rail order: $_railOrder');
  }

  /// Registers a [FocusNode] belonging to a specific region.
  void registerNode(String regionId, FocusNode node) {
    final nodes = _regionNodes.putIfAbsent(regionId, () => <FocusNode>[]);
    if (!nodes.contains(node)) {
      nodes.add(node);
    }
  }

  /// Unregisters a [FocusNode] from a region.
  void unregisterNode(String regionId, FocusNode node) {
    _regionNodes[regionId]?.remove(node);
    final memory = _regionMemory[regionId];
    if (memory?.lastFocusedNode == node) {
      memory?.lastFocusedNode = null;
    }
  }

  /// Records that focus has moved to a widget in [regionId].
  void recordFocus({
    required String regionId,
    required FocusNode node,
    String? itemId,
    int? itemIndex,
    double? horizontalRatio,
  }) {
    currentRegionId.value = regionId;
    currentItemId.value = itemId ?? node.debugLabel ?? '';

    if (regionId != 'sidebar') {
      _preSidebarRegion = regionId;
    }

    var memory = _regionMemory[regionId];
    if (memory == null) {
      memory = TvRegionMemory(
        regionId: regionId,
        type: TvFocusRegionType.content,
      );
      _regionMemory[regionId] = memory;
    }

    double ratio = horizontalRatio ?? 0.0;
    if (horizontalRatio == null) {
      try {
        final renderBox = node.context?.findRenderObject();
        if (renderBox is RenderBox && renderBox.hasSize) {
          final globalOffset = renderBox.localToGlobal(Offset.zero);
          final screenWidth = (node.context != null)
              ? MediaQuery.sizeOf(node.context!).width
              : 1920.0;
          ratio = (globalOffset.dx / screenWidth).clamp(0.0, 1.0);
        }
      } catch (_) {}
    }

    memory.update(
      node: node,
      itemId: itemId,
      index: itemIndex,
      horizontalRatio: ratio,
    );

    registerNode(regionId, node);

    if (itemId != null) {
      _itemIdNodeMap[itemId] = node;
    }

    logNav(
      'Focus recorded in $regionId: item="$itemId", index=$itemIndex, ratio=${ratio.toStringAsFixed(2)}',
    );
  }

  /// Returns the stored memory for [regionId], if any.
  TvRegionMemory? getMemory(String regionId) => _regionMemory[regionId];

  /// Attempts to restore focus to the last known focused widget in [regionId].
  /// Item ID is the primary lookup key (stable across widget rebuilds);
  /// FocusNode is a secondary fallback (may be stale after rebuilds).
  /// Returns `true` if focus was successfully requested.
  bool restoreFocus(String regionId) {
    final memory = _regionMemory[regionId];
    if (memory != null) {
      // 1. Try restoring by item ID (stable across rebuilds)
      final itemId = memory.lastFocusedItemId;
      if (itemId != null) {
        final node = _itemIdNodeMap[itemId];
        if (node != null && node.canRequestFocus) {
          node.requestFocus();
          logNav('Restored focus by item ID "$itemId" in $regionId');
          return true;
        }
      }

      // 2. Try lastFocusedNode as fallback (may be stale after rebuilds)
      final node = memory.lastFocusedNode;
      if (node != null && node.canRequestFocus) {
        node.requestFocus();
        logNav('Restored focus to node in $regionId');
        return true;
      }

      // 3. Try matching by index in registered nodes
      final nodes = _regionNodes[regionId] ?? const <FocusNode>[];
      final activeNodes = nodes.where((n) => n.canRequestFocus).toList();
      if (activeNodes.isNotEmpty) {
        if (memory.lastFocusedIndex != null) {
          final targetIndex = memory.lastFocusedIndex!.clamp(
            0,
            activeNodes.length - 1,
          );
          activeNodes[targetIndex].requestFocus();
          logNav('Restored focus by index $targetIndex in $regionId');
          return true;
        }

        // 4. Fallback: first available active node in region
        activeNodes.first.requestFocus();
        logNav('Restored focus to first active node in $regionId');
        return true;
      }
    }

    // 5. Region has nodes but no memory
    final nodes = _regionNodes[regionId];
    if (nodes != null && nodes.isNotEmpty) {
      for (final n in nodes) {
        if (n.canRequestFocus) {
          n.requestFocus();
          logNav('Fallback focus to node in $regionId');
          return true;
        }
      }
    }

    return false;
  }

  /// Restores focus after the sidebar closes. Delegates entirely to
  /// [restoreFocus] using the pre-sidebar region as the target.
  /// Returns `true` if focus was successfully restored.
  bool restoreFocusAfterSidebar() {
    final region = _preSidebarRegion;
    if (region != null && region != 'sidebar') {
      if (restoreFocus(region)) return true;
    }
    // Fallback: try any non-sidebar region with memory
    for (final entry in _regionMemory.entries) {
      if (entry.key == 'sidebar') continue;
      if (restoreFocus(entry.key)) return true;
    }
    return false;
  }

  /// Handles vertical navigation (UP/DOWN) between stacked horizontal rails.
  /// Returns `true` when the current region is a rail — consuming the key
  /// so Flutter's default traversal does not compete. Returns `false` only
  /// when the current region is NOT a rail, allowing Flutter to handle it.
  /// Preserves the user's horizontal intent by targeting the item in the
  /// destination rail with the closest horizontal coordinate or ratio.
  bool handleInterRailNavigation({
    required String currentRegionId,
    required TraversalDirection direction,
  }) {
    if (!_railOrder.contains(currentRegionId)) return false;
    final currentIndex = _railOrder.indexOf(currentRegionId);

    int targetRailIndex;
    if (direction == TraversalDirection.down) {
      targetRailIndex = currentIndex + 1;
    } else if (direction == TraversalDirection.up) {
      targetRailIndex = currentIndex - 1;
    } else {
      return false;
    }

    if (targetRailIndex < 0 || targetRailIndex >= _railOrder.length) {
      // At the top/bottom rail — consume the key rather than letting
      // Flutter's traversal wrap around or move to an unintended target.
      return true;
    }

    final targetRegionId = _railOrder[targetRailIndex];
    final currentMemory = _regionMemory[currentRegionId];
    final desiredRatio = currentMemory?.lastHorizontalRatio ?? 0.0;

    final targetNodes = (_regionNodes[targetRegionId] ?? <FocusNode>[])
        .where((n) => n.canRequestFocus)
        .toList();

    if (targetNodes.isEmpty) {
      // Rail exists but has no nodes yet — it's lazy/unbuilt.
      // Trigger the build callback if available, consume the key,
      // and wait for the rail to populate. The UI then calls
      // restoreFocus(targetRegionId) after items are built.
      if (onLazyRailRequest != null) {
        logNav('Lazy rail requested: $targetRegionId');
        onLazyRailRequest!();
        return true;
      }
      return restoreFocus(targetRegionId);
    }

    // Find the node in targetNodes that best matches desiredRatio or geometric dx
    FocusNode? bestNode;
    double bestDistance = double.infinity;

    for (int i = 0; i < targetNodes.length; i++) {
      final node = targetNodes[i];
      try {
        final box = node.context?.findRenderObject();
        if (box is RenderBox && box.hasSize) {
          final offset = box.localToGlobal(Offset.zero);
          final screenWidth = (node.context != null)
              ? MediaQuery.sizeOf(node.context!).width
              : 1920.0;
          final nodeRatio = (offset.dx / screenWidth).clamp(0.0, 1.0);
          final dist = (nodeRatio - desiredRatio).abs();
          if (dist < bestDistance) {
            bestDistance = dist;
            bestNode = node;
          }
        }
      } catch (_) {}
    }

    if (bestNode != null) {
      bestNode.requestFocus();
      logNav(
        'Inter-rail move: $currentRegionId -> $targetRegionId, ratio=$desiredRatio',
      );
      return true;
    }

    return restoreFocus(targetRegionId);
  }

  /// Determines whether [node] sits on the leftmost boundary of its container/page,
  /// meaning a D-pad Left event should transition to the sidebar.
  bool isAtLeftEdge(FocusNode? node) {
    if (node == null || !node.hasFocus) return false;

    RenderBox? currentBox;
    try {
      final currentObject = node.context?.findRenderObject();
      currentBox = currentObject is RenderBox ? currentObject : null;
    } catch (_) {
      return false;
    }

    if (currentBox == null || !currentBox.hasSize) return false;

    final currentOffset = currentBox.localToGlobal(Offset.zero);
    final currentLeft = currentOffset.dx;
    final currentTop = currentOffset.dy;
    final currentBottom = currentTop + currentBox.size.height;

    // First, check whether a valid same-row sibling still exists to the left.
    // If so, this is not an edge condition and the body should keep moving left
    // within the content rather than jumping to the sidebar.
    final region = currentRegionId.value;
    final siblings = _regionNodes[region] ?? const <FocusNode>[];

    for (final candidate in siblings) {
      if (identical(node, candidate) || !candidate.canRequestFocus) continue;
      RenderBox? candBox;
      try {
        final candObj = candidate.context?.findRenderObject();
        candBox = candObj is RenderBox ? candObj : null;
      } catch (_) {
        continue;
      }
      if (candBox == null || !candBox.hasSize) continue;

      final candOffset = candBox.localToGlobal(Offset.zero);
      final candLeft = candOffset.dx;
      final candTop = candOffset.dy;
      final candBottom = candTop + candBox.size.height;

      final hasOverlap = candTop < currentBottom && candBottom > currentTop;
      if (hasOverlap && candLeft < currentLeft - TvNavigationConstants.siblingComparisonEpsilon) {
        return false;
      }
    }

    // Once all same-row left siblings are exhausted, treat anything near the
    // content boundary as the actual left edge of the TV body.
    return currentLeft <=
        TvNavigationConstants.sidebarCollapsedWidth +
            TvNavigationConstants.sidebarEdgeTolerance;
  }

  /// Ensures that both the immediate [Scrollable] (e.g. horizontal carousel)
  /// and any ancestor [Scrollable] (e.g. vertical page CustomScrollView)
  /// bring the focused widget smoothly into view.
  void ensureVisible(
    BuildContext context, {
    double alignment = 0.5,
    Duration duration = const Duration(milliseconds: 250),
    Curve curve = Curves.easeOutCubic,
  }) {
    // Scroll the nearest enclosing scrollable
    Scrollable.ensureVisible(
      context,
      alignment: alignment,
      duration: duration,
      curve: curve,
    );

    // Also look for parent vertical scrollable if current is horizontal
    final nearestScrollable = Scrollable.maybeOf(context);
    if (nearestScrollable != null &&
        nearestScrollable.axisDirection == AxisDirection.right) {
      // Find parent scrollable
      Element? parentElement;
      context.visitAncestorElements((ancestor) {
        if (ancestor.widget is Scrollable &&
            ancestor != nearestScrollable.context) {
          parentElement = ancestor;
          return false;
        }
        return true;
      });

      if (parentElement != null) {
        Scrollable.ensureVisible(
          parentElement!,
          alignment: alignment,
          duration: duration,
          curve: curve,
        );
      }
    }
  }
}
