import 'package:just_game_engine/just_game_engine.dart';

import 'combo_set.dart';
import 'third_person_controller_component.dart';

/// A hero's punches and kicks: `punch` and `kick` each start a chain of
/// strikes from the [combosPath] file (a `.combos.json` beside its model).
/// A press of the same button in a strike's combo window queues the next
/// strike, which starts as this one ends; otherwise it ends in the guard
/// stance, which it leaves after [guardTime] or when it moves. Strikes
/// start on the ground, not crouched or jumping, and hold it still while
/// they last. A `StrikeHit3DEvent` says when each blow lands.
///
/// Goes on a hero with a [ThirdPersonControllerComponent] and an `InputComponent`;
/// an animator graph plays each strike on the trigger of its name, and
/// reads `striking` and `inCombat`.
class ThirdPersonCombatComponent extends Component {
  /// Combat from the strikes in [combosPath]; none while it is empty.
  ThirdPersonCombatComponent({
    this.combosPath = '',
    this.punchAction = 'punch',
    this.kickAction = 'kick',
    this.punchChain = 'punch_combo',
    this.kickChain = 'kick_combo',
    this.guardTime = 1.5,
  });

  /// Asset path of the strikes and their chains (e.g.
  /// `assets/models/hero.combos.json`).
  String combosPath;

  /// The button that punches.
  String punchAction;

  /// The button that kicks.
  String kickAction;

  /// The chain [punchAction] starts and goes on with.
  String punchChain;

  /// The chain [kickAction] starts and goes on with.
  String kickChain;

  /// Seconds it keeps its guard after a strike, standing still.
  double guardTime;

  // ── Runtime, not saved ──────────────────────────────────────────────────

  /// The strike playing; null between strikes.
  Strike? strike;

  /// The chain [strike] belongs to.
  String chain = '';

  /// Where in its chain [strike] is: 1 for the first.
  int step = 0;

  /// Seconds into [strike].
  double strikeTime = 0;

  /// Whether [strike]'s blow has landed.
  bool hitLanded = false;

  /// The strike asked for in [strike]'s combo window, to start as it ends.
  String? queued;

  /// Seconds of guard left after the last strike; 0 when it has dropped
  /// its guard.
  double guardLeft = 0;

  /// Whether a strike is playing.
  bool get isStriking => strike != null;

  /// Whether it is fighting: striking, or in its guard after a strike.
  bool get inCombat => strike != null || guardLeft > 0;
}
