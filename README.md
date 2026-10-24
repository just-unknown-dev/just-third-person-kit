# just_third_person_kit

Third-person gameplay for `just_game_engine` in 3D, drawn by its 3-D graphics (`package:just_game_engine/graphics_3d.dart`) on its 3-D physics (`package:just_game_engine/physics_3d.dart`, Jolt). The app's pubspec builds Jolt with `hooks: user_defines: just_jolt: build: true`.

It runs where the engine's 3-D does: Windows, macOS, Linux, Android and iOS. Not the web, where Flutter GPU and Jolt are not available: a game with `EngineConfig(physics3D: Physics3D())` stops at start there.

```dart
final engine = Engine(config: EngineConfig(
  extensions: [ThirdPersonKit.extension],
  graphics3D: Graphics3D(),
  physics3D: Physics3D(),
));
await engine.initialize();
ThirdPersonKit.registerSystems(engine.world, input: engine.input, camera: engine.cameraSystem.mainCamera);
```

| Component | Goes on | Does |
|---|---|---|
| `ThirdPersonController` | the hero, with `CharacterBody3D` and `InputComponent` | walks, runs, crouches and jumps relative to the camera |
| `ThirdPersonCombat` | the hero | punch and kick chains from a `.combos.json` (`ComboSet`); each blow lands as a `StrikeHit3DEvent` |
| `ThirdPersonCamera` | a virtual camera with `OrbitFollowComponent` | turns with the look actions, zooms |
| `Pickup3D` | a sensor | taken on touch, counted |
| `MovingPlatform3D` | a kinematic body | goes there and back, carrying characters |
| `Checkpoint3D` | a sensor | where the hero comes back after a fall |
| `KillZone3D` | a sensor | sends the hero back |

The actions it reads: `move` (vector 2, y down), `jump`, `sprint`, `crouch`, `punch`, `kick`, `zoom` (axis), and the look actions `look` and `lookStick` (`LookActions`). The template `just_third_person_template` shows it all in a level.

An animator graph on the hero can read `planarSpeed` (m/s along the ground), `grounded`, `jumping`, `falling` and `crouching`, and with `ThirdPersonCombat` `striking` and `inCombat`, bound by `ThirdPersonKit.extension`. A strike plays on the animator trigger of its name (`punch_1`, …).

A combo set (`.combos.json`) names a `guard` clip, `chains` of strike names, and `strikes`, each with `duration`, `hit` (when the blow lands), `combo_window` (`[open, close]`, when a press chains to `next`; null on a finisher) and `next`, in seconds. A press starts its chain; a press of the same button in the window queues the next strike, which starts as this one ends; otherwise the strike ends in the guard, kept for `guardTime` or until the hero moves. Strikes start on the ground, not crouched or jumping, and hold the hero still. Listen for `StrikeHit3DEvent` to apply damage.

Crouching lowers the hero's `CharacterBody3D` to the controller's `crouchHeight`, so it ducks under low roofs; it stays down while something is above it. A `jumpDelay` gives the jump a wind-up on the ground, for a jump animation that crouches before it springs: `jumping` is true from the press, so a graph can start the jump then.

Up is -Y, as everywhere in the engine; lengths are metres.

## In the editor

`ThirdPersonModule` (`package:just_third_person_kit/editor.dart`) is a Level Designer kit for 3-D scenes: **Third Person** in the designer's switch, with the kit's prefabs — the hero, a camera rig, ground, a block, a moving platform, a light, a coin, a kill zone and a checkpoint. Its `LevelAids` tell the editor how the hero moves: the 3-D designer draws how far it jumps and how steep it walks, marks the height below which it falls out, and *Play from here* puts it where you right-clicked.
