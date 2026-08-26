import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/helpers/platform_helper.dart';
import '../../../core/media/enums/media_type.dart';
import '../../../core/streaming/vod/xtream_vod_info_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/image_url_formatter.dart';
import '../../../data/models/media_item.dart';
import '../../../shared/widgets/cached_home_image.dart';
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
    final size = MediaQuery.of(context).size;
    final width = size.width;
    final screenHeight = size.height;
    final heroHeight = isTv
        ? 440.0
        : (width >= 1024
            ? (screenHeight * 0.65).clamp(500.0, 900.0)
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
                  key: ValueKey(item.id),
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

class _HeroSlide extends StatefulWidget {
  final MediaItem item;
  final bool isTv;
  final bool isFavorite;
  final VoidCallback? onWatch;
  final VoidCallback? onToggleFavorite;

  const _HeroSlide({
    super.key,
    required this.item,
    required this.isTv,
    required this.isFavorite,
    this.onWatch,
    this.onToggleFavorite,
  });

  @override
  State<_HeroSlide> createState() => _HeroSlideState();
}

class _HeroSlideState extends State<_HeroSlide> {
  String? _resolvedImage;
  String? _resolvedPlot;

  @override
  void initState() {
    super.initState();
    _checkAndResolveImage();
  }

  @override
  void didUpdateWidget(covariant _HeroSlide oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.id != widget.item.id ||
        oldWidget.item.backdrop != widget.item.backdrop ||
        oldWidget.item.poster != widget.item.poster) {
      _resolvedImage = null;
      _resolvedPlot = null;
      _checkAndResolveImage();
    }
  }

  void _checkAndResolveImage() {
    final direct = _computeDirectImage(widget.item);
    if (direct != null && direct.isNotEmpty) {
      _resolvedImage = direct;
      return;
    }

    if (widget.item.mediaType == MediaType.movie && Get.isRegistered<XtreamVodInfoService>()) {
      final vodService = Get.find<XtreamVodInfoService>();
      final cached = vodService.getCachedBackdrop(widget.item);
      if (cached != null && cached.isNotEmpty) {
        _resolvedImage = cached;
        return;
      }

      vodService.fetchForMediaItem(widget.item).then((info) {
        if (!mounted) return;
        final backdrop = (info?.backdrop != null && info!.backdrop!.trim().isNotEmpty)
            ? info.backdrop!.trim()
            : null;
        final poster = (info?.poster != null && info!.poster!.trim().isNotEmpty)
            ? info.poster!.trim()
            : null;
        final img = backdrop ?? poster;
        if (img != null && img.isNotEmpty) {
          setState(() {
            _resolvedImage = img;
            _resolvedPlot = info?.plot;
          });
        }
      }).catchError((_) {});
    }
  }

  static String? _computeDirectImage(MediaItem item) {
    final formattedImage = ImageUrlFormatter.extractFromMediaItem(item);
    final rawImage = (item.backdrop != null && item.backdrop!.trim().isNotEmpty)
        ? item.backdrop!.trim()
        : ((item.poster != null && item.poster!.trim().isNotEmpty)
            ? item.poster!.trim()
            : item.thumbnail?.trim());
    return (formattedImage != null && formattedImage.isNotEmpty)
        ? formattedImage
        : rawImage;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final image = _resolvedImage ?? _computeDirectImage(widget.item);
    final description = _resolvedPlot ?? widget.item.description;

    return Stack(
      fit: StackFit.expand,
      children: [
        // Backdrop Image & Fitted Image to prevent over-scaling
        if (image != null && image.isNotEmpty) ...[
          // Blurred background
          Positioned.fill(
            child: CachedHomeImage(
              imageUrl: image,
              fit: BoxFit.cover,
              color: Colors.black.withValues(alpha: 0.6),
              colorBlendMode: BlendMode.darken,
              errorBuilder: (context, url) =>
                  ColoredBox(color: colorScheme.surfaceContainerHighest),
            ),
          ),
          // Blur effect
          Positioned.fill(
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: const SizedBox(),
            ),
          ),
          // Main fitted image
          Positioned.fill(
            child: Align(
              alignment: widget.isTv ? Alignment.centerRight : Alignment.topCenter,
              child: CachedHomeImage(
                imageUrl: image,
                fit: BoxFit.contain,
                alignment: widget.isTv ? Alignment.centerRight : Alignment.topCenter,
                errorBuilder: (context, url) => const SizedBox.shrink(),
              ),
            ),
          ),
        ] else
          Positioned.fill(child: ColoredBox(color: colorScheme.surfaceContainerHighest)),

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
                widget.item.title,
                style: AppTypography.getHeadline(
                  color: Colors.white,
                  scale: widget.isTv ? 1.4 : 1.1,
                ).copyWith(fontWeight: FontWeight.w800),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              AppSpacing.heightXS,

              // Metadata row (Rating, Type, Duration, Genres)
              _buildMetaRow(widget.item, colorScheme),

              // Description if available
              if (description != null && description.trim().isNotEmpty) ...[
                AppSpacing.heightSM,
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 680),
                  child: Text(
                    description.trim(),
                    style: AppTypography.getBody(
                      color: Colors.white.withValues(alpha: 0.82),
                      scale: widget.isTv ? 0.95 : 0.85,
                    ),
                    maxLines: widget.isTv ? 3 : 2,
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
                  if (widget.onWatch != null)
                    TvFocusable(
                      onTap: widget.onWatch,
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
                  if (widget.onToggleFavorite != null)
                    TvFocusable(
                      onTap: widget.onToggleFavorite,
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
                              widget.isFavorite
                                  ? Icons.favorite_rounded
                                  : Icons.add_rounded,
                              color: widget.isFavorite ? AppColors.darkError : Colors.white,
                              size: 18.0,
                            ),
                            AppSpacing.widthXS,
                            Text(
                              widget.isFavorite ? 'IN MY LIST' : 'MY LIST',
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
