/// Third-person gameplay for just_game_engine in 3D.
///
/// - [ThirdPersonController]: moves a `CharacterBody3D` from its input,
///   relative to where the camera looks, with coyote time and a buffered
///   jump, turning to face the way it runs.
/// - [ThirdPersonCombat]: punch and kick chains from a [ComboSet], each
///   blow told by a [StrikeHit3DEvent].
/// - [ThirdPersonCamera]: turns and zooms an orbit-follow camera from the
///   look and zoom actions, once per rendered frame.
/// - [Pickup3D], [MovingPlatform3D], [Checkpoint3D], [KillZone3D]: the
///   level's pieces.
///
/// [ThirdPersonKit] installs it all.
library;

export 'src/combo_set.dart';
export 'src/third_person_components.dart' hide PickupRuntime, MovingPlatformRuntime;
export 'src/third_person_kit.dart';
export 'src/third_person_schemas.dart';
export 'src/third_person_systems.dart';
