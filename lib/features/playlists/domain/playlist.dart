/// User-defined local playlist stored in SQLite.
class PlaylistModel {
  const PlaylistModel({
    required this.id,
    required this.name,
    required this.trackIds,
    required this.createdAtMs,
  });

  final String id;
  final String name;
  final List<String> trackIds;
  final int createdAtMs;

  PlaylistModel copyWith({
    String? id,
    String? name,
    List<String>? trackIds,
    int? createdAtMs,
  }) {
    return PlaylistModel(
      id: id ?? this.id,
      name: name ?? this.name,
      trackIds: trackIds ?? this.trackIds,
      createdAtMs: createdAtMs ?? this.createdAtMs,
    );
  }
}
