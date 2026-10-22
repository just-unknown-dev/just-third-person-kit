/// The design-time half of the third-person kit: its pieces as prefabs in
/// a 3-D scene's viewport menu, scene-tree icons, markers and the moving
/// platforms' travel.
///
/// Kept out of `just_third_person_kit.dart` so the runtime library carries
/// no dependency on `just_game_engine_editor`. Import this only from a
/// debug entry point.
///
/// ```dart
/// JustGameEditorPlugin.register(engine: engine, modules: [ThirdPersonModule()]);
/// ```
library;

export 'src/editor/third_person_aids.dart';
export 'src/editor/third_person_module.dart';
