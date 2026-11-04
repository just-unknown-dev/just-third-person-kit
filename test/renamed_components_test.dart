// Levels saved before every component's name ended in `Component` (scene
// format 10) load with the kit's components under their new names.
import 'package:flutter_test/flutter_test.dart';
import 'package:just_game_engine/just_game_engine.dart';
import 'package:just_third_person_kit/just_third_person_kit.dart';

void main() {
  test('v10 kit components load under their new names', () {
    final context = EngineContext(extensions: [ThirdPersonKit.extension]);
    final old = ThirdPersonKit.renamedTypes.keys.toList();
    final scene = SceneFormat.migrate({
      'version': 10,
      'name': 's',
      'entities': [
        for (final type in old)
          {
            'name': type,
            'components': [
              {'type': type, 'fields': <String, dynamic>{}},
            ],
          },
      ],
    }, hooks: context.migrations);
    final types = [
      for (final e in scene['entities'] as List)
        ((e as Map)['components'] as List).single['type'],
    ];
    expect(types, ThirdPersonKit.renamedTypes.values.toList());
    for (final type in types) {
      expect(
        context.definitions.definitionByType(type as String),
        isNotNull,
        reason: type,
      );
    }
  });
}
