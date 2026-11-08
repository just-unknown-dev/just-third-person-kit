import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:just_editor_core/just_editor_core.dart';
import 'package:just_game_engine/just_game_engine.dart';
import 'package:just_game_engine/just_game_engine_3d.dart';

import '../camera/camera.dart';
import '../character/character.dart';
import '../level/level.dart';
import 'third_person_models.dart';

/// The kit's prefabs. Each places its entity on the surface under the
/// pointer, standing on it (up is -Y).
abstract final class ThirdPersonPrefabs {
  static const String _category = 'Third Person';

  /// Every prefab, showing [models].
  static List<PrefabDefinition> all(ThirdPersonModels models) => [
    _prefab(
      'tp_player',
      'Player',
      Icons.directions_run,
      'The hero: a character the player moves, with its animations.',
      (at) => [
        TransformComponent(position: Vector3.copy(at.position)),
        ModelComponent(model: models.hero),
        AnimationPlayerComponent(clip: 'idle'),
        AnimatorComponent(graphPath: models.heroAnimator),
        CharacterBody3DComponent(),
        ThirdPersonControllerComponent(),
        ThirdPersonCombatComponent(combosPath: models.heroCombos),
        InputComponent(),
      ],
    ),
    _prefab(
      'tp_camera',
      'Camera Rig',
      Icons.videocam_outlined,
      'A camera circling the Player, turned by the look actions, kept out of walls.',
      (at) => [
        TransformComponent(position: at.position + Vector3(0, -3, -6)),
        VirtualCameraComponent(
          follow: const EntityTarget.name('Player'),
          projection: CameraProjection.perspective,
          fieldOfView: math.pi / 3,
          nearClip: 0.1,
          farClip: 300,
        ),
        OrbitFollowComponent(
          distance: 6,
          pitch: -0.35,
          pivot: Vector3(0, -1.4, 0),
          damping: 0.05,
        ),
        ThirdPersonCameraComponent(),
        CameraCollision3DComponent(),
      ],
    ),
    _prefab(
      'tp_ground',
      'Ground',
      Icons.landscape_outlined,
      'A 40 m square of ground, its top where it is placed.',
      (at) => [
        TransformComponent(position: Vector3.copy(at.position)),
        ModelComponent(model: models.ground),
        Collider3DComponent(
          size: Vector3(40, 1, 40),
          offset: Vector3(0, 0.5, 0),
        ),
      ],
    ),
    _prefab(
      'tp_block',
      'Block',
      Icons.check_box_outline_blank,
      'A 2 m block to stand on.',
      (at) => _box(models.block, at, Vector3(2, 2, 2)),
    ),
    _prefab(
      'tp_platform',
      'Moving Platform',
      Icons.swap_horiz,
      'A platform that goes 6 m and back, carrying what stands on it.',
      (at) => [
        ..._box(models.platform, at, Vector3(3, 0.4, 3)),
        RigidBody3DComponent(bodyType: Body3DType.kinematic),
        MovingPlatform3DComponent(
          travel: Vector3(6, 0, 0),
          speed: 2.5,
          wait: 1,
        ),
      ],
    ),
    _prefab(
      'tp_light',
      'Light',
      Icons.lightbulb_outline,
      'A point light 3 m above the surface.',
      (at) => [
        TransformComponent(position: at.position + Vector3(0, -3, 0)),
        Light3DComponent(range: 10),
      ],
    ),
    _prefab(
      'tp_pickup',
      'Coin',
      Icons.star_outline,
      'A coin to collect, a metre above the surface.',
      (at) => [
        TransformComponent(position: at.position + at.normal * 1.0),
        ModelComponent(model: models.coin, castShadows: false),
        Collider3DComponent(shape: Collider3DShape.sphere, radius: 0.35),
        RigidBody3DComponent(bodyType: Body3DType.kinematic, isSensor: true),
        Pickup3DComponent(),
      ],
    ),
    _prefab(
      'tp_killzone',
      'Kill Zone',
      Icons.dangerous_outlined,
      'A pit, water, a crusher: what enters it goes back to its spawn point.',
      (at) => [
        TransformComponent(position: at.position + at.normal * 1.0),
        Collider3DComponent(size: Vector3(4, 2, 4)),
        RigidBody3DComponent(bodyType: Body3DType.static, isSensor: true),
        KillZone3DComponent(),
      ],
    ),
    _prefab(
      'tp_checkpoint',
      'Checkpoint',
      Icons.flag_outlined,
      'Where the hero comes back after a fall, once reached.',
      (at) => [
        TransformComponent(position: at.position + at.normal * 1.0),
        ModelComponent(model: models.flag),
        Collider3DComponent(size: Vector3(1.5, 2, 1.5)),
        RigidBody3DComponent(bodyType: Body3DType.static, isSensor: true),
        Checkpoint3DComponent(),
      ],
    ),
  ];

  /// A unit-cube model scaled to [size], standing on [at].
  static List<Component> _box(String model, SurfacePoint at, Vector3 size) => [
    TransformComponent(
      position: at.position + at.normal * (size.y / 2),
      scale: Vector3.copy(size),
    ),
    ModelComponent(model: model),
    Collider3DComponent(size: Vector3(1, 1, 1)),
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
    build: (position, size) => buildAt(
      SurfacePoint(Vector3(position.dx, 0, position.dy), Vector3(0, -1, 0)),
    ),
  );
}
