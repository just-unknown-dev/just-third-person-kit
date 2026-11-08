// The controller on its own, with the character's ground state set by
// hand: camera-relative movement, turning, jumps with coyote time, a buffer
// and a wind-up, and crouching (its body lowered).
import 'dart:convert';
import 'dart:math' as math;

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

  test("a camera's ground axes: forward along its yaw, right a quarter on", () {
    final (forward, right) = groundAxesOf(math.pi / 2);
    expect([forward.x, forward.y, forward.z].map((v) => v.roundToDouble()), [
      1,
      0,
      0,
    ]);
    expect([right.x, right.y, right.z].map((v) => v.roundToDouble()), [
      0,
      0,
      -1,
    ]);
  });

  group('the controller', () {
    late Entity hero;
    late CharacterBody3DComponent body;
    late ThirdPersonControllerComponent control;
    late InputComponent input;
    var yaw = 0.0;

    setUp(() {
      yaw = 0;
      world.addSystem(ThirdPersonControllerSystem(cameraYaw: () => yaw));
      body = CharacterBody3DComponent()..groundState = Ground3DState.onGround;
      control = ThirdPersonControllerComponent();
      input = InputComponent();
      hero = world.createEntityWithComponents([
        TransformComponent(),
        body,
        control,
        input,
      ], name: 'Hero');
    });

    void step({int frames = 1}) {
      for (var i = 0; i < frames; i++) {
        world.update(_dt);
        input.pressed.clear();
      }
    }

    test(
      'forward on the stick runs where the camera looks, up to walking speed',
      () {
        input.setVector('move', const Offset(0, -1));
        step();
        expect(
          body.moveVelocity.z,
          closeTo(control.acceleration * _dt, 1e-9),
          reason: 'accelerating',
        );
        step(frames: 60);
        expect(body.moveVelocity.z, closeTo(control.walkSpeed, 1e-9));
        expect(body.moveVelocity.x, closeTo(0, 1e-9));
        expect(control.planarSpeed, closeTo(control.walkSpeed, 1e-9));
      },
    );

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
      final front = Vector3(
        0,
        0,
        -1,
      ); // a glTF character's front, in engine axes
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

    test(
      'just off an edge, a jump still works (coyote time); later it does not',
      () {
        step();
        body.groundState = Ground3DState.inAir;
        step(frames: 3); // 0.05 s
        input.pressed.add('jump');
        step();
        expect(body.velocity.y, -control.jumpSpeed, reason: 'up is -Y');

        // Again, but too late.
        control.isJumping = false;
        body.velocity.setZero();
        body.groundState = Ground3DState.onGround;
        step();
        body.groundState = Ground3DState.inAir;
        step(frames: 20); // 0.33 s
        input.pressed.add('jump');
        step();
        expect(body.velocity.y, 0);
        expect(body.pendingJump, isNull);
      },
    );

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
      body.groundState = Ground3DState.inAir;
      body.velocity.y = -6; // rising (up is -Y)
      step(frames: 5);
      body.velocity.y = 7.5; // and falling
      step(frames: 2);
      body.velocity.y = 3;
      step();
      expect(landed, isEmpty, reason: 'still in the air');
      body.groundState = Ground3DState.onGround;
      step();
      expect(landed, [(hero, 7.5)], reason: 'the fastest it fell');
      step(frames: 3);
      expect(landed, hasLength(1));
    });

    test('a jump pressed just before landing happens on landing (buffer)', () {
      body.groundState = Ground3DState.inAir;
      step(frames: 30);
      input.pressed.add('jump');
      step(frames: 3);
      expect(body.pendingJump, isNull, reason: 'still in the air');
      body.groundState = Ground3DState.onGround;
      step();
      expect(body.pendingJump, control.jumpSpeed);
    });

    test(
      'crouch held on the ground slows it to crouching speed, sprint or not; let go, it stands',
      () {
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
      },
    );

    test(
      'a jump stands it up; in the air it does not crouch, and it lands crouched',
      () {
        input.setDown('crouch', true);
        step();
        expect(control.isCrouching, isTrue);
        input.pressed.add('jump');
        step();
        expect(control.isJumping, isTrue, reason: 'it jumps from a crouch');
        expect(control.isCrouching, isFalse);
        expect(body.effectiveHeight, 1.8, reason: 'stood up');
        expect(body.heightOverride, isNull);
        // Its body is made again at its new height, and takes that first step
        // as in the air: the jump goes as its speed, not to the ground.
        expect(body.velocity.y, -control.jumpSpeed);
        expect(body.pendingJump, isNull);
        body.groundState = Ground3DState.inAir;
        step(frames: 10);
        expect(control.isCrouching, isFalse);
        body.groundState = Ground3DState.onGround;
        body.velocity.setZero();
        step();
        expect(control.isCrouching, isTrue, reason: 'crouch still held');
      },
    );

    test(
      'crouching lowers its body to the crouching height; standing gives its height back',
      () {
        input.setDown('crouch', true);
        step();
        expect(body.effectiveHeight, control.crouchHeight);
        expect(body.heightOverride, control.crouchHeight);
        step(frames: 5);
        expect(body.effectiveHeight, control.crouchHeight);
        input.setDown('crouch', false);
        step();
        expect(
          control.isCrouching,
          isFalse,
          reason: 'nothing above it (no physics to find any)',
        );
        expect(body.effectiveHeight, 1.8);
        expect(body.heightOverride, isNull);

        // A body no taller than its crouch keeps its height.
        body.height = 1.2;
        input.setDown('crouch', true);
        step();
        expect(control.isCrouching, isTrue);
        expect(body.effectiveHeight, 1.2);
        expect(body.heightOverride, isNull);
        input.setDown('crouch', false);
        step();
        expect(body.effectiveHeight, 1.2);
      },
    );

    test(
      'a crouch and a stand-up never write its saved height; a save mid-crouch keeps the authored one',
      () {
        final definition = Physics3DDefinitions.characterBody;
        input.setDown('crouch', true);
        step(frames: 3);
        expect(body.effectiveHeight, control.crouchHeight);
        expect(body.height, 1.8, reason: 'crouched: the authored height');
        final saved =
            jsonDecode(jsonEncode(definition.encode(body)))
                as Map<String, dynamic>;
        expect((saved['fields'] as Map)['height'], 1.8);
        expect(definition.decode(saved).effectiveHeight, 1.8);

        input.setDown('crouch', false);
        step();
        expect(control.isCrouching, isFalse);
        expect(
          (body.height, body.effectiveHeight),
          (1.8, 1.8),
          reason: 'stood',
        );

        input.setDown('crouch', true);
        step();
        expect(body.effectiveHeight, control.crouchHeight);
        input.pressed.add('jump');
        step();
        expect(control.isCrouching, isFalse, reason: 'stood up to jump');
        expect((body.height, body.effectiveHeight), (1.8, 1.8));
      },
    );

    test(
      'with a wind-up, the jump leaves the ground its delay after the press, and is told then',
      () {
        control.jumpDelay = 0.2;
        final jumped = <Entity>[];
        world.events.on<Jumped3DEvent>((e) => jumped.add(e.player));
        step();
        input.pressed.add('jump');
        step();
        expect(control.isJumping, isTrue, reason: 'winding up');
        expect(control.windUp, 0.2);
        step(frames: 11);
        expect(
          body.pendingJump,
          isNull,
          reason: 'still winding up, 11 steps on',
        );
        expect(control.isJumping, isTrue, reason: 'on the ground, and jumping');
        expect(jumped, isEmpty);
        step();
        expect(body.pendingJump, control.jumpSpeed, reason: '0.2 s on');
        expect(control.windUp, isNull);
        expect(jumped, [hero]);
      },
    );

    test(
      'off the ground in the wind-up it springs at once; a jump taken landing winds up a step on; a coyote jump has none',
      () {
        control.jumpDelay = 0.2;
        step();
        input.pressed.add('jump');
        step(frames: 3);
        body.groundState = Ground3DState.inAir;
        step();
        expect(
          body.velocity.y,
          -control.jumpSpeed,
          reason: 'the ground went from under it',
        );
        expect(control.windUp, isNull);

        // Pressed just before landing: the landing is seen first.
        body.velocity.setZero();
        step(frames: 30);
        input.pressed.add('jump');
        step(frames: 3);
        body.groundState = Ground3DState.onGround;
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
        body.groundState = Ground3DState.inAir;
        step(frames: 3);
        input.pressed.add('jump');
        step();
        expect(body.velocity.y, -control.jumpSpeed);
        expect(control.windUp, isNull);
      },
    );

    test('a controller with no crouch action never crouches', () {
      control.crouchAction = 'duck';
      input.setDown('crouch', true);
      step();
      expect(control.isCrouching, isFalse);
    });
  });
}
