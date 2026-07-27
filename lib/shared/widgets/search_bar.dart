import 'package:flutter/material.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';

class AppSearchBar extends StatefulWidget {
  final TextEditingController? controller;
  final String hintText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onClear;

  const AppSearchBar({
    super.key,
    this.controller,
    this.hintText = 'Search...',
    this.onChanged,
    this.onSubmitted,
    this.onClear,
  });

  @override
  State<AppSearchBar> createState() => _AppSearchBarState();
}

class _AppSearchBarState extends State<AppSearchBar> {
  late final TextEditingController _controller;
  bool _showClear = false;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? TextEditingController();
    _controller.addListener(_onTextChanged);
    _showClear = _controller.text.isNotEmpty;
  }

  @override
  void dispose() {
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      height: 48.0,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
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
              onChanged: widget.onChanged,
              onSubmitted: widget.onSubmitted,
              style: AppTypography.getBody(color: colorScheme.onSurface),
              decoration: InputDecoration(
                hintText: widget.hintText,
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
  }
}
