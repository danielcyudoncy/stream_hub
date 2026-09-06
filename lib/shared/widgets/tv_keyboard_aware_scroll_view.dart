import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/helpers/platform_helper.dart';
import '../../core/utils/responsive_helper.dart';

/// TV keyboards are full-screen overlays that never resize the app
/// ([MediaQuery.viewInsets.bottom] stays `0`), so Flutter cannot auto-scroll
/// focused fields above them. When this returns true the viewport should
/// reserve an estimated keyboard height.
@visibleForTesting
bool shouldReserveKeyboardHeight({
  required bool isAndroid,
  required bool isTvLayout,
  required bool isDesktop,
  required bool textFieldFocused,
  required double bottomInset,
}) =>
    isAndroid &&
    isTvLayout &&
    !isDesktop &&
    textFieldFocused &&
    bottomInset <= 0;

/// A vertical [SingleChildScrollView] that stays usable when a soft keyboard is
/// on screen.
///
/// On phones/desktops the platform reports keyboard insets via
/// [MediaQuery.viewInsets] and [Scaffold] already resizes the body, so this
/// widget is a plain scroll view.
///
/// Android TV soft keyboards are notorious for rendering as full-screen
/// overlays that do NOT resize the app ([MediaQuery.viewInsets.bottom] stays
/// `0`). In that case Flutter cannot auto-scroll focused fields above the
/// keyboard, which hides lower fields (e.g. the password field under the
/// email field). When TV mode is detected and a [TextField] inside the scroll
/// view is focused, this widget reserves an estimated keyboard height for the
/// viewport so focused fields can always be scrolled into the visible area.
class TvKeyboardAwareScrollView extends StatefulWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double maxWidth;

  const TvKeyboardAwareScrollView({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16.0),
    this.maxWidth = 420.0,
  });

  @override
  State<TvKeyboardAwareScrollView> createState() =>
      _TvKeyboardAwareScrollViewState();
}

class _TvKeyboardAwareScrollViewState extends State<TvKeyboardAwareScrollView> {
  bool _textFieldFocused = false;

  @override
  void initState() {
    super.initState();
    FocusManager.instance.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    FocusManager.instance.removeListener(_onFocusChanged);
    super.dispose();
  }

  void _onFocusChanged() {
    final focused = _hasFocusedEditable();
    if (focused == _textFieldFocused) return;
    _textFieldFocused = focused;
    if (!mounted) return;
    setState(() {});
    if (focused) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _bringActiveFieldInView(),
      );
    }
  }

  bool _hasFocusedEditable() {
    final context = FocusManager.instance.primaryFocus?.context;
    if (context == null) return false;
    if (context.widget is EditableText) return true;
    var isEditable = false;
    context.visitAncestorElements((element) {
      if (element.widget is EditableText) {
        isEditable = true;
        return false;
      }
      return true;
    });
    return isEditable;
  }

  /// Scrolls the currently focused field toward the top of the viewport so
  /// it sits comfortably above the reserved keyboard area.
  void _bringActiveFieldInView() {
    if (!mounted) return;
    final context = FocusManager.instance.primaryFocus?.context;
    if (context == null) return;
    Scrollable.ensureVisible(
      context,
      alignment: 0.12,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
    );
  }

  /// Estimated height of a full-screen Android TV soft keyboard.
  double _estimateKeyboardHeight(BuildContext context) {
    final screenHeight = MediaQuery.sizeOf(context).height;
    return (screenHeight * 0.45).clamp(320.0, 720.0);
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      debugLabel: 'TvKeyboardAwareScrollView',
      onKeyEvent: _handleKeyEvent,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
          final reserveKeyboard = shouldReserveKeyboardHeight(
            isAndroid: PlatformHelper.isAndroid,
            isTvLayout: ResponsiveHelper.isTV(context),
            isDesktop: ResponsiveHelper.isDesktop(context),
            textFieldFocused: _textFieldFocused,
            bottomInset: bottomInset,
          );

          final reserve = reserveKeyboard
              ? _estimateKeyboardHeight(context)
              : 0.0;
          final viewportHeight = math
              .max(0.0, constraints.maxHeight - reserve)
              .clamp(0.0, constraints.maxHeight);

          final scrollView = SingleChildScrollView(
            padding: widget.padding,
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: widget.maxWidth),
                child: widget.child,
              ),
            ),
          );

          // When the keyboard is logically present, anchor the viewport to the
          // top so the reserved area sits exactly where the keyboard is.
          // Otherwise keep the original vertically-centered presentation.
          return Align(
            alignment: reserveKeyboard ? Alignment.topCenter : Alignment.center,
            child: SizedBox(
              width: constraints.maxWidth,
              height: viewportHeight,
              child: scrollView,
            ),
          );
        },
      ),
    );
  }

  /// On Android TV the soft keyboard is a full-screen overlay that consumes
  /// Up/Down D-pad presses inside the focused text field, so the user can never
  /// traverse to fields or buttons below it (e.g. the form actions row). While
  /// a text field inside this scroll view is focused, remap Up/Down to focus
  /// traversal so the user can navigate out of the field.
  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (!_textFieldFocused) return KeyEventResult.ignored;
    if (!PlatformHelper.isAndroid || !ResponsiveHelper.isTV(context)) {
      return KeyEventResult.ignored;
    }
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    final logical = event.logicalKey;
    final bool moveForward;
    if (logical == LogicalKeyboardKey.arrowDown) {
      moveForward = true;
    } else if (logical == LogicalKeyboardKey.arrowUp) {
      moveForward = false;
    } else {
      return KeyEventResult.ignored;
    }

    final group = FocusManager.instance.primaryFocus;
    if (group == null) return KeyEventResult.ignored;
    final moved = moveForward ? group.nextFocus() : group.previousFocus();
    return moved ? KeyEventResult.handled : KeyEventResult.ignored;
  }
}
