import 'package:flutter/material.dart';
import 'package:just_editor_core/just_editor_core.dart';
import 'package:just_game_engine/just_game_engine.dart';

import '../camera/camera.dart';
import '../character/character.dart';
import '../level/level.dart';
import 'third_person_aids.dart';
import 'third_person_models.dart';
import 'third_person_overlays.dart';
import 'third_person_prefabs.dart';

/// The third-person kit in the editor: a Level Designer kit for 3-D scenes
/// ("Third Person" in its switch) whose pieces are placed on the surface
/// under the pointer — from its palette or the viewport menu — an icon for
/// each in the scene tree, markers for the ones with nothing to draw, and
/// a moving platform's travel drawn when it is selected.
///
/// Design-time only; see `package:just_third_person_kit/editor.dart`.
class ThirdPersonModule extends EditorModule {
  /// The module, its prefabs showing [models].
  ThirdPersonModule({this.models = const ThirdPersonModels()});

  /// The models the prefabs show.
  final ThirdPersonModels models;

  @override
  String get id => 'just_third_person_kit';

  @override
  String get name => 'Third Person';

  @override
  IconData? get icon => Icons.directions_run;

  /// A kit for the Level Designer in 3-D scenes, as the platformer kit is
  /// for 2-D ones: "Third Person" in its switch, its pieces in the palette.
  @override
  Set<SceneMode> get designerModes => const {SceneMode.threeD};

  @override
  List<PrefabDefinition> get prefabs => ThirdPersonPrefabs.all(models);

  @override
  List<EntityIcon> get entityIcons => [
    EntityIcon(
      id: 'third_person',
      order: 40,
      of: (e) {
        if (e.hasComponent<ThirdPersonControllerComponent>()) {
          return Icons.directions_run;
        }
        if (e.hasComponent<ThirdPersonCameraComponent>()) {
          return Icons.videocam_outlined;
        }
        if (e.hasComponent<Pickup3DComponent>()) return Icons.star_outline;
        if (e.hasComponent<MovingPlatform3DComponent>()) {
          return Icons.swap_horiz;
        }
        if (e.hasComponent<Checkpoint3DComponent>()) return Icons.flag_outlined;
        if (e.hasComponent<KillZone3DComponent>()) {
          return Icons.dangerous_outlined;
        }
        return null;
      },
    ),
  ];

  @override
  List<EditorMarker> get markers => [
    const EditorMarker(
      id: 'killZone',
      components: [KillZone3DComponent],
      icon: Icons.dangerous_outlined,
      color: Color(0xFFE57373),
    ),
  ];

  @override
  List<ViewportOverlay> get viewportOverlays => [
    PlatformTravelOverlay(),
    JumpReachOverlay(),
    WalkableSlopeOverlay(),
  ];

  /// The hero's jump and slopes, its fall limit, playing from a point.
  @override
  LevelAids get levelAids => const ThirdPersonAids();
}
