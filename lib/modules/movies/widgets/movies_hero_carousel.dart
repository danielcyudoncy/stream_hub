import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/helpers/platform_helper.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/image_url_formatter.dart';
import '../../../data/models/media_item.dart';
import '../../../shared/widgets/tv_focusable.dart';

class MoviesHeroCarousel extends StatefulWidget {
  final List<MediaItem> movies;
  final void Function(MediaItem movie)? onWatch;
  final Duration autoPlayInterval;

  const MoviesHeroCarousel({
    super.key,
    required this.movies,
    this.onWatch,
    this.autoPlayInterval = const Duration(seconds: 5),
  });

  @override
  State<MoviesHeroCarousel> createState() => _MoviesHeroCarouselState();
}

class _MoviesHeroCarouselState extends State<MoviesHeroCarousel> {
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
  void didUpdateWidget(covariant MoviesHeroCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.movies.length != widget.movies.length) {
      if (_currentPage >= widget.movies.length) {
        _currentPage = 0;
      }
      _startTimer();
    }
  }

  void _startTimer() {
    _stopTimer();
    if (widget.movies.length > 1) {
      _timer = Timer.periodic(widget.autoPlayInterval, (timer) {
        if (!_isInteracting && mounted && _pageController.hasClients && widget.movies.isNotEmpty) {
          final nextPage = (_currentPage + 1) % widget.movies.length;
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
    if (widget.movies.isEmpty) {
      return const SizedBox.shrink();
    }

    final isTv = PlatformHelper.isTV;

    return LayoutBuilder(
      builder: (context, constraints) {
        final heroHeight = isTv
            ? (constraints.maxHeight * 0.55).clamp(320.0, 560.0)
            : 320.0;

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
                  itemCount: widget.movies.length,
                  onPageChanged: (index) {
                    setState(() {
                      _currentPage = index;
                    });
                  },
                  itemBuilder: (context, index) {
                    final movie = widget.movies[index];
                    return _HeroSlide(
                      movie: movie,
                      isTv: isTv,
                      onWatch: widget.onWatch != null
                          ? () => widget.onWatch!(movie)
                          : null,
                    );
                  },
                ),
              ),
              if (widget.movies.length > 1)
                Positioned(
                  bottom: AppSpacing.md,
                  right: AppSpacing.lg,
                  child: _PageIndicator(
                    count: widget.movies.length,
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
      },
    );
  }
}

class _HeroSlide extends StatelessWidget {
  final MediaItem movie;
  final bool isTv;
  final VoidCallback? onWatch;

  const _HeroSlide({
    required this.movie,
    required this.isTv,
    this.onWatch,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final formattedImage = ImageUrlFormatter.extractFromMediaItem(movie);
    final rawImage = (movie.backdrop != null && movie.backdrop!.trim().isNotEmpty)
        ? movie.backdrop!.trim()
        : ((movie.poster != null && movie.poster!.trim().isNotEmpty)
            ? movie.poster!.trim()
            : movie.thumbnail?.trim());
    final image = (formattedImage != null && formattedImage.isNotEmpty)
        ? formattedImage
        : rawImage;

    return Stack(
      fit: StackFit.expand,
      children: [
        if (image != null && image.isNotEmpty)
          Image.network(
            image,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) =>
                ColoredBox(color: colorScheme.surfaceContainerHighest),
          )
        else
          ColoredBox(color: colorScheme.surfaceContainerHighest),
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.transparent,
                Colors.black54,
                Colors.black87,
              ],
              stops: [0.0, 0.45, 1.0],
            ),
          ),
        ),
        Positioned(
          left: AppSpacing.lg,
          right: AppSpacing.lg,
          bottom: AppSpacing.lg,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                movie.title,
                style: AppTypography.getHeadline(
                  color: Colors.white,
                  scale: isTv ? 1.4 : 1.0,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              AppSpacing.heightXS,
              _buildMetaRow(movie),
              if (movie.description != null &&
                  movie.description!.trim().isNotEmpty) ...[
                AppSpacing.heightSM,
                Text(
                  movie.description!,
                  style: AppTypography.getBody(
                    color: Colors.white70,
                    scale: isTv ? 1.0 : 0.88,
                  ),
                  maxLines: isTv ? 3 : 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              AppSpacing.heightMD,
              if (onWatch != null)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TvFocusable(
                      onTap: onWatch,
                      borderRadius: AppRadius.pill,
                      scale: 1.05,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.lg,
                          vertical: AppSpacing.sm,
                        ),
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: AppColors.primaryGradient,
                          ),
                          borderRadius: AppRadius.pill,
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
                              style: AppTypography.getButton(color: Colors.white),
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

  Widget _buildMetaRow(MediaItem movie) {
    final parts = <String>[];

    if (movie.rating != null && movie.rating! > 0) {
      parts.add('⭐ ${movie.rating!.toStringAsFixed(1)}');
    }

    final year = movie.metadata['year']?.toString();
    if (year != null && year.isNotEmpty) {
      parts.add(year);
    }

    parts.addAll(movie.genres.take(3));

    if (parts.isEmpty) return const SizedBox.shrink();

    return Text(
      parts.join('  ·  '),
      style: AppTypography.getCaption(color: Colors.white70),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
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
            width: isActive ? 20.0 : 6.0,
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
