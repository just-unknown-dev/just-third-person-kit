// The camera's player controls: the look turns the orbit, the zoom moves it
// in and out within its limits, its look reader lives as long as the
// system is in a world, and nothing turns while time stands still.
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
  });

  test("the camera's look turns the orbit; down looks down, clamped", () {
    final orbit = OrbitFollowComponent(
      yaw: 0,
      pitch: -0.3,
      minPitch: -1,
      maxPitch: 0.5,
    );
    final camera = ThirdPersonCameraComponent(sensitivity: 2);
    ThirdPersonCameraSystem.applyLook(orbit, camera, const Offset(0.1, 0.05));
    expect(orbit.yaw, closeTo(0.2, 1e-9));
    expect(orbit.pitch, closeTo(-0.4, 1e-9));
    ThirdPersonCameraSystem.applyLook(
      orbit,
      camera..invertY = true,
      const Offset(0, 0.05),
    );
    expect(orbit.pitch, closeTo(-0.3, 1e-9));
    ThirdPersonCameraSystem.applyLook(
      orbit,
      camera..invertY = false,
      const Offset(0, 10),
    );
    expect(orbit.pitch, -1);
  });

  test(
    'the zoom moves it in and out by a share of the distance a second, kept within its limits',
    () {
      final orbit = OrbitFollowComponent(
        distance: 6,
        minDistance: 2,
        maxDistance: 12,
      );
      final camera = ThirdPersonCameraComponent(zoomSpeed: 1.5);
      ThirdPersonCameraSystem.applyZoom(orbit, camera, 1, 0.5);
      expect(
        orbit.distance,
        closeTo(6 * 0.4723665527410147, 1e-9),
        reason: 'in: e^-0.75 of the way',
      );
      ThirdPersonCameraSystem.applyZoom(orbit, camera, -1, 0.5);
      expect(orbit.distance, closeTo(6, 1e-9), reason: 'out again as far');
      ThirdPersonCameraSystem.applyZoom(orbit, camera, 1, 10);
      expect(orbit.distance, 2, reason: 'no nearer than its nearest');
      ThirdPersonCameraSystem.applyZoom(orbit, camera, -1, 10);
      expect(orbit.distance, 12, reason: 'no farther than its farthest');
      ThirdPersonCameraSystem.applyZoom(orbit, camera, -1, 0);
      ThirdPersonCameraSystem.applyZoom(orbit, camera, 0, 1);
      expect(orbit.distance, 12, reason: 'no time, or no zoom: no change');
    },
  );

  test(
    'it makes its look reader when it joins a world and lets it go when it leaves',
    () {
      final input = InputService();
      addTearDown(input.dispose);
      final systems = ThirdPersonKit.systems(
        input: input,
        camera: OutputCamera(position: Offset.zero, zoom: 1),
      );
      final camera = systems.whereType<ThirdPersonCameraSystem>().single;
      expect(
        camera.look,
        isNull,
        reason: 'a list made only to look at listens to nothing',
      );

      world.addSystem(camera);
      expect(camera.look, isNotNull);
      world.removeSystem(camera);
      expect(camera.look, isNull);
    },
  );

  test('it turns the view before the camera brain frames it', () {
    final camera = ThirdPersonCameraSystem(actions: InputService().actions);
    expect(camera.priority, greaterThan(SystemPriorities.camera));
  });

  group('the mouse look', () {
    late InputService input;
    late OrbitFollowComponent orbit;

    setUp(() {
      input = InputService()
        ..loadAsset(LookActions.addTo(InputActionAsset.empty));
      addTearDown(input.dispose);
      final system = ThirdPersonCameraSystem(actions: input.actions);
      world.addSystem(system);
      // Its look reader is let go before the input service.
      addTearDown(() => world.removeSystem(system));
      orbit = OrbitFollowComponent(yaw: 0.25, pitch: -0.3);
      world.createEntityWithComponents([
        orbit,
        ThirdPersonCameraComponent(),
      ], name: 'Camera Rig');
    });

    test('turns the orbit while time runs', () {
      input.mouse.injectDelta(const Offset(100, 0));
      world.frame(_dt, 1);
      expect(orbit.yaw, greaterThan(0.25));
    });

    test(
      'turns nothing while time stands still, and is dropped rather than kept for later',
      () {
        // An editor authoring the level, or a pause: the rig keeps the turn
        // it was given (and saved with).
        input.mouse.injectDelta(const Offset(100, 40));
        world.frame(0, 1);
        expect((orbit.yaw, orbit.pitch), (0.25, -0.3));
        world.frame(_dt, 1);
        expect(
          (orbit.yaw, orbit.pitch),
          (0.25, -0.3),
          reason: 'no jump as time moves again',
        );
      },
    );
  });
}
