// How the kit's components are saved and loaded: every one under its own
// type, 3-D, round-tripped; numbers with floors; the input actions they
// read marked as such.
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:just_game_engine/just_game_engine.dart';
import 'package:just_third_person_kit/just_third_person_kit.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'every definition is a 3-D component of its own type, in the group "Third Person"',
    () {
      final types = [for (final d in ThirdPersonDefinitions.all) d.type];
      expect(types.toSet(), hasLength(types.length));
      for (final d in ThirdPersonDefinitions.all) {
        expect(d.type, endsWith('Component'), reason: d.type);
        expect(d.hints.dimensions, Dimensions.threeD, reason: d.type);
        expect(d.hints.group, 'Third Person', reason: d.type);
      }
    },
  );

  test('a saved controller loads with its settings', () {
    final context = EngineContext(extensions: [ThirdPersonKit.extension]);
    final saved = context.definitions.encode(
      ThirdPersonControllerComponent(fallLimit: 25, jumpSpeed: 7),
    );
    final loaded =
        context.definitions.decode(saved!) as ThirdPersonControllerComponent;
    expect((loaded.fallLimit, loaded.jumpSpeed), (25, 7));
    expect(
      saved['fields'] as Map,
      isNot(contains('lowestSpawnY')),
      reason: 'run time is not saved',
    );
  });

  test('numbers have floors: a negative turn speed loads as none', () {
    final context = EngineContext(extensions: [ThirdPersonKit.extension]);
    final controller =
        context.definitions.decode({
              'type': 'ThirdPersonControllerComponent',
              'fields': {
                'turnSpeed': -5,
                'walkSpeed': -1,
                'facingOffset': -math.pi,
              },
            })
            as ThirdPersonControllerComponent;
    expect(controller.turnSpeed, 0);
    expect(controller.walkSpeed, 0);
    expect(
      controller.facingOffset,
      -math.pi,
      reason: 'an angle may be negative',
    );
  });

  group('the input actions they read are input action fields', () {
    const actions = {
      'ThirdPersonControllerComponent': [
        'moveAction',
        'jumpAction',
        'sprintAction',
        'crouchAction',
      ],
      'ThirdPersonCombatComponent': ['punchAction', 'kickAction'],
      'ThirdPersonCameraComponent': ['zoomAction'],
    };

    test('every …Action field is of the input action kind', () {
      for (final d in ThirdPersonDefinitions.all) {
        final marked = [
          for (final f in d.fields)
            if (InputDefinitions.isActionKind(f.kind)) f.name,
        ];
        expect(marked, actions[d.type] ?? const <String>[], reason: d.type);
      }
    });

    test("a combat chain's name is not an input action", () {
      final combat = ThirdPersonDefinitions.combat.fields;
      for (final name in ['punchChain', 'kickChain']) {
        expect(
          combat.singleWhere((f) => f.name == name).kind,
          FieldTypes.text,
          reason: '$name names a chain in the combo set',
        );
      }
    });

    test('saved as before: the action names are plain text', () {
      final context = EngineContext(extensions: [ThirdPersonKit.extension]);
      addTearDown(context.dispose);
      final saved = context.definitions.encode(
        ThirdPersonControllerComponent(jumpAction: 'hop'),
      )!;
      final fields = saved['fields'] as Map;
      expect(fields['jumpAction'], 'hop');
      expect(fields['moveAction'], 'move');
      final loaded =
          context.definitions.decode({
                'type': 'ThirdPersonCameraComponent',
                'fields': {'zoomAction': 'player/zoom'},
              })
              as ThirdPersonCameraComponent;
      expect(loaded.zoomAction, 'player/zoom');
    });
  });
}
