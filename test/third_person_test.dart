// The kit's gameplay, one system at a time, with the character's ground
// state set by hand: camera-relative movement, turning, jumps with coyote
// time, a buffer and a wind-up, crouching (its body lowered), punch and kick
// chains, the camera's look, pickups, platforms, checkpoints and respawns,
// and what the extension installs.
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:just_game_engine/just_game_engine.dart';
import 'package:just_game_engine/physics_3d.dart';
import 'package:just_third_person_kit/just_third_person_kit.dart';

const _dt = 1 / 60;

// Two punches that chain and a kick: shorter than JustHumanoid's, in the
// same shape.
const _combos = ComboSet(
  guard: 'combat_idle',
  chains: {
    'punch_combo': ['punch_1', 'punch_2'],
    'kick_combo': ['kick_1'],
  },
  strikes: {
    'punch_1': Strike(name: 'punch_1', duration: 0.5, hit: 0.1, comboWindow: (open: 0.2, close: 0.4), next: 'punch_2'),
    'punch_2': Strike(name: 'punch_2', duration: 0.6, hit: 0.2),
    'kick_1': Strike(name: 'kick_1', duration: 0.6, hit: 0.3),
  },
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late World world;
  setUp(() {
    world = World()..initialize();
    addTearDown(world.dispose);
  });

  group('the controller', () {
    late Entity hero;
    late CharacterBody3D body;
    late ThirdPersonController control;
    late InputComponent input;
    var yaw = 0.0;

    setUp(() {
      yaw = 0;
      world.addSystem(ThirdPersonControllerSystem(cameraYaw: () => yaw));
      body = CharacterBody3D()..groundState = GroundState3D.onGround;
      control = ThirdPersonController();
      input = InputComponent();
      hero = world.createEntityWithComponents([TransformComponent(), body, control, input], name: 'Hero');
    });

    void step({int frames = 1}) {
      for (var i = 0; i < frames; i++) {
        world.update(_dt);
        input.pressed.clear();
      }
    }

    test('forward on the stick runs where the camera looks, up to walking speed', () {
      input.setVector('move', const Offset(0, -1));
      step();
      expect(body.moveVelocity.z, closeTo(control.acceleration * _dt, 1e-9), reason: 'accelerating');
      step(frames: 60);
      expect(body.moveVelocity.z, closeTo(control.walkSpeed, 1e-9));
      expect(body.moveVelocity.x, closeTo(0, 1e-9));
      expect(control.planarSpeed, closeTo(control.walkSpeed, 1e-9));
    });

    test('turned a quarter, the camera makes forward +X; sprint is faster', () {
      yaw = math.pi / 2;
      input
        ..setVector('move', const Offset(0, -1))
        ..setDown('sprint', true);
      step(frames: 60);
      expect(body.moveVelocity.x, closeTo(control.sprintSpeed, 1e-6));
      expect(body.moveVelocity.z, closeTo(0, 1e-6));
    });

    test('it turns to face the way it runs, a glTF character turned round', () {
      input.setVector('move', const Offset(1, 0)); // right: +X with yaw 0
      step(frames: 120);
      expect(control.facing, closeTo(math.pi / 2, 1e-6));
      final q = Quaternion.identity();
      hero.getComponent<TransformComponent>()!.rotationInto(q);
      final front = Vector3(0, 0, -1); // a glTF character's front, in engine axes
      q.rotate(front);
      expect(front.x, closeTo(1, 1e-6), reason: 'its front faces +X');
    });

    test('a jump on the ground goes to the character; one per press', () {
      input.pressed.add('jump');
      step();
      expect(body.pendingJump, control.jumpSpeed);
      expect(control.isJumping, isTrue);
      body.pendingJump = null;
      step();
      expect(body.pendingJump, isNull);
    });

    test('just off an edge, a jump still works (coyote time); later it does not', () {
      step();
      body.groundState = GroundState3D.inAir;
      step(frames: 3); // 0.05 s
      input.pressed.add('jump');
      step();
      expect(body.velocity.y, -control.jumpSpeed, reason: 'up is -Y');

      // Again, but too late.
      control.isJumping = false;
      body.velocity.setZero();
      body.groundState = GroundState3D.onGround;
      step();
      body.groundState = GroundState3D.inAir;
      step(frames: 20); // 0.33 s
      input.pressed.add('jump');
      step();
      expect(body.velocity.y, 0);
      expect(body.pendingJump, isNull);
    });

    test('a jump and a landing are told, with how fast it fell', () {
      final jumped = <Entity>[];
      final landed = <(Entity, double)>[];
      world.events
        ..on<Jumped3DEvent>((e) => jumped.add(e.player))
        ..on<Landed3DEvent>((e) => landed.add((e.player, e.fallSpeed)));
      step(frames: 3);
      expect(landed, isEmpty, reason: 'standing where it starts is no landing');

      input.pressed.add('jump');
      step();
      expect(jumped, [hero]);
      body.groundState = GroundState3D.inAir;
      body.velocity.y = -6; // rising (up is -Y)
      step(frames: 5);
      body.velocity.y = 7.5; // and falling
      step(frames: 2);
      body.velocity.y = 3;
      step();
      expect(landed, isEmpty, reason: 'still in the air');
      body.groundState = GroundState3D.onGround;
      step();
      expect(landed, [(hero, 7.5)], reason: 'the fastest it fell');
      step(frames: 3);
      expect(landed, hasLength(1));
    });

    test('a jump pressed just before landing happens on landing (buffer)', () {
      body.groundState = GroundState3D.inAir;
      step(frames: 30);
      input.pressed.add('jump');
      step(frames: 3);
      expect(body.pendingJump, isNull, reason: 'still in the air');
      body.groundState = GroundState3D.onGround;
      step();
      expect(body.pendingJump, control.jumpSpeed);
    });

    test('crouch held on the ground slows it to crouching speed, sprint or not; let go, it stands', () {
      input
        ..setVector('move', const Offset(0, -1))
        ..setDown('sprint', true)
        ..setDown('crouch', true);
      step(frames: 60);
      expect(control.isCrouching, isTrue);
      expect(control.planarSpeed, closeTo(control.crouchSpeed, 1e-9));
      input.setDown('crouch', false);
      step();
      expect(control.isCrouching, isFalse);
      step(frames: 60);
      expect(control.planarSpeed, closeTo(control.sprintSpeed, 1e-9));
    });

    test('a jump stands it up; in the air it does not crouch, and it lands crouched', () {
      input.setDown('crouch', true);
      step();
      expect(control.isCrouching, isTrue);
      input.pressed.add('jump');
      step();
      expect(control.isJumping, isTrue, reason: 'it jumps from a crouch');
      expect(control.isCrouching, isFalse);
      expect(body.height, 1.8, reason: 'stood up');
      // Its body is made again at its new height, and takes that first step
      // as in the air: the jump goes as its speed, not to the ground.
      expect(body.velocity.y, -control.jumpSpeed);
      expect(body.pendingJump, isNull);
      body.groundState = GroundState3D.inAir;
      step(frames: 10);
      expect(control.isCrouching, isFalse);
      body.groundState = GroundState3D.onGround;
      body.velocity.setZero();
      step();
      expect(control.isCrouching, isTrue, reason: 'crouch still held');
    });

    test('crouching lowers its body to the crouching height; standing gives its height back', () {
      input.setDown('crouch', true);
      step();
      expect(body.height, control.crouchHeight);
      expect(control.standingHeight, 1.8);
      step(frames: 5);
      expect(body.height, control.crouchHeight);
      input.setDown('crouch', false);
      step();
      expect(control.isCrouching, isFalse, reason: 'nothing above it (no physics to find any)');
      expect(body.height, 1.8);
      expect(control.standingHeight, isNull);

      // A body no taller than its crouch keeps its height.
      body.height = 1.2;
      input.setDown('crouch', true);
      step();
      expect(control.isCrouching, isTrue);
      expect(body.height, 1.2);
      input.setDown('crouch', false);
      step();
      expect(body.height, 1.2);
    });

    test('with a wind-up, the jump leaves the ground its delay after the press, and is told then', () {
      control.jumpDelay = 0.2;
      final jumped = <Entity>[];
      world.events.on<Jumped3DEvent>((e) => jumped.add(e.player));
      step();
      input.pressed.add('jump');
      step();
      expect(control.isJumping, isTrue, reason: 'winding up');
      expect(control.windUp, 0.2);
      step(frames: 11);
      expect(body.pendingJump, isNull, reason: 'still winding up, 11 steps on');
      expect(control.isJumping, isTrue, reason: 'on the ground, and jumping');
      expect(jumped, isEmpty);
      step();
      expect(body.pendingJump, control.jumpSpeed, reason: '0.2 s on');
      expect(control.windUp, isNull);
      expect(jumped, [hero]);
    });

    test('off the ground in the wind-up it springs at once; a jump taken landing winds up a step on; a coyote jump has none', () {
      control.jumpDelay = 0.2;
      step();
      input.pressed.add('jump');
      step(frames: 3);
      body.groundState = GroundState3D.inAir;
      step();
      expect(body.velocity.y, -control.jumpSpeed, reason: 'the ground went from under it');
      expect(control.windUp, isNull);

      // Pressed just before landing: the landing is seen first.
      body.velocity.setZero();
      step(frames: 30);
      input.pressed.add('jump');
      step(frames: 3);
      body.groundState = GroundState3D.onGround;
      step();
      expect(control.isJumping, isFalse, reason: 'landed');
      expect(control.windUp, isNull);
      step();
      expect(control.windUp, 0.2, reason: 'a step later');
      expect(control.isJumping, isTrue);

      // Just off an edge there is no ground to wind up on.
      control
        ..isJumping = false
        ..windUp = null;
      step();
      body.groundState = GroundState3D.inAir;
      step(frames: 3);
      input.pressed.add('jump');
      step();
      expect(body.velocity.y, -control.jumpSpeed);
      expect(control.windUp, isNull);
    });

    test('a controller with no crouch action never crouches', () {
      control.crouchAction = 'duck';
      input.setDown('crouch', true);
      step();
      expect(control.isCrouching, isFalse);
    });
  });

  test("the camera's look turns the orbit; down looks down, clamped", () {
    final orbit = OrbitFollowComponent(yaw: 0, pitch: -0.3, minPitch: -1, maxPitch: 0.5);
    final camera = ThirdPersonCamera(sensitivity: 2);
    ThirdPersonCameraSystem.applyLook(orbit, camera, const Offset(0.1, 0.05));
    expect(orbit.yaw, closeTo(0.2, 1e-9));
    expect(orbit.pitch, closeTo(-0.4, 1e-9));
    ThirdPersonCameraSystem.applyLook(orbit, camera..invertY = true, const Offset(0, 0.05));
    expect(orbit.pitch, closeTo(-0.3, 1e-9));
    ThirdPersonCameraSystem.applyLook(orbit, camera..invertY = false, const Offset(0, 10));
    expect(orbit.pitch, -1);
  });

  test('a pickup touched by a player is taken, counted and gone; it bobs till then', () {
    world.addSystem(Pickup3DSystem());
    final player = world.createEntityWithComponents([TransformComponent(), ThirdPersonController()], name: 'Hero');
    final coin = world.createEntityWithComponents([TransformComponent(position: Vector3(0, -1, 3)), Pickup3D(value: 5)], name: 'Coin');
    world.update(0.25);
    expect(coin.getComponent<TransformComponent>()!.position.y, isNot(-1), reason: 'bobbing');
    final taken = <PickupCollected3DEvent>[];
    world.events.on<PickupCollected3DEvent>(taken.add);
    // A stranger touching it takes nothing.
    world.events.fire(SensorEnter3DEvent(sensor: coin, other: world.createEntity()));
    world.update(_dt);
    expect(taken, isEmpty);
    world.events.fire(SensorEnter3DEvent(sensor: coin, other: player));
    world.update(_dt);
    expect(taken.single.value, 5);
    expect(taken.single.collector, player);
    expect(coin.isAlive, isFalse);
  });

  test('a platform goes to its travel and back, resting at each end', () {
    world.addSystem(MovingPlatform3DSystem());
    final lift = world.createEntityWithComponents([
      TransformComponent(position: Vector3(1, 0, 0)),
      MovingPlatform3D(travel: Vector3(4, 0, 0), speed: 2, wait: 0.5),
    ]);
    double x() => lift.getComponent<TransformComponent>()!.position.x;
    for (var i = 0; i < 60; i++) {
      world.update(_dt);
    }
    expect(x(), closeTo(3, 1e-6));
    for (var i = 0; i < 60; i++) {
      world.update(_dt);
    }
    expect(x(), closeTo(5, 1e-6), reason: 'at the end, resting');
    for (var i = 0; i < 30 + 60; i++) {
      world.update(_dt);
    }
    expect(x(), closeTo(3, 0.05), reason: 'rested, then a second back (to a frame)');
  });

  group('respawns', () {
    late Entity hero;
    late List<Respawned3DEvent> respawned;

    setUp(() {
      world.addSystem(Respawn3DSystem());
      hero = world.createEntityWithComponents([
        TransformComponent(position: Vector3(0, 0, 0)),
        ThirdPersonController(fallLimit: 10)..spawnPoint = Vector3.zero(),
        CharacterBody3D(),
      ], name: 'Hero');
      respawned = [];
      world.events.on<Respawned3DEvent>(respawned.add);
    });

    Vector3 at() => hero.getComponent<TransformComponent>()!.position;

    test('falling past the limit puts it back, still', () {
      at().setValues(3, 12, 1);
      hero.getComponent<CharacterBody3D>()!.velocity.setValues(0, 20, 0);
      world.update(_dt);
      expect([at().x, at().y, at().z], [0, 0, 0]);
      expect(hero.getComponent<CharacterBody3D>()!.velocity.y, 0);
      expect(respawned, hasLength(1));
    });

    test('a checkpoint moves the spawn; an earlier one does not move it back; a kill zone sends it there', () {
      final first = world.createEntityWithComponents([TransformComponent(position: Vector3(5, 0, 0)), Checkpoint3D(order: 1)]);
      final second = world.createEntityWithComponents([TransformComponent(position: Vector3(9, 0, 0)), Checkpoint3D(order: 2)]);
      final pit = world.createEntityWithComponents([TransformComponent(), KillZone3D()]);
      final reached = <CheckpointReached3DEvent>[];
      world.events.on<CheckpointReached3DEvent>(reached.add);
      world.events.fire(SensorEnter3DEvent(sensor: second, other: hero));
      world.update(_dt);
      world.events.fire(SensorEnter3DEvent(sensor: first, other: hero));
      world.update(_dt);
      expect(hero.getComponent<ThirdPersonController>()!.spawnPoint!.x, 9);
      expect(reached.map((e) => e.checkpoint), [second]);
      at().setValues(20, 0, 0);
      world.events.fire(SensorEnter3DEvent(sensor: pit, other: hero));
      world.update(_dt);
      expect(at().x, 9);
      expect(respawned, hasLength(1));
    });
  });

  group('combat', () {
    late Entity hero;
    late CharacterBody3D body;
    late ThirdPersonController control;
    late ThirdPersonCombat combat;
    late AnimatorComponent animator;
    late InputComponent input;
    late List<StrikeHit3DEvent> hits;

    setUp(() async {
      world
        ..addSystem(ThirdPersonCombatSystem(loader: (_) async => _combos))
        ..addSystem(ThirdPersonControllerSystem(cameraYaw: () => 0));
      body = CharacterBody3D()..groundState = GroundState3D.onGround;
      control = ThirdPersonController();
      combat = ThirdPersonCombat(combosPath: 'hero.combos.json', guardTime: 1);
      animator = AnimatorComponent();
      input = InputComponent();
      hero = world.createEntityWithComponents([TransformComponent(), body, control, combat, animator, input], name: 'Hero');
      hits = [];
      world.events.on<StrikeHit3DEvent>(hits.add);
      world.update(_dt);
      await Future<void>.delayed(Duration.zero); // the combos load
    });

    void step({int frames = 1}) {
      for (var i = 0; i < frames; i++) {
        world.update(_dt);
        input.pressed.clear();
      }
    }

    // Steps until [combat]'s strike has gone [seconds] in.
    void stepTo(double seconds) {
      while (combat.isStriking && combat.strikeTime < seconds - 1e-9) {
        step();
      }
    }

    test('a punch starts its chain on the animator trigger, holds the hero still, and lands once at its hit', () {
      input.setVector('move', const Offset(0, -1));
      step(frames: 30);
      expect(control.planarSpeed, closeTo(control.walkSpeed, 1e-9));

      input.pressed.add('punch');
      step();
      expect((combat.strike?.name, combat.chain, combat.step), ('punch_1', 'punch_combo', 1));
      expect((combat.isStriking, combat.inCombat), (true, true));
      expect(animator.getBool('punch_1'), isTrue, reason: 'the trigger the graph plays it on');
      expect(control.planarSpeed, 0, reason: 'still while it strikes');
      expect(body.moveVelocity.length, 0);
      // Let go, or the guard drops as the strike ends.
      input.setVector('move', Offset.zero);

      stepTo(0.08); // 5 steps in
      expect(hits, isEmpty);
      stepTo(0.11);
      expect(hits.map((h) => (h.player, h.strike.name, h.chain, h.step)), [(hero, 'punch_1', 'punch_combo', 1)]);
      stepTo(0.5);
      step();
      expect(hits, hasLength(1), reason: 'once a strike');
      expect(combat.isStriking, isFalse, reason: 'it played out');
      expect(combat.inCombat, isTrue, reason: 'in its guard');
      expect(animator.getBool('punch_1'), isFalse);
    });

    test('a press in the window queues the next strike, which starts as this one ends; a finisher chains to nothing', () {
      input.pressed.add('punch');
      step();
      stepTo(0.1);
      input.pressed.add('punch'); // before the window
      step();
      expect(combat.queued, isNull);
      stepTo(0.3);
      input.pressed.add('kick'); // the other button
      step();
      expect(combat.queued, isNull);
      input.pressed.add('punch');
      step();
      expect(combat.queued, 'punch_2');
      stepTo(0.5);
      step();
      expect((combat.strike?.name, combat.step), ('punch_2', 2));
      expect(animator.getBool('punch_2'), isTrue);

      stepTo(0.3);
      input.pressed.add('punch');
      step();
      expect(combat.queued, isNull, reason: 'the last of the chain');
      stepTo(0.6);
      step();
      expect(combat.isStriking, isFalse);
      expect(hits.map((h) => h.strike.name), ['punch_1', 'punch_2']);

      // From the guard, a kick starts its own chain.
      input.pressed.add('kick');
      step();
      expect((combat.strike?.name, combat.chain), ('kick_1', 'kick_combo'));
    });

    test('a press as a strike ends starts a new chain on the next step, so the animator sees the end', () {
      input.pressed.add('punch');
      step();
      stepTo(0.5 - _dt);
      input.pressed.add('punch'); // past the window, on its last step
      step();
      expect(combat.isStriking, isFalse);
      input.pressed.add('punch');
      step();
      expect((combat.strike?.name, combat.step), ('punch_1', 1));
    });

    test('the guard drops after its time, or at once when the hero moves', () {
      input.pressed.add('kick');
      step();
      stepTo(0.6);
      step();
      expect((combat.isStriking, combat.inCombat), (false, true));
      step(frames: 30);
      expect(combat.inCombat, isTrue);
      step(frames: 31);
      expect(combat.inCombat, isFalse, reason: 'a second of guard');

      input.pressed.add('kick');
      step();
      stepTo(0.6);
      step();
      expect(combat.inCombat, isTrue);
      input.setVector('move', const Offset(1, 0));
      step();
      expect(combat.inCombat, isFalse);
      expect(control.planarSpeed, greaterThan(0));
    });

    test('no strike in the air, crouched or winding up a jump; off the ground mid-strike, it ends', () {
      body.groundState = GroundState3D.inAir;
      step();
      input.pressed.add('punch');
      step();
      expect(combat.isStriking, isFalse);

      body.groundState = GroundState3D.onGround;
      input.setDown('crouch', true);
      step();
      input.pressed.add('punch');
      step();
      expect(combat.isStriking, isFalse);
      input.setDown('crouch', false);
      step();

      control.jumpDelay = 0.2;
      input.pressed.add('jump');
      step();
      expect(control.windUp, isNotNull);
      input.pressed.add('punch');
      step();
      expect(combat.isStriking, isFalse);
      body.pendingJump = null;
      step(frames: 20);
      control
        ..isJumping = false
        ..windUp = null;
      step();

      input.pressed.add('punch');
      step();
      expect(combat.isStriking, isTrue);
      body.groundState = GroundState3D.inAir;
      step();
      expect((combat.isStriking, combat.inCombat), (false, false));
    });

    test('a jump or a crouch is not taken while it strikes', () {
      input.pressed.add('punch');
      step();
      input.pressed.add('jump');
      input.setDown('crouch', true);
      step();
      expect(body.pendingJump, isNull);
      expect(control.isCrouching, isFalse);
    });

    test('a hero whose combos have not loaded does nothing', () {
      combat.combosPath = 'missing.combos.json';
      world.systems.whereType<ThirdPersonCombatSystem>().single;
      input.pressed.add('punch');
      step();
      expect(combat.isStriking, isFalse);
    });
  });

  test('a combo set reads its file: chains, strikes, hits and windows', () {
    final combos = ComboSet.parse('''{
      "fps": 30,
      "guard": "combat_idle",
      "chains": {"kick_combo": ["kick_1", "kick_2"]},
      "strikes": {
        "kick_1": {"move": "front kick", "limb": "left foot", "duration": 0.6667, "hit": 0.2667,
                   "combo_window": [0.3333, 0.5667], "next": "kick_2", "then": "combat_idle"},
        "kick_2": {"move": "roundhouse", "limb": "right foot", "duration": 0.8667, "hit": 0.3,
                   "combo_window": null, "next": null, "then": "combat_idle"}
      }
    }''');
    expect(combos.guard, 'combat_idle');
    expect(combos.chains, {'kick_combo': ['kick_1', 'kick_2']});
    expect(combos.firstOf('kick_combo')?.name, 'kick_1');
    final kick = combos.strikes['kick_1']!;
    expect((kick.move, kick.limb, kick.duration, kick.hit, kick.next, kick.then), ('front kick', 'left foot', 0.6667, 0.2667, 'kick_2', 'combat_idle'));
    expect(kick.comboWindow, (open: 0.3333, close: 0.5667));
    expect([kick.inWindow(0.3), kick.inWindow(0.4), kick.inWindow(0.6)], [false, true, false]);
    expect(combos.strikes['kick_2']!.comboWindow, isNull);
    expect(combos.validate(), isEmpty);
    expect(_combos.validate(), isEmpty);

    final broken = ComboSet(
      chains: const {'c': ['a', 'x']},
      strikes: const {'a': Strike(name: 'a', duration: 0.5, hit: 0.7, next: 'b')},
    );
    expect(broken.validate(), [
      'Chain "c" names "x", which is not a strike.',
      'Strike "a" lands outside its duration.',
      'Strike "a" goes on to "b", which is not a strike.',
      'Strike "a" goes on to "b" but has no combo window.',
    ]);
  });

  test('the extension installs the components and the animator bindings', () {
    final context = EngineContext();
    ThirdPersonKit.extension.install(context);
    for (final c in [ThirdPersonController(), ThirdPersonCombat(), ThirdPersonCamera(), Pickup3D(), MovingPlatform3D(), Checkpoint3D(), KillZone3D()]) {
      final d = context.definitions.definitionFor(c);
      expect(d, isNotNull, reason: '${c.runtimeType}');
      expect(d!.hints.dimensions, Dimensions.threeD);
    }
    final w = World(context: context)..initialize();
    addTearDown(w.dispose);
    final control = ThirdPersonController()..planarVelocity.setValues(3, 0, 4);
    final hero = w.createEntityWithComponents([control]);
    expect(context.animatorBindings.of('planarSpeed')!(hero), 5);
    expect(context.animatorBindings.of('grounded')!(hero), isFalse);
    expect(context.animatorBindings.of('crouching')!(hero), isFalse);
    control.isCrouching = true;
    expect(context.animatorBindings.of('crouching')!(hero), isTrue);
    expect(context.animatorBindings.of('striking')!(hero), isNull, reason: 'no combat');

    final combat = ThirdPersonCombat();
    final fighter = w.createEntityWithComponents([ThirdPersonController(), combat]);
    expect(context.animatorBindings.of('striking')!(fighter), isFalse);
    expect(context.animatorBindings.of('inCombat')!(fighter), isFalse);
    combat.guardLeft = 1;
    expect(context.animatorBindings.of('inCombat')!(fighter), isTrue);
    combat.strike = const Strike(name: 'jab', duration: 0.4, hit: 0.1);
    expect(context.animatorBindings.of('striking')!(fighter), isTrue);
  });
}
