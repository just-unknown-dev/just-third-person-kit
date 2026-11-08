import 'package:just_game_engine/just_game_engine.dart';

import 'combo_set.dart';

/// A player left the ground in a jump (or jumped just after running off an
/// edge).
final class Jumped3DEvent extends GameEvent {
  /// [player] jumped.
  Jumped3DEvent(this.player);

  /// Who.
  final Entity player;
}

/// A player came down on the ground after being in the air.
final class Landed3DEvent extends GameEvent {
  /// [player] landed, falling at [fallSpeed].
  Landed3DEvent(this.player, this.fallSpeed);

  /// Who.
  final Entity player;

  /// How fast it was falling when it landed, m/s (the fastest it fell on
  /// the way down): small for a step down, large for a long fall — a game
  /// picks what is worth a sound.
  final double fallSpeed;
}

/// A strike's blow landed: the moment game code applies its damage.
final class StrikeHit3DEvent extends GameEvent {
  /// [player]'s [strike], the [step]th of [chain] (from 1), landed.
  StrikeHit3DEvent(this.player, this.strike, this.chain, this.step);

  /// Who struck.
  final Entity player;

  /// The strike: its name, what it is, what it strikes with.
  final Strike strike;

  /// The chain it is part of.
  final String chain;

  /// Where in the chain it is: 1 for the first.
  final int step;
}
