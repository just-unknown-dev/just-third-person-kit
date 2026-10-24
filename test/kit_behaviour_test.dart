// What the kit promises beyond one move at a time: a coin left as placed
// while an editor authors (time held at 0) and spun from the way it was
// placed; a respawn that carries nothing of the fall over; checkpoint
// progress that goes with the hero's controller; a camera system that owns
// its look reader and turns the view before the brain frames it; floors on
// the components' numbers; a combo set with a wrong value said plainly; and
// level aids that read the scene's own gravity.

import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:just_game_engine/just_game_engine.dart';
import 'package:just_game_engine/physics_3d.dart';
import 'package:just_third_person_kit/editor.dart';
import 'package:just_third_person_kit/just_third_person_kit.dart';

const _dt = 1 / 60;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late World world;
  setUp(() {
    world = World()..initialize();
    addTearDown(world.dispose);
  });

  group('a pickup', () {
    setUp(() => world.addSystem(Pickup3DSystem()));

    test('stays where it is moved, and as it is turned, while time stands still', () {
      final coin = world.createEntityWithComponents([
        TransformComponent(position: Vector3(0, -1, 3)),
        Pickup3D(),
      ]);
      final t = coin.getComponent<TransformComponent>()!;
      world.update(0);
      // The designer drags and turns it.
      t
        ..setPositionXYZ(5, -1, 3)
        ..setEuler(0, 0.7, 0);
      for (var i = 0; i < 5; i++) {
        world.update(0);
      }
      expect([t.position.x, t.position.y, t.position.z], [5, -1, 3]);
      expect(t.eulerY, closeTo(0.7, 1e-9));
    });

    test('spins from the way it was placed', () {
      final coin = world.createEntityWithComponents([
        TransformComponent(position: Vector3(0, -1, 3))..setEuler(0, 0.5, 0),
        Pickup3D(spinSpeed: 2),
      ]);
      world.update(0.25);
      expect(coin.getComponent<TransformComponent>()!.eulerY, closeTo(0.5 + 0.5, 1e-6));
    });
  });

  group('a respawn', () {
    late Entity hero;
    late CharacterBody3D body;
    late ThirdPersonController control;
    late InputComponent input;
    late List<Landed3DEvent> landed;

    setUp(() {
      world
        ..addSystem(ThirdPersonControllerSystem(cameraYaw: () => 0))
        ..addSystem(Respawn3DSystem());
      body = CharacterBody3D()..groundState = GroundState3D.onGround;
      control = ThirdPersonController(fallLimit: 10);
      input = InputComponent();
      hero = world.createEntityWithComponents([TransformComponent(), body, control, input], name: 'Hero');
      landed = [];
      world.events.on<Landed3DEvent>(landed.add);
    });

    void step({int frames = 1}) {
      for (var i = 0; i < frames; i++) {
        world.update(_dt);
        input.pressed.clear();
      }
    }

    test('after a fall, tells no landing and takes no jump pressed before', () {
      step(); // its spawn point: where it starts
      body
        ..groundState = GroundState3D.inAir
        ..velocity.setValues(0, 25, 0);
      step(frames: 3);
      expect(control.fallSpeed, 25);
      input.pressed.add('jump'); // pressed just as it fell out
      hero.getComponent<TransformComponent>()!.position.setValues(0, 12, 0);
      step();
      expect(hero.getComponent<TransformComponent>()!.position.y, 0, reason: 'put back');

      body.groundState = GroundState3D.onGround;
      step(frames: 3);
      expect(landed, isEmpty, reason: 'coming back is not a landing');
      expect(body.pendingJump, isNull);
      expect(control.isJumping, isFalse);
    });

    test('puts a crouched hero back on its feet', () {
      body.height = 1.8;
      control
        ..spawnPoint = Vector3.zero()
        ..isCrouching = true
        ..standingHeight = 1.8;
      body.height = control.crouchHeight;
      Respawn3DSystem respawns() => world.systems.whereType<Respawn3DSystem>().single;
      respawns().respawn(hero);
      expect(body.height, 1.8);
      expect(control.isCrouching, isFalse);
    });

    test("checkpoint progress goes with the hero's controller", () {
      final first = world.createEntityWithComponents([TransformComponent(position: Vector3(5, 0, 0)), Checkpoint3D(order: 1)]);
      final second = world.createEntityWithComponents([TransformComponent(position: Vector3(9, 0, 0)), Checkpoint3D(order: 2)]);
      step();
      world.events.fire(SensorEnter3DEvent(sensor: second, other: hero));
      step();
      expect(control.spawnPoint!.x, 9);

      // A play-test stopped: the hero's components are put back fresh.
      final fresh = ThirdPersonController(fallLimit: 10);
      hero.addComponent(fresh);
      step();
      world.events.fire(SensorEnter3DEvent(sensor: first, other: hero));
      step();
      expect(fresh.spawnPoint!.x, 5, reason: 'the last play-test reached order 2; this one has not');
    });
  });

  group('the camera system', () {
    test('makes its look reader when it joins a world and lets it go when it leaves', () {
      final input = InputService();
      final systems = ThirdPersonKit.systems(input: input, camera: Camera(position: Offset.zero, zoom: 1));
      final camera = systems.whereType<ThirdPersonCameraSystem>().single;
      expect(camera.look, isNull, reason: 'a list made only to look at listens to nothing');

      world.addSystem(camera);
      expect(camera.look, isNotNull);
      world.removeSystem(camera);
      expect(camera.look, isNull);
    });

    test('turns the view before the camera brain frames it', () {
      final camera = ThirdPersonCameraSystem(actions: InputService().actions);
      expect(camera.priority, greaterThan(SystemPriorities.camera));
    });
  });

  test('numbers have floors: a negative turn speed loads as none', () {
    final context = EngineContext(extensions: [ThirdPersonKit.extension]);
    final controller = context.definitions.decode({
      'type': 'ThirdPersonController',
      'fields': {'turnSpeed': -5, 'walkSpeed': -1, 'facingOffset': -math.pi},
    }) as ThirdPersonController;
    expect(controller.turnSpeed, 0);
    expect(controller.walkSpeed, 0);
    expect(controller.facingOffset, -math.pi, reason: 'an angle may be negative');
  });

  test('a combo set with a value of the wrong type is a FormatException naming it', () {
    expect(
      () => ComboSet.parse('{"strikes": {"jab": {"duration": "0.5"}}}'),
      throwsA(isA<FormatException>().having((e) => e.message, 'message', contains('jab'))),
    );
  });

  test('the level aids measure as the game does', () {
    expect(ThirdPersonAids.gravityOf(world), ThirdPersonAids.gravity, reason: 'no 3-D physics yet');
    final controller = ThirdPersonController(fallLimit: 10)..spawnPoint = Vector3(0, -4, 0);
    world.createEntityWithComponents([TransformComponent(position: Vector3(0, -2, 0)), controller]);
    expect(const ThirdPersonAids().killHeight(world), 6, reason: 'from where it is put back');
  });
}
