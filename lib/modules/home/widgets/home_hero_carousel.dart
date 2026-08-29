import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/helpers/platform_helper.dart';
import '../../../core/media/enums/media_type.dart';
import '../../../core/streaming/vod/xtream_vod_info_service.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/image_url_formatter.dart';
import '../../../data/models/media_item.dart';
import '../../../shared/widgets/hero_banner.dart';

class HomeHeroCarousel extends StatefulWidget {
  final List<MediaItem> items;
  final void Function(MediaItem item)? onWatch;
  final void Function(MediaItem item)? onDetails;
  final void Function(MediaItem item)? onToggleFavorite;
  final bool Function(String itemId)? isFavorite;
  final Duration autoPlayInterval;

  const HomeHeroCarousel({
    super.key,
    required this.items,
    this.onWatch,
    this.onDetails,
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
        if (!_isInteracting &&
            mounted &&
            _pageController.hasClients &&
            widget.items.isNotEmpty) {
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
        ? 560.0
        : (width >= 1024
            ? (screenHeight * 0.65).clamp(500.0, 900.0)
            : (width >= 600 ? 380.0 : 330.0));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: SizedBox(
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
                  final isFav =
                      widget.isFavorite?.call(item.id) ?? item.favorite;
                  return _HeroSlide(
                    key: ValueKey(item.id),
                    item: item,
                    isTv: isTv,
                    isFavorite: isFav,
                    onWatch: widget.onWatch != null
                        ? () => widget.onWatch!(item)
                        : null,
                    onDetails: widget.onDetails != null
                        ? () => widget.onDetails!(item)
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
      ),
    );
  }
}

class _HeroSlide extends StatefulWidget {
  final MediaItem item;
  final bool isTv;
  final bool isFavorite;
  final VoidCallback? onWatch;
  final VoidCallback? onDetails;
  final VoidCallback? onToggleFavorite;

  const _HeroSlide({
    super.key,
    required this.item,
    required this.isTv,
    required this.isFavorite,
    this.onWatch,
    this.onDetails,
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

    if (widget.item.mediaType == MediaType.movie &&
        Get.isRegistered<XtreamVodInfoService>()) {
      final vodService = Get.find<XtreamVodInfoService>();
      final cached = vodService.getCachedBackdrop(widget.item);
      if (cached != null && cached.isNotEmpty) {
        _resolvedImage = cached;
        return;
      }

      vodService.fetchForMediaItem(widget.item).then((info) {
        if (!mounted) return;
        final backdrop =
            (info?.backdrop != null && info!.backdrop!.trim().isNotEmpty)
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
    final image = _resolvedImage ?? _computeDirectImage(widget.item);
    final description = _resolvedPlot ?? widget.item.description;

    final yearStr = widget.item.metadata['year']?.toString() ??
        widget.item.metadata['release_date']?.toString() ??
        widget.item.metadata['releaseDate']?.toString();

    final genreStr = widget.item.genres.isNotEmpty
        ? widget.item.genres.take(2).join(' • ')
        : (widget.item.metadata['genre']?.toString() ??
            widget.item.metadata['category_name']?.toString());

    final qualityStr = widget.item.metadata['quality']?.toString() ??
        widget.item.metadata['resolution']?.toString();

    final typeStr = widget.item.mediaType == MediaType.movie
        ? 'Movie'
        : (widget.item.mediaType == MediaType.series ? 'Series' : null);

    return HeroBanner(
      title: widget.item.title,
      subtitle: description,
      imageUrl: image ?? '',
      rating: widget.item.rating,
      year: yearStr,
      genre: genreStr,
      quality: qualityStr,
      mediaType: typeStr,
      isFavorite: widget.isFavorite,
      onPlayPressed: widget.onWatch,
      onDetailsPressed: widget.onDetails,
      onFavoritePressed: widget.onToggleFavorite,
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.35),
        borderRadius: AppRadius.pill,
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(count, (index) {
          final isActive = index == currentIndex;
          return GestureDetector(
            onTap: onTap != null ? () => onTap!(index) : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: 3.0),
              height: 5.0,
              width: isActive ? 20.0 : 5.0,
              decoration: BoxDecoration(
                color: isActive ? Colors.white : Colors.white38,
                borderRadius: AppRadius.pill,
              ),
            ),
          );
        }),
      ),
    );
  }
}
