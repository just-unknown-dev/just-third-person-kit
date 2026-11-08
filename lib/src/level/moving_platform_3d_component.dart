import 'package:flutter/foundation.dart' show internal;
import 'package:just_game_engine/just_game_engine.dart';

/// A platform that moves to [travel] from where it starts and back, at
/// [speed], resting [wait] seconds at each end. A kinematic body: characters
/// standing on it ride along.
class MovingPlatform3DComponent extends Component {
  /// A platform going [travel] metres and back.
  MovingPlatform3DComponent({Vector3? travel, this.speed = 2, this.wait = 0.5})
    : travel = travel ?? Vector3(4, 0, 0);

  /// Where it goes, from where it starts.
  Vector3 travel;

  /// Metres a second.
  double speed;

  /// Seconds it rests at each end.
  double wait;

  // ── Runtime, not saved: the kit's own ──────────────────────────────────

  /// Where it started.
  @internal
  Vector3? start;

  /// How far along its travel, 0–1.
  @internal
  double along = 0;

  /// +1 going, -1 coming back.
  @internal
  double direction = 1;

  /// Seconds left resting.
  @internal
  double resting = 0;
}
