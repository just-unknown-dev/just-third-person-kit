import 'dart:math' as math;

import 'package:just_game_engine/just_game_engine.dart';
import 'package:just_game_engine/just_game_engine_3d.dart';

import '../character/character.dart';
import 'level_3d_events.dart';
import 'pickup_3d_component.dart';

/// Spins and bobs pickups, and hands one to the player whose character
/// touches it.
///
/// The spin and bob stand still while time does (a `deltaTime` of 0: paused,
/// or an editor authoring the level), so a pickup stays where — and turned
/// the way — it was placed, and starts from there when play does.
class Pickup3DSystem extends System {
  /// The system; it listens on the world's events once added.
  Pickup3DSystem();

  @override
  List<Type> get requiredComponents => const [
    TransformComponent,
    Pickup3DComponent,
  ];

  final List<(Entity, Entity)> _touched = [];
  EventSubscription? _subscription;

  @override
  void onAddedToWorld() {
    super.onAddedToWorld();
    _subscription = world.events.on<SensorEnter3DEvent>((e) {
      final pickup = e.sensor.getComponent<Pickup3DComponent>();
      if (pickup != null &&
          !pickup.isCollected &&
          e.other.hasComponent<ThirdPersonControllerComponent>()) {
        _touched.add((e.sensor, e.other));
      }
    });
  }

  @override
  void onRemovedFromWorld() {
    _subscription?.cancel();
    _subscription = null;
    super.onRemovedFromWorld();
  }

  @override
  void update(double deltaTime) {
    for (final (pickup, collector) in _touched) {
      final p = pickup.getComponent<Pickup3DComponent>();
      if (p == null || p.isCollected || !pickup.isAlive) continue;
      p.collect();
      world.events.fire(PickupCollected3DEvent(pickup, collector, p.value));
      world.destroyEntity(pickup);
    }
    _touched.clear();
    if (deltaTime <= 0) return;
    for (final entity in entities) {
      if (!entity.isActive) continue;
      final p = entity.getComponent<Pickup3DComponent>()!;
      final t = entity.getComponent<TransformComponent>()!;
      final home = p.home ??= Vector3.copy(t.position);
      final placed = p.homeRotation ??= _rotationOf(t);
      p.time += deltaTime;
      t.position.setValues(
        home.x,
        home.y - math.sin(p.time * p.bobSpeed) * p.bobHeight,
        home.z,
      );
      // Its spin about the up axis, after the way it was placed.
      _spin
        ..setAxisAngle(0, 1, 0, p.time * p.spinSpeed)
        ..multiply(placed);
      t.setRotation(_spin);
    }
  }

  static Quaternion _rotationOf(TransformComponent t) {
    final q = Quaternion.identity();
    t.rotationInto(q);
    return q;
  }

  static final Quaternion _spin = Quaternion.identity();
}
