// A moving platform: there and back, resting at each end.
import 'package:flutter_test/flutter_test.dart';
import 'package:just_game_engine/just_game_engine.dart';
import 'package:just_third_person_kit/just_third_person_kit.dart';

const _dt = 1 / 60;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late World world;
  setUp(() {
    world = World()..initialize();
    addTearDown(world.dispose);
    world.addSystem(MovingPlatform3DSystem());
  });

  test('a platform goes to its travel and back, resting at each end', () {
    final lift = world.createEntityWithComponents([
      TransformComponent(position: Vector3(1, 0, 0)),
      MovingPlatform3DComponent(travel: Vector3(4, 0, 0), speed: 2, wait: 0.5),
    ]);
    double x() => lift.getComponent<TransformComponent>()!.position.x;
    for (var i = 0; i < 60; i++) {
      world.update(_dt);
    }
    expect(x(), closeTo(3, 1e-6));
    for (var i = 0; i < 60; i++) {
      world.update(_dt);
    }
    expect(x(), closeTo(5, 1e-6), reason: 'at the end, resting');
    for (var i = 0; i < 30 + 60; i++) {
      world.update(_dt);
    }
    expect(
      x(),
      closeTo(3, 0.05),
      reason: 'rested, then a second back (to a frame)',
    );
  });
}
