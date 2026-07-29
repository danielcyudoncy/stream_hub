import 'package:flutter_test/flutter_test.dart';
import 'package:stream_hub/data/services/xmltv_sync_service.dart';
import 'package:stream_hub/data/models/xmltv_models.dart';

void main() {
  group('XMLTVSyncService', () {
    late XMLTVSyncService syncService;

    setUp(() {
      syncService = XMLTVSyncService();
    });

    test('full sync when no previous guide', () {
      final newGuide = XMLTVGuide(
        sourceId: 'test',
        channels: [
          XMLTVChannel(id: 'ch1', displayName: 'Channel 1'),
        ],
        programs: [
          XMLTVProgram(
            id: 'p1',
            channelId: 'ch1',
            title: 'Program 1',
            start: DateTime(2026, 1, 1, 12, 0),
            end: DateTime(2026, 1, 1, 13, 0),
            duration: Duration(hours: 1),
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        ],
        generatedAt: DateTime.now(),
      );

      final result = syncService.prepareIncrementalSync(newGuide, null);

      expect(result.type, SyncType.full);
      expect(result.addedPrograms, 1);
      expect(result.addedChannels, 1);
      expect(result.newPrograms, ['p1']);
    });

    test('incremental sync detects changes', () {
      final previousGuide = XMLTVGuide(
        sourceId: 'test',
        channels: [
          XMLTVChannel(id: 'ch1', displayName: 'Channel 1'),
          XMLTVChannel(id: 'ch2', displayName: 'Channel 2'),
        ],
        programs: [
          XMLTVProgram(
            id: 'p1',
            channelId: 'ch1',
            title: 'Program 1',
            start: DateTime(2026, 1, 1, 12, 0),
            end: DateTime(2026, 1, 1, 13, 0),
            duration: Duration(hours: 1),
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
          XMLTVProgram(
            id: 'p2',
            channelId: 'ch2',
            title: 'Program 2',
            start: DateTime(2026, 1, 1, 14, 0),
            end: DateTime(2026, 1, 1, 15, 0),
            duration: Duration(hours: 1),
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        ],
        generatedAt: DateTime.now().subtract(const Duration(hours: 24)),
      );

      final newGuide = XMLTVGuide(
        sourceId: 'test',
        channels: [
          XMLTVChannel(id: 'ch1', displayName: 'Channel 1'),
          XMLTVChannel(id: 'ch2', displayName: 'Channel 2'),
          XMLTVChannel(id: 'ch3', displayName: 'Channel 3'),
        ],
        programs: [
          XMLTVProgram(
            id: 'p1',
            channelId: 'ch1',
            title: 'Program 1',
            start: DateTime(2026, 1, 1, 12, 0),
            end: DateTime(2026, 1, 1, 13, 0),
            duration: Duration(hours: 1),
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
          XMLTVProgram(
            id: 'p3',
            channelId: 'ch1',
            title: 'Program 3',
            start: DateTime(2026, 1, 2, 12, 0),
            end: DateTime(2026, 1, 2, 13, 0),
            duration: Duration(hours: 1),
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        ],
        generatedAt: DateTime.now(),
      );

      final result = syncService.prepareIncrementalSync(newGuide, previousGuide);

      expect(result.type, SyncType.incremental);
      expect(result.addedPrograms, 1);
      expect(result.removedPrograms, 1);
      expect(result.addedChannels, 1);
      expect(result.removedChannels, 0);
      expect(result.newPrograms, contains('p3'));
      expect(result.expiredPrograms, contains('p2'));
    });

    test('merge guides combines channels and programs', () {
      final baseGuide = XMLTVGuide(
        sourceId: 'test',
        channels: [
          XMLTVChannel(id: 'ch1', displayName: 'Channel 1'),
        ],
        programs: [
          XMLTVProgram(
            id: 'p1',
            channelId: 'ch1',
            title: 'Program 1',
            start: DateTime(2026, 1, 1, 12, 0),
            end: DateTime(2026, 1, 1, 13, 0),
            duration: Duration(hours: 1),
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        ],
        generatedAt: DateTime.now(),
      );

      final updateGuide = XMLTVGuide(
        sourceId: 'test',
        channels: [
          XMLTVChannel(id: 'ch1', displayName: 'Channel 1 Updated'),
          XMLTVChannel(id: 'ch2', displayName: 'Channel 2'),
        ],
        programs: [
          XMLTVProgram(
            id: 'p1',
            channelId: 'ch1',
            title: 'Program 1 Updated',
            start: DateTime(2026, 1, 1, 12, 0),
            end: DateTime(2026, 1, 1, 13, 0),
            duration: Duration(hours: 1),
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
          XMLTVProgram(
            id: 'p2',
            channelId: 'ch2',
            title: 'Program 2',
            start: DateTime(2026, 1, 2, 12, 0),
            end: DateTime(2026, 1, 2, 13, 0),
            duration: Duration(hours: 1),
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        ],
        generatedAt: DateTime.now(),
      );

      final merged = syncService.mergeGuides(baseGuide, updateGuide);

      expect(merged.channels.length, 2);
      expect(merged.programs.length, 2);
      expect(merged.programs.first.title, 'Program 1 Updated');
    });

    test('resolves conflicts by timestamp', () {
      final localProgram = XMLTVProgram(
        id: 'p1',
        channelId: 'ch1',
        title: 'Local Title',
        start: DateTime(2026, 1, 1, 12, 0),
        end: DateTime(2026, 1, 1, 13, 0),
        duration: Duration(hours: 1),
        createdAt: DateTime.now(),
        updatedAt: DateTime(2026, 1, 1, 12, 0),
      );

      final remoteProgram = XMLTVProgram(
        id: 'p1',
        channelId: 'ch1',
        title: 'Remote Title',
        start: DateTime(2026, 1, 1, 12, 0),
        end: DateTime(2026, 1, 1, 13, 0),
        duration: Duration(hours: 1),
        createdAt: DateTime.now(),
        updatedAt: DateTime(2026, 1, 1, 12, 1),
      );

      final resolution = syncService.resolveConflict(localProgram, remoteProgram);

      expect(resolution.useLocal, isFalse);
      expect(resolution.reason, 'Remote version is newer');
    });
  });
}