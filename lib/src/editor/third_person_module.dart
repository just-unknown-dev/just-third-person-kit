import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:just_game_engine/just_game_engine.dart';
import 'package:just_editor_core/just_editor_core.dart';
import 'package:just_game_engine/graphics_3d.dart';
import 'package:just_game_engine/physics_3d.dart';

import '../third_person_components.dart';
import 'third_person_aids.dart';

/// The models the kit's prefabs show; the third-person template's by
/// default.
final class ThirdPersonModels {
  /// Models at these paths.
  const ThirdPersonModels({
    this.hero = 'assets/models/hero.glb',
    this.ground = 'assets/models/ground.glb',
    this.block = 'assets/models/block.glb',
    this.platform = 'assets/models/platform.glb',
    this.coin = 'assets/models/coin.glb',
    this.flag = 'assets/models/flag.glb',
    this.heroAnimator = 'assets/animators/hero.animator.json',
    this.heroCombos = 'assets/models/hero.combos.json',
  });

  /// The hero: in the template, JustHumanoid, with idle, walk, run, jump,
  /// crouch_idle and crouch_walk.
  final String hero;

  /// The ground: its top at the model's origin.
  final String ground;

  /// A unit cube about its origin.
  final String block;

  /// A unit cube about its origin, for moving platforms.
  final String platform;

  /// A coin about its origin.
  final String coin;

  /// A checkpoint's flag about its origin.
  final String flag;

  /// The hero's animator graph: in the template, its moves by speed, the
  /// jump in the air and the crouch.
  final String heroAnimator;

  /// The hero's strikes and their chains: in the template, JustHumanoid's
  /// punch and kick combos.
  final String heroCombos;
}

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
        if (e.hasComponent<ThirdPersonController>()) return Icons.directions_run;
        if (e.hasComponent<ThirdPersonCamera>()) return Icons.videocam_outlined;
        if (e.hasComponent<Pickup3D>()) return Icons.star_outline;
        if (e.hasComponent<MovingPlatform3D>()) return Icons.swap_horiz;
        if (e.hasComponent<Checkpoint3D>()) return Icons.flag_outlined;
        if (e.hasComponent<KillZone3D>()) return Icons.dangerous_outlined;
        return null;
      },
    ),
  ];

  @override
  List<EditorMarker> get markers => [
    const EditorMarker(
      id: 'killZone',
      components: [KillZone3D],
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

/// A selected moving platform's travel: a line from where it starts to
/// where it turns back, with a ring at the far end.
final class PlatformTravelOverlay extends ViewportOverlay {
  @override
  String get id => 'thirdPerson.platformTravel';

  @override
  String get label => 'Platform travel';

  @override
  Dimensions get dimensions => Dimensions.threeD;

  @override
  void paint(ViewportOverlayContext context) {
    final paint = Paint()
      ..color = const Color(0xFF64B5F6)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    for (final e in context.world.query([TransformComponent, MovingPlatform3D])) {
      if (!context.isShown(e) || !context.isSelected(e)) continue;
      final p = e.getComponent<MovingPlatform3D>()!;
      // While authoring the platform rests where it starts.
      final from = e.getComponent<TransformComponent>()!.position;
      final to = from + p.travel;
      final a = context.project(from), b = context.project(to);
      if (a == null || b == null) continue;
      context.canvas
        ..drawLine(a, b, paint)
        ..drawCircle(b, 6, paint);
    }
  }
}

/// The kit's prefabs. Each places its entity on the surface under the
/// pointer, standing on it (up is -Y).
abstract final class ThirdPersonPrefabs {
  static const String _category = 'Third Person';

  /// Every prefab, showing [models].
  static List<PrefabDefinition> all(ThirdPersonModels models) => [
    _prefab('tp_player', 'Player', Icons.directions_run, 'The hero: a character the player moves, with its animations.',
        (at) => [
              TransformComponent(position: Vector3.copy(at.position)),
              ModelComponent(model: models.hero),
              AnimationPlayerComponent(clip: 'idle'),
              AnimatorComponent(graphPath: models.heroAnimator),
              CharacterBody3D(),
              ThirdPersonController(),
              ThirdPersonCombat(combosPath: models.heroCombos),
              InputComponent(),
            ]),
    _prefab('tp_camera', 'Camera Rig', Icons.videocam_outlined, 'A camera circling the Player, turned by the look actions, kept out of walls.',
        (at) => [
              TransformComponent(position: at.position + Vector3(0, -3, -6)),
              VirtualCameraComponent(
                follow: const EntityTarget.name('Player'),
                projection: CameraProjection.perspective,
                fieldOfView: math.pi / 3,
                nearClip: 0.1,
                farClip: 300,
              ),
              OrbitFollowComponent(distance: 6, pitch: -0.35, pivot: Vector3(0, -1.4, 0), damping: 0.05),
              ThirdPersonCamera(),
              CameraCollision3D(),
            ]),
    _prefab('tp_ground', 'Ground', Icons.landscape_outlined, 'A 40 m square of ground, its top where it is placed.',
        (at) => [
              TransformComponent(position: Vector3.copy(at.position)),
              ModelComponent(model: models.ground),
              Collider3D(size: Vector3(40, 1, 40), offset: Vector3(0, 0.5, 0)),
            ]),
    _prefab('tp_block', 'Block', Icons.check_box_outline_blank, 'A 2 m block to stand on.',
        (at) => _box(models.block, at, Vector3(2, 2, 2))),
    _prefab('tp_platform', 'Moving Platform', Icons.swap_horiz, 'A platform that goes 6 m and back, carrying what stands on it.',
        (at) => [
              ..._box(models.platform, at, Vector3(3, 0.4, 3)),
              RigidBody3D(bodyType: BodyType3D.kinematic),
              MovingPlatform3D(travel: Vector3(6, 0, 0), speed: 2.5, wait: 1),
            ]),
    _prefab('tp_light', 'Light', Icons.lightbulb_outline, 'A point light 3 m above the surface.',
        (at) => [
              TransformComponent(position: at.position + Vector3(0, -3, 0)),
              LightComponent(range: 10),
            ]),
    _prefab('tp_pickup', 'Coin', Icons.star_outline, 'A coin to collect, a metre above the surface.',
        (at) => [
              TransformComponent(position: at.position + at.normal * 1.0),
              ModelComponent(model: models.coin, castShadows: false),
              Collider3D(shape: ColliderShape3D.sphere, radius: 0.35),
              RigidBody3D(bodyType: BodyType3D.kinematic, isSensor: true),
              Pickup3D(),
            ]),
    _prefab('tp_killzone', 'Kill Zone', Icons.dangerous_outlined, 'A pit, water, a crusher: what enters it goes back to its spawn point.',
        (at) => [
              TransformComponent(position: at.position + at.normal * 1.0),
              Collider3D(size: Vector3(4, 2, 4)),
              RigidBody3D(bodyType: BodyType3D.static, isSensor: true),
              KillZone3D(),
            ]),
    _prefab('tp_checkpoint', 'Checkpoint', Icons.flag_outlined, 'Where the hero comes back after a fall, once reached.',
        (at) => [
              TransformComponent(position: at.position + at.normal * 1.0),
              ModelComponent(model: models.flag),
              Collider3D(size: Vector3(1.5, 2, 1.5)),
              RigidBody3D(bodyType: BodyType3D.static, isSensor: true),
              Checkpoint3D(),
            ]),
  ];

  /// A unit-cube model scaled to [size], standing on [at].
  static List<Component> _box(String model, SurfacePoint at, Vector3 size) => [
    TransformComponent(position: at.position + at.normal * (size.y / 2), scale: Vector3.copy(size)),
    ModelComponent(model: model),
    Collider3D(size: Vector3(1, 1, 1)),
  ];

  static PrefabDefinition _prefab(
    String id,
    String name,
    IconData icon,
    String description,
    List<Component> Function(SurfacePoint at) buildAt,
  ) => PrefabDefinition(
    id: id,
    name: name,
    category: _category,
    icon: icon,
    color: const Color(0xFF7E57C2),
    description: description,
    placement: PrefabPlacement.point,
    dimensions: Dimensions.threeD,
    namePrefix: name.replaceAll(' ', ''),
    buildAt: buildAt,
    // Placed from 2-D coordinates only by a tool that ignores dimensions:
    // on the ground at that point.
    build: (position, size) => buildAt(SurfacePoint(Vector3(position.dx, 0, position.dy), Vector3(0, -1, 0))),
  );
}
