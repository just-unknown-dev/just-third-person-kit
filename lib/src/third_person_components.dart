import 'dart:math' as math;

import 'package:just_game_engine/just_game_engine.dart';

import 'combo_set.dart';

/// A third-person hero: moved by the `move` action relative to where the
/// camera looks, jumping with `jump` (with coyote time and a buffered
/// press, and an optional wind-up), crouching while `crouch` is held —
/// its body lowered to [ThirdPersonController.crouchHeight], so it fits
/// under what it could not walk under standing — turning to face the way it
/// runs. Goes on an entity with a
/// `CharacterBody3D` (`package:just_game_engine/physics_3d.dart`) and an `InputComponent`; the
/// character does the walking — slopes, steps, platforms — this decides
/// where to.
class ThirdPersonController extends Component {
  /// A controller; the defaults suit a person-sized character in metres.
  ThirdPersonController({
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

  /// How far below its spawn point (metres, +Y is down) it may fall before
  /// it is put back.
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
  double get planarSpeed => math.sqrt(planarVelocity.x * planarVelocity.x + planarVelocity.z * planarVelocity.z);

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

  /// Its body's height before it crouched, given back when it stands; null
  /// while its body has its standing height.
  double? standingHeight;

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
}

/// A hero's punches and kicks: `punch` and `kick` each start a chain of
/// strikes from the [combosPath] file (a `.combos.json` beside its model).
/// A press of the same button in a strike's combo window queues the next
/// strike, which starts as this one ends; otherwise it ends in the guard
/// stance, which it leaves after [guardTime] or when it moves. Strikes
/// start on the ground, not crouched or jumping, and hold it still while
/// they last. A `StrikeHit3DEvent` says when each blow lands.
///
/// Goes on a hero with a [ThirdPersonController] and an `InputComponent`;
/// an animator graph plays each strike on the trigger of its name, and
/// reads `striking` and `inCombat`.
class ThirdPersonCombat extends Component {
  /// Combat from the strikes in [combosPath]; none while it is empty.
  ThirdPersonCombat({
    this.combosPath = '',
    this.punchAction = 'punch',
    this.kickAction = 'kick',
    this.punchChain = 'punch_combo',
    this.kickChain = 'kick_combo',
    this.guardTime = 1.5,
  });

  /// Asset path of the strikes and their chains (e.g.
  /// `assets/models/hero.combos.json`).
  String combosPath;

  /// The button that punches.
  String punchAction;

  /// The button that kicks.
  String kickAction;

  /// The chain [punchAction] starts and goes on with.
  String punchChain;

  /// The chain [kickAction] starts and goes on with.
  String kickChain;

  /// Seconds it keeps its guard after a strike, standing still.
  double guardTime;

  // ── Runtime, not saved ──────────────────────────────────────────────────

  /// The strike playing; null between strikes.
  Strike? strike;

  /// The chain [strike] belongs to.
  String chain = '';

  /// Where in its chain [strike] is: 1 for the first.
  int step = 0;

  /// Seconds into [strike].
  double strikeTime = 0;

  /// Whether [strike]'s blow has landed.
  bool hitLanded = false;

  /// The strike asked for in [strike]'s combo window, to start as it ends.
  String? queued;

  /// Seconds of guard left after the last strike; 0 when it has dropped
  /// its guard.
  double guardLeft = 0;

  /// Whether a strike is playing.
  bool get isStriking => strike != null;

  /// Whether it is fighting: striking, or in its guard after a strike.
  bool get inCombat => strike != null || guardLeft > 0;
}

/// A third-person camera's player controls: on a virtual camera with an
/// `OrbitFollowComponent`, turned by the look actions (`look`, the mouse or
/// a drag; `lookStick`, a stick) and zoomed by the `zoom` axis.
class ThirdPersonCamera extends Component {
  /// Camera controls.
  ThirdPersonCamera({
    this.sensitivity = 1,
    this.invertY = false,
    this.zoomSpeed = 1.5,
    this.zoomAction = 'zoom',
  });

  /// Scales the look settings' turn: 2 turns twice as far.
  double sensitivity;

  /// Whether moving up looks down.
  bool invertY;

  /// How fast `zoom` moves it in and out, as a share of the distance a
  /// second at full deflection.
  double zoomSpeed;

  /// The axis action that zooms (positive moves in).
  String zoomAction;
}

/// Something to collect: a sensor that, touched by a player, disappears and
/// counts [value]. It spins (about the up axis, from the way it was placed)
/// and bobs to be seen, while the game runs.
class Pickup3D extends Component {
  /// A pickup worth [value].
  Pickup3D({this.value = 1, this.spinSpeed = 2, this.bobHeight = 0.15, this.bobSpeed = 2});

  /// What it is worth.
  int value;

  /// Turns a second, radians.
  double spinSpeed;

  /// How far it rises and falls, metres.
  double bobHeight;

  /// Rises and falls a second, radians of the bob's cycle.
  double bobSpeed;

  // Runtime.
  Vector3? _home;
  Quaternion? _homeRotation;
  double _time = 0;
  bool _collected = false;

  /// Whether a player has taken it.
  bool get isCollected => _collected;
}

/// A platform that moves to [travel] from where it starts and back, at
/// [speed], resting [wait] seconds at each end. A kinematic body: characters
/// standing on it ride along.
class MovingPlatform3D extends Component {
  /// A platform going [travel] metres and back.
  MovingPlatform3D({Vector3? travel, this.speed = 2, this.wait = 0.5})
    : travel = travel ?? Vector3(4, 0, 0);

  /// Where it goes, from where it starts.
  Vector3 travel;

  /// Metres a second.
  double speed;

  /// Seconds it rests at each end.
  double wait;

  // Runtime.
  Vector3? _start;
  double _along = 0;
  double _direction = 1;
  double _resting = 0;
}

/// A checkpoint: a sensor that, reached by a player, becomes where it comes
/// back after a fall.
class Checkpoint3D extends Component {
  /// A checkpoint; [order] lets a later one not be undone by an earlier.
  Checkpoint3D({this.order = 0});

  /// Its place in the level: one with a lower order reached after a higher
  /// one does not move the spawn back.
  int order;

  /// Whether a player has reached it.
  bool reached = false;
}

/// A sensor that sends a player back to its spawn point: water, a pit, a
/// crusher.
class KillZone3D extends Component {
  /// A kill zone.
  KillZone3D();
}

/// Internal access for the kit's systems.
extension PickupRuntime on Pickup3D {
  /// Where it bobs about.
  Vector3? get home => _home;
  set home(Vector3? v) => _home = v;

  /// The way it was placed, which it spins from.
  Quaternion? get homeRotation => _homeRotation;
  set homeRotation(Quaternion? v) => _homeRotation = v;

  /// Seconds it has been bobbing.
  double get time => _time;
  set time(double v) => _time = v;

  /// Marks it taken.
  void collect() => _collected = true;
}

/// Internal access for the kit's systems.
extension MovingPlatformRuntime on MovingPlatform3D {
  /// Where it started.
  Vector3? get start => _start;
  set start(Vector3? v) => _start = v;

  /// How far along its travel, 0–1.
  double get along => _along;
  set along(double v) => _along = v;

  /// +1 going, -1 coming back.
  double get direction => _direction;
  set direction(double v) => _direction = v;

  /// Seconds left resting.
  double get resting => _resting;
  set resting(double v) => _resting = v;
}
