import 'dart:math' as math;
import 'dart:ui' show Offset;

import 'package:just_game_engine/just_game_engine.dart';
import 'package:just_game_engine/just_game_engine_3d.dart';

import 'character_3d_events.dart';
import 'third_person_combat_component.dart';
import 'third_person_controller_component.dart';

/// The way along the ground a camera with [yaw] faces, and its right.
(Vector3 forward, Vector3 right) groundAxesOf(double yaw) => (
  Vector3(math.sin(yaw), 0, math.cos(yaw)),
  Vector3(math.cos(yaw), 0, -math.sin(yaw)),
);

/// Moves [ThirdPersonControllerComponent] characters from their input, relative to
/// where the camera looks; before physics, so the step uses it. A crouch
/// lowers the character's body, and it stands only when the world's
/// [Physics3DSystem] finds nothing above it.
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
    CharacterBody3DComponent,
    ThirdPersonControllerComponent,
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
      final character = entity.getComponent<CharacterBody3DComponent>()!;
      final c = entity.getComponent<ThirdPersonControllerComponent>()!;
      final input = entity.getComponent<InputComponent>()!;
      c.spawnPoint ??= Vector3.copy(transform.position);
      // A strike holds it still: no moving, jumping or crouching till it
      // ends.
      final striking =
          entity.getComponent<ThirdPersonCombatComponent>()?.isStriking ??
          false;

      // Ground and air time.
      final wasGrounded = c.isGrounded;
      final height = character.effectiveHeight;
      c.isGrounded = character.isGrounded;
      if (c.isGrounded) {
        c.airTime = 0;
        if (c.windUp == null && character.velocity.y >= -0.01) {
          c.isJumping = false;
        }
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
      if (c.isGrounded &&
          !c.isJumping &&
          !striking &&
          input.isDown(c.crouchAction)) {
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
      final rate =
          (c.isGrounded ? c.acceleration : c.airAcceleration) * deltaTime;
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
        if (c.windUp! <= 1e-9 || !c.isGrounded) {
          _launch(entity, character, c, height);
        }
      } else if (c.sincePressed <= c.jumpBuffer && !c.isJumping && !striking) {
        if (c.isGrounded) {
          // A crouch stands up for it, if there is room. A wind-up starts
          // from ground it stood on the step before, so a jump taken as it
          // lands lets the landing be seen first.
          if (c.jumpDelay <= 0) {
            if (_standUp(entity, character, c)) {
              _launch(entity, character, c, height);
            }
          } else if (wasGrounded && _standUp(entity, character, c)) {
            c
              ..windUp = c.jumpDelay
              ..isJumping = true
              ..sincePressed = double.infinity;
          }
        } else if (c.airTime <= c.coyoteTime &&
            _standUp(entity, character, c)) {
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
  void _launch(
    Entity entity,
    CharacterBody3DComponent character,
    ThirdPersonControllerComponent c,
    double height,
  ) {
    if (character.isGrounded && character.effectiveHeight == height) {
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

  /// Lowers [c]'s [character] to its crouching height, through its
  /// `heightOverride`: its authored `height` is never written.
  static void _crouch(
    CharacterBody3DComponent character,
    ThirdPersonControllerComponent c,
  ) {
    if (c.crouchHeight < character.height) {
      character.heightOverride = c.crouchHeight;
    }
    c.isCrouching = true;
  }

  /// Stands [c]'s [character] up from a crouch, if there is room above it;
  /// whether it stands.
  bool _standUp(
    Entity entity,
    CharacterBody3DComponent character,
    ThirdPersonControllerComponent c,
  ) {
    if (!c.isCrouching) return true;
    if (character.heightOverride != null) {
      final rise = character.height - character.effectiveHeight;
      if (_blockedAbove(entity, character, rise)) return false;
      character.heightOverride = null;
    }
    c.isCrouching = false;
    return true;
  }

  /// Whether something is within [rise] metres above [entity]'s
  /// [character]'s head: a sphere a little thinner than it, swept up from
  /// its head. Nothing is, without 3-D physics.
  bool _blockedAbove(
    Entity entity,
    CharacterBody3DComponent character,
    double rise,
  ) {
    if (rise <= 0) return false;
    final queries = _queries();
    if (queries == null) return false;
    final feet = entity.getComponent<TransformComponent>()!.position;
    final radius = character.radius * 0.9;
    final head = _head
      ..setValues(
        feet.x,
        feet.y - (character.effectiveHeight - character.radius),
        feet.z,
      );
    final hit = queries.sphereCast(
      head,
      radius,
      _up,
      maxDistance: rise + character.radius - radius,
      ignore: entity,
    );
    return hit != null;
  }

  static final Vector3 _up = Vector3(0, -1, 0);
  static final Quaternion _turn = Quaternion.identity();
  static final Vector3 _head = Vector3.zero();
  Physics3DQueries? _physicsQueries;

  /// Queries on the world's 3-D physics, or null without it.
  Physics3DQueries? _queries() {
    final system = world.getSystem<Physics3DSystem>();
    if (system == null) return null;
    if (_physicsQueries?.system != system) {
      _physicsQueries = Physics3DQueries(system);
    }
    return _physicsQueries;
  }
}
