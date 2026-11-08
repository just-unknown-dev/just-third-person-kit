import 'package:just_game_engine/just_game_engine.dart';

/// A checkpoint: a sensor that, reached by a player, becomes where it comes
/// back after a fall.
class Checkpoint3DComponent extends Component {
  /// A checkpoint; [order] lets a later one not be undone by an earlier.
  Checkpoint3DComponent({this.order = 0});

  /// Its place in the level: one with a lower order reached after a higher
  /// one does not move the spawn back.
  int order;

  /// Whether a player has reached it. Runtime, not saved.
  bool reached = false;
}
