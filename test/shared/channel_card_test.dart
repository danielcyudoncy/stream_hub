import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stream_hub/core/media/enums/media_source_type.dart';
import 'package:stream_hub/core/media/enums/media_type.dart';
import 'package:stream_hub/data/models/channel.dart';
import 'package:stream_hub/shared/widgets/channel_card.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    home: Scaffold(
      body: SizedBox(
        width: 200,
        height: 250,
        child: child,
      ),
    ),
  );
}

void main() {
  group('ChannelCard', () {
    final testChannel = Channel(
      id: 'ch-1',
      providerId: 'prov-1',
      providerType: MediaSourceType.xtream,
      mediaType: MediaType.channel,
      title: 'BBC One HD',
      number: '101',
      isLive: true,
      favorite: false,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      metadata: {'resolution': '1080p'},
    );

    testWidgets('renders channel title, number, and badges properly',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          ChannelCard(
            channel: testChannel,
            showFavoriteButton: true,
            showChannelNumber: true,
            showHD: true,
          ),
        ),
      );

      expect(find.text('BBC One HD'), findsOneWidget);
      expect(find.text('101'), findsOneWidget);
      expect(find.text('1080p'), findsOneWidget);
    });

    testWidgets('tapping favorite button triggers onFavorite callback without triggering onTap',
        (tester) async {
      bool cardTapped = false;
      bool favoriteTapped = false;

      await tester.pumpWidget(
        _wrap(
          ChannelCard(
            channel: testChannel,
            onTap: () => cardTapped = true,
            onFavorite: () => favoriteTapped = true,
            showFavoriteButton: true,
          ),
        ),
      );

      final favoriteFinder = find.byIcon(Icons.favorite_border_rounded);
      expect(favoriteFinder, findsOneWidget);

      await tester.tap(favoriteFinder);
      await tester.pump();

      expect(favoriteTapped, isTrue);
      expect(cardTapped, isFalse);
    });

    testWidgets('tapping card body triggers onTap callback',
        (tester) async {
      bool cardTapped = false;
      bool favoriteTapped = false;

      await tester.pumpWidget(
        _wrap(
          ChannelCard(
            channel: testChannel,
            onTap: () => cardTapped = true,
            onFavorite: () => favoriteTapped = true,
            showFavoriteButton: true,
          ),
        ),
      );

      await tester.tap(find.text('BBC One HD'));
      await tester.pump();

      expect(cardTapped, isTrue);
      expect(favoriteTapped, isFalse);
    });

    testWidgets('displays filled heart when favorite is true',
        (tester) async {
      final favoritedChannel = testChannel.copyWith(favorite: true);

      await tester.pumpWidget(
        _wrap(
          ChannelCard(
            channel: favoritedChannel,
            showFavoriteButton: true,
          ),
        ),
      );

      expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);
    });
  });
}
