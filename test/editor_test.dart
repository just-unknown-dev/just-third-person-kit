// The kit in the editor: its prefabs stand on what they are placed on, its
// pieces have icons — and the runtime library never reaches the editor.
import 'dart:io';

import 'package:flutter/material.dart' show Icons;
import 'package:flutter_test/flutter_test.dart';
import 'package:just_game_engine/just_game_engine.dart';
import 'package:just_editor_core/just_editor_core.dart';
import 'package:just_game_engine/physics_3d.dart';
import 'package:just_third_person_kit/editor.dart';
import 'package:just_third_person_kit/just_third_person_kit.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final module = ThirdPersonModule();
  final ground = SurfacePoint(Vector3(2, 0, 3), Vector3(0, -1, 0));

  List<Component> build(String id) => module.prefabs.firstWhere((p) => p.id == id).buildAt!(ground);
  Vector3 at(List<Component> c) => c.whereType<TransformComponent>().single.position;

  test('every prefab is for 3-D scenes and places in space', () {
    expect(module.prefabs, hasLength(9));
    for (final p in module.prefabs) {
      expect(p.dimensions, Dimensions.threeD, reason: p.id);
      expect(p.buildAt, isNotNull, reason: p.id);
    }
    // A Level Designer kit for 3-D scenes, as the platformer kit is for 2-D.
    expect(module.providesLevelDesigner, isTrue);
    expect(module.designerModes, {SceneMode.threeD});
  });

  test('a kill zone: a sensor box a metre up, sending back what enters', () {
    final zone = build('tp_killzone');
    expect(at(zone).y, -1);
    expect(zone.whereType<KillZone3D>(), hasLength(1));
    expect(zone.whereType<RigidBody3D>().single.isSensor, isTrue);
  });

  group('its level aids', () {
    late World world;
    setUp(() {
      world = World()..initialize();
      addTearDown(world.dispose);
    });

    test("the hero's jump, from its controller and body (the prefab's with no hero)", () {
      const aids = ThirdPersonAids();
      final none = aids.movementOf(world);
      expect(none.jumpSpeed, ThirdPersonController().jumpSpeed);
      final hero = world.createEntityWithComponents([
        TransformComponent(),
        ThirdPersonController(jumpSpeed: 9.81, sprintSpeed: 5),
        CharacterBody3D(),
      ], name: 'Player');
      final move = aids.movementOf(world);
      expect(move.jumpHeight, closeTo(4.905, 1e-6));
      expect(move.jumpDistance, closeTo(10, 1e-6));
      expect(module.levelAids, isA<ThirdPersonAids>());

      // Put back once it falls past its fall limit below where it starts.
      world.createEntityWithComponents([TransformComponent(position: Vector3(0, -2, 0)), SpawnComponent()], name: 'Spawn');
      expect(aids.killHeight(world), closeTo(-2 + hero.getComponent<ThirdPersonController>()!.fallLimit, 1e-9));

      expect(aids.playFrom(world, Vector3(7, -1, 3)), isTrue);
      expect(hero.getComponent<TransformComponent>()!.position.x, 7);
    });
  });

  test('the player stands on its feet where placed; a block stands on the surface', () {
    final player = build('tp_player');
    expect([at(player).x, at(player).y, at(player).z], [2, 0, 3]);
    expect(player.whereType<CharacterBody3D>(), hasLength(1));
    expect(player.whereType<ThirdPersonController>(), hasLength(1));
    final block = build('tp_block');
    expect(at(block).y, -1, reason: 'a 2 m block, its centre 1 m up (-Y)');
    final coin = build('tp_pickup');
    expect(at(coin).y, -1, reason: 'a metre above the surface');
    expect(coin.whereType<RigidBody3D>().single.isSensor, isTrue);
  });

  test("the kit's pieces have icons in the scene tree", () {
    final world = World()..initialize();
    addTearDown(world.dispose);
    final icon = module.entityIcons.single.of;
    expect(icon(world.createEntityWithComponents([Pickup3D()])), Icons.star_outline);
    expect(icon(world.createEntityWithComponents([Checkpoint3D()])), Icons.flag_outlined);
    expect(icon(world.createEntity()), isNull);
  });

  test('the runtime library never reaches the editor', () {
    final seen = <String>{};
    final pending = ['lib/just_third_person_kit.dart'];
    final import = RegExp(r"^(?:import|export)\s+'([^']+)'", multiLine: true);
    while (pending.isNotEmpty) {
      final path = pending.removeLast();
      if (!seen.add(path)) continue;
      for (final m in import.allMatches(File(path).readAsStringSync())) {
        final uri = m.group(1)!;
        expect(uri, isNot(contains('just_game_engine_editor')), reason: '$path imports $uri');
        expect(uri, isNot(contains('just_graphics_engine')), reason: '$path imports $uri');
        if (!uri.contains(':')) pending.add(Uri.parse(path).resolve(uri).path);
      }
    }
    expect(seen.any((p) => p.contains('src/editor/')), isFalse);
  });
}
