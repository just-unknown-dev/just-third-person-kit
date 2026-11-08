import 'package:just_game_engine/just_game_engine.dart';

import '../camera/camera.dart';
import '../character/character.dart';
import '../level/level.dart';
import 'third_person_definitions.dart';
import 'third_person_migrations.dart';

/// The third-person kit's front door.
///
/// ```dart
/// final engine = Engine(config: EngineConfig(
///   extensions: [ThirdPersonKit.extension],
///   services: [Graphics3D(), Physics3D()],
/// ));
/// await engine.initialize();
/// ThirdPersonKit.registerSystems(engine.world, input: engine.input, camera: engine.camera.mainCamera);
/// ```
///
/// `Graphics3D` and `Physics3D` are in
/// `package:just_game_engine/just_game_engine_3d.dart`; the game's pubspec
/// builds Jolt (`hooks: user_defines: just_jolt: build: true`).
abstract final class ThirdPersonKit {
  /// Give it to the engine: the kit's components (saved, loaded, shown in
  /// the editor), the renames of its older levels and its animator
  /// bindings.
  static const ContextExtension extension = _ThirdPersonKitExtension();

  /// What [extension] does, for a context of your own.
  static void install(EngineContext context) {
    // Its levels use the engine's own components too.
    context.install(BuiltInComponents.extension);
    context.definitions.registerAll(ThirdPersonDefinitions.all, ifAbsent: true);
    ThirdPersonMigrations.install(context);
    registerAnimatorBindings(context.animatorBindings);
  }

  /// Animator parameters a third-person character's graph can read:
  /// `planarSpeed` (m/s along the ground), `grounded`, `jumping`,
  /// `falling` and `crouching`; with [ThirdPersonCombatComponent], `striking` and
  /// `inCombat` (striking, or keeping its guard after a strike).
  static void registerAnimatorBindings(AnimatorBindings bindings) {
    ThirdPersonControllerComponent? of(Entity e) =>
        e.getComponent<ThirdPersonControllerComponent>();
    bindings.register('planarSpeed', (e) => of(e)?.planarSpeed);
    bindings.register('grounded', (e) => of(e)?.isGrounded);
    bindings.register('jumping', (e) => of(e)?.isJumping);
    bindings.register('falling', (e) {
      final c = of(e);
      return c == null ? null : !c.isGrounded && !c.isJumping;
    });
    bindings.register('crouching', (e) => of(e)?.isCrouching);
    bindings.register(
      'striking',
      (e) => e.getComponent<ThirdPersonCombatComponent>()?.isStriking,
    );
    bindings.register(
      'inCombat',
      (e) => e.getComponent<ThirdPersonCombatComponent>()?.inCombat,
    );
  }

  /// The kit's systems, moving characters relative to [camera] and turning
  /// cameras with player [player]'s look actions (the shared ones when it
  /// has none).
  static List<System> systems({
    required InputService input,
    required OutputCamera camera,
    int player = 0,
  }) {
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
  static void registerSystems(
    World world, {
    required InputService input,
    required OutputCamera camera,
    int player = 0,
  }) {
    for (final system in systems(
      input: input,
      camera: camera,
      player: player,
    )) {
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
    context.definitions.refresh(ThirdPersonDefinitions.all);
    ThirdPersonKit.registerAnimatorBindings(context.animatorBindings);
  }
}
