// Checkpoints, kill zones and falls: where a player is put back, what
// height a fall puts it back from, and that nothing of the fall is carried
// over.
import 'package:flutter_test/flutter_test.dart';
import 'package:just_game_engine/just_game_engine.dart';
import 'package:just_game_engine/just_game_engine_3d.dart';
import 'package:just_third_person_kit/just_third_person_kit.dart';

const _dt = 1 / 60;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late World world;
  setUp(() {
    world = World()..initialize();
    addTearDown(world.dispose);
  });

  group('on its own', () {
    late Entity hero;
    late List<PlayerRespawn3DEvent> respawned;

    setUp(() {
      world.addSystem(Respawn3DSystem());
      hero = world.createEntityWithComponents([
        TransformComponent(position: Vector3(0, 0, 0)),
        ThirdPersonControllerComponent(fallLimit: 10)
          ..spawnPoint = Vector3.zero(),
        CharacterBody3DComponent(),
      ], name: 'Hero');
      respawned = [];
      world.events.on<PlayerRespawn3DEvent>(respawned.add);
    });

    Vector3 at() => hero.getComponent<TransformComponent>()!.position;

    test('falling past the limit puts it back, still', () {
      at().setValues(3, 12, 1);
      hero.getComponent<CharacterBody3DComponent>()!.velocity.setValues(
        0,
        20,
        0,
      );
      world.update(_dt);
      expect([at().x, at().y, at().z], [0, 0, 0]);
      expect(hero.getComponent<CharacterBody3DComponent>()!.velocity.y, 0);
      expect(respawned, hasLength(1));
    });

    test(
      'a checkpoint moves the spawn; an earlier one does not move it back; a kill zone sends it there',
      () {
        final first = world.createEntityWithComponents([
          TransformComponent(position: Vector3(5, 0, 0)),
          Checkpoint3DComponent(order: 1),
        ]);
        final second = world.createEntityWithComponents([
          TransformComponent(position: Vector3(9, 0, 0)),
          Checkpoint3DComponent(order: 2),
        ]);
        final pit = world.createEntityWithComponents([
          TransformComponent(),
          KillZone3DComponent(),
        ]);
        final reached = <CheckpointActivated3DEvent>[];
        world.events.on<CheckpointActivated3DEvent>(reached.add);
        world.events.fire(SensorEnter3DEvent(sensor: second, other: hero));
        world.update(_dt);
        world.events.fire(SensorEnter3DEvent(sensor: first, other: hero));
        world.update(_dt);
        expect(
          hero.getComponent<ThirdPersonControllerComponent>()!.spawnPoint!.x,
          9,
        );
        expect(reached.map((e) => e.checkpoint), [second]);
        at().setValues(20, 0, 0);
        world.events.fire(SensorEnter3DEvent(sensor: pit, other: hero));
        world.update(_dt);
        expect(at().x, 9);
        expect(respawned, hasLength(1));
      },
    );
  });

  group('the fall limit', () {
    late Entity hero;
    late ThirdPersonControllerComponent control;
    late List<PlayerRespawn3DEvent> respawned;

    setUp(() {
      world.addSystem(Respawn3DSystem());
      // The default fall limit, 40 m, from a start on the ground at y = 0.
      control = ThirdPersonControllerComponent()..spawnPoint = Vector3.zero();
      hero = world.createEntityWithComponents([
        TransformComponent(),
        control,
        CharacterBody3DComponent(),
      ], name: 'Hero');
      respawned = [];
      world.events.on<PlayerRespawn3DEvent>(respawned.add);
      world.update(_dt);
    });

    Vector3 at() => hero.getComponent<TransformComponent>()!.position;

    Entity reach(Vector3 where, {int order = 0}) {
      final checkpoint = world.createEntityWithComponents([
        TransformComponent(position: where),
        Checkpoint3DComponent(order: order),
      ]);
      world.events.fire(SensorEnter3DEvent(sensor: checkpoint, other: hero));
      world.update(_dt);
      return checkpoint;
    }

    test(
      'a checkpoint high above the ground does not make that ground deadly',
      () {
        // A tower 45 m up (up is -Y): more than the fall limit above the
        // ground the level starts on.
        reach(Vector3(0, -45, 10));
        expect(control.spawnPoint!.y, -45);
        // Down the ramp to the ground at its foot.
        at().setValues(0, 0, 20);
        for (var i = 0; i < 30; i++) {
          world.update(_dt);
        }
        expect(
          respawned,
          isEmpty,
          reason: 'the ground the level starts on is safe',
        );
        expect([at().x, at().y, at().z], [0, 0, 20]);

        // Off the edge of the world below it: back on the tower.
        at().setValues(0, 41, 20);
        world.update(_dt);
        expect(respawned.single.at.y, -45);
        expect(at().y, -45);
      },
    );

    test('a checkpoint lower down lowers the fall limit with it', () {
      reach(Vector3(0, 60, 0)); // 60 m down a shaft
      at().setValues(0, 62, 5);
      world.update(_dt);
      expect(
        respawned,
        isEmpty,
        reason: 'beside the checkpoint, 62 m below the start',
      );
      at().setValues(0, 101, 5);
      world.update(_dt);
      expect(respawned.single.at.y, 60);
    });

    test('it never rises: down to a low checkpoint, then up to a high one', () {
      reach(Vector3(0, 50, 0), order: 1);
      reach(Vector3(0, -45, 0), order: 2);
      expect(control.lowestSpawnY, 50);
      at().setValues(0, 80, 0);
      world.update(_dt);
      expect(
        respawned,
        isEmpty,
        reason: 'within the limit of the lowest checkpoint reached',
      );
      at().setValues(0, 91, 0);
      world.update(_dt);
      expect(
        respawned.single.at.y,
        -45,
        reason: 'put back at the last checkpoint',
      );
    });
  });

  group('with the controller', () {
    late Entity hero;
    late CharacterBody3DComponent body;
    late ThirdPersonControllerComponent control;
    late InputComponent input;
    late List<Landed3DEvent> landed;

    setUp(() {
      world
        ..addSystem(ThirdPersonControllerSystem(cameraYaw: () => 0))
        ..addSystem(Respawn3DSystem());
      body = CharacterBody3DComponent()..groundState = Ground3DState.onGround;
      control = ThirdPersonControllerComponent(fallLimit: 10);
      input = InputComponent();
      hero = world.createEntityWithComponents([
        TransformComponent(),
        body,
        control,
        input,
      ], name: 'Hero');
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
        ..groundState = Ground3DState.inAir
        ..velocity.setValues(0, 25, 0);
      step(frames: 3);
      expect(control.fallSpeed, 25);
      input.pressed.add('jump'); // pressed just as it fell out
      hero.getComponent<TransformComponent>()!.position.setValues(0, 12, 0);
      step();
      expect(
        hero.getComponent<TransformComponent>()!.position.y,
        0,
        reason: 'put back',
      );

      body.groundState = Ground3DState.onGround;
      step(frames: 3);
      expect(landed, isEmpty, reason: 'coming back is not a landing');
      expect(body.pendingJump, isNull);
      expect(control.isJumping, isFalse);
    });

    test('puts a crouched hero back on its feet', () {
      body
        ..height = 1.8
        ..heightOverride = control.crouchHeight;
      control
        ..spawnPoint = Vector3.zero()
        ..isCrouching = true;
      Respawn3DSystem respawns() =>
          world.systems.whereType<Respawn3DSystem>().single;
      respawns().respawn(hero);
      expect(body.effectiveHeight, 1.8);
      expect(body.heightOverride, isNull);
      expect(body.height, 1.8, reason: 'its saved height never changed');
      expect(control.isCrouching, isFalse);
    });

    test('puts a striking hero back out of its strike', () {
      final combat = ThirdPersonCombatComponent()
        ..strike = const Strike(name: 'jab', duration: 0.4, hit: 0.1)
        ..guardLeft = 1;
      hero.addComponent(combat);
      control.spawnPoint = Vector3.zero();
      world.systems.whereType<Respawn3DSystem>().single.respawn(hero);
      expect((combat.isStriking, combat.inCombat), (false, false));
    });

    test("checkpoint progress goes with the hero's controller", () {
      final first = world.createEntityWithComponents([
        TransformComponent(position: Vector3(5, 0, 0)),
        Checkpoint3DComponent(order: 1),
      ]);
      final second = world.createEntityWithComponents([
        TransformComponent(position: Vector3(9, 0, 0)),
        Checkpoint3DComponent(order: 2),
      ]);
      step();
      world.events.fire(SensorEnter3DEvent(sensor: second, other: hero));
      step();
      expect(control.spawnPoint!.x, 9);

      // A play-test stopped: the hero's components are put back fresh.
      final fresh = ThirdPersonControllerComponent(fallLimit: 10);
      hero.addComponent(fresh);
      step();
      world.events.fire(SensorEnter3DEvent(sensor: first, other: hero));
      step();
      expect(
        fresh.spawnPoint!.x,
        5,
        reason: 'the last play-test reached order 2; this one has not',
      );
    });
  });
}
