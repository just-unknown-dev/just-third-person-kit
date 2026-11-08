// Pickups: taken by a player's touch, counted and gone; bobbing and
// spinning from the way they were placed, and left as placed while time
// stands still (an editor authoring the level).
import 'package:flutter_test/flutter_test.dart';
import 'package:just_game_engine/just_game_engine.dart';
import 'package:just_game_engine/just_game_engine_3d.dart';
import 'package:just_third_person_kit/just_third_person_kit.dart';

const _dt = 1 / 60;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late World world;
  setUp(() {
    world = World()..initialize();
    addTearDown(world.dispose);
    world.addSystem(Pickup3DSystem());
  });

  test(
    'a pickup touched by a player is taken, counted and gone; it bobs till then',
    () {
      final player = world.createEntityWithComponents([
        TransformComponent(),
        ThirdPersonControllerComponent(),
      ], name: 'Hero');
      final coin = world.createEntityWithComponents([
        TransformComponent(position: Vector3(0, -1, 3)),
        Pickup3DComponent(value: 5),
      ], name: 'Coin');
      world.update(0.25);
      expect(
        coin.getComponent<TransformComponent>()!.position.y,
        isNot(-1),
        reason: 'bobbing',
      );
      final taken = <PickupCollected3DEvent>[];
      world.events.on<PickupCollected3DEvent>(taken.add);
      // A stranger touching it takes nothing.
      world.events.fire(
        SensorEnter3DEvent(sensor: coin, other: world.createEntity()),
      );
      world.update(_dt);
      expect(taken, isEmpty);
      world.events.fire(SensorEnter3DEvent(sensor: coin, other: player));
      world.update(_dt);
      expect(taken.single.value, 5);
      expect(taken.single.collector, player);
      expect(coin.isAlive, isFalse);
    },
  );

  test(
    'stays where it is moved, and as it is turned, while time stands still',
    () {
      final coin = world.createEntityWithComponents([
        TransformComponent(position: Vector3(0, -1, 3)),
        Pickup3DComponent(),
      ]);
      final t = coin.getComponent<TransformComponent>()!;
      world.update(0);
      // The designer drags and turns it.
      t
        ..setPositionXYZ(5, -1, 3)
        ..setEuler(0, 0.7, 0);
      for (var i = 0; i < 5; i++) {
        world.update(0);
      }
      expect([t.position.x, t.position.y, t.position.z], [5, -1, 3]);
      expect(t.eulerY, closeTo(0.7, 1e-9));
    },
  );

  test('spins from the way it was placed', () {
    final coin = world.createEntityWithComponents([
      TransformComponent(position: Vector3(0, -1, 3))..setEuler(0, 0.5, 0),
      Pickup3DComponent(spinSpeed: 2),
    ]);
    world.update(0.25);
    expect(
      coin.getComponent<TransformComponent>()!.eulerY,
      closeTo(0.5 + 0.5, 1e-6),
    );
  });
}
