# Changelog

## 0.1.0-dev.1

- A 3-D Level Designer kit: **Third Person** in the switch of 3-D scenes, with its prefabs and a new Kill Zone.
- `LevelAids`: how far the hero jumps and how steep it walks, drawn over the level; the height below which it falls out; play from here.
- **Crouch**: `ThirdPersonController` crouches on the ground while `crouchAction` (`crouch`) is held, moving at `crouchSpeed` (1 m/s), and says so in `isCrouching`; animator graphs read it as `crouching`. Its `CharacterBody3D` is lowered to `crouchHeight` (1.5 m) meanwhile, so it goes under what it could not walk under standing; it stands again (and jumps) only when nothing is above it, found through the world's `PhysicsSystem3D`.
- **Jump wind-up**: `jumpDelay` (0 s, so leaving at once as before) holds a jump on the ground that long before it springs, for a jump animation that crouches first. `isJumping` (`jumping`) is true from the press; `Jumped3DEvent` comes as it leaves. Only from the ground: a coyote jump springs at once.
- A jump from a crouch launches through the character's velocity: its body, made again at its new height, takes that step as in the air, which dropped `CharacterBody3D.jump`.
- **Combat**: `ThirdPersonCombat` punches and kicks in chains read from a `.combos.json` (`ComboSet`, `Strike`): a press starts a chain, a press of the same button in a strike's combo window queues the next, and the strike otherwise ends in the guard, dropped after `guardTime` or on moving. `ThirdPersonCombatSystem` runs it (in `ThirdPersonKit.systems`), plays each strike on the animator trigger of its name, and fires `StrikeHit3DEvent` as each blow lands. A strike holds the controller still. Animator graphs read `striking` and `inCombat`.
- The Player prefab's hero is JustHumanoid in the template: idle, walk, run, jump, crouch_idle and crouch_walk, combat_idle, and three punches and three kicks (`ThirdPersonModels.heroCombos`).

## 0.1.0-dev

- **Builds on `just_editor_core`**, the editor's module contract, instead of depending on `just_game_engine_editor`: the module's code needs nothing else of the editor.

First version: third-person gameplay for just_game_engine in 3D.

- `ThirdPersonController` and `ThirdPersonControllerSystem`: moves a `CharacterBody3D` from the `move` action relative to the camera's yaw, `sprint`, `jump` with coyote time and a buffered press, turning to face the way it runs (`facingOffset` π for a glTF character).
- `ThirdPersonCamera` and `ThirdPersonCameraSystem` (a `FrameSystem`): the look actions (`LookInput`) turn an `OrbitFollowComponent`; `zoom` moves it in and out.
- `Jumped3DEvent` and `Landed3DEvent` (with how fast it fell) from `ThirdPersonControllerSystem`, for a game's sounds and effects.
- `Pickup3D` (spins, bobs, taken on a sensor touch: `PickupCollected3DEvent`), `MovingPlatform3D` (a kinematic body there and back, carrying characters), `Checkpoint3D` and `KillZone3D` with `Respawn3DSystem` (falls past `fallLimit` too: `Respawned3DEvent`, `CheckpointReached3DEvent`).
- `ThirdPersonKit.extension`: the definitions (3-D, group "Third Person") and animator bindings `planarSpeed`, `grounded`, `jumping`, `falling`; `ThirdPersonKit.registerSystems`.
- `package:just_third_person_kit/editor.dart` (design-time): `ThirdPersonModule` with the kit's pieces as prefabs for a 3-D scene's viewport menu (Player, Camera Rig, Ground, Block, Moving Platform, Light, Coin, Checkpoint; models from `ThirdPersonModels`), scene-tree icons, a kill-zone marker and a selected platform's travel.
- `just_store.json`: a kit; its editor part editor-only.
- Tests: the systems one at a time, and the gameplay on Jolt (walk, jump, stairs, a slope, a moving platform, respawn).
- On the engine's own 3D physics (`package:just_game_engine/physics_3d.dart`); the tests build Jolt through this package's pubspec (`hooks: user_defines: just_jolt: build: true`).
