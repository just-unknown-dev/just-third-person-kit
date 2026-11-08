/// Third-person gameplay for just_game_engine in 3D.
///
/// - [ThirdPersonControllerComponent]: moves a `CharacterBody3DComponent`
///   from its input, relative to where the camera looks, with coyote time
///   and a buffered jump, turning to face the way it runs.
/// - [ThirdPersonCombatComponent]: punch and kick chains from a
///   [ComboSet], each blow told by a [StrikeHit3DEvent].
/// - [ThirdPersonCameraComponent]: turns and zooms an orbit-follow camera
///   from the look and zoom actions, once per rendered frame.
/// - [Pickup3DComponent], [MovingPlatform3DComponent],
///   [Checkpoint3DComponent], [KillZone3DComponent]: the level's pieces.
///
/// [ThirdPersonKit] installs it all. This library never reaches the
/// editor: its design-time half is `package:just_third_person_kit/editor.dart`.
library;

export 'src/camera/camera.dart';
export 'src/character/character.dart';
export 'src/kit/kit.dart';
export 'src/level/level.dart';
