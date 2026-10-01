import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/helpers/platform_helper.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/responsive_helper.dart';
import 'tv_focusable.dart';

class AppSearchBar extends StatefulWidget {
  final TextEditingController? controller;
  final String hintText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onClear;
  final FocusNode? focusNode;
  final Color? backgroundColor;

  const AppSearchBar({
    super.key,
    this.controller,
    this.hintText = 'Search...',
    this.onChanged,
    this.onSubmitted,
    this.onClear,
    this.focusNode,
    this.backgroundColor,
  });

  @override
  State<AppSearchBar> createState() => _AppSearchBarState();
}

class _AppSearchBarState extends State<AppSearchBar> {
  late final TextEditingController _controller;
  late final FocusNode _textFocusNode;
  final FocusNode _tvBarFocusNode = FocusNode(debugLabel: 'AppSearchBar_TvBar');
  bool _internalFocusNode = false;
  bool _showClear = false;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? TextEditingController();
    _controller.addListener(_onTextChanged);
    _showClear = _controller.text.isNotEmpty;

    if (widget.focusNode != null) {
      _textFocusNode = widget.focusNode!;
    } else {
      _textFocusNode = FocusNode(debugLabel: 'AppSearchBar_TextField');
      _internalFocusNode = true;
    }

    _textFocusNode.addListener(_onTextFocusChanged);
    _textFocusNode.onKeyEvent = _handleTextKeyEvent;
  }

  KeyEventResult _handleTextKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowDown) {
      if (_isEditing && mounted) {
        setState(() => _isEditing = false);
        _textFocusNode.canRequestFocus = false;
        final moved = node.focusInDirection(TraversalDirection.down);
        if (!moved) {
          node.nextFocus();
        }
        return KeyEventResult.handled;
      }
    } else if (key == LogicalKeyboardKey.arrowUp) {
      if (_isEditing && mounted) {
        setState(() => _isEditing = false);
        _textFocusNode.canRequestFocus = false;
        final moved = node.focusInDirection(TraversalDirection.up);
        if (!moved) {
          node.previousFocus();
        }
        return KeyEventResult.handled;
      }
    } else if (key == LogicalKeyboardKey.escape || key == LogicalKeyboardKey.goBack) {
      if (_isEditing && mounted) {
        setState(() => _isEditing = false);
        _textFocusNode.canRequestFocus = false;
        _tvBarFocusNode.requestFocus();
        return KeyEventResult.handled;
      }
    }

    return KeyEventResult.ignored;
  }

  void _onTextFocusChanged() {
    if (!_textFocusNode.hasFocus && _isEditing && mounted) {
      setState(() => _isEditing = false);
    }
  }

  @override
  void didUpdateWidget(AppSearchBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      _textFocusNode.removeListener(_onTextFocusChanged);
      if (_internalFocusNode) {
        _textFocusNode.dispose();
      }
      if (widget.focusNode != null) {
        _textFocusNode = widget.focusNode!;
        _internalFocusNode = false;
      } else {
        _textFocusNode = FocusNode(debugLabel: 'AppSearchBar_TextField');
        _internalFocusNode = true;
      }
      _textFocusNode.addListener(_onTextFocusChanged);
      _textFocusNode.onKeyEvent = _handleTextKeyEvent;
    }
  }

  @override
  void dispose() {
    _textFocusNode.removeListener(_onTextFocusChanged);
    if (_internalFocusNode) {
      _textFocusNode.dispose();
    }
    _tvBarFocusNode.dispose();
    if (widget.controller == null) {
      _controller.dispose();
    } else {
      _controller.removeListener(_onTextChanged);
    }
    super.dispose();
  }

  void _onTextChanged() {
    final show = _controller.text.isNotEmpty;
    if (_showClear != show) {
      setState(() => _showClear = show);
    }
  }

  void _activateEditing() {
    setState(() => _isEditing = true);
    _textFocusNode.canRequestFocus = true;
    _textFocusNode.requestFocus();
  }

  void _handleSubmitted(String value) {
    widget.onSubmitted?.call(value);
    if (mounted) {
      setState(() => _isEditing = false);
      _textFocusNode.canRequestFocus = false;
      _tvBarFocusNode.requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isTv = PlatformHelper.isTV || ResponsiveHelper.isTV(context);

    // If on TV and not actively editing, disable text field focus so D-pad navigates over the search bar
    if (isTv) {
      _textFocusNode.canRequestFocus = _isEditing;
    }

    final barContent = Container(
      height: 48.0,
      decoration: BoxDecoration(
        color: widget.backgroundColor ??
            colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: AppRadius.medium,
        border: Border.all(
          color: colorScheme.outline.withValues(alpha: 0.1),
          width: 1.0,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Row(
        children: [
          Icon(
            AppIcons.search,
            color: colorScheme.onSurface.withValues(alpha: 0.6),
            size: 20.0,
          ),
          AppSpacing.widthXS,
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: _textFocusNode,
              onChanged: widget.onChanged,
              onSubmitted: _handleSubmitted,
              style: AppTypography.getBody(color: colorScheme.onSurface),
              decoration: InputDecoration(
                hintText: isTv && !_isEditing
                    ? '${widget.hintText} (Press OK to type)'
                    : widget.hintText,
                hintStyle: AppTypography.getBody(
                  color: colorScheme.onSurface.withValues(alpha: 0.4),
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          if (_showClear)
            IconButton(
              icon: Icon(
                AppIcons.close,
                size: 18.0,
                color: colorScheme.onSurface.withValues(alpha: 0.6),
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () {
                _controller.clear();
                widget.onClear?.call();
                widget.onChanged?.call('');
              },
            ),
        ],
      ),
    );

    if (!isTv) {
      return barContent;
    }

    return TvFocusable(
      focusNode: _tvBarFocusNode,
      canRequestFocus: !_isEditing,
      onTap: _activateEditing,
      borderRadius: AppRadius.medium,
      scale: 1.01,
      child: barContent,
    );
  }
}
