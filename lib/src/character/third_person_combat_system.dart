import 'dart:math' as math;

import 'package:flutter/foundation.dart' show debugPrint, internal;
import 'package:just_game_engine/just_game_engine.dart';
import 'package:just_game_engine/just_game_engine_3d.dart';

import 'character_3d_events.dart';
import 'combo_set.dart';
import 'third_person_combat_component.dart';
import 'third_person_controller_component.dart';

/// Plays [ThirdPersonCombatComponent] strikes from the punch and kick buttons: a
/// press starts its chain; a press of the same button in a strike's combo
/// window queues the next, which starts as this one ends; a
/// [StrikeHit3DEvent] says when each blow lands; after the last strike the
/// guard is kept a while, dropped sooner when the hero moves, jumps or
/// crouches. Before the controller, which holds a striking hero still.
class ThirdPersonCombatSystem extends System {
  /// A system reading each combo set with [loader] once per path, shared
  /// by every hero that names it.
  ThirdPersonCombatSystem({this.loader});

  /// Reads the combo set at a path; null reads it from the world context's
  /// asset bundle.
  final Future<ComboSet> Function(String path)? loader;
  final Map<String, Future<void>> _loading = {};
  final Map<String, ComboSet> _sets = {};

  /// A stick pushed further than this drops the guard.
  static const double moveDeadZone = 0.2;

  @override
  int get priority => SystemPriorities.playerControl + 2;

  @override
  List<Type> get requiredComponents => const [
    ThirdPersonCombatComponent,
    InputComponent,
  ];

  /// The combo set read from [path], once it has loaded.
  ComboSet? combosAt(String path) => _sets[path.trim()];

  @override
  void update(double deltaTime) {
    if (deltaTime <= 0) return;
    for (final entity in entities) {
      if (!entity.isActive) continue;
      final combat = entity.getComponent<ThirdPersonCombatComponent>()!;
      final combos = _combos(combat.combosPath.trim());
      if (combos == null) continue;
      final input = entity.getComponent<InputComponent>()!;
      final control = entity.getComponent<ThirdPersonControllerComponent>();
      // On its feet: not in the air (as its body found this step; the
      // controller runs after), in a jump's wind-up or crouched.
      final grounded =
          entity.getComponent<CharacterBody3DComponent>()?.isGrounded ??
          control?.isGrounded ??
          true;
      final ready =
          grounded &&
          !(control?.isJumping ?? false) &&
          !(control?.isCrouching ?? false);
      final pressed = input.wasPressed(combat.punchAction)
          ? combat.punchChain
          : input.wasPressed(combat.kickAction)
          ? combat.kickChain
          : null;

      final strike = combat.strike;
      if (strike != null) {
        // Off the ground under it (an edge, a platform): no strike, no guard.
        if (!ready) {
          endStrike(entity, combat, guard: 0);
          continue;
        }
        // Read before the time moves on: a press is in the window it was
        // made in.
        if (pressed == combat.chain &&
            strike.next != null &&
            strike.inWindow(combat.strikeTime)) {
          combat.queued = strike.next;
        }
        combat.strikeTime += deltaTime;
        // Steps of 1/60 s add up a hair short of a time they reach.
        if (!combat.hitLanded && combat.strikeTime >= strike.hit - 1e-9) {
          combat.hitLanded = true;
          world.events.fire(
            StrikeHit3DEvent(entity, strike, combat.chain, combat.step),
          );
        }
        if (combat.strikeTime >= strike.duration - 1e-9) {
          final next = combos.strikes[combat.queued];
          if (next != null) {
            _start(entity, combat, next, combat.chain, combat.step + 1);
          } else {
            // A press as it ends starts a new chain on the next step, once
            // the animator has seen this one end.
            endStrike(entity, combat, guard: combat.guardTime);
          }
        }
        continue;
      }

      if (combat.guardLeft > 0) {
        final moving =
            input.vector(control?.moveAction ?? 'move').distance > moveDeadZone;
        combat.guardLeft = moving || !ready
            ? 0
            : math.max(0, combat.guardLeft - deltaTime);
      }
      if (pressed != null && ready) {
        final first = combos.firstOf(pressed);
        if (first != null) _start(entity, combat, first, pressed, 1);
      }
    }
  }

  /// Starts [strike], the [step]th of [chain], and plays it on the
  /// entity's animator: the trigger of its name.
  static void _start(
    Entity entity,
    ThirdPersonCombatComponent combat,
    Strike strike,
    String chain,
    int step,
  ) {
    combat
      ..strike = strike
      ..chain = chain
      ..step = step
      ..strikeTime = 0
      ..hitLanded = false
      ..queued = null
      ..guardLeft = 0;
    entity.getComponent<AnimatorComponent>()?.setTrigger(strike.name);
  }

  /// Ends [entity]'s strike playing, keeping the guard [guard] seconds: as
  /// a strike plays out, as the ground goes from under it, and as a respawn
  /// puts the hero back (`Respawn3DSystem`).
  @internal
  static void endStrike(
    Entity entity,
    ThirdPersonCombatComponent combat, {
    required double guard,
  }) {
    // A trigger no transition took (a graph without the strike) is not
    // left to fire later.
    final name = combat.strike?.name;
    if (name != null) {
      entity.getComponent<AnimatorComponent>()?.resetTrigger(name);
    }
    combat
      ..strike = null
      ..queued = null
      ..guardLeft = math.max(0, guard);
  }

  /// The combo set at [path], or null while it loads (or could not).
  ComboSet? _combos(String path) {
    if (path.isEmpty) return null;
    final known = _sets[path];
    if (known != null || _loading.containsKey(path)) return known;
    _loading[path] = (loader ?? _fromBundle)(path)
        .then((set) {
          // A strike with no duration ends at once, one that lands past its end
          // never lands: said once, as the set loads.
          final problems = set.validate();
          if (problems.isNotEmpty) {
            debugPrint(
              'ThirdPersonCombatSystem: "$path": ${problems.join(' ')}',
            );
          }
          return _sets[path] = set;
        })
        .catchError((Object error) {
          // Not tried again; said once.
          debugPrint(
            'ThirdPersonCombatSystem: "$path" could not be loaded; its strikes do nothing. $error',
          );
          return const ComboSet();
        });
    return null;
  }

  Future<ComboSet> _fromBundle(String path) async =>
      ComboSet.parse(await world.context.bundle.loadString(path));
}
