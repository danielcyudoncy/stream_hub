import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/helpers/platform_helper.dart';
import '../../../core/media/enums/media_type.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/image_url_formatter.dart';
import '../../../data/models/media_item.dart';
import '../../../shared/widgets/tv_focusable.dart';

class HomeHeroCarousel extends StatefulWidget {
  final List<MediaItem> items;
  final void Function(MediaItem item)? onWatch;
  final void Function(MediaItem item)? onToggleFavorite;
  final bool Function(String itemId)? isFavorite;
  final Duration autoPlayInterval;

  const HomeHeroCarousel({
    super.key,
    required this.items,
    this.onWatch,
    this.onToggleFavorite,
    this.isFavorite,
    this.autoPlayInterval = const Duration(seconds: 7),
  });

  @override
  State<HomeHeroCarousel> createState() => _HomeHeroCarouselState();
}

class _HomeHeroCarouselState extends State<HomeHeroCarousel> {
  late final PageController _pageController;
  Timer? _timer;
  int _currentPage = 0;
  bool _isInteracting = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _startTimer();
  }

  @override
  void didUpdateWidget(covariant HomeHeroCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.items.length != widget.items.length) {
      if (_currentPage >= widget.items.length) {
        _currentPage = 0;
      }
      _startTimer();
    }
  }

  void _startTimer() {
    _stopTimer();
    if (widget.items.length > 1) {
      _timer = Timer.periodic(widget.autoPlayInterval, (_) {
        if (!_isInteracting && mounted && _pageController.hasClients && widget.items.isNotEmpty) {
          final nextPage = (_currentPage + 1) % widget.items.length;
          _pageController.animateToPage(
            nextPage,
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeInOutCubic,
          );
        }
      });
    }
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  @override
  void dispose() {
    _stopTimer();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) {
      return const SizedBox.shrink();
    }

    final isTv = PlatformHelper.isTV;
    final width = MediaQuery.of(context).size.width;
    final heroHeight = isTv
        ? 440.0
        : (width >= 1024
            ? 420.0
            : (width >= 600 ? 360.0 : 320.0));

    return SizedBox(
      width: double.infinity,
      height: heroHeight,
      child: Stack(
        children: [
          NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (notification is ScrollStartNotification) {
                _isInteracting = true;
              } else if (notification is ScrollEndNotification) {
                _isInteracting = false;
              }
              return false;
            },
            child: PageView.builder(
              controller: _pageController,
              itemCount: widget.items.length,
              onPageChanged: (index) {
                setState(() {
                  _currentPage = index;
                });
              },
              itemBuilder: (context, index) {
                final item = widget.items[index];
                final isFav = widget.isFavorite?.call(item.id) ?? item.favorite;
                return _HeroSlide(
                  item: item,
                  isTv: isTv,
                  isFavorite: isFav,
                  onWatch: widget.onWatch != null
                      ? () => widget.onWatch!(item)
                      : null,
                  onToggleFavorite: widget.onToggleFavorite != null
                      ? () => widget.onToggleFavorite!(item)
                      : null,
                );
              },
            ),
          ),
          if (widget.items.length > 1)
            Positioned(
              bottom: AppSpacing.md,
              right: AppSpacing.lg,
              child: _PageIndicator(
                count: widget.items.length,
                currentIndex: _currentPage,
                onTap: (index) {
                  _pageController.animateToPage(
                    index,
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeInOut,
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _HeroSlide extends StatelessWidget {
  final MediaItem item;
  final bool isTv;
  final bool isFavorite;
  final VoidCallback? onWatch;
  final VoidCallback? onToggleFavorite;

  const _HeroSlide({
    required this.item,
    required this.isTv,
    required this.isFavorite,
    this.onWatch,
    this.onToggleFavorite,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final formattedImage = ImageUrlFormatter.extractFromMediaItem(item);
    final rawImage = (item.backdrop != null && item.backdrop!.trim().isNotEmpty)
        ? item.backdrop!.trim()
        : ((item.poster != null && item.poster!.trim().isNotEmpty)
            ? item.poster!.trim()
            : item.thumbnail?.trim());
    final image = (formattedImage != null && formattedImage.isNotEmpty)
        ? formattedImage
        : rawImage;

    return Stack(
      fit: StackFit.expand,
      children: [
        // Backdrop Image
        if (image != null && image.isNotEmpty)
          Image.network(
            image,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) =>
                ColoredBox(color: colorScheme.surfaceContainerHighest),
          )
        else
          ColoredBox(color: colorScheme.surfaceContainerHighest),

        // Deep Cinematic Multi-Stop Gradient Overlays
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.15),
                  Colors.black.withValues(alpha: 0.5),
                  Colors.black.withValues(alpha: 0.95),
                ],
                stops: const [0.0, 0.45, 1.0],
              ),
            ),
          ),
        ),

        // Left subtle vignette for readability
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  Colors.black.withValues(alpha: 0.7),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.65],
              ),
            ),
          ),
        ),

        // Content details
        Positioned(
          left: AppSpacing.lg,
          right: AppSpacing.lg,
          bottom: AppSpacing.lg,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Title
              Text(
                item.title,
                style: AppTypography.getHeadline(
                  color: Colors.white,
                  scale: isTv ? 1.4 : 1.1,
                ).copyWith(fontWeight: FontWeight.w800),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              AppSpacing.heightXS,

              // Metadata row (Rating, Type, Duration, Genres)
              _buildMetaRow(item, colorScheme),

              // Description if available
              if (item.description != null &&
                  item.description!.trim().isNotEmpty) ...[
                AppSpacing.heightSM,
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 680),
                  child: Text(
                    item.description!.trim(),
                    style: AppTypography.getBody(
                      color: Colors.white.withValues(alpha: 0.82),
                      scale: isTv ? 0.95 : 0.85,
                    ),
                    maxLines: isTv ? 3 : 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
              AppSpacing.heightMD,

              // Actions Row (Watch Now & My List)
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (onWatch != null)
                    TvFocusable(
                      onTap: onWatch,
                      borderRadius: AppRadius.pill,
                      scale: 1.05,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: 9.0,
                        ),
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: AppColors.primaryGradient,
                          ),
                          borderRadius: AppRadius.pill,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black45,
                              blurRadius: 12.0,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              AppIcons.play,
                              color: Colors.white,
                              size: 18.0,
                            ),
                            AppSpacing.widthXS,
                            Text(
                              'WATCH NOW',
                              style: AppTypography.getButton(
                                color: Colors.white,
                              ).copyWith(fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (onToggleFavorite != null)
                    TvFocusable(
                      onTap: onToggleFavorite,
                      borderRadius: AppRadius.pill,
                      scale: 1.05,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm + 2,
                          vertical: 9.0,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.14),
                          borderRadius: AppRadius.pill,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.22),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isFavorite
                                  ? Icons.favorite_rounded
                                  : Icons.add_rounded,
                              color: isFavorite ? AppColors.darkError : Colors.white,
                              size: 18.0,
                            ),
                            AppSpacing.widthXS,
                            Text(
                              isFavorite ? 'IN MY LIST' : 'MY LIST',
                              style: AppTypography.getButton(
                                color: Colors.white,
                              ).copyWith(fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMetaRow(MediaItem item, ColorScheme colorScheme) {
    final chips = <Widget>[];

    // Rating
    if (item.rating != null && item.rating! > 0) {
      chips.add(
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
          decoration: BoxDecoration(
            color: Colors.amber.shade700,
            borderRadius: AppRadius.small,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.star_rounded, size: 13.0, color: Colors.white),
              const SizedBox(width: 2.0),
              Text(
                item.rating!.toStringAsFixed(1),
                style: const TextStyle(
                  fontSize: 11.0,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Media Type Tag
    final typeLabel = item.mediaType == MediaType.movie
        ? 'Movie'
        : item.mediaType == MediaType.series
            ? 'Series'
            : (item.mediaType == MediaType.channel ? 'Live TV' : null);

    if (typeLabel != null) {
      chips.add(
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.16),
            borderRadius: AppRadius.small,
          ),
          child: Text(
            typeLabel,
            style: const TextStyle(
              fontSize: 11.0,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ),
      );
    }

    // Release Year
    final year = item.metadata['year']?.toString();
    if (year != null && year.isNotEmpty) {
      chips.add(
        Text(
          year,
          style: const TextStyle(
            fontSize: 12.0,
            color: Colors.white70,
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    }

    // Duration if available
    final duration = item.metadata['duration']?.toString() ??
        item.metadata['runtime']?.toString();
    if (duration != null && duration.isNotEmpty) {
      chips.add(
        Text(
          duration.contains('m') || duration.contains('h')
              ? duration
              : '${duration}m',
          style: const TextStyle(
            fontSize: 12.0,
            color: Colors.white70,
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    }

    // Top genres
    if (item.genres.isNotEmpty) {
      final genreText = item.genres.take(2).join(' · ');
      chips.add(
        Text(
          genreText,
          style: const TextStyle(
            fontSize: 12.0,
            color: Colors.white70,
            fontWeight: FontWeight.w500,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      );
    }

    if (chips.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.xs,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: chips,
    );
  }
}

class _PageIndicator extends StatelessWidget {
  final int count;
  final int currentIndex;
  final ValueChanged<int>? onTap;

  const _PageIndicator({
    required this.count,
    required this.currentIndex,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(count, (index) {
        final isActive = index == currentIndex;
        return GestureDetector(
          onTap: onTap != null ? () => onTap!(index) : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            margin: const EdgeInsets.symmetric(horizontal: 3.0),
            height: 6.0,
            width: isActive ? 22.0 : 6.0,
            decoration: BoxDecoration(
              color: isActive ? Colors.white : Colors.white38,
              borderRadius: AppRadius.pill,
            ),
          ),
        );
      }),
    );
  }
}
