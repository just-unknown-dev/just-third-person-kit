# Changelog

## 0.2.0-beta.1

### Breaking

- Every component's name ends in `Component` (old → new): `ThirdPersonController` → `ThirdPersonControllerComponent`, `ThirdPersonCombat` → `ThirdPersonCombatComponent`, `ThirdPersonCamera` → `ThirdPersonCameraComponent`, `Pickup3D` → `Pickup3DComponent`, `MovingPlatform3D` → `MovingPlatform3DComponent`, `Checkpoint3D` → `Checkpoint3DComponent`, `KillZone3D` → `KillZone3DComponent`. Levels saved with the old names are renamed as they load, at any scene format (`ThirdPersonMigrations.renamedTypes`).
- `ThirdPersonSchemas` → `ThirdPersonDefinitions` (file `third_person_definitions.dart`; was `third_person_schemas.dart`), and its components' definitions are `ComponentDefinition`s, now that the engine has folded `ComponentSchema` into it.
- The events take the engine's words for the same things: `CheckpointReached3DEvent` → `CheckpointActivated3DEvent`, `Respawned3DEvent` → `PlayerRespawn3DEvent`. Their fields are unchanged.
- `ThirdPersonKit.renamedTypes` → `ThirdPersonMigrations.renamedTypes`, as the other kits have it.
- `ThirdPersonControllerComponent.standingHeight` is gone: the crouch lowers the body through `CharacterBody3DComponent.heightOverride` (just_game_engine 2.0.0), and the standing height is the body's own `height`.
- `lib/src/` is laid out by feature: `character/`, `camera/`, `level/`, `kit/` and `editor/`, one barrel each. Import only `package:just_third_person_kit/just_third_person_kit.dart` and `package:just_third_person_kit/editor.dart`; every `src/` path has moved.
- The fall limit is measured from the lowest spawn point the hero has had, no longer from its last checkpoint (see Fixed).

### Added

- `ThirdPersonMigrations`: `renamedTypes` and `install(context)`, which `ThirdPersonKit.extension` calls.
- `ThirdPersonControllerComponent.lowestSpawnY` and `killHeight` (run time, not saved): the height a fall puts the hero back from.
- `ThirdPersonCameraSystem.applyZoom`, beside `applyLook`.
- Tests mirror `lib/src/` (`test/character/`, `test/camera/`, `test/level/`, `test/kit/`, `test/editor/`). `test/library_layout_test.dart` guards the layout, the layers (`character`, `camera` → `level` → `kit` → `editor`) and the release split; `test/store_manifest_test.dart` checks `just_store.json` against the pubspec, the CHANGELOG and the definitions.

### Changed

- Requires just_game_engine ^2.0.0 and just_editor_core ^0.1.0. `just_store.json` asks for the same engine (`^2.0.0`; it asked for `^2.0.0-dev.2`, older than the kit needs) and for just_game_engine_editor ^0.1.0.
- Installing the kit installs the engine's built-in components (`BuiltInComponents.extension`) too: its levels use them.
- The editor half is one file per class, as named: `ThirdPersonModule`, `ThirdPersonModels`, `ThirdPersonPrefabs` and `ThirdPersonAids`, with the three overlays (`PlatformTravelOverlay`, `JumpReachOverlay`, `WalkableSlopeOverlay`) together in `third_person_overlays.dart`.
- The level aids' kill height is measured as a respawn measures it, from the lowest spawn point.
- The source is formatted with `dart format`.
- The controller's `moveAction`, `jumpAction`, `sprintAction` and `crouchAction`, the combat's `punchAction` and `kickAction`, and the camera's `zoomAction` are input action fields (just_game_engine's `InputDefinitions.actionType`; they were text): the editor's inspector offers the project's actions for them, and the Input Actions editor finds them when an action is renamed, moved or deleted. They save and load as before. The combat's `punchChain` and `kickChain` name chains in the combo set and stay text.

### Fixed

- A checkpoint more than `fallLimit` (40 m) above the ground made that ground deadly: the limit was measured from the moving spawn point, so walking down from a high checkpoint respawned the hero there, every time. It is now measured from the lowest spawn point the hero has had (where it started, or the lowest checkpoint reached), so it never rises with a checkpoint.
- The camera's look turned the orbit while time stood still (an editor authoring the level, a pause), writing the rig's saved `yaw` and `pitch`. `ThirdPersonCameraSystem` now stands still with the other systems, and drops the look made meanwhile instead of turning by it all at once later.
- The `ThirdPersonKit` sample used `EngineConfig(graphics3D:, physics3D:)`, which does not exist: it is `services: [Graphics3D(), Physics3D()]`. `editor.dart` said the runtime avoided `just_game_engine_editor`; the editor half builds on `just_editor_core`.
- The crouch wrote the character body's saved `height` at run time, so a world saved mid-crouch kept the crouching height. It now sets the body's run-time `heightOverride` and clears it on standing up and on respawn; the saved `height` never changes.

### Removed

- The `PickupRuntime` and `MovingPlatformRuntime` extensions, which the runtime library hid: what the systems keep is now `@internal` on `Pickup3DComponent` (`home`, `homeRotation`, `time`, `collect()`) and `MovingPlatform3DComponent` (`start`, `along`, `direction`, `resting`).

## 0.1.0-beta.1

First version: third-person gameplay for just_game_engine in 3D.

- **Builds on `just_editor_core`**, the editor's module contract, instead of depending on `just_game_engine_editor`: the module's code needs nothing else of the editor.
- `ThirdPersonController` and `ThirdPersonControllerSystem`: moves a `CharacterBody3D` from the `move` action relative to the camera's yaw, `sprint`, `jump` with coyote time and a buffered press, turning to face the way it runs (`facingOffset` π for a glTF character).
- `ThirdPersonCamera` and `ThirdPersonCameraSystem` (a `FrameSystem`): the look actions (`LookInput`) turn an `OrbitFollowComponent`; `zoom` moves it in and out.
- `Jumped3DEvent` and `Landed3DEvent` (with how fast it fell) from `ThirdPersonControllerSystem`, for a game's sounds and effects.
- `Pickup3D` (spins, bobs, taken on a sensor touch: `PickupCollected3DEvent`), `MovingPlatform3D` (a kinematic body there and back, carrying characters), `Checkpoint3D` and `KillZone3D` with `Respawn3DSystem` (falls past `fallLimit` too: `Respawned3DEvent`, `CheckpointReached3DEvent`).
- `ThirdPersonKit.extension`: the definitions (3-D, group "Third Person") and animator bindings `planarSpeed`, `grounded`, `jumping`, `falling`; `ThirdPersonKit.registerSystems`.
- `package:just_third_person_kit/editor.dart` (design-time): `ThirdPersonModule` with the kit's pieces as prefabs for a 3-D scene's viewport menu (Player, Camera Rig, Ground, Block, Moving Platform, Light, Coin, Checkpoint; models from `ThirdPersonModels`), scene-tree icons, a kill-zone marker and a selected platform's travel.
- `just_store.json`: a kit; its editor part editor-only.
- Tests: the systems one at a time, and the gameplay on Jolt (walk, jump, stairs, a slope, a moving platform, respawn).
- On the engine's own 3D physics (`package:just_game_engine/physics_3d.dart`); the tests build Jolt through this package's pubspec (`hooks: user_defines: just_jolt: build: true`).
- A 3-D Level Designer kit: **Third Person** in the switch of 3-D scenes, with its prefabs and a new Kill Zone.
- `LevelAids`: how far the hero jumps and how steep it walks, drawn over the level; the height below which it falls out; play from here.
- **Crouch**: `ThirdPersonController` crouches on the ground while `crouchAction` (`crouch`) is held, moving at `crouchSpeed` (1 m/s), and says so in `isCrouching`; animator graphs read it as `crouching`. Its `CharacterBody3D` is lowered to `crouchHeight` (1.5 m) meanwhile, so it goes under what it could not walk under standing; it stands again (and jumps) only when nothing is above it, found through the world's `PhysicsSystem3D`.
- **Jump wind-up**: `jumpDelay` (0 s, so leaving at once as before) holds a jump on the ground that long before it springs, for a jump animation that crouches first. `isJumping` (`jumping`) is true from the press; `Jumped3DEvent` comes as it leaves. Only from the ground: a coyote jump springs at once.
- A jump from a crouch launches through the character's velocity: its body, made again at its new height, takes that step as in the air, which dropped `CharacterBody3D.jump`.
- **Combat**: `ThirdPersonCombat` punches and kicks in chains read from a `.combos.json` (`ComboSet`, `Strike`): a press starts a chain, a press of the same button in a strike's combo window queues the next, and the strike otherwise ends in the guard, dropped after `guardTime` or on moving. `ThirdPersonCombatSystem` runs it (in `ThirdPersonKit.systems`), plays each strike on the animator trigger of its name, and fires `StrikeHit3DEvent` as each blow lands. A strike holds the controller still. Animator graphs read `striking` and `inCombat`.
- The Player prefab's hero is JustHumanoid in the template: idle, walk, run, jump, crouch_idle and crouch_walk, combat_idle, and three punches and three kicks (`ThirdPersonModels.heroCombos`).
- Pickups stand still while time does (a `deltaTime` of 0: paused, or an editor authoring the level), as the controller, the combat and the platforms do: a coin stays where, and turned as, it was placed, and spins from there once play starts.
- A respawn puts the hero back on its feet with nothing of its fall, jump, crouch or strike carried over (no landing is told for the fall). The best checkpoint a hero has reached is kept with its controller, so a new play-test or level starts from none.
- `ThirdPersonCameraSystem` makes its look reader as it joins a world and lets it go as it leaves, and turns the camera just before the camera brain, so a frame's look is in that frame's view.
- The components' numbers have floors (no negative speeds, times or turn rates), and a combo set with a value of the wrong type is a `FormatException` naming it; its problems (`ComboSet.validate`) are said once as it loads.
- The level aids read gravity from the scene's 3-D physics.
