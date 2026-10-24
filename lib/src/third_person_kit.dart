import 'package:just_game_engine/just_game_engine.dart';

import 'third_person_components.dart';
import 'third_person_schemas.dart';
import 'third_person_systems.dart';

/// The third-person kit's front door.
///
/// ```dart
/// final engine = Engine(config: EngineConfig(
///   extensions: [ThirdPersonKit.extension],
///   graphics3D: Graphics3D(),
///   physics3D: Physics3D(),
/// ));
/// await engine.initialize();
/// ThirdPersonKit.registerSystems(engine.world, input: engine.input, camera: engine.cameraSystem.mainCamera);
/// ```
abstract final class ThirdPersonKit {
  /// Give it to the engine: the kit's components (saved, loaded, shown in
  /// the editor) and its animator bindings.
  static const ContextExtension extension = _ThirdPersonKitExtension();

  /// What [extension] does, for a context of your own.
  static void install(EngineContext context) {
    context.definitions.registerAll(ThirdPersonSchemas.all, ifAbsent: true);
    registerAnimatorBindings(context.animatorBindings);
  }

  /// Animator parameters a third-person character's graph can read:
  /// `planarSpeed` (m/s along the ground), `grounded`, `jumping`,
  /// `falling` and `crouching`; with [ThirdPersonCombat], `striking` and
  /// `inCombat` (striking, or keeping its guard after a strike).
  static void registerAnimatorBindings(AnimatorBindings bindings) {
    ThirdPersonController? of(Entity e) => e.getComponent<ThirdPersonController>();
    bindings.register('planarSpeed', (e) => of(e)?.planarSpeed);
    bindings.register('grounded', (e) => of(e)?.isGrounded);
    bindings.register('jumping', (e) => of(e)?.isJumping);
    bindings.register('falling', (e) {
      final c = of(e);
      return c == null ? null : !c.isGrounded && !c.isJumping;
    });
    bindings.register('crouching', (e) => of(e)?.isCrouching);
    bindings.register('striking', (e) => e.getComponent<ThirdPersonCombat>()?.isStriking);
    bindings.register('inCombat', (e) => e.getComponent<ThirdPersonCombat>()?.inCombat);
  }

  /// The kit's systems, moving characters relative to [camera] and turning
  /// cameras with player [player]'s look actions (the shared ones when it
  /// has none).
  static List<System> systems({required InputService input, required Camera camera, int player = 0}) {
    final actions = input.actionsFor(player) ?? input.actions;
    return [
      Respawn3DSystem(),
      ThirdPersonCombatSystem(),
      ThirdPersonControllerSystem(cameraYaw: () => camera.yaw),
      MovingPlatform3DSystem(),
      Pickup3DSystem(),
      // Its look reader is made as it joins the world: a list made only to
      // see what is missing (after a hot reload) leaves nothing listening.
      ThirdPersonCameraSystem(actions: actions),
    ];
  }

  /// Adds [systems] to [world].
  static void registerSystems(World world, {required InputService input, required Camera camera, int player = 0}) {
    for (final system in systems(input: input, camera: camera, player: player)) {
      world.addSystem(system);
    }
  }
}

final class _ThirdPersonKitExtension implements RefreshableExtension {
  const _ThirdPersonKitExtension();

  @override
  String get id => 'just_third_person_kit';

  @override
  void install(EngineContext context) => ThirdPersonKit.install(context);

  @override
  void refresh(EngineContext context) {
    context.definitions.refresh(ThirdPersonSchemas.all);
    ThirdPersonKit.registerAnimatorBindings(context.animatorBindings);
  }
}
