import 'package:flutter/widgets.dart';

/// An [InheritedWidget] that lets focusable leaf widgets inside a TV body
/// register themselves with their host scaffold.
///
/// TvScaffold installs this around its body so it always has a stable,
/// reading-ordered list of real, actionable focus targets. When D-pad
/// navigation moves focus back into the body (e.g. closing the sidebar), it
/// can therefore hand focus to an actual button instead of an invisible body
/// container — which is what previously made the "Add Media Source" /
/// "Add Provider" actions unreachable by remote.
class TvBodyFocusRegistry extends InheritedWidget {
  const TvBodyFocusRegistry({
    super.key,
    required this.register,
    required this.unregister,
    required super.child,
    this.openSidebar,
  });

  final ValueChanged<FocusNode> register;
  final ValueChanged<FocusNode> unregister;

  /// Opens the sidebar with the current nav item focused. Provided by
  /// TvScaffold so leftmost body elements (first filter pill, "All
  /// Categories" chip, leftmost grid column) can deterministically open the
  /// sidebar when D-pad Left is pressed at the body's left edge.
  final VoidCallback? openSidebar;

  static TvBodyFocusRegistry? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<TvBodyFocusRegistry>();

  static TvBodyFocusRegistry? of(BuildContext context) =>
      context.getInheritedWidgetOfExactType<TvBodyFocusRegistry>();

  @override
  bool updateShouldNotify(TvBodyFocusRegistry oldWidget) => false;
}
