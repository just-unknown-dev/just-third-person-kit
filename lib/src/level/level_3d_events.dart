import 'package:just_game_engine/just_game_engine.dart';

/// A pickup was taken.
final class PickupCollected3DEvent extends GameEvent {
  /// [collector] took [pickup], worth [value].
  PickupCollected3DEvent(this.pickup, this.collector, this.value);

  /// The pickup, now gone.
  final Entity pickup;

  /// Who took it.
  final Entity collector;

  /// What it was worth.
  final int value;
}

/// A player reached a checkpoint for the first time: from now on it comes
/// back there after a fall. The 3-D twin of the engine's
/// `CheckpointActivatedEvent`.
final class CheckpointActivated3DEvent extends GameEvent {
  /// [player] reached [checkpoint].
  CheckpointActivated3DEvent(this.checkpoint, this.player);

  /// The checkpoint.
  final Entity checkpoint;

  /// Who reached it.
  final Entity player;
}

/// A player was put back at its spawn point: after a fall past its fall
/// limit, or on touching a kill zone. The 3-D twin of the engine's
/// `PlayerRespawnEvent`.
final class PlayerRespawn3DEvent extends GameEvent {
  /// [player] came back at [at].
  PlayerRespawn3DEvent(this.player, this.at);

  /// Who.
  final Entity player;

  /// Where.
  final Vector3 at;
}
