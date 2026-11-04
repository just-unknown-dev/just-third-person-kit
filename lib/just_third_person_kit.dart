/// Third-person gameplay for just_game_engine in 3D.
///
/// - [ThirdPersonControllerComponent]: moves a `CharacterBody3DComponent` from its input,
///   relative to where the camera looks, with coyote time and a buffered
///   jump, turning to face the way it runs.
/// - [ThirdPersonCombatComponent]: punch and kick chains from a [ComboSet], each
///   blow told by a [StrikeHit3DEvent].
/// - [ThirdPersonCameraComponent]: turns and zooms an orbit-follow camera from the
///   look and zoom actions, once per rendered frame.
/// - [Pickup3DComponent], [MovingPlatform3DComponent], [Checkpoint3DComponent], [KillZone3DComponent]: the
///   level's pieces.
///
/// [ThirdPersonKit] installs it all.
library;

export 'src/combo_set.dart';
export 'src/third_person_components.dart' hide PickupRuntime, MovingPlatformRuntime;
export 'src/third_person_kit.dart';
export 'src/third_person_definitions.dart';
export 'src/third_person_systems.dart';
