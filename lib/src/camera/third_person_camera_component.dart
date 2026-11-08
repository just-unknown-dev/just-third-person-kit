import 'package:just_game_engine/just_game_engine.dart';

/// A third-person camera's player controls: on a virtual camera with an
/// `OrbitFollowComponent`, turned by the look actions (`look`, the mouse or
/// a drag; `lookStick`, a stick) and zoomed by the `zoom` axis.
class ThirdPersonCameraComponent extends Component {
  /// Camera controls.
  ThirdPersonCameraComponent({
    this.sensitivity = 1,
    this.invertY = false,
    this.zoomSpeed = 1.5,
    this.zoomAction = 'zoom',
  });

  /// Scales the look settings' turn: 2 turns twice as far.
  double sensitivity;

  /// Whether moving up looks down.
  bool invertY;

  /// How fast `zoom` moves it in and out, as a share of the distance a
  /// second at full deflection.
  double zoomSpeed;

  /// The axis action that zooms (positive moves in).
  String zoomAction;
}
