import 'dart:math' as math;

import 'package:just_game_engine/just_game_engine.dart';
import 'package:just_game_engine/just_game_engine_3d.dart';

import '../character/character.dart';
import 'checkpoint_3d_component.dart';
import 'kill_zone_3d_component.dart';
import 'level_3d_events.dart';

/// Checkpoints and falls: a player reaching a [Checkpoint3DComponent] comes back
/// there; one falling past its controller's fall limit, or touching a
/// [KillZone3DComponent], is put back at once.
///
/// The fall limit is measured from the lowest spawn point the player has
/// had ([ThirdPersonControllerComponent.killHeight]), not from the last
/// checkpoint: a checkpoint high above the ground never makes that ground
/// deadly.
class Respawn3DSystem extends System {
  @override
  int get priority => SystemPriorities.playerControl - 1;

  @override
  List<Type> get requiredComponents => const [
    TransformComponent,
    ThirdPersonControllerComponent,
  ];

  final List<(Entity, Entity)> _sensed = [];
  EventSubscription? _subscription;

  @override
  void onAddedToWorld() {
    super.onAddedToWorld();
    _subscription = world.events.on<SensorEnter3DEvent>((e) {
      if (e.other.hasComponent<ThirdPersonControllerComponent>() &&
          (e.sensor.hasComponent<Checkpoint3DComponent>() ||
              e.sensor.hasComponent<KillZone3DComponent>())) {
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
      final controller = player.getComponent<ThirdPersonControllerComponent>();
      if (controller == null || !player.isAlive) continue;
      final checkpoint = sensor.getComponent<Checkpoint3DComponent>();
      if (checkpoint != null) {
        final best = _best[controller];
        if (best == null || checkpoint.order >= best) {
          _best[controller] = checkpoint.order;
          final at = sensor.getComponent<TransformComponent>()?.position;
          if (at != null) controller.spawnPoint = Vector3.copy(at);
          if (!checkpoint.reached) {
            checkpoint.reached = true;
            world.events.fire(CheckpointActivated3DEvent(sensor, player));
          }
        }
      } else {
        reset.add(player);
      }
    }
    _sensed.clear();
    for (final player in entities) {
      final c = player.getComponent<ThirdPersonControllerComponent>()!;
      final t = player.getComponent<TransformComponent>()!;
      final spawn = c.spawnPoint;
      if (spawn == null) continue;
      // The lowest spawn point so far (+Y is down): it never rises with a
      // checkpoint, so ground below a high checkpoint stays safe.
      c.lowestSpawnY = math.max(c.lowestSpawnY ?? spawn.y, spawn.y);
      if (reset.contains(player) || t.position.y > c.killHeight!) {
        respawn(player);
      }
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
    final c = player.getComponent<ThirdPersonControllerComponent>()!;
    final t = player.getComponent<TransformComponent>()!;
    final at = c.spawnPoint;
    if (at == null) return;
    // A write the physics reads as a teleport; no blending across it.
    t.position.setFrom(at);
    t.capturePrevious();
    c.planarVelocity.setZero();
    final character = player.getComponent<CharacterBody3DComponent>();
    if (character != null) {
      character
        ..moveVelocity.setZero()
        ..velocity.setZero();
      // Stood up: the spawn point is where it stood before.
      if (c.isCrouching) character.heightOverride = null;
    }
    c
      ..isCrouching = false
      ..isJumping = false
      ..windUp = null
      ..sincePressed = double.infinity
      ..airTime = 0
      ..fallSpeed = 0;
    final combat = player.getComponent<ThirdPersonCombatComponent>();
    if (combat != null && combat.inCombat) {
      ThirdPersonCombatSystem.endStrike(player, combat, guard: 0);
    }
    world.events.fire(PlayerRespawn3DEvent(player, Vector3.copy(at)));
  }
}
