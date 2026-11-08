// What installing the kit gives a context: its components' definitions,
// the engine's built-in ones, its renames and its animator bindings; and
// the systems it hands a game.
import 'package:flutter_test/flutter_test.dart';
import 'package:just_game_engine/just_game_engine.dart';
import 'package:just_third_person_kit/just_third_person_kit.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the extension installs the components and the animator bindings', () {
    final context = EngineContext();
    ThirdPersonKit.extension.install(context);
    for (final c in [
      ThirdPersonControllerComponent(),
      ThirdPersonCombatComponent(),
      ThirdPersonCameraComponent(),
      Pickup3DComponent(),
      MovingPlatform3DComponent(),
      Checkpoint3DComponent(),
      KillZone3DComponent(),
    ]) {
      final d = context.definitions.definitionFor(c);
      expect(d, isNotNull, reason: '${c.runtimeType}');
      expect(d!.hints.dimensions, Dimensions.threeD);
    }
    expect(
      context.definitions.definitionByType('TransformComponent'),
      isNotNull,
      reason: "the engine's own, which its levels use",
    );
    final w = World(context: context)..initialize();
    addTearDown(w.dispose);
    final control = ThirdPersonControllerComponent()
      ..planarVelocity.setValues(3, 0, 4);
    final hero = w.createEntityWithComponents([control]);
    expect(context.animatorBindings.of('planarSpeed')!(hero), 5);
    expect(context.animatorBindings.of('grounded')!(hero), isFalse);
    expect(context.animatorBindings.of('crouching')!(hero), isFalse);
    control.isCrouching = true;
    expect(context.animatorBindings.of('crouching')!(hero), isTrue);
    expect(
      context.animatorBindings.of('striking')!(hero),
      isNull,
      reason: 'no combat',
    );

    final combat = ThirdPersonCombatComponent();
    final fighter = w.createEntityWithComponents([
      ThirdPersonControllerComponent(),
      combat,
    ]);
    expect(context.animatorBindings.of('striking')!(fighter), isFalse);
    expect(context.animatorBindings.of('inCombat')!(fighter), isFalse);
    combat.guardLeft = 1;
    expect(context.animatorBindings.of('inCombat')!(fighter), isTrue);
    combat.strike = const Strike(name: 'jab', duration: 0.4, hit: 0.1);
    expect(context.animatorBindings.of('striking')!(fighter), isTrue);
  });

  test('the extension installs the renames of older levels', () {
    final context = EngineContext(extensions: [ThirdPersonKit.extension]);
    expect(ThirdPersonMigrations.renamedTypes, isNotEmpty);
    for (final MapEntry(:key, :value)
        in ThirdPersonMigrations.renamedTypes.entries) {
      expect(context.migrations.renamedTypes[key], value, reason: key);
    }
  });

  test(
    'the systems: combat before the controller, the camera once per frame',
    () {
      final input = InputService();
      addTearDown(input.dispose);
      final systems = ThirdPersonKit.systems(
        input: input,
        camera: OutputCamera(position: Offset.zero, zoom: 1),
      );
      expect(systems.map((s) => s.runtimeType), [
        Respawn3DSystem,
        ThirdPersonCombatSystem,
        ThirdPersonControllerSystem,
        MovingPlatform3DSystem,
        Pickup3DSystem,
        ThirdPersonCameraSystem,
      ]);
      // Higher runs earlier: a striking hero is held still the same step.
      final combat = systems.whereType<ThirdPersonCombatSystem>().single;
      final controller = systems
          .whereType<ThirdPersonControllerSystem>()
          .single;
      expect(combat.priority, greaterThan(controller.priority));
      expect(
        systems.whereType<PerFrame>().single,
        isA<ThirdPersonCameraSystem>(),
      );
    },
  );
}
