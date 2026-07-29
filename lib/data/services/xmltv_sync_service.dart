import 'package:stream_hub/data/models/xmltv_models.dart';

class XMLTVSyncService {
  XMLTVSyncService();

  SyncResult prepareIncrementalSync(
    XMLTVGuide newGuide,
    XMLTVGuide? previousGuide,
  ) {
    if (previousGuide == null) {
      return SyncResult(
        type: SyncType.full,
        addedPrograms: newGuide.programs.length,
        addedChannels: newGuide.channels.length,
        removedPrograms: 0,
        removedChannels: 0,
        changedChannels: <String>[],
        newPrograms: newGuide.programs.map((p) => p.id).toList(),
        expiredPrograms: <String>[],
        changedPrograms: <String>[],
      );
    }

    final previousProgramIds = <String>{};
    for (final p in previousGuide.programs) {
      previousProgramIds.add(p.id);
    }

    final newProgramIds = <String>{};
    for (final p in newGuide.programs) {
      newProgramIds.add(p.id);
    }

    final addedPrograms = newProgramIds.difference(previousProgramIds).length;
    final removedPrograms = previousProgramIds.difference(newProgramIds).length;
    final changedPrograms = newProgramIds.intersection(previousProgramIds).toList();

    final previousChannelIds = <String>{};
    for (final c in previousGuide.channels) {
      previousChannelIds.add(c.id);
    }

    final newChannelIds = <String>{};
    for (final c in newGuide.channels) {
      newChannelIds.add(c.id);
    }

    final addedChannels = newChannelIds.difference(previousChannelIds).length;
    final removedChannels = previousChannelIds.difference(newChannelIds).length;
    final changedChannels = newChannelIds.intersection(previousChannelIds).toList();

    final expiredPrograms = previousProgramIds.difference(newProgramIds).toList();

    return SyncResult(
      type: SyncType.incremental,
      addedPrograms: addedPrograms,
      addedChannels: addedChannels,
      removedPrograms: removedPrograms,
      removedChannels: removedChannels,
      changedChannels: changedChannels,
      newPrograms: newProgramIds.difference(previousProgramIds).toList(),
      expiredPrograms: expiredPrograms,
      changedPrograms: changedPrograms,
    );
  }

  XMLTVGuide mergeGuides(XMLTVGuide base, XMLTVGuide update) {
    final mergedChannels = <XMLTVChannel>[];
    final channelMap = <String, XMLTVChannel>{};

    for (final channel in base.channels) {
      channelMap[channel.id] = channel;
    }

    for (final channel in update.channels) {
      if (channelMap.containsKey(channel.id)) {
        final existing = channelMap[channel.id]!;
        channelMap[channel.id] = _mergeChannel(existing, channel);
      } else {
        channelMap[channel.id] = channel;
      }
    }

    mergedChannels.addAll(channelMap.values);

    final mergedPrograms = <XMLTVProgram>[];
    final programMap = <String, XMLTVProgram>{};

    for (final program in base.programs) {
      programMap[program.id] = program;
    }

    for (final program in update.programs) {
      if (programMap.containsKey(program.id)) {
        programMap[program.id] = _mergeProgram(programMap[program.id]!, program);
      } else {
        programMap[program.id] = program;
      }
    }

    mergedPrograms.addAll(programMap.values);

    return base.copyWith(
      channels: mergedChannels,
      programs: mergedPrograms,
      generatedAt: DateTime.now(),
      version: update.version ?? base.version,
    );
  }

  XMLTVChannel _mergeChannel(XMLTVChannel base, XMLTVChannel update) {
    return base.copyWith(
      displayName: update.displayName.isNotEmpty ? update.displayName : base.displayName,
      iconUrl: update.iconUrl ?? base.iconUrl,
      language: update.language ?? base.language,
      country: update.country ?? base.country,
      aliases: {...base.aliases, ...update.aliases}.toList(),
    );
  }

  XMLTVProgram _mergeProgram(XMLTVProgram base, XMLTVProgram update) {
    return base.copyWith(
      title: update.title.isNotEmpty ? update.title : base.title,
      subtitle: update.subtitle ?? base.subtitle,
      description: update.description ?? base.description,
      categories: update.categories.isNotEmpty ? update.categories : base.categories,
      rating: update.rating ?? base.rating,
      poster: update.poster ?? base.poster,
      isNew: update.isNew || base.isNew,
      isPremiere: update.isPremiere || base.isPremiere,
      isPreviouslyShown: update.isPreviouslyShown || base.isPreviouslyShown,
      updatedAt: DateTime.now(),
    );
  }

  ConflictResolution resolveConflict(XMLTVProgram local, XMLTVProgram remote) {
    if (local.updatedAt.isAfter(remote.updatedAt)) {
      return ConflictResolution(useLocal: true, reason: 'Local version is newer');
    }
    if (remote.updatedAt.isAfter(local.updatedAt)) {
      return ConflictResolution(useLocal: false, reason: 'Remote version is newer');
    }
    return ConflictResolution(useLocal: true, reason: 'Same timestamp, defaulting to local');
  }
}

enum SyncType { full, incremental }

class SyncResult {
  final SyncType type;
  final int addedPrograms;
  final int addedChannels;
  final int removedPrograms;
  final int removedChannels;
  final List<String> changedChannels;
  final List<String> newPrograms;
  final List<String> expiredPrograms;
  final List<String> changedPrograms;

  const SyncResult({
    required this.type,
    required this.addedPrograms,
    required this.addedChannels,
    required this.removedPrograms,
    required this.removedChannels,
    required this.changedChannels,
    required this.newPrograms,
    required this.expiredPrograms,
    required this.changedPrograms,
  });
}

class ConflictResolution {
  final bool useLocal;
  final String reason;

  const ConflictResolution({
    required this.useLocal,
    required this.reason,
  });
}