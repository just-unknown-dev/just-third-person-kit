import 'dart:math' as math;

import 'package:just_editor_core/just_editor_core.dart';
import 'package:just_game_engine/just_game_engine.dart';
import 'package:just_game_engine/just_game_engine_3d.dart';

import '../character/character.dart';

/// What the third-person kit knows of how its levels are played: its
/// hero's jump (from its [ThirdPersonControllerComponent] and [CharacterBody3DComponent], or
/// the Player prefab's when the level has no hero yet), the height its
/// fall limit puts back at, and playing from a point.
final class ThirdPersonAids extends LevelAids {
  /// The kit's aids; they read the level they are asked about.
  const ThirdPersonAids();

  /// Gravity, as the 3-D physics has it by default (m/s²): what the aids
  /// use while the world has no 3-D physics of its own yet.
  static const double gravity = 9.81;

  /// How hard [world]'s 3-D physics pulls down (m/s²): its own gravity once
  /// it has a physics world, [gravity] before.
  static double gravityOf(World world) {
    final system = world.getSystem<Physics3DSystem>();
    if (system == null || !system.hasWorld) return gravity;
    final g = system.physics.gravity;
    // +Y is down.
    return g.y > 0 ? g.y : g.length;
  }

  /// The level's hero: the entity with a [ThirdPersonControllerComponent].
  static Entity? heroOf(World world) {
    for (final e in world.entities) {
      if (e.isAlive && e.hasComponent<ThirdPersonControllerComponent>()) {
        return e;
      }
    }
    return null;
  }

  @override
  MovementProfile movementOf(World world) {
    final hero = heroOf(world);
    final controller =
        hero?.getComponent<ThirdPersonControllerComponent>() ??
        ThirdPersonControllerComponent();
    final body =
        hero?.getComponent<CharacterBody3DComponent>() ??
        CharacterBody3DComponent();
    return MovementProfile(
      jumpSpeed: controller.jumpSpeed,
      gravity: gravityOf(world) * (body.useGravity ? body.gravityScale : 0),
      runSpeed: controller.sprintSpeed,
      maxSlopeDegrees: body.maxSlopeAngle * 180 / math.pi,
      stepHeight: body.stepHeight,
    );
  }

  @override
  double? killHeight(World world) {
    final hero = heroOf(world);
    final controller = hero?.getComponent<ThirdPersonControllerComponent>();
    if (controller == null) return null;
    // Measured as `Respawn3DSystem` measures it: in play, from the lowest
    // spawn point the hero has had (ThirdPersonControllerComponent
    // .killHeight); before, from the level's player spawn point, where a
    // spawner would put it, else from where the hero stands.
    final inPlay = controller.killHeight;
    if (inPlay != null) return inPlay;
    final at = (SpawnPoints.of(world, 'player').firstOrNull ?? hero)
        ?.getComponent<TransformComponent>()
        ?.position;
    return at == null ? null : at.y + controller.fallLimit;
  }

  @override
  bool playFrom(World world, Vector3 at) {
    final hero = heroOf(world);
    final t = hero?.getComponent<TransformComponent>();
    if (t == null) return false;
    t.position.setFrom(at);
    world.transformHierarchy.propagateFrom(hero!);
    return true;
  }
}
