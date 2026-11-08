// Punch and kick chains, with the controller beside them and the
// character's ground state set by hand.
import 'package:flutter_test/flutter_test.dart';
import 'package:just_game_engine/just_game_engine.dart';
import 'package:just_game_engine/just_game_engine_3d.dart';
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
    'punch_1': Strike(
      name: 'punch_1',
      duration: 0.5,
      hit: 0.1,
      comboWindow: (open: 0.2, close: 0.4),
      next: 'punch_2',
    ),
    'punch_2': Strike(name: 'punch_2', duration: 0.6, hit: 0.2),
    'kick_1': Strike(name: 'kick_1', duration: 0.6, hit: 0.3),
  },
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late World world;
  late Entity hero;
  late CharacterBody3DComponent body;
  late ThirdPersonControllerComponent control;
  late ThirdPersonCombatComponent combat;
  late AnimatorComponent animator;
  late InputComponent input;
  late List<StrikeHit3DEvent> hits;

  setUp(() async {
    world = World()..initialize();
    addTearDown(world.dispose);
    world
      ..addSystem(ThirdPersonCombatSystem(loader: (_) async => _combos))
      ..addSystem(ThirdPersonControllerSystem(cameraYaw: () => 0));
    body = CharacterBody3DComponent()..groundState = Ground3DState.onGround;
    control = ThirdPersonControllerComponent();
    combat = ThirdPersonCombatComponent(
      combosPath: 'hero.combos.json',
      guardTime: 1,
    );
    animator = AnimatorComponent();
    input = InputComponent();
    hero = world.createEntityWithComponents([
      TransformComponent(),
      body,
      control,
      combat,
      animator,
      input,
    ], name: 'Hero');
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

  test(
    'a punch starts its chain on the animator trigger, holds the hero still, and lands once at its hit',
    () {
      expect(_combos.validate(), isEmpty);
      input.setVector('move', const Offset(0, -1));
      step(frames: 30);
      expect(control.planarSpeed, closeTo(control.walkSpeed, 1e-9));

      input.pressed.add('punch');
      step();
      expect(
        (combat.strike?.name, combat.chain, combat.step),
        ('punch_1', 'punch_combo', 1),
      );
      expect((combat.isStriking, combat.inCombat), (true, true));
      expect(
        animator.getBool('punch_1'),
        isTrue,
        reason: 'the trigger the graph plays it on',
      );
      expect(control.planarSpeed, 0, reason: 'still while it strikes');
      expect(body.moveVelocity.length, 0);
      // Let go, or the guard drops as the strike ends.
      input.setVector('move', Offset.zero);

      stepTo(0.08); // 5 steps in
      expect(hits, isEmpty);
      stepTo(0.11);
      expect(hits.map((h) => (h.player, h.strike.name, h.chain, h.step)), [
        (hero, 'punch_1', 'punch_combo', 1),
      ]);
      stepTo(0.5);
      step();
      expect(hits, hasLength(1), reason: 'once a strike');
      expect(combat.isStriking, isFalse, reason: 'it played out');
      expect(combat.inCombat, isTrue, reason: 'in its guard');
      expect(animator.getBool('punch_1'), isFalse);
    },
  );

  test(
    'a press in the window queues the next strike, which starts as this one ends; a finisher chains to nothing',
    () {
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
    },
  );

  test(
    'a press as a strike ends starts a new chain on the next step, so the animator sees the end',
    () {
      input.pressed.add('punch');
      step();
      stepTo(0.5 - _dt);
      input.pressed.add('punch'); // past the window, on its last step
      step();
      expect(combat.isStriking, isFalse);
      input.pressed.add('punch');
      step();
      expect((combat.strike?.name, combat.step), ('punch_1', 1));
    },
  );

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

  test(
    'no strike in the air, crouched or winding up a jump; off the ground mid-strike, it ends',
    () {
      body.groundState = Ground3DState.inAir;
      step();
      input.pressed.add('punch');
      step();
      expect(combat.isStriking, isFalse);

      body.groundState = Ground3DState.onGround;
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
      body.groundState = Ground3DState.inAir;
      step();
      expect((combat.isStriking, combat.inCombat), (false, false));
    },
  );

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

  test(
    'ending a strike resets its animator trigger and keeps the guard asked for',
    () {
      input.pressed.add('punch');
      step();
      expect(animator.getBool('punch_1'), isTrue);
      ThirdPersonCombatSystem.endStrike(hero, combat, guard: 0.5);
      expect(
        (combat.isStriking, combat.queued, combat.guardLeft),
        (false, null, 0.5),
      );
      expect(
        animator.getBool('punch_1'),
        isFalse,
        reason: 'a trigger no transition took is not left to fire later',
      );
    },
  );
}
