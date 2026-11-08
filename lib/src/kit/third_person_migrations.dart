import 'package:just_game_engine/just_game_engine.dart';

/// How levels saved with older versions of the kit load.
///
/// The kit's renamed components ([renamedTypes]) are renamed in every
/// scene, prefab and timeline as it loads, whatever its format: a level
/// saved before a rename keeps loading after it. Installing
/// `ThirdPersonKit.extension` installs them.
abstract final class ThirdPersonMigrations {
  /// Adds the kit's renames to [context]'s migrations
  /// (`context.migrations.renamedTypes`).
  static void install(EngineContext context) {
    context.migrations.renamedTypes.addAll(renamedTypes);
  }

  /// The kit's saved component names that changed: old name → new.
  ///
  /// - 0.2.0-beta.1 (scene format 11): every component's name came to end
  ///   in `Component`.
  ///
  /// A later rename is added here with the old entries kept: a chain
  /// (`A → B`, `B → C`) loads both `A` and `B` as `C`.
  static const Map<String, String> renamedTypes = {
    'ThirdPersonController': 'ThirdPersonControllerComponent',
    'ThirdPersonCombat': 'ThirdPersonCombatComponent',
    'ThirdPersonCamera': 'ThirdPersonCameraComponent',
    'Pickup3D': 'Pickup3DComponent',
    'MovingPlatform3D': 'MovingPlatform3DComponent',
    'Checkpoint3D': 'Checkpoint3DComponent',
    'KillZone3D': 'KillZone3DComponent',
  };
}
