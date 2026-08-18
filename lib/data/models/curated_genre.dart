import 'package:flutter/material.dart';

/// Represents a standardized universal entertainment genre with curated
/// keywords and visual metadata for browsing and fast filtering.
class CuratedGenre {
  final String id;
  final String title;
  final IconData icon;
  final List<String> keywords;

  const CuratedGenre({
    required this.id,
    required this.title,
    required this.icon,
    required this.keywords,
  });

  static const List<CuratedGenre> defaultGenres = [
    CuratedGenre(
      id: 'sports',
      title: 'Sports',
      icon: Icons.sports_soccer_rounded,
      keywords: [
        'sport',
        'sports',
        'football',
        'soccer',
        'nba',
        'nfl',
        'ufc',
        'wwe',
        'espn',
        'bein',
        'sky sport',
        'supersport',
        'tennis',
        'cricket',
        'formula',
        'f1',
        'golf',
        'racing',
        'boxing',
        'rugby',
        'baseball',
        'nhl',
        'premier league',
        'champions league',
        'laliga',
        'serie a',
        'bundesliga',
        'eurosport',
        'dazn',
      ],
    ),
    CuratedGenre(
      id: 'movies',
      title: 'Movies',
      icon: Icons.movie_filter_rounded,
      keywords: [
        'movie',
        'movies',
        'cinema',
        'film',
        'vod',
        'hbo',
        'cinemax',
        'blockbuster',
      ],
    ),
    CuratedGenre(
      id: 'series',
      title: 'TV Series',
      icon: Icons.tv_rounded,
      keywords: [
        'series',
        'tv show',
        'shows',
        'season',
        'episode',
      ],
    ),
    CuratedGenre(
      id: 'documentary',
      title: 'Documentary',
      icon: Icons.public_rounded,
      keywords: [
        'documentary',
        'docu',
        'discovery',
        'nat geo',
        'national geographic',
        'history',
        'animal planet',
        'science',
        'investigation',
        'planet',
        'nature',
        'wild',
      ],
    ),
    CuratedGenre(
      id: 'kids',
      title: 'Kids & Family',
      icon: Icons.child_care_rounded,
      keywords: [
        'kids',
        'family',
        'child',
        'children',
        'cartoon',
        'disney',
        'nickelodeon',
        'nick',
        'animation',
        'junior',
        'baby',
        'toon',
        'anime',
        'boomerang',
      ],
    ),
    CuratedGenre(
      id: 'music',
      title: 'Music',
      icon: Icons.music_note_rounded,
      keywords: [
        'music',
        'mtv',
        'vh1',
        'radio',
        'concert',
        'hit',
        'song',
        'soundtrack',
        'pop',
        'rock',
      ],
    ),
    CuratedGenre(
      id: 'news',
      title: 'News',
      icon: Icons.newspaper_rounded,
      keywords: [
        'news',
        'cnn',
        'bbc',
        'fox news',
        'msnbc',
        'al jazeera',
        'sky news',
        'bloomberg',
        'cnbc',
        'euronews',
        'headline',
        'weather',
      ],
    ),
    CuratedGenre(
      id: 'action',
      title: 'Action',
      icon: Icons.flash_on_rounded,
      keywords: [
        'action',
        'adventure',
        'thriller',
        'combat',
        'fight',
        'martial',
      ],
    ),
    CuratedGenre(
      id: 'comedy',
      title: 'Comedy',
      icon: Icons.sentiment_very_satisfied_rounded,
      keywords: [
        'comedy',
        'humor',
        'funny',
        'standup',
        'sitcom',
        'laugh',
      ],
    ),
    CuratedGenre(
      id: 'drama',
      title: 'Drama',
      icon: Icons.theater_comedy_rounded,
      keywords: [
        'drama',
        'dramatic',
        'romance',
        'romantic',
        'soap',
      ],
    ),
    CuratedGenre(
      id: 'scifi',
      title: 'Sci-Fi',
      icon: Icons.rocket_launch_rounded,
      keywords: [
        'sci-fi',
        'scifi',
        'science fiction',
        'fantasy',
        'space',
        'alien',
        'future',
      ],
    ),
    CuratedGenre(
      id: 'horror',
      title: 'Horror',
      icon: Icons.psychology_alt_rounded,
      keywords: [
        'horror',
        'scary',
        'ghost',
        'fear',
        'thriller',
        'slasher',
        'paranormal',
      ],
    ),
    CuratedGenre(
      id: 'animation',
      title: 'Animation',
      icon: Icons.palette_rounded,
      keywords: [
        'animation',
        'animated',
        'anime',
        'manga',
        'cartoon',
        'pixar',
        'dreamworks',
      ],
    ),
  ];

  static CuratedGenre? findByQuery(String query) {
    final lower = query.trim().toLowerCase();
    for (final genre in defaultGenres) {
      if (genre.id.toLowerCase() == lower ||
          genre.title.toLowerCase() == lower) {
        return genre;
      }
      for (final keyword in genre.keywords) {
        if (keyword.toLowerCase() == lower) {
          return genre;
        }
      }
    }
    return null;
  }
}
