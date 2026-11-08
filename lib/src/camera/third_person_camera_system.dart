import 'dart:math' as math;
import 'dart:ui' show Offset;

import 'package:just_game_engine/just_game_engine.dart';

import 'third_person_camera_component.dart';

/// Turns and zooms [ThirdPersonCameraComponent] cameras from the look and zoom
/// actions, once per rendered frame, so the view is smooth at any rate.
///
/// It runs just before the camera brain ([SystemPriorities.camera] + 1), so
/// a frame's look is in the view that frame is drawn with. Like the kit's
/// other systems it stands still while time does (a `deltaTime` of 0:
/// paused, or an editor authoring the level): the rig keeps the turn and
/// distance it was given, and a look made meanwhile is dropped rather than
/// turned all at once when time moves again.
class ThirdPersonCameraSystem extends System implements PerFrame {
  /// A system reading looks and zoom through [actions]. Its [look] reader
  /// is made when it joins a world and let go when it leaves.
  ThirdPersonCameraSystem({required this.actions});

  /// Where the look and zoom actions are read.
  final InputActions actions;

  /// The look actions' reader (the mouse's movement and the stick's rate),
  /// while the system is in a world; null otherwise. It listens to the input
  /// service, so it exists only while it is used.
  LookInput? get look => _look;
  LookInput? _look;

  @override
  int get priority => SystemPriorities.camera + 1;

  @override
  List<Type> get requiredComponents => const [
    OrbitFollowComponent,
    ThirdPersonCameraComponent,
  ];

  @override
  void onAddedToWorld() {
    super.onAddedToWorld();
    _look ??= LookInput(actions);
  }

  @override
  void onRemovedFromWorld() {
    _look?.dispose();
    _look = null;
    super.onRemovedFromWorld();
  }

  @override
  void update(double deltaTime) {}

  @override
  void frame(double deltaTime, double alpha) {
    final look = _look;
    if (look == null) return;
    if (deltaTime <= 0) {
      // The mouse's movement since the last frame is dropped, not kept for
      // when time moves again.
      look.reset();
      return;
    }
    final turn = look.read(deltaTime);
    for (final entity in entities) {
      if (!entity.isActive) continue;
      final orbit = entity.getComponent<OrbitFollowComponent>()!;
      final camera = entity.getComponent<ThirdPersonCameraComponent>()!;
      applyLook(orbit, camera, turn);
      applyZoom(
        orbit,
        camera,
        actions.tryAction(camera.zoomAction)?.readAxis() ?? 0,
        deltaTime,
      );
    }
  }

  /// [orbit] turned by [turn] (radians: x right, y down) as [camera] says.
  static void applyLook(
    OrbitFollowComponent orbit,
    ThirdPersonCameraComponent camera,
    Offset turn,
  ) {
    if (turn == Offset.zero) return;
    orbit.yaw += turn.dx * camera.sensitivity;
    // Down on the look turns the view down: a lower pitch (-Y is up).
    final dy = turn.dy * camera.sensitivity * (camera.invertY ? -1 : 1);
    orbit.pitch = (orbit.pitch - dy).clamp(orbit.minPitch, orbit.maxPitch);
  }

  /// [orbit] moved in or out over [deltaTime] seconds by [zoom], the zoom
  /// axis (positive moves in), at [camera]'s zoom speed: a share of the
  /// distance a second, so it zooms as fast near as far. It stays between
  /// the orbit's nearest and farthest distances.
  static void applyZoom(
    OrbitFollowComponent orbit,
    ThirdPersonCameraComponent camera,
    double zoom,
    double deltaTime,
  ) {
    if (zoom == 0 || deltaTime <= 0) return;
    orbit.distance =
        (orbit.distance * math.exp(-zoom * camera.zoomSpeed * deltaTime)).clamp(
          orbit.minDistance,
          orbit.maxDistance,
        );
  }
}
