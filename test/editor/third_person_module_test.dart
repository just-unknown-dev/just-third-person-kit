// The kit in the editor: a Level Designer kit for 3-D scenes whose prefabs
// stand on what they are placed on, and whose pieces have icons.
import 'package:flutter/material.dart' show Icons;
import 'package:flutter_test/flutter_test.dart';
import 'package:just_editor_core/just_editor_core.dart';
import 'package:just_game_engine/just_game_engine.dart';
import 'package:just_game_engine/just_game_engine_3d.dart';
import 'package:just_third_person_kit/editor.dart';
import 'package:just_third_person_kit/just_third_person_kit.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final module = ThirdPersonModule();
  final ground = SurfacePoint(Vector3(2, 0, 3), Vector3(0, -1, 0));

  List<Component> build(String id) =>
      module.prefabs.firstWhere((p) => p.id == id).buildAt!(ground);
  Vector3 at(List<Component> c) =>
      c.whereType<TransformComponent>().single.position;

  test('every prefab is for 3-D scenes and places in space', () {
    expect(module.prefabs, hasLength(9));
    for (final p in module.prefabs) {
      expect(p.dimensions, Dimensions.threeD, reason: p.id);
      expect(p.buildAt, isNotNull, reason: p.id);
    }
    // A Level Designer kit for 3-D scenes, as the platformer kit is for 2-D.
    expect(module.providesLevelDesigner, isTrue);
    expect(module.designerModes, {SceneMode.threeD});
    expect(module.levelAids, isA<ThirdPersonAids>());
  });

  test('a kill zone: a sensor box a metre up, sending back what enters', () {
    final zone = build('tp_killzone');
    expect(at(zone).y, -1);
    expect(zone.whereType<KillZone3DComponent>(), hasLength(1));
    expect(zone.whereType<RigidBody3DComponent>().single.isSensor, isTrue);
  });

  test(
    'the player stands on its feet where placed; a block stands on the surface',
    () {
      final player = build('tp_player');
      expect([at(player).x, at(player).y, at(player).z], [2, 0, 3]);
      expect(player.whereType<CharacterBody3DComponent>(), hasLength(1));
      expect(player.whereType<ThirdPersonControllerComponent>(), hasLength(1));
      final block = build('tp_block');
      expect(at(block).y, -1, reason: 'a 2 m block, its centre 1 m up (-Y)');
      final coin = build('tp_pickup');
      expect(at(coin).y, -1, reason: 'a metre above the surface');
      expect(coin.whereType<RigidBody3DComponent>().single.isSensor, isTrue);
    },
  );

  test("the kit's pieces have icons in the scene tree", () {
    final world = World()..initialize();
    addTearDown(world.dispose);
    final icon = module.entityIcons.single.of;
    expect(
      icon(world.createEntityWithComponents([Pickup3DComponent()])),
      Icons.star_outline,
    );
    expect(
      icon(world.createEntityWithComponents([Checkpoint3DComponent()])),
      Icons.flag_outlined,
    );
    expect(icon(world.createEntity()), isNull);
  });

  test('its overlays are for 3-D scenes, each under its own id', () {
    final overlays = module.viewportOverlays;
    expect(overlays.map((o) => o.runtimeType), [
      PlatformTravelOverlay,
      JumpReachOverlay,
      WalkableSlopeOverlay,
    ]);
    expect(overlays.map((o) => o.id).toSet(), hasLength(3));
    for (final o in overlays) {
      expect(o.dimensions, Dimensions.threeD, reason: o.id);
    }
  });
}
