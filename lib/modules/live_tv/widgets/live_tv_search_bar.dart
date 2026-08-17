import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';

class LiveTvSearchBar extends StatefulWidget {
  final String query;
  final ValueChanged<String> onChanged;
  final VoidCallback? onClear;
  final int totalCount;
  final String hintText;

  const LiveTvSearchBar({
    super.key,
    required this.query,
    required this.onChanged,
    this.onClear,
    required this.totalCount,
    this.hintText = 'Search channels, genres, numbers...',
  });

  @override
  State<LiveTvSearchBar> createState() => _LiveTvSearchBarState();
}

class _LiveTvSearchBarState extends State<LiveTvSearchBar> {
  late final TextEditingController _textController;
  late final FocusNode _focusNode;
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.query);
    _focusNode = FocusNode();
    _focusNode.addListener(_handleFocusChange);
  }

  void _handleFocusChange() {
    if (mounted) {
      setState(() => _isFocused = _focusNode.hasFocus);
    }
  }

  @override
  void didUpdateWidget(covariant LiveTvSearchBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.query != _textController.text) {
      _textController.text = widget.query;
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocusChange);
    _focusNode.dispose();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: AppRadius.pill,
          border: Border.all(
            color: _isFocused
                ? colorScheme.primary
                : colorScheme.outline.withValues(alpha: 0.15),
            width: _isFocused ? 2.0 : 1.0,
          ),
          boxShadow: _isFocused
              ? [
                  BoxShadow(
                    color: colorScheme.primary.withValues(alpha: 0.25),
                    blurRadius: 12.0,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            const SizedBox(width: AppSpacing.md),
            Icon(
              Icons.search_rounded,
              color: _isFocused ? colorScheme.primary : AppColors.darkTextMuted,
              size: 20.0,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: TextField(
                controller: _textController,
                focusNode: _focusNode,
                style: AppTypography.getBody(
                  color: Colors.white,
                  scale: 0.95,
                ),
                decoration: InputDecoration(
                  hintText: widget.hintText,
                  hintStyle: AppTypography.getBody(
                    color: AppColors.darkTextMuted,
                    scale: 0.9,
                  ),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: AppSpacing.sm,
                  ),
                ),
                onChanged: widget.onChanged,
              ),
            ),
            if (widget.query.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 18.0),
                color: AppColors.darkTextSecondary,
                onPressed: () {
                  _textController.clear();
                  widget.onChanged('');
                  widget.onClear?.call();
                },
                tooltip: 'Clear search',
              ),
            if (widget.totalCount >= 0)
              Padding(
                padding: const EdgeInsets.only(right: AppSpacing.md),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8.0,
                    vertical: 3.0,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: AppRadius.pill,
                  ),
                  child: Text(
                    '${widget.totalCount}',
                    style: TextStyle(
                      fontSize: 11.0,
                      fontWeight: FontWeight.w600,
                      color: AppColors.darkTextSecondary,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
