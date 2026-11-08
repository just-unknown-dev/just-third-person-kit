import 'package:flutter/foundation.dart' show internal;
import 'package:just_game_engine/just_game_engine.dart';

/// Something to collect: a sensor that, touched by a player, disappears and
/// counts [value]. It spins (about the up axis, from the way it was placed)
/// and bobs to be seen, while the game runs.
class Pickup3DComponent extends Component {
  /// A pickup worth [value].
  Pickup3DComponent({
    this.value = 1,
    this.spinSpeed = 2,
    this.bobHeight = 0.15,
    this.bobSpeed = 2,
  });

  /// What it is worth.
  int value;

  /// Turns a second, radians.
  double spinSpeed;

  /// How far it rises and falls, metres.
  double bobHeight;

  /// Rises and falls a second, radians of the bob's cycle.
  double bobSpeed;

  // ── Runtime, not saved: the kit's own ──────────────────────────────────

  /// Where it bobs about: where it was when time first moved.
  @internal
  Vector3? home;

  /// The way it was placed, which it spins from.
  @internal
  Quaternion? homeRotation;

  /// Seconds it has been bobbing.
  @internal
  double time = 0;

  bool _collected = false;

  /// Whether a player has taken it.
  bool get isCollected => _collected;

  /// Marks it taken.
  @internal
  void collect() => _collected = true;
}
