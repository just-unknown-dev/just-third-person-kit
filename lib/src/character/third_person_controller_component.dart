import 'dart:math' as math;

import 'package:just_game_engine/just_game_engine.dart';

/// A third-person hero: moved by the `move` action relative to where the
/// camera looks, jumping with `jump` (with coyote time and a buffered
/// press, and an optional wind-up), crouching while `crouch` is held —
/// its body lowered to [ThirdPersonControllerComponent.crouchHeight], so it fits
/// under what it could not walk under standing — turning to face the way it
/// runs. Goes on an entity with a
/// `CharacterBody3DComponent` (`package:just_game_engine/just_game_engine_3d.dart`) and an `InputComponent`; the
/// character does the walking — slopes, steps, platforms — this decides
/// where to.
class ThirdPersonControllerComponent extends Component {
  /// A controller; the defaults suit a person-sized character in metres.
  ThirdPersonControllerComponent({
    this.walkSpeed = 4.5,
    this.sprintSpeed = 7.5,
    this.crouchSpeed = 1.0,
    this.crouchHeight = 1.5,
    this.acceleration = 30,
    this.airAcceleration = 8,
    this.jumpSpeed = 6.5,
    this.jumpDelay = 0,
    this.coyoteTime = 0.12,
    this.jumpBuffer = 0.12,
    this.turnSpeed = 12,
    this.facingOffset = math.pi,
    this.fallLimit = 40,
    this.moveAction = 'move',
    this.jumpAction = 'jump',
    this.sprintAction = 'sprint',
    this.crouchAction = 'crouch',
  });

  /// Top speed on foot, metres a second.
  double walkSpeed;

  /// Top speed while `sprint` is held.
  double sprintSpeed;

  /// Top speed while crouching; it wins over sprinting.
  double crouchSpeed;

  /// Its body's height while crouching, metres: it ducks under what it
  /// could not walk under standing, and stands again only where there is
  /// room. A body no taller keeps its height.
  ///
  /// The crouch sets the `CharacterBody3DComponent`'s runtime
  /// `heightOverride`, never its saved `height`, and clears it as it stands
  /// up or is put back at its spawn point; a world saved mid-crouch keeps
  /// the authored height.
  double crouchHeight;

  /// How fast it reaches its speed (and stops) on the ground, m/s².
  double acceleration;

  /// The same in the air: less, so a jump keeps its line.
  double airAcceleration;

  /// Upward speed of a jump, m/s.
  double jumpSpeed;

  /// Seconds from taking a jump on the ground to leaving it: a wind-up, for
  /// a jump animation that crouches before it springs. 0 leaves at once.
  double jumpDelay;

  /// Seconds after running off an edge that a jump still works.
  double coyoteTime;

  /// Seconds a jump pressed just before landing is remembered.
  double jumpBuffer;

  /// How fast it turns to face where it runs, radians a second.
  double turnSpeed;

  /// Added to the way it faces: a glTF character faces its file's +Z,
  /// which is the engine's -Z, so π turns it round to face forward.
  double facingOffset;

  /// How far it may fall (metres, +Y is down) below the lowest place it
  /// has had as its spawn point — where it started, or the lowest
  /// checkpoint it has reached — before it is put back ([killHeight]). A
  /// checkpoint high above the ground never makes that ground deadly. A
  /// kill zone gives a level an exact floor.
  double fallLimit;

  /// The vector action that moves it (y down: up on the stick is forward).
  String moveAction;

  /// The button that jumps.
  String jumpAction;

  /// The button held to sprint; a missing action never sprints.
  String sprintAction;

  /// The button held to crouch; a missing action never crouches.
  String crouchAction;

  // ── Runtime, not saved ──────────────────────────────────────────────────

  /// Its velocity along the ground this step, m/s.
  final Vector3 planarVelocity = Vector3.zero();

  /// How fast it moves along the ground: what an animator blends walking on.
  double get planarSpeed => math.sqrt(
    planarVelocity.x * planarVelocity.x + planarVelocity.z * planarVelocity.z,
  );

  /// Whether it stood on ground at the last step.
  bool isGrounded = false;

  /// Whether it is jumping: winding up on the ground ([jumpDelay]), or off
  /// the ground in a jump and not landed yet.
  bool isJumping = false;

  /// Seconds left of the wind-up before it leaves the ground; null when no
  /// jump is winding up.
  double? windUp;

  /// Whether it crouches: on the ground with `crouch` held at the last
  /// step, or kept down by something overhead. A jump stands it up where
  /// there is room.
  bool isCrouching = false;

  /// The way it faces, radians about the up axis (0 faces +Z).
  double facing = 0;

  /// Seconds since it last stood on ground.
  double airTime = 0;

  /// The fastest it has fallen since it left the ground, m/s: what a
  /// `Landed3DEvent` reports.
  double fallSpeed = 0;

  /// Seconds since `jump` was pressed and not used; infinity for none.
  double sincePressed = double.infinity;

  /// Where it is put back after a fall: where it started, or the last
  /// checkpoint reached.
  Vector3? spawnPoint;

  /// The lowest of its spawn points so far, as a height (y, +Y is down):
  /// where it started, or the lowest checkpoint it has reached. [fallLimit]
  /// is measured from it, so it never rises with a checkpoint. Null until
  /// it has had a spawn point.
  double? lowestSpawnY;

  /// The height (y, +Y is down) past which it is put back after a fall:
  /// [fallLimit] below the lower of [lowestSpawnY] and [spawnPoint]; null
  /// while it has neither.
  double? get killHeight {
    final spawn = spawnPoint?.y, lowest = lowestSpawnY;
    final from = spawn == null
        ? lowest
        : lowest == null
        ? spawn
        : math.max(spawn, lowest);
    return from == null ? null : from + fallLimit;
  }
}
