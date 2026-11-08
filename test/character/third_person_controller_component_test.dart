// What the controller works out of its own state: how fast it moves along
// the ground, and the height past which a fall puts it back.
import 'package:flutter_test/flutter_test.dart';
import 'package:just_game_engine/just_game_engine.dart';
import 'package:just_third_person_kit/just_third_person_kit.dart';

void main() {
  test('its planar speed ignores the vertical', () {
    final c = ThirdPersonControllerComponent()
      ..planarVelocity.setValues(3, 9, 4);
    expect(c.planarSpeed, 5);
  });

  test(
    'its kill height is the fall limit below the lower of its spawn point and its lowest so far',
    () {
      final c = ThirdPersonControllerComponent(fallLimit: 10);
      expect(c.killHeight, isNull, reason: 'no spawn point yet');
      c.spawnPoint = Vector3(0, -4, 0);
      expect(c.killHeight, 6);
      c.lowestSpawnY = 2; // once lower than the spawn point (+Y is down)
      expect(
        c.killHeight,
        12,
        reason: 'a checkpoint higher up does not raise it',
      );
      c.spawnPoint = Vector3(0, 5, 0);
      expect(c.killHeight, 15, reason: 'a checkpoint lower down lowers it');
    },
  );
}
