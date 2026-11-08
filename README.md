# just_third_person_kit

Third-person gameplay for `just_game_engine` in 3D, drawn by its 3-D graphics on its 3-D physics (Jolt), both from `package:just_game_engine/just_game_engine_3d.dart`. The app's pubspec builds Jolt with `hooks: user_defines: just_jolt: build: true`.

It runs where the engine's 3-D does: Windows, macOS, Linux, Android and iOS. Not the web, where Flutter GPU and Jolt are not available: a game with `EngineConfig(services: [Physics3D()])` stops at start there.

```dart
final engine = Engine(config: EngineConfig(
  extensions: [ThirdPersonKit.extension],
  services: [Graphics3D(), Physics3D()],
));
await engine.initialize();
ThirdPersonKit.registerSystems(engine.world, input: engine.input, camera: engine.camera.mainCamera);
```

| Component | Goes on | Does |
|---|---|---|
| `ThirdPersonControllerComponent` | the hero, with `CharacterBody3DComponent` and `InputComponent` | walks, runs, crouches and jumps relative to the camera |
| `ThirdPersonCombatComponent` | the hero | punch and kick chains from a `.combos.json` (`ComboSet`); each blow lands as a `StrikeHit3DEvent` |
| `ThirdPersonCameraComponent` | a virtual camera with `OrbitFollowComponent` | turns with the look actions, zooms |
| `Pickup3DComponent` | a sensor | taken on touch, counted |
| `MovingPlatform3DComponent` | a kinematic body | goes there and back, carrying characters |
| `Checkpoint3DComponent` | a sensor | where the hero comes back after a fall |
| `KillZone3DComponent` | a sensor | sends the hero back |

The actions it reads: `move` (vector 2, y down), `jump`, `sprint`, `crouch`, `punch`, `kick`, `zoom` (axis), and the look actions `look` and `lookStick` (`LookActions`). The fields that name them (`moveAction`, `jumpAction`, `sprintAction`, `crouchAction`, `punchAction`, `kickAction`, `zoomAction`) are input action fields, so the editor's inspector offers the project's actions for them. The template `just_third_person_template` shows it all in a level.

An animator graph on the hero can read `planarSpeed` (m/s along the ground), `grounded`, `jumping`, `falling` and `crouching`, and with `ThirdPersonCombatComponent` `striking` and `inCombat`, bound by `ThirdPersonKit.extension`. A strike plays on the animator trigger of its name (`punch_1`, …).

A combo set (`.combos.json`) names a `guard` clip, `chains` of strike names, and `strikes`, each with `duration`, `hit` (when the blow lands), `combo_window` (`[open, close]`, when a press chains to `next`; null on a finisher) and `next`, in seconds. A press starts its chain; a press of the same button in the window queues the next strike, which starts as this one ends; otherwise the strike ends in the guard, kept for `guardTime` or until the hero moves. Strikes start on the ground, not crouched or jumping, and hold the hero still. Listen for `StrikeHit3DEvent` to apply damage.

Crouching lowers the hero's `CharacterBody3DComponent` to the controller's `crouchHeight` (through the body's run-time `heightOverride`: its saved `height` stays as authored), so it ducks under low roofs; it stays down while something is above it. A `jumpDelay` gives the jump a wind-up on the ground, for a jump animation that crouches before it springs: `jumping` is true from the press, so a graph can start the jump then.

A hero that falls more than its controller's `fallLimit` (40 m) below the lowest spawn point it has had — where it started, or the lowest checkpoint it has reached — is put back at its spawn point (the last checkpoint reached). A checkpoint high above the ground never makes that ground deadly. A `KillZone3DComponent` gives a level an exact floor.

The events, for a game's sounds, effects and score: `Jumped3DEvent`, `Landed3DEvent` (with how fast it fell), `StrikeHit3DEvent`, `PickupCollected3DEvent`, `CheckpointActivated3DEvent` and `PlayerRespawn3DEvent`.

```dart
var coins = 0;
engine.world.events
  ..on<PickupCollected3DEvent>((e) => coins += e.value)
  ..on<PlayerRespawn3DEvent>((e) => debugPrint('back at ${e.at}'));
```

Levels saved with the kit's older component names (before 0.2.0-beta.1, every name without `Component`) keep loading: `ThirdPersonKit.extension` installs `ThirdPersonMigrations`, which renames them as a scene loads.

Up is -Y, as everywhere in the engine; lengths are metres.

## In the editor

`ThirdPersonModule` (`package:just_third_person_kit/editor.dart`) is a Level Designer kit for 3-D scenes: **Third Person** in the designer's switch, with the kit's prefabs — the hero, a camera rig, ground, a block, a moving platform, a light, a coin, a kill zone and a checkpoint. Its `LevelAids` tell the editor how the hero moves: the 3-D designer draws how far it jumps and how steep it walks, marks the height below which it falls out, and *Play from here* puts it where you right-clicked.

The editor half is design-time only. `package:just_third_person_kit/just_third_person_kit.dart` never reaches it (or `just_editor_core`), so a release build carries none of it; import `editor.dart` only from the game's debug entry point:

```dart
await JustGameEditorPlugin.register(engine: engine, modules: [ThirdPersonModule()]);
```
