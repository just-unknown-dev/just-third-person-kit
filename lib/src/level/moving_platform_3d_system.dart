import 'package:just_game_engine/just_game_engine.dart';

import 'moving_platform_3d_component.dart';

/// Moves [MovingPlatform3DComponent] platforms there and back; before physics, so a
/// kinematic body moves over the step and carries what stands on it.
class MovingPlatform3DSystem extends System {
  @override
  int get priority => SystemPriorities.playerControl + 1;

  @override
  List<Type> get requiredComponents => const [
    TransformComponent,
    MovingPlatform3DComponent,
  ];

  @override
  void update(double deltaTime) {
    if (deltaTime <= 0) return;
    for (final entity in entities) {
      if (!entity.isActive) continue;
      final p = entity.getComponent<MovingPlatform3DComponent>()!;
      final t = entity.getComponent<TransformComponent>()!;
      final start = p.start ??= Vector3.copy(t.position);
      final length = p.travel.length;
      if (length < 1e-6 || p.speed <= 0) continue;
      if (p.resting > 0) {
        p.resting -= deltaTime;
        if (p.resting > 1e-9) continue;
        p.resting = 0;
      }
      p.along += p.direction * p.speed * deltaTime / length;
      if (p.along >= 1 || p.along <= 0) {
        p.along = p.along.clamp(0.0, 1.0);
        p.direction = -p.direction;
        p.resting = p.wait;
      }
      t.position.setValues(
        start.x + p.travel.x * p.along,
        start.y + p.travel.y * p.along,
        start.z + p.travel.z * p.along,
      );
    }
  }
}
