// Levels saved with the kit's older component names load under the new
// ones: from before every name ended in `Component` (scene format 10), and
// from a scene already at the current format that still names them.
import 'package:flutter_test/flutter_test.dart';
import 'package:just_game_engine/just_game_engine.dart';
import 'package:just_third_person_kit/just_third_person_kit.dart';

/// A scene at [version] with one entity per old name, each holding one
/// component of that type.
Map<String, dynamic> _sceneNaming(
  Iterable<String> types, {
  required int version,
}) => {
  'version': version,
  'name': 's',
  'entities': [
    for (final type in types)
      {
        'name': type,
        'components': [
          {'type': type, 'fields': <String, dynamic>{}},
        ],
      },
  ],
};

List<Object?> _typesIn(Map<String, dynamic> scene) => [
  for (final e in scene['entities'] as List)
    ((e as Map)['components'] as List).single['type'],
];

void main() {
  final context = EngineContext(extensions: [ThirdPersonKit.extension]);
  final old = ThirdPersonMigrations.renamedTypes.keys.toList();

  test('v10 kit components load under their new names', () {
    final scene = SceneFormat.migrate(
      _sceneNaming(old, version: 10),
      hooks: context.migrations,
    );
    final types = _typesIn(scene);
    expect(types, ThirdPersonMigrations.renamedTypes.values.toList());
    for (final type in types) {
      expect(
        context.definitions.definitionByType(type as String),
        isNotNull,
        reason: type,
      );
    }
  });

  test(
    'a scene at the current format that names an old component loads it under its new name',
    () {
      final scene = SceneFormat.migrate(
        _sceneNaming(old, version: SceneFormat.current),
        hooks: context.migrations,
      );
      expect(
        _typesIn(scene),
        ThirdPersonMigrations.renamedTypes.values.toList(),
      );
    },
  );

  test('a scene naming only the current names is left as it is', () {
    final current = _sceneNaming(
      ThirdPersonMigrations.renamedTypes.values,
      version: SceneFormat.current,
    );
    expect(
      identical(
        SceneFormat.migrate(current, hooks: context.migrations),
        current,
      ),
      isTrue,
    );
  });
}
