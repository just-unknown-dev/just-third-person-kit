// The kit on Jolt: a third-person character walking, jumping (from a crouch
// and with a wind-up), crouching under a low roof, climbing stairs and a
// slope, ridden by a moving platform, and put back after a fall — the
// slice's gameplay with the real physics.
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:just_game_engine/just_game_engine.dart';
import 'package:just_game_engine/physics_3d.dart';
import 'package:just_third_person_kit/just_third_person_kit.dart';

const _dt = 1 / 60;
final _backend = JoltPhysicsEngine();

void main() {
  final skip = _backend.unavailableReason;

  late World world;
  late Entity hero;
  late InputComponent input;

  setUp(() {
    if (skip != null) return;
    final physics = _backend.createWorld(PhysicsWorldSettings3D());
    world = World()..initialize();
    world
      ..addSystem(Respawn3DSystem())
      ..addSystem(ThirdPersonControllerSystem(cameraYaw: () => 0))
      ..addSystem(MovingPlatform3DSystem())
      ..addSystem(Pickup3DSystem())
      ..addSystem(PhysicsSystem3D(physics));
    addTearDown(() {
      world.dispose();
      physics.dispose();
    });
    // A 40 m floor, its top at y = 0 (+Y is down).
    world.createEntityWithComponents([
      TransformComponent(position: Vector3(0, 0.5, 0)),
      Collider3D(size: Vector3(40, 1, 40)),
    ], name: 'Floor');
    input = InputComponent();
    hero = world.createEntityWithComponents([
      TransformComponent(position: Vector3(0, 0, 0)),
      CharacterBody3D(),
      ThirdPersonController(),
      input,
    ], name: 'Hero');
  });

  Vector3 at() => hero.getComponent<TransformComponent>()!.position;
  void run(int frames) {
    for (var i = 0; i < frames; i++) {
      world.update(_dt);
      input.pressed.clear();
    }
  }

  test('it settles on the floor and walks forward (+Z with the camera at yaw 0)', () {
    run(30);
    expect(hero.getComponent<CharacterBody3D>()!.isGrounded, isTrue);
    input.setVector('move', const Offset(0, -1));
    run(120);
    expect(at().z, greaterThan(6), reason: 'about 4.5 m/s for 2 s, after speeding up');
    expect(at().y, closeTo(0, 0.05), reason: 'still on the floor');
  }, skip: skip);

  test('a jump leaves the ground and comes back down', () {
    run(30);
    input.pressed.add('jump');
    var highest = 0.0;
    for (var i = 0; i < 90; i++) {
      run(1);
      highest = math.min(highest, at().y);
    }
    expect(highest, lessThan(-1.5), reason: '6.5 m/s up under 9.81 rises about 2 m');
    expect(at().y, closeTo(0, 0.05));
    expect(hero.getComponent<ThirdPersonController>()!.isJumping, isFalse);
  }, skip: skip);

  test('it jumps from a crouch, standing up as it goes', () {
    final control = hero.getComponent<ThirdPersonController>()!;
    final body = hero.getComponent<CharacterBody3D>()!;
    run(30);
    input.setDown('crouch', true);
    run(10);
    expect(body.height, control.crouchHeight);
    input.pressed.add('jump');
    run(1);
    expect(body.height, 1.8, reason: 'stood up to jump');
    var highest = at().y;
    for (var i = 0; i < 90; i++) {
      run(1);
      highest = math.min(highest, at().y);
    }
    expect(highest, lessThan(-1.5), reason: 'the whole jump, though its body was made again');
    expect(at().y, closeTo(0, 0.05));
    expect(control.isCrouching, isTrue, reason: 'landed with crouch held');
  }, skip: skip);

  test('with a wind-up it leaves the ground its delay after the press, and comes back down', () {
    final control = hero.getComponent<ThirdPersonController>()!..jumpDelay = 0.2;
    var jumps = 0;
    world.events.on<Jumped3DEvent>((_) => jumps++);
    run(30);
    input.pressed.add('jump');
    var steps = 0;
    while (steps < 60 && at().y > -0.02) {
      run(1);
      steps++;
      if (at().y > -0.02) expect(hero.getComponent<CharacterBody3D>()!.isGrounded, isTrue);
    }
    // Pressed at the first step: it springs at the 13th, 12 steps (0.2 s) on.
    expect(steps, 13);
    expect(jumps, 1, reason: 'told as it leaves');
    var highest = at().y;
    for (var i = 0; i < 90; i++) {
      run(1);
      highest = math.min(highest, at().y);
    }
    expect(highest, lessThan(-1.5));
    expect(at().y, closeTo(0, 0.05));
    expect(control.isJumping, isFalse);
  }, skip: skip);

  test('crouched, it goes under a roof too low to walk under standing; it stays down beneath it', () {
    // A roof from z = 2 to 6, its underside 1.6 m up: lower than the hero
    // (1.8 m), higher than its crouch (1.5 m).
    world.createEntityWithComponents([
      TransformComponent(position: Vector3(0, -1.6 - 0.25, 4)),
      Collider3D(size: Vector3(4, 0.5, 4)),
    ], name: 'Roof');
    final control = hero.getComponent<ThirdPersonController>()!;
    final body = hero.getComponent<CharacterBody3D>()!;
    run(30);
    input.setVector('move', const Offset(0, -1));
    run(90);
    expect(at().z, closeTo(1.7, 0.05), reason: "standing, its head meets the roof's edge");

    input.setDown('crouch', true);
    run(120);
    expect(control.isCrouching, isTrue);
    expect(body.height, control.crouchHeight);
    expect(at().z, greaterThan(3), reason: 'crouched, it goes in under the roof');
    expect(at().y, closeTo(0, 0.05));

    // Let go beneath it: no room to stand, nor to jump.
    input
      ..setVector('move', Offset.zero)
      ..setDown('crouch', false);
    run(30);
    expect(control.isCrouching, isTrue, reason: 'held down by the roof');
    expect(body.height, control.crouchHeight);
    input.pressed.add('jump');
    run(30);
    expect(control.isJumping, isFalse);
    expect(at().y, closeTo(0, 0.05));

    // Out the far side, it stands.
    input.setVector('move', const Offset(0, -1));
    run(240);
    expect(at().z, greaterThan(6.3));
    expect(control.isCrouching, isFalse);
    expect(body.height, 1.8);
    expect(at().y, closeTo(0, 0.05));
  }, skip: skip);

  double highestWalking(int frames) {
    input.setVector('move', const Offset(0, -1));
    var highest = 0.0;
    for (var i = 0; i < frames; i++) {
      run(1);
      highest = math.min(highest, at().y);
    }
    return highest;
  }

  test('it climbs stairs of 0.25 m steps', () {
    // Steps 0.25 m high, 0.5 m deep, ahead along +Z.
    for (var i = 0; i < 6; i++) {
      final top = -0.25 * (i + 1);
      world.createEntityWithComponents([
        // From the floor (y = 0) up to its top.
        TransformComponent(position: Vector3(0, top / 2, 3 + i * 0.5 + 0.25)),
        Collider3D(size: Vector3(4, -top, 0.5)),
      ]);
    }
    run(30);
    expect(highestWalking(100), lessThan(-1.4), reason: 'to the top step, 1.5 m up');
  }, skip: skip);

  test('it walks up a 25° slope', () {
    const angle = 25 * math.pi / 180;
    // A ramp rising along +Z from z = 3: turned about X so that ahead is up.
    world.createEntityWithComponents([
      TransformComponent(position: Vector3(0, -4 * math.sin(angle), 3 + 4 * math.cos(angle))),
      Collider3D(size: Vector3(4, 0.2, 8), rotation: Vector3(angle, 0, 0)),
    ]);
    run(30);
    expect(highestWalking(150), lessThan(-1.2), reason: 'well up the ramp');
  }, skip: skip);

  test('a moving platform carries it', () {
    world.createEntityWithComponents([
      TransformComponent(position: Vector3(10, -1, 0)),
      Collider3D(size: Vector3(3, 0.5, 3)),
      RigidBody3D(bodyType: BodyType3D.kinematic),
      MovingPlatform3D(travel: Vector3(0, 0, 6), speed: 2, wait: 0),
    ], name: 'Lift');
    at().setValues(10, -1.3, 0);
    run(30);
    final startZ = at().z;
    run(90);
    expect(at().z - startZ, greaterThan(2), reason: 'riding along about 3 m');
  }, skip: skip);

  test('off the edge of the world, it comes back where it started', () {
    final respawns = <Respawned3DEvent>[];
    world.events.on<Respawned3DEvent>(respawns.add);
    run(10);
    at().setValues(30, -1, 0); // past the floor's edge
    run(240);
    expect(respawns, isNotEmpty);
    expect(at().x, closeTo(0, 0.1));
  }, skip: skip);
}
