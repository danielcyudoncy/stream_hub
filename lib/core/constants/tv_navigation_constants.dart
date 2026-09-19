class TvNavigationConstants {
  TvNavigationConstants._();

  /// Width of the sidebar when collapsed (body offset from left).
  static const double sidebarCollapsedWidth = 96.0;

  /// Width of the sidebar when expanded.
  static const double sidebarExpandedWidth = 270.0;

  /// Tolerance added to [sidebarCollapsedWidth] in [isAtLeftEdge].
  /// A node is considered at the left edge if its left position
  /// is within this distance of the collapsed sidebar boundary.
  static const double sidebarEdgeTolerance = 80.0;

  /// Small margin used when comparing horizontal positions
  /// of sibling focus nodes.
  static const double siblingComparisonEpsilon = 12.0;
}
