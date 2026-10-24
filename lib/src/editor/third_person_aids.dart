import 'dart:math' as math;
import 'dart:ui';

import 'package:just_game_engine/just_game_engine.dart';
import 'package:just_editor_core/just_editor_core.dart';
import 'package:just_game_engine/graphics_3d.dart';
import 'package:just_game_engine/physics_3d.dart';

import '../third_person_components.dart';

/// What the third-person kit knows of how its levels are played: its
/// hero's jump (from its [ThirdPersonController] and [CharacterBody3D], or
/// the Player prefab's when the level has no hero yet), the height its
/// fall limit puts back at, and playing from a point.
final class ThirdPersonAids extends LevelAids {
  const ThirdPersonAids();

  /// Gravity, as the 3-D physics has it by default (m/s²): what the aids
  /// use while the world has no 3-D physics of its own yet.
  static const double gravity = 9.81;

  /// How hard [world]'s 3-D physics pulls down (m/s²): its own gravity once
  /// it has a physics world, [gravity] before.
  static double gravityOf(World world) {
    final system = world.getSystem<PhysicsSystem3D>();
    if (system == null || !system.hasWorld) return gravity;
    final g = system.physics.gravity;
    // +Y is down.
    return g.y > 0 ? g.y : g.length;
  }

  /// The level's hero: the entity with a [ThirdPersonController].
  static Entity? heroOf(World world) {
    for (final e in world.entities) {
      if (e.isAlive && e.hasComponent<ThirdPersonController>()) return e;
    }
    return null;
  }

  @override
  MovementProfile movementOf(World world) {
    final hero = heroOf(world);
    final controller = hero?.getComponent<ThirdPersonController>() ?? ThirdPersonController();
    final body = hero?.getComponent<CharacterBody3D>() ?? CharacterBody3D();
    return MovementProfile(
      jumpSpeed: controller.jumpSpeed,
      gravity: gravityOf(world) * (body.useGravity ? body.gravityScale : 0),
      runSpeed: controller.sprintSpeed,
      maxSlopeDegrees: body.maxSlopeAngle * 180 / math.pi,
      stepHeight: body.stepHeight,
    );
  }

  @override
  double? killHeight(World world) {
    final hero = heroOf(world);
    final controller = hero?.getComponent<ThirdPersonController>();
    if (controller == null) return null;
    // Measured as `Respawn3DSystem` measures it, from where the hero is put
    // back: its spawn point once it has one (in play); else the level's
    // player spawn point, where a spawner would put it; else where it stands.
    final at =
        controller.spawnPoint ??
        (SpawnPoints.of(world, 'player').firstOrNull ?? hero)?.getComponent<TransformComponent>()?.position;
    return at == null ? null : at.y + controller.fallLimit;
  }

  @override
  bool playFrom(World world, Vector3 at) {
    final hero = heroOf(world);
    final t = hero?.getComponent<TransformComponent>();
    if (t == null) return false;
    t.position.setFrom(at);
    world.transformHierarchy.propagateFrom(hero!);
    return true;
  }
}

/// How far the hero's running jump reaches from what is selected: a ring
/// round the middle of its top, as wide as the jump carries, and a tick as
/// high as it rises — so a designer sees whether the next platform can be
/// reached.
final class JumpReachOverlay extends ViewportOverlay {
  @override
  String get id => 'thirdPerson.jumpReach';

  @override
  String get label => 'Jump reach';

  @override
  Dimensions get dimensions => Dimensions.threeD;

  @override
  void paint(ViewportOverlayContext context) {
    final selected = context.scope.sceneState.selectedEntity.value;
    if (selected == null || !selected.isAlive || selected.hasComponent<ThirdPersonController>()) return;
    final box = Aabb3();
    if (!RayEntityPicker.boundsOf(selected, box)) return;
    final move = const ThirdPersonAids().movementOf(context.world);
    final top = Vector3((box.min.x + box.max.x) / 2, box.min.y, (box.min.z + box.max.z) / 2);
    final reach = move.jumpDistance + math.max(box.max.x - box.min.x, box.max.z - box.min.z) / 2;
    final ring = Path();
    var started = false;
    for (var i = 0; i <= 64; i++) {
      final a = 2 * math.pi * i / 64;
      final p = context.project(top + Vector3(math.cos(a) * reach, 0, math.sin(a) * reach));
      if (p == null) {
        started = false;
        continue;
      }
      if (started) {
        ring.lineTo(p.dx, p.dy);
      } else {
        ring.moveTo(p.dx, p.dy);
        started = true;
      }
    }
    final colour = const Color(0xFF81C784);
    context.canvas.drawPath(
      ring,
      Paint()
        ..color = colour.withValues(alpha: 0.8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    final a = context.project(top), b = context.project(top + Vector3(0, -move.jumpHeight, 0));
    if (a != null && b != null) {
      context.canvas
        ..drawLine(a, b, Paint()..color = colour..strokeWidth = 2)
        ..drawCircle(b, 3, Paint()..color = colour);
      _label(
        context.canvas,
        b + const Offset(6, -6),
        'Jump ${move.jumpHeight.toStringAsFixed(1)} m up, ${move.jumpDistance.toStringAsFixed(1)} m across',
        colour,
      );
    }
  }
}

/// A selected slope's steepness — a ramp's, a staircase's — green when
/// the hero walks up it, red when it is too steep.
final class WalkableSlopeOverlay extends ViewportOverlay {
  @override
  String get id => 'thirdPerson.walkableSlope';

  @override
  String get label => 'Walkable slopes';

  @override
  Dimensions get dimensions => Dimensions.threeD;

  @override
  void paint(ViewportOverlayContext context) {
    final selected = context.scope.sceneState.selectedEntity.value;
    final shape = selected?.getComponent<Primitive3D>();
    final t = selected?.getComponent<TransformComponent>();
    if (selected == null || t == null) return;
    final (rise, run) = switch (shape) {
      Ramp3D s => (s.height * t.scale.y.abs(), s.depth * t.scale.z.abs()),
      Stairs3D s => (s.height * t.scale.y.abs(), s.depth * t.scale.z.abs()),
      _ => (0.0, 0.0),
    };
    if (run <= 0) return;
    final degrees = math.atan2(rise, run) * 180 / math.pi;
    final move = const ThirdPersonAids().movementOf(context.world);
    final walkable = shape is Stairs3D
        ? rise / math.max(1, (shape).steps) <= move.stepHeight
        : degrees <= move.maxSlopeDegrees;
    final at = context.project(t.position);
    if (at == null) return;
    _label(
      context.canvas,
      at + const Offset(10, 10),
      shape is Stairs3D
          ? (walkable ? 'Steps walkable' : 'Steps too high to walk up')
          : '${degrees.round()}° ${walkable ? 'walkable' : 'too steep'}',
      walkable ? const Color(0xFF81C784) : const Color(0xFFE57373),
    );
  }
}

void _label(Canvas canvas, Offset at, String text, Color colour) {
  final builder = ParagraphBuilder(ParagraphStyle(fontSize: 11))
    ..pushStyle(TextStyle(color: colour, fontSize: 11))
    ..addText(text);
  final paragraph = builder.build()..layout(const ParagraphConstraints(width: 320));
  final box = Rect.fromLTWH(at.dx - 4, at.dy - 2, paragraph.longestLine + 8, paragraph.height + 4);
  canvas
    ..drawRRect(RRect.fromRectAndRadius(box, const Radius.circular(3)), Paint()..color = const Color(0xCC1E1F24))
    ..drawParagraph(paragraph, at);
}
