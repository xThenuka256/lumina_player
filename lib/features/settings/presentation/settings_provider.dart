import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lumina_player/core/storage/library_database.dart';
import 'package:lumina_player/features/library/data/library_scanner.dart';
import 'package:lumina_player/features/library/presentation/library_provider.dart';

class SettingsState {
  const SettingsState({
    this.watchedFolders = const [],
    this.excludedFolders = const [],
    this.xdgMusicDir,
  });

  final List<String> watchedFolders;
  final List<String> excludedFolders;
  final String? xdgMusicDir;

  SettingsState copyWith({
    List<String>? watchedFolders,
    List<String>? excludedFolders,
    String? xdgMusicDir,
  }) {
    return SettingsState(
      watchedFolders: watchedFolders ?? this.watchedFolders,
      excludedFolders: excludedFolders ?? this.excludedFolders,
      xdgMusicDir: xdgMusicDir ?? this.xdgMusicDir,
    );
  }
}

class SettingsNotifier extends Notifier<SettingsState> {
  @override
  SettingsState build() {
    Future.microtask(load);
    return const SettingsState();
  }

  Future<void> load() async {
    final db = LibraryDatabase.instance;
    final watched = await db.getFolders('watched');
    final excluded = await db.getFolders('excluded');
    final xdg = await LibraryScanner.instance.detectXdgMusicDirectory();
    state = SettingsState(
      watchedFolders: watched,
      excludedFolders: excluded,
      xdgMusicDir: xdg,
    );
  }

  Future<void> pickWatchedFolder() async {
    final path = await LibraryScanner.instance.pickAndAddFolder();
    if (path != null) {
      await load();
      await ref.read(libraryProvider.notifier).rescan();
    }
  }

  Future<void> removeWatchedFolder(String path) async {
    await LibraryDatabase.instance.removeFolderRule(path, 'watched');
    await load();
    await ref.read(libraryProvider.notifier).rescan();
  }

  Future<void> pickExcludedFolder() async {
    final selected = await LibraryScanner.instance.pickAndAddFolder();
    if (selected != null) {
      await LibraryDatabase.instance.removeFolderRule(selected, 'watched');
      await LibraryDatabase.instance.addFolderRule(selected, 'excluded');
      await load();
      await ref.read(libraryProvider.notifier).rescan();
    }
  }

  Future<void> removeExcludedFolder(String path) async {
    await LibraryDatabase.instance.removeFolderRule(path, 'excluded');
    await load();
    await ref.read(libraryProvider.notifier).rescan();
  }
}

final settingsProvider = NotifierProvider<SettingsNotifier, SettingsState>(
  SettingsNotifier.new,
);
