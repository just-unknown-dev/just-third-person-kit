/// The design-time half of the third-person kit: its pieces as prefabs in
/// a 3-D scene's viewport menu, scene-tree icons, markers and the moving
/// platforms' travel.
///
/// Kept out of `just_third_person_kit.dart` so the runtime library carries
/// no dependency on `just_editor_core`, the editor's module contract.
/// Import this only from a debug entry point.
///
/// ```dart
/// await JustGameEditorPlugin.register(engine: engine, modules: [ThirdPersonModule()]);
/// ```
library;

export 'src/editor/editor.dart';
