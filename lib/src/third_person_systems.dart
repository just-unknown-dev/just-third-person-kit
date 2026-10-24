import 'dart:math' as math;
import 'dart:ui' show Offset;

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:just_game_engine/just_game_engine.dart';
import 'package:just_game_engine/physics_3d.dart';

import 'combo_set.dart';
import 'third_person_components.dart';

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

/// A player reached a checkpoint.
final class CheckpointReached3DEvent extends GameEvent {
  /// [player] reached [checkpoint].
  CheckpointReached3DEvent(this.checkpoint, this.player);

  /// The checkpoint.
  final Entity checkpoint;

  /// Who reached it.
  final Entity player;
}

/// A player was put back at its spawn point.
final class Respawned3DEvent extends GameEvent {
  /// [player] came back at [at].
  Respawned3DEvent(this.player, this.at);

  /// Who.
  final Entity player;

  /// Where.
  final Vector3 at;
}

/// A player left the ground in a jump (or jumped just after running off an
/// edge).
final class Jumped3DEvent extends GameEvent {
  /// [player] jumped.
  Jumped3DEvent(this.player);

  /// Who.
  final Entity player;
}

/// A player came down on the ground after being in the air.
final class Landed3DEvent extends GameEvent {
  /// [player] landed, falling at [fallSpeed].
  Landed3DEvent(this.player, this.fallSpeed);

  /// Who.
  final Entity player;

  /// How fast it was falling when it landed, m/s (the fastest it fell on
  /// the way down): small for a step down, large for a long fall — a game
  /// picks what is worth a sound.
  final double fallSpeed;
}

/// A strike's blow landed: the moment game code applies its damage.
final class StrikeHit3DEvent extends GameEvent {
  /// [player]'s [strike], the [step]th of [chain] (from 1), landed.
  StrikeHit3DEvent(this.player, this.strike, this.chain, this.step);

  /// Who struck.
  final Entity player;

  /// The strike: its name, what it is, what it strikes with.
  final Strike strike;

  /// The chain it is part of.
  final String chain;

  /// Where in the chain it is: 1 for the first.
  final int step;
}

/// The way along the ground a camera with [yaw] faces, and its right.
(Vector3 forward, Vector3 right) groundAxesOf(double yaw) => (
  Vector3(math.sin(yaw), 0, math.cos(yaw)),
  Vector3(math.cos(yaw), 0, -math.sin(yaw)),
);

/// Moves [ThirdPersonController] characters from their input, relative to
/// where the camera looks; before physics, so the step uses it. A crouch
/// lowers the character's body, and it stands only when the world's
/// [PhysicsSystem3D] finds nothing above it.
class ThirdPersonControllerSystem extends System {
  /// A system reading the camera's yaw from [cameraYaw].
  ThirdPersonControllerSystem({required this.cameraYaw});

  /// Which way the camera looks about the up axis, radians.
  final double Function() cameraYaw;

  @override
  int get priority => SystemPriorities.playerControl;

  @override
  List<Type> get requiredComponents => [
    TransformComponent,
    CharacterBody3D,
    ThirdPersonController,
    InputComponent,
  ];

  @override
  void update(double deltaTime) {
    if (deltaTime <= 0) return;
    // The camera's ground axes ([groundAxesOf]): forward (sin, 0, cos),
    // right (cos, 0, -sin) — as numbers, so a step allocates nothing.
    final yaw = cameraYaw();
    final sinYaw = math.sin(yaw), cosYaw = math.cos(yaw);
    for (final entity in entities) {
      if (!entity.isActive) continue;
      final transform = entity.getComponent<TransformComponent>()!;
      final character = entity.getComponent<CharacterBody3D>()!;
      final c = entity.getComponent<ThirdPersonController>()!;
      final input = entity.getComponent<InputComponent>()!;
      c.spawnPoint ??= Vector3.copy(transform.position);
      // A strike holds it still: no moving, jumping or crouching till it
      // ends.
      final striking = entity.getComponent<ThirdPersonCombat>()?.isStriking ?? false;

      // Ground and air time.
      final wasGrounded = c.isGrounded;
      final height = character.height;
      c.isGrounded = character.isGrounded;
      if (c.isGrounded) {
        c.airTime = 0;
        if (c.windUp == null && character.velocity.y >= -0.01) c.isJumping = false;
        // Down from the air — not just standing where it started.
        if (!wasGrounded && c.fallSpeed > 0) {
          world.events.fire(Landed3DEvent(entity, c.fallSpeed));
        }
        c.fallSpeed = 0;
      } else {
        c.airTime += deltaTime;
        // Falling is +Y.
        c.fallSpeed = math.max(c.fallSpeed, character.velocity.y);
      }

      // Crouching: only on the ground and not in a jump, slower than
      // walking, its body lowered; it stays down while something is above.
      if (c.isGrounded && !c.isJumping && !striking && input.isDown(c.crouchAction)) {
        _crouch(character, c);
      } else {
        _standUp(entity, character, c);
      }

      // Where to: the stick's up is forward from the camera.
      var stick = striking ? Offset.zero : input.vector(c.moveAction);
      if (stick.distanceSquared > 1) stick = stick / stick.distance;
      final speed = c.isCrouching
          ? c.crouchSpeed
          : input.isDown(c.sprintAction)
          ? c.sprintSpeed
          : c.walkSpeed;
      final wantX = (cosYaw * stick.dx - sinYaw * stick.dy) * speed;
      final wantZ = (-sinYaw * stick.dx - cosYaw * stick.dy) * speed;
      final rate = (c.isGrounded ? c.acceleration : c.airAcceleration) * deltaTime;
      final v = c.planarVelocity;
      final dx = wantX - v.x, dz = wantZ - v.z;
      final gap = math.sqrt(dx * dx + dz * dz);
      if (striking || gap <= rate || gap == 0) {
        v.setValues(wantX, 0, wantZ);
      } else {
        v.setValues(v.x + dx / gap * rate, 0, v.z + dz / gap * rate);
      }
      character.moveVelocity.setValues(v.x, 0, v.z);

      // Jump: a press is remembered a moment; the ground, a moment longer.
      if (input.wasPressed(c.jumpAction) && !striking) {
        c.sincePressed = 0;
      } else {
        c.sincePressed += deltaTime;
      }
      final windUp = c.windUp;
      if (windUp != null) {
        // Winding up: it springs when the wind-up is over, or at once if the
        // ground goes from under it.
        c.windUp = windUp - deltaTime;
        if (c.windUp! <= 1e-9 || !c.isGrounded) _launch(entity, character, c, height);
      } else if (c.sincePressed <= c.jumpBuffer && !c.isJumping && !striking) {
        if (c.isGrounded) {
          // A crouch stands up for it, if there is room. A wind-up starts
          // from ground it stood on the step before, so a jump taken as it
          // lands lets the landing be seen first.
          if (c.jumpDelay <= 0) {
            if (_standUp(entity, character, c)) _launch(entity, character, c, height);
          } else if (wasGrounded && _standUp(entity, character, c)) {
            c
              ..windUp = c.jumpDelay
              ..isJumping = true
              ..sincePressed = double.infinity;
          }
        } else if (c.airTime <= c.coyoteTime && _standUp(entity, character, c)) {
          _launch(entity, character, c, height);
        }
      }

      // Face where it runs.
      final planar = c.planarSpeed;
      if (planar > 0.2) {
        final target = math.atan2(v.x, v.z);
        var delta = target - c.facing;
        delta = (delta + math.pi) % (2 * math.pi) - math.pi;
        final step = c.turnSpeed * deltaTime;
        c.facing += delta.abs() <= step ? delta : step * delta.sign;
        _turn.setAxisAngle(0, 1, 0, c.facing + c.facingOffset);
        transform.setRotation(_turn);
      }
    }
  }

  /// Sends [c]'s [character] up, its body [height] tall at the step's
  /// start, and says so.
  void _launch(Entity entity, CharacterBody3D character, ThirdPersonController c, double height) {
    if (character.isGrounded && character.height == height) {
      character.jump(c.jumpSpeed);
    } else {
      // Just off an edge, or its body just made again at a new height,
      // whose first step is taken as in the air: the character keeps its
      // speed in the air, so give it the jump's (up is -Y).
      character.velocity.y = -c.jumpSpeed;
    }
    c
      ..isJumping = true
      ..isCrouching = false
      ..windUp = null
      ..sincePressed = double.infinity
      ..airTime = double.infinity;
    world.events.fire(Jumped3DEvent(entity));
  }

  /// Lowers [c]'s [character] to its crouching height.
  static void _crouch(CharacterBody3D character, ThirdPersonController c) {
    if (c.standingHeight == null && c.crouchHeight < character.height) {
      c.standingHeight = character.height;
      character.height = c.crouchHeight;
    }
    c.isCrouching = true;
  }

  /// Stands [c]'s [character] up from a crouch, if there is room above it;
  /// whether it stands.
  bool _standUp(Entity entity, CharacterBody3D character, ThirdPersonController c) {
    if (!c.isCrouching) return true;
    final standing = c.standingHeight;
    if (standing != null) {
      if (_blockedAbove(entity, character, standing - character.height)) return false;
      character.height = standing;
      c.standingHeight = null;
    }
    c.isCrouching = false;
    return true;
  }

  /// Whether something is within [rise] metres above [entity]'s
  /// [character]'s head: a sphere a little thinner than it, swept up from
  /// its head. Nothing is, without 3-D physics.
  bool _blockedAbove(Entity entity, CharacterBody3D character, double rise) {
    if (rise <= 0) return false;
    final queries = _queries();
    if (queries == null) return false;
    final feet = entity.getComponent<TransformComponent>()!.position;
    final radius = character.radius * 0.9;
    final head = _head..setValues(feet.x, feet.y - (character.height - character.radius), feet.z);
    final hit = queries.sphereCast(head, radius, _up, maxDistance: rise + character.radius - radius, ignore: entity);
    return hit != null;
  }

  static final Vector3 _up = Vector3(0, -1, 0);
  static final Quaternion _turn = Quaternion.identity();
  static final Vector3 _head = Vector3.zero();
  Physics3DQueries? _physicsQueries;

  /// Queries on the world's 3-D physics, or null without it.
  Physics3DQueries? _queries() {
    final system = world.getSystem<PhysicsSystem3D>();
    if (system == null) return null;
    if (_physicsQueries?.system != system) _physicsQueries = Physics3DQueries(system);
    return _physicsQueries;
  }
}

/// Plays [ThirdPersonCombat] strikes from the punch and kick buttons: a
/// press starts its chain; a press of the same button in a strike's combo
/// window queues the next, which starts as this one ends; a
/// [StrikeHit3DEvent] says when each blow lands; after the last strike the
/// guard is kept a while, dropped sooner when the hero moves, jumps or
/// crouches. Before the controller, which holds a striking hero still.
class ThirdPersonCombatSystem extends System {
  /// A system reading each combo set with [loader] once per path, shared
  /// by every hero that names it.
  ThirdPersonCombatSystem({this.loader});

  /// Reads the combo set at a path; null reads it from the world context's
  /// asset bundle.
  final Future<ComboSet> Function(String path)? loader;
  final Map<String, Future<void>> _loading = {};
  final Map<String, ComboSet> _sets = {};

  /// A stick pushed further than this drops the guard.
  static const double moveDeadZone = 0.2;

  @override
  int get priority => SystemPriorities.playerControl + 2;

  @override
  List<Type> get requiredComponents => const [ThirdPersonCombat, InputComponent];

  /// The combo set read from [path], once it has loaded.
  ComboSet? combosAt(String path) => _sets[path.trim()];

  @override
  void update(double deltaTime) {
    if (deltaTime <= 0) return;
    for (final entity in entities) {
      if (!entity.isActive) continue;
      final combat = entity.getComponent<ThirdPersonCombat>()!;
      final combos = _combos(combat.combosPath.trim());
      if (combos == null) continue;
      final input = entity.getComponent<InputComponent>()!;
      final control = entity.getComponent<ThirdPersonController>();
      // On its feet: not in the air (as its body found this step; the
      // controller runs after), in a jump's wind-up or crouched.
      final grounded = entity.getComponent<CharacterBody3D>()?.isGrounded ?? control?.isGrounded ?? true;
      final ready = grounded && !(control?.isJumping ?? false) && !(control?.isCrouching ?? false);
      final pressed = input.wasPressed(combat.punchAction)
          ? combat.punchChain
          : input.wasPressed(combat.kickAction)
          ? combat.kickChain
          : null;

      final strike = combat.strike;
      if (strike != null) {
        // Off the ground under it (an edge, a platform): no strike, no guard.
        if (!ready) {
          _end(entity, combat, guard: 0);
          continue;
        }
        // Read before the time moves on: a press is in the window it was
        // made in.
        if (pressed == combat.chain && strike.next != null && strike.inWindow(combat.strikeTime)) {
          combat.queued = strike.next;
        }
        combat.strikeTime += deltaTime;
        // Steps of 1/60 s add up a hair short of a time they reach.
        if (!combat.hitLanded && combat.strikeTime >= strike.hit - 1e-9) {
          combat.hitLanded = true;
          world.events.fire(StrikeHit3DEvent(entity, strike, combat.chain, combat.step));
        }
        if (combat.strikeTime >= strike.duration - 1e-9) {
          final next = combos.strikes[combat.queued];
          if (next != null) {
            _start(entity, combat, next, combat.chain, combat.step + 1);
          } else {
            // A press as it ends starts a new chain on the next step, once
            // the animator has seen this one end.
            _end(entity, combat, guard: combat.guardTime);
          }
        }
        continue;
      }

      if (combat.guardLeft > 0) {
        final moving = input.vector(control?.moveAction ?? 'move').distance > moveDeadZone;
        combat.guardLeft = moving || !ready ? 0 : math.max(0, combat.guardLeft - deltaTime);
      }
      if (pressed != null && ready) {
        final first = combos.firstOf(pressed);
        if (first != null) _start(entity, combat, first, pressed, 1);
      }
    }
  }

  /// Starts [strike], the [step]th of [chain], and plays it on the
  /// entity's animator: the trigger of its name.
  static void _start(Entity entity, ThirdPersonCombat combat, Strike strike, String chain, int step) {
    combat
      ..strike = strike
      ..chain = chain
      ..step = step
      ..strikeTime = 0
      ..hitLanded = false
      ..queued = null
      ..guardLeft = 0;
    entity.getComponent<AnimatorComponent>()?.setTrigger(strike.name);
  }

  /// Ends the strike playing, keeping the guard [guard] seconds.
  static void _end(Entity entity, ThirdPersonCombat combat, {required double guard}) {
    // A trigger no transition took (a graph without the strike) is not
    // left to fire later.
    final name = combat.strike?.name;
    if (name != null) entity.getComponent<AnimatorComponent>()?.resetTrigger(name);
    combat
      ..strike = null
      ..queued = null
      ..guardLeft = math.max(0, guard);
  }

  /// The combo set at [path], or null while it loads (or could not).
  ComboSet? _combos(String path) {
    if (path.isEmpty) return null;
    final known = _sets[path];
    if (known != null || _loading.containsKey(path)) return known;
    _loading[path] = (loader ?? _fromBundle)(path).then((set) {
      // A strike with no duration ends at once, one that lands past its end
      // never lands: said once, as the set loads.
      final problems = set.validate();
      if (problems.isNotEmpty) {
        debugPrint('ThirdPersonCombatSystem: "$path": ${problems.join(' ')}');
      }
      return _sets[path] = set;
    }).catchError((Object error) {
      // Not tried again; said once.
      debugPrint('ThirdPersonCombatSystem: "$path" could not be loaded; its strikes do nothing. $error');
      return const ComboSet();
    });
    return null;
  }

  Future<ComboSet> _fromBundle(String path) async => ComboSet.parse(await world.context.bundle.loadString(path));
}

/// Turns and zooms [ThirdPersonCamera] cameras from the look and zoom
/// actions, once per rendered frame, so the view is smooth at any rate.
///
/// It runs just before the camera brain ([SystemPriorities.camera] + 1), so
/// a frame's look is in the view that frame is drawn with.
class ThirdPersonCameraSystem extends System implements FrameSystem {
  /// A system reading looks and zoom through [actions]. Its [look] reader
  /// is made when it joins a world and let go when it leaves.
  ThirdPersonCameraSystem({required this.actions});

  /// Where the look and zoom actions are read.
  final InputActions actions;

  /// The look actions' reader (the mouse's movement and the stick's rate),
  /// while the system is in a world; null otherwise. It listens to the input
  /// service, so it exists only while it is used.
  LookInput? get look => _look;
  LookInput? _look;

  @override
  int get priority => SystemPriorities.camera + 1;

  @override
  List<Type> get requiredComponents => const [OrbitFollowComponent, ThirdPersonCamera];

  @override
  void onAddedToWorld() {
    super.onAddedToWorld();
    _look ??= LookInput(actions);
  }

  @override
  void onRemovedFromWorld() {
    _look?.dispose();
    _look = null;
    super.onRemovedFromWorld();
  }

  @override
  void update(double deltaTime) {}

  @override
  void frame(double deltaTime, double alpha) {
    final look = _look;
    if (look == null) return;
    final turn = look.read(deltaTime);
    for (final entity in entities) {
      if (!entity.isActive) continue;
      final orbit = entity.getComponent<OrbitFollowComponent>()!;
      final camera = entity.getComponent<ThirdPersonCamera>()!;
      applyLook(orbit, camera, turn);
      final zoom = actions.tryAction(camera.zoomAction)?.readAxis() ?? 0;
      if (zoom != 0 && deltaTime > 0) {
        orbit.distance = (orbit.distance * math.exp(-zoom * camera.zoomSpeed * deltaTime))
            .clamp(orbit.minDistance, orbit.maxDistance);
      }
    }
  }

  /// [orbit] turned by [turn] (radians: x right, y down) as [camera] says.
  static void applyLook(OrbitFollowComponent orbit, ThirdPersonCamera camera, Offset turn) {
    if (turn == Offset.zero) return;
    orbit.yaw += turn.dx * camera.sensitivity;
    // Down on the look turns the view down: a lower pitch (-Y is up).
    final dy = turn.dy * camera.sensitivity * (camera.invertY ? -1 : 1);
    orbit.pitch = (orbit.pitch - dy).clamp(orbit.minPitch, orbit.maxPitch);
  }
}

/// Spins and bobs pickups, and hands one to the player whose character
/// touches it.
///
/// The spin and bob stand still while time does (a `deltaTime` of 0: paused,
/// or an editor authoring the level), so a pickup stays where — and turned
/// the way — it was placed, and starts from there when play does.
class Pickup3DSystem extends System {
  /// The system; it listens on the world's events once added.
  Pickup3DSystem();

  @override
  List<Type> get requiredComponents => const [TransformComponent, Pickup3D];

  final List<(Entity, Entity)> _touched = [];
  EventSubscription? _subscription;

  @override
  void onAddedToWorld() {
    super.onAddedToWorld();
    _subscription = world.events.on<SensorEnter3DEvent>((e) {
      final pickup = e.sensor.getComponent<Pickup3D>();
      if (pickup != null && !pickup.isCollected && e.other.hasComponent<ThirdPersonController>()) {
        _touched.add((e.sensor, e.other));
      }
    });
  }

  @override
  void onRemovedFromWorld() {
    _subscription?.cancel();
    _subscription = null;
    super.onRemovedFromWorld();
  }

  @override
  void update(double deltaTime) {
    for (final (pickup, collector) in _touched) {
      final p = pickup.getComponent<Pickup3D>();
      if (p == null || p.isCollected || !pickup.isAlive) continue;
      p.collect();
      world.events.fire(PickupCollected3DEvent(pickup, collector, p.value));
      world.destroyEntity(pickup);
    }
    _touched.clear();
    if (deltaTime <= 0) return;
    for (final entity in entities) {
      if (!entity.isActive) continue;
      final p = entity.getComponent<Pickup3D>()!;
      final t = entity.getComponent<TransformComponent>()!;
      final home = p.home ??= Vector3.copy(t.position);
      final placed = p.homeRotation ??= _rotationOf(t);
      p.time += deltaTime;
      t.position.setValues(home.x, home.y - math.sin(p.time * p.bobSpeed) * p.bobHeight, home.z);
      // Its spin about the up axis, after the way it was placed.
      _spin
        ..setAxisAngle(0, 1, 0, p.time * p.spinSpeed)
        ..multiply(placed);
      t.setRotation(_spin);
    }
  }

  static Quaternion _rotationOf(TransformComponent t) {
    final q = Quaternion.identity();
    t.rotationInto(q);
    return q;
  }

  static final Quaternion _spin = Quaternion.identity();
}

/// Moves [MovingPlatform3D] platforms there and back; before physics, so a
/// kinematic body moves over the step and carries what stands on it.
class MovingPlatform3DSystem extends System {
  @override
  int get priority => SystemPriorities.playerControl + 1;

  @override
  List<Type> get requiredComponents => const [TransformComponent, MovingPlatform3D];

  @override
  void update(double deltaTime) {
    if (deltaTime <= 0) return;
    for (final entity in entities) {
      if (!entity.isActive) continue;
      final p = entity.getComponent<MovingPlatform3D>()!;
      final t = entity.getComponent<TransformComponent>()!;
      final start = p.start ??= Vector3.copy(t.position);
      final length = p.travel.length;
      if (length < 1e-6 || p.speed <= 0) continue;
      if (p.resting > 0) {
        p.resting -= deltaTime;
        if (p.resting > 1e-9) continue;
        p.resting = 0;
      }
      p.along += p.direction * p.speed * deltaTime / length;
      if (p.along >= 1 || p.along <= 0) {
        p.along = p.along.clamp(0.0, 1.0);
        p.direction = -p.direction;
        p.resting = p.wait;
      }
      t.position.setValues(
        start.x + p.travel.x * p.along,
        start.y + p.travel.y * p.along,
        start.z + p.travel.z * p.along,
      );
    }
  }
}

/// Checkpoints and falls: a player reaching a [Checkpoint3D] comes back
/// there; one falling past its controller's fall limit, or touching a
/// [KillZone3D], is put back at once.
class Respawn3DSystem extends System {
  @override
  int get priority => SystemPriorities.playerControl - 1;

  @override
  List<Type> get requiredComponents => const [TransformComponent, ThirdPersonController];

  final List<(Entity, Entity)> _sensed = [];
  EventSubscription? _subscription;

  @override
  void onAddedToWorld() {
    super.onAddedToWorld();
    _subscription = world.events.on<SensorEnter3DEvent>((e) {
      if (e.other.hasComponent<ThirdPersonController>() &&
          (e.sensor.hasComponent<Checkpoint3D>() || e.sensor.hasComponent<KillZone3D>())) {
        _sensed.add((e.sensor, e.other));
      }
    });
  }

  @override
  void onRemovedFromWorld() {
    _subscription?.cancel();
    _subscription = null;
    super.onRemovedFromWorld();
  }

  /// Players to put back this step; kept, so a step allocates nothing.
  final Set<Entity> _reset = {};

  @override
  void update(double deltaTime) {
    final reset = _reset..clear();
    for (final (sensor, player) in _sensed) {
      final controller = player.getComponent<ThirdPersonController>();
      if (controller == null || !player.isAlive) continue;
      final checkpoint = sensor.getComponent<Checkpoint3D>();
      if (checkpoint != null) {
        final best = _best[controller];
        if (best == null || checkpoint.order >= best) {
          _best[controller] = checkpoint.order;
          final at = sensor.getComponent<TransformComponent>()?.position;
          if (at != null) controller.spawnPoint = Vector3.copy(at);
          if (!checkpoint.reached) {
            checkpoint.reached = true;
            world.events.fire(CheckpointReached3DEvent(sensor, player));
          }
        }
      } else {
        reset.add(player);
      }
    }
    _sensed.clear();
    for (final player in entities) {
      final c = player.getComponent<ThirdPersonController>()!;
      final t = player.getComponent<TransformComponent>()!;
      final spawn = c.spawnPoint;
      if (spawn == null) continue;
      if (reset.contains(player) || t.position.y > spawn.y + c.fallLimit) respawn(player);
    }
  }

  /// The highest checkpoint order each hero has reached, kept by its
  /// controller: a play-test stopped (which puts back fresh components) or a
  /// level loaded starts from none, and nothing is kept for heroes gone.
  final Expando<int> _best = Expando('bestCheckpoint');

  /// Puts [player] back at its spawn point, still, and says so: on its feet,
  /// with nothing of the fall, jump or strike it was in carried over — no
  /// landing is told for the fall, and a jump pressed before is not taken.
  void respawn(Entity player) {
    final c = player.getComponent<ThirdPersonController>()!;
    final t = player.getComponent<TransformComponent>()!;
    final at = c.spawnPoint;
    if (at == null) return;
    // A write the physics reads as a teleport; no blending across it.
    t.position.setFrom(at);
    t.capturePrevious();
    c.planarVelocity.setZero();
    final character = player.getComponent<CharacterBody3D>();
    if (character != null) {
      character
        ..moveVelocity.setZero()
        ..velocity.setZero();
      // Stood up: the spawn point is where it stood before.
      final standing = c.standingHeight;
      if (standing != null) character.height = standing;
    }
    c
      ..standingHeight = null
      ..isCrouching = false
      ..isJumping = false
      ..windUp = null
      ..sincePressed = double.infinity
      ..airTime = 0
      ..fallSpeed = 0;
    final combat = player.getComponent<ThirdPersonCombat>();
    if (combat != null && combat.inCombat) {
      ThirdPersonCombatSystem._end(player, combat, guard: 0);
    }
    world.events.fire(Respawned3DEvent(player, Vector3.copy(at)));
  }
}
