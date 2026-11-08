import 'dart:math' as math;
import 'dart:ui';

import 'package:just_editor_core/just_editor_core.dart';
import 'package:just_game_engine/just_game_engine.dart';
import 'package:just_game_engine/just_game_engine_3d.dart';

import '../character/character.dart';
import '../level/level.dart';
import 'third_person_aids.dart';

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
    for (final e in context.world.query([
      TransformComponent,
      MovingPlatform3DComponent,
    ])) {
      if (!context.isShown(e) || !context.isSelected(e)) continue;
      final p = e.getComponent<MovingPlatform3DComponent>()!;
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
    if (selected == null ||
        !selected.isAlive ||
        selected.hasComponent<ThirdPersonControllerComponent>()) {
      return;
    }
    final box = Aabb3();
    if (!RayEntityPicker.boundsOf(selected, box)) return;
    final move = const ThirdPersonAids().movementOf(context.world);
    final top = Vector3(
      (box.min.x + box.max.x) / 2,
      box.min.y,
      (box.min.z + box.max.z) / 2,
    );
    final reach =
        move.jumpDistance +
        math.max(box.max.x - box.min.x, box.max.z - box.min.z) / 2;
    final ring = Path();
    var started = false;
    for (var i = 0; i <= 64; i++) {
      final a = 2 * math.pi * i / 64;
      final p = context.project(
        top + Vector3(math.cos(a) * reach, 0, math.sin(a) * reach),
      );
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
    final color = const Color(0xFF81C784);
    context.canvas.drawPath(
      ring,
      Paint()
        ..color = color.withValues(alpha: 0.8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    final a = context.project(top),
        b = context.project(top + Vector3(0, -move.jumpHeight, 0));
    if (a != null && b != null) {
      context.canvas
        ..drawLine(
          a,
          b,
          Paint()
            ..color = color
            ..strokeWidth = 2,
        )
        ..drawCircle(b, 3, Paint()..color = color);
      _label(
        context.canvas,
        b + const Offset(6, -6),
        'Jump ${move.jumpHeight.toStringAsFixed(1)} m up, ${move.jumpDistance.toStringAsFixed(1)} m across',
        color,
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
    final shape = selected?.getComponent<Primitive3DComponent>();
    final t = selected?.getComponent<TransformComponent>();
    if (selected == null || t == null) return;
    final (rise, run) = switch (shape) {
      Ramp3DComponent s => (
        s.height * t.scale.y.abs(),
        s.depth * t.scale.z.abs(),
      ),
      Stairs3DComponent s => (
        s.height * t.scale.y.abs(),
        s.depth * t.scale.z.abs(),
      ),
      _ => (0.0, 0.0),
    };
    if (run <= 0) return;
    final degrees = math.atan2(rise, run) * 180 / math.pi;
    final move = const ThirdPersonAids().movementOf(context.world);
    final walkable = shape is Stairs3DComponent
        ? rise / math.max(1, (shape).steps) <= move.stepHeight
        : degrees <= move.maxSlopeDegrees;
    final at = context.project(t.position);
    if (at == null) return;
    _label(
      context.canvas,
      at + const Offset(10, 10),
      shape is Stairs3DComponent
          ? (walkable ? 'Steps walkable' : 'Steps too high to walk up')
          : '${degrees.round()}° ${walkable ? 'walkable' : 'too steep'}',
      walkable ? const Color(0xFF81C784) : const Color(0xFFE57373),
    );
  }
}

void _label(Canvas canvas, Offset at, String text, Color color) {
  final builder = ParagraphBuilder(ParagraphStyle(fontSize: 11))
    ..pushStyle(TextStyle(color: color, fontSize: 11))
    ..addText(text);
  final paragraph = builder.build()
    ..layout(const ParagraphConstraints(width: 320));
  final box = Rect.fromLTWH(
    at.dx - 4,
    at.dy - 2,
    paragraph.longestLine + 8,
    paragraph.height + 4,
  );
  canvas
    ..drawRRect(
      RRect.fromRectAndRadius(box, const Radius.circular(3)),
      Paint()..color = const Color(0xCC1E1F24),
    )
    ..drawParagraph(paragraph, at);
}
