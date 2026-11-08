// What the kit tells the editor of how its levels are played: the hero's
// jump, the height a fall puts it back from (measured as the game measures
// it), the scene's own gravity, and playing from a point.
import 'package:flutter_test/flutter_test.dart';
import 'package:just_game_engine/just_game_engine.dart';
import 'package:just_game_engine/just_game_engine_3d.dart';
import 'package:just_third_person_kit/editor.dart';
import 'package:just_third_person_kit/just_third_person_kit.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late World world;
  setUp(() {
    world = World()..initialize();
    addTearDown(world.dispose);
  });

  test(
    "the hero's jump, from its controller and body (the prefab's with no hero)",
    () {
      const aids = ThirdPersonAids();
      final none = aids.movementOf(world);
      expect(none.jumpSpeed, ThirdPersonControllerComponent().jumpSpeed);
      final hero = world.createEntityWithComponents([
        TransformComponent(),
        ThirdPersonControllerComponent(jumpSpeed: 9.81, sprintSpeed: 5),
        CharacterBody3DComponent(),
      ], name: 'Player');
      final move = aids.movementOf(world);
      expect(move.jumpHeight, closeTo(4.905, 1e-6));
      expect(move.jumpDistance, closeTo(10, 1e-6));

      // Put back once it falls past its fall limit below where it starts.
      world.createEntityWithComponents([
        TransformComponent(position: Vector3(0, -2, 0)),
        SpawnComponent(),
      ], name: 'Spawn');
      expect(
        aids.killHeight(world),
        closeTo(
          -2 + hero.getComponent<ThirdPersonControllerComponent>()!.fallLimit,
          1e-9,
        ),
      );

      expect(aids.playFrom(world, Vector3(7, -1, 3)), isTrue);
      expect(hero.getComponent<TransformComponent>()!.position.x, 7);
    },
  );

  test('the level aids measure as the game does', () {
    expect(
      ThirdPersonAids.gravityOf(world),
      ThirdPersonAids.gravity,
      reason: 'no 3-D physics yet',
    );
    final controller = ThirdPersonControllerComponent(fallLimit: 10)
      ..spawnPoint = Vector3(0, -4, 0);
    world.createEntityWithComponents([
      TransformComponent(position: Vector3(0, -2, 0)),
      controller,
    ]);
    expect(
      const ThirdPersonAids().killHeight(world),
      6,
      reason: 'from where it is put back',
    );
  });

  test(
    'in play, the kill height is measured from the lowest spawn point, as a respawn measures it',
    () {
      world.addSystem(Respawn3DSystem());
      final controller = ThirdPersonControllerComponent(fallLimit: 10)
        ..spawnPoint = Vector3.zero();
      world.createEntityWithComponents([
        TransformComponent(),
        controller,
      ], name: 'Hero');
      world.update(1 / 60);
      controller.spawnPoint = Vector3(0, -45, 0); // a checkpoint high up
      world.update(1 / 60);
      expect(
        const ThirdPersonAids().killHeight(world),
        10,
        reason: 'not -35: the ground stays safe',
      );
    },
  );
}
