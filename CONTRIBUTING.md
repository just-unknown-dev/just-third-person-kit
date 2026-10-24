# Contributing to Just Third Person Kit

Thank you for your interest in contributing to **Just Third Person Kit**. Bug fixes, features, tests and documentation are all welcome.

---

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Reporting Bugs and Suggesting Features](#reporting-bugs-and-suggesting-features)
- [Development Setup](#development-setup)
- [Working Against Unpublished Dependencies](#working-against-unpublished-dependencies)
- [How the Package Fits Together](#how-the-package-fits-together)
- [Running the Tests](#running-the-tests)
- [Coding Guidelines](#coding-guidelines)
- [Submitting a Pull Request](#submitting-a-pull-request)
- [Commit Message Convention](#commit-message-convention)
- [License](#license)

---

## Code of Conduct

This project follows our [Code of Conduct](CODE_OF_CONDUCT.md). By taking part you agree to its terms. Please report unacceptable behaviour to the maintainers.

---

## Reporting Bugs and Suggesting Features

Before opening an issue, search the [existing issues](https://github.com/just-unknown-dev/just-third-person-kit/issues) and check that the problem happens on the latest version.

A bug report should have:

- a clear title;
- steps to reproduce, and what you expected instead of what happened;
- the output of `flutter --version`, and the platform (Android, iOS, Linux, macOS, Windows);
- if the game stops at start with a `Physics3DUnsupportedError`, its message. It usually means the game's own pubspec does not build Jolt;
- the scene's `.scene.json`, or the smallest part of it that shows the problem: the hero with its `CharacterBody3D` and `ThirdPersonController` settings, and what it stood on or touched;
- for a camera bug, the camera's `OrbitFollowComponent` and `ThirdPersonCamera` settings, and whether the look came from a mouse, a drag or a stick;
- for an input bug, the actions the kit reads (`move`, `jump`, `sprint`, `zoom`, `look`, `lookStick`) as the game's `.input.json` binds them;
- for an editor bug, the prefab involved and what you did in the editor.

Bugs often belong somewhere else:

- The kit decides where a character goes; the engine's `CharacterBody3D` does the walking. A slope, step or platform bug you can show without `ThirdPersonController` belongs in [just_game_engine](https://github.com/just-unknown-dev/just-game-engine/issues), and so does the orbit camera's follow and wall collision (`OrbitFollowComponent`, `CameraCollision3D`). Wrong physics with no kit component involved belongs in [just_physics_engine](https://github.com/just-unknown-dev/just-physics-engine/issues), which runs Jolt.
- A model, light or material that draws wrongly belongs in [just_graphics_engine](https://github.com/just-unknown-dev/just-graphics-engine/issues).
- Reading the mouse or stick for the look (`LookInput`, `LookActions`) belongs in [just_inputs](https://github.com/just-unknown-dev/just-inputs/issues).
- An editor bug you can show without `ThirdPersonModule` belongs in `just_game_engine_editor`.

For a feature, open an issue labelled **`enhancement`** that describes the problem it solves and how it should behave. The package's scope is third-person gameplay in 3D: the controller, the camera's player controls, pickups, moving platforms, checkpoints and kill zones, and the editor module that offers them as prefabs. A change to how a component is saved affects every scene a game has saved, so open the issue first and agree the approach before you write it.

---

## Development Setup

| Tool | Minimum version |
|------|-----------------|
| Dart | 3.12.2 |
| Flutter | 3.47.1. The package's own pubspec accepts Flutter 3.41.0, but `just_game_engine` needs 3.47.1 (its 3-D graphics) |
| C++17 toolchain | For Jolt, which the tests compile from source. Windows: Visual Studio with the "Desktop development with C++" workload. Linux: clang. macOS: Xcode |

There is no app to run here: you work on the package and its tests. To try a change in a real game, take a game made from the third-person template (`just_third_person_template`) and override `just_third_person_kit` in its `pubspec_overrides.yaml` with `path: ../just_third_person_kit`. The template's pubspec already builds Jolt, and its `lib/main_editor.dart` opens the editor, where the kit's prefabs are in a 3-D scene's viewport menu.

The kit is not published to pub.dev (`publish_to: none`). Games get it as an Asset Store item, described by `just_store.json`.

```bash
git clone https://github.com/just-unknown-dev/just-third-person-kit.git just_third_person_kit
cd just_third_person_kit
flutter pub get
flutter test
```

The package's `pubspec.yaml` turns the native Jolt build on (`hooks: user_defines: just_jolt: build: true`), so the first `flutter test` compiles Jolt and takes longer than the runs after it.

If you're working from the Just engine monorepo, run every command from `plugins/just_third_person_kit`.

---

## Working Against Unpublished Dependencies

The package depends on two just_* packages: `just_game_engine` and `just_game_engine_editor`. When a change needs an unreleased version of one of them, check it out next to this repository and point this package at it with a `pubspec_overrides.yaml` in the repository root:

```yaml
# pubspec_overrides.yaml: local only, never commit it.
dependency_overrides:
  just_game_engine:
    path: ../just_game_engine
  just_game_engine_editor:
    path: ../just_game_engine_editor
```

List only the ones you need. If an overridden package needs an unreleased version of a package it depends on in turn (`just_graphics_engine`, `just_physics_engine`, `just_jolt`, `just_inputs`, …), add that one too. In the monorepo the file overrides all fourteen just_* packages the kit reaches.

Then run `flutter pub get`. Delete the file (or the entry) and run `flutter pub get` again to go back to the published versions.

Do not change `pubspec.yaml` to a path dependency. If your pull request needs a version of a just_* package that is not published yet, say so in the pull request: this package can only be released after it.

The third-person template depends on this package. Its game adds `ThirdPersonKit.systems` (in `lib/game/third_person_game.dart`), and the lists the Asset Store generates for it register `ThirdPersonKit.extension` and `ThirdPersonModule`. The `just` CLI (`just_core_cli`) also lists the kit among the Asset Store packages for 3-D games. If you change the public API, a saved field or `just_store.json`, say in the pull request what the template will need.

---

## How the Package Fits Together

| Path | Contents |
|------|----------|
| `lib/just_third_person_kit.dart` | The runtime library, safe in a release build |
| `lib/src/third_person_components.dart` | `ThirdPersonController`, `ThirdPersonCamera`, `Pickup3D`, `MovingPlatform3D`, `Checkpoint3D`, `KillZone3D` |
| `lib/src/third_person_schemas.dart` | `ThirdPersonSchemas`: how each component is saved, loaded and shown in the inspector |
| `lib/src/third_person_systems.dart` | `ThirdPersonControllerSystem`, `ThirdPersonCameraSystem`, `Pickup3DSystem`, `MovingPlatform3DSystem`, `Respawn3DSystem`; the events `PickupCollected3DEvent`, `CheckpointReached3DEvent` and `Respawned3DEvent` |
| `lib/src/third_person_kit.dart` | `ThirdPersonKit`: the extension, the animator bindings and the systems |
| `lib/editor.dart`, `lib/src/editor/` | Design time only: `ThirdPersonModule`, `ThirdPersonPrefabs`, `ThirdPersonModels`, `PlatformTravelOverlay` |
| `just_store.json` | The Asset Store manifest: the extension and module a game registers, the component types the kit adds, the setup code shown after installing it, and the editor-only libraries. The `just` CLI's release check reads that last list |
| `test/` | `third_person_test.dart` (each system on its own), `jolt_gameplay_test.dart` (the gameplay on real Jolt), `editor_test.dart` (the module and the library boundary) |

A few rules hold the package together. Keep them:

- **The runtime never reaches the editor.** Nothing that `lib/just_third_person_kit.dart` reaches imports `just_game_engine_editor`, `just_graphics_engine` or a file under `lib/src/editor/`. Only the prefabs use models and lights (from `package:just_game_engine/graphics_3d.dart`). `just_store.json` lists `editor.dart` and `src/editor/` as editor-only; keep it in step.
- **3-D physics comes through the engine.** The kit imports `package:just_game_engine/physics_3d.dart` and never `just_physics_engine` or `just_jolt`. A game turns 3-D physics on with `EngineConfig(physics3D: Physics3D())` and builds Jolt in its own pubspec. The `hooks:` block in this package's pubspec only builds Jolt for its own tests, because a build hook reads only the root package's user-defines.
- **Every saved component has a `ComponentSchema`** in `ThirdPersonSchemas.all`, with 3-D hints (`Dimensions.threeD`, group "Third Person"), and its type is listed under `runtime.componentTypes` in `just_store.json`. The schemas are getters, so `ThirdPersonKit.extension`, a `RefreshableExtension`, can rebuild them after a hot reload. Write new ones as getters too.
- **Saved scenes must keep loading.** Never change a schema's `type` or `id`, or a field's name. A new field needs nothing more, because a scene saved without it loads the constructor's default. The kit has no scene migrations; a change that would need one is for an issue first.
- **Only settings are saved.** What the systems keep while the game runs (a pickup's bob, a platform's progress) is private to `third_person_components.dart`. The systems reach it through the `PickupRuntime` and `MovingPlatformRuntime` extensions, which the runtime library hides.
- **Metres, and up is -Y**, as everywhere in the engine. A glTF character faces its file's +Z, which is the engine's -Z, so `facingOffset` defaults to π.
- **Gameplay runs at the fixed step, before physics.** `Respawn3DSystem`, `ThirdPersonControllerSystem` and `MovingPlatform3DSystem` run at `SystemPriorities.playerControl` or next to it, so the physics step uses what they set. Only `ThirdPersonCameraSystem` is a `FrameSystem`: it turns the camera once per rendered frame, so the view is smooth at any frame rate. Keep gameplay out of `frame`.

---

## Running the Tests

Run every command from the repository root. `test/editor_test.dart` reads `lib/` from disk and expects that working directory.

```bash
# The whole suite.
flutter test

# One file.
flutter test test/third_person_test.dart
```

**The library boundary.** `test/editor_test.dart` walks every import that `just_third_person_kit.dart` reaches. It fails if one names `just_game_engine_editor` or `just_graphics_engine`, or reaches `lib/src/editor/`. The same file checks the prefabs: there are eight, each for 3-D scenes and placed with `buildAt`.

**Jolt.** `test/jolt_gameplay_test.dart` runs the gameplay on real Jolt physics: walking, jumping, stairs, a slope, a moving platform and a respawn. Where Jolt is not available, each of its tests is skipped with the reason `JoltPhysicsEngine().unavailableReason` gives. Say in your pull request if they were skipped for you.

**Writing tests.** There is no shared helper library. For a system's logic, follow `test/third_person_test.dart`: a bare `World` with only the system under test, the character's ground state set by hand (`CharacterBody3D()..groundState = GroundState3D.onGround`), and sensor events fired straight at the world's events (`world.events.fire(SensorEnter3DEvent(...))`). Step it with `world.update(1 / 60)`, and drive the hero through its `InputComponent` (`setVector('move', …)`, `pressed.add('jump')`), clearing `pressed` after each step. Use real Jolt, as `test/jolt_gameplay_test.dart` does, only for what needs real collisions.

---

## Coding Guidelines

- **Formatting.** Format the files you change with `dart format <files>`. Most files in the package are not formatted yet: put a reformat of a whole file in a commit of its own, so that reviewers can see your change.
- **Analysis.** `flutter analyze` must report no issues at all: no errors, warnings or infos. The rules are in `analysis_options.yaml`: `flutter_lints`, with `build/` excluded.
- **Documentation.** Give every public API you add a `///` doc comment. Describe user-visible changes in [CHANGELOG.md](CHANGELOG.md), and update [README.md](README.md) if the public API changes.
- **Tests.** Add or update tests for any behaviour you change. A bug fix comes with a test that fails without it.
- **Dependencies.** Do not add a dependency without discussing it in an issue first.
- **Structure.** Runtime code goes in the files under `lib/src/` and reaches users through `lib/just_third_person_kit.dart`; design-time code goes under `lib/src/editor/` and reaches users through `lib/editor.dart`.

---

## Submitting a Pull Request

1. Create a topic branch from `main`:
   ```bash
   git checkout -b fix/coyote-jump-off-platform
   ```
2. Make your change, following the [Coding Guidelines](#coding-guidelines).
3. Check that everything passes:
   ```bash
   dart format <the files you changed>
   flutter analyze
   flutter test
   ```
4. Commit with a [conventional commit message](#commit-message-convention).
5. Push to your fork and open a pull request against `main`. Say what changed and why. List any unpublished just_* version it needs, say whether it changes how a component is saved or what the third-person template must do, and say whether the Jolt tests ran.
6. Answer review feedback.

Small pull requests are easier to review.

---

## Commit Message Convention

We use [Conventional Commits](https://www.conventionalcommits.org/):

```
<type>(<scope>): <short summary>
```

| Type | When to use |
|------|-------------|
| `feat` | New feature |
| `fix` | Bug fix |
| `docs` | Documentation only |
| `refactor` | Code change that neither fixes a bug nor adds a feature |
| `perf` | Performance improvement |
| `test` | Adding or updating tests |
| `chore` | Build process, tooling, dependencies |

Use the area as the scope: `components`, `schemas`, `systems`, `kit` or `editor`. Mark a change that breaks the public API or how scenes are saved with `!` and a `BREAKING CHANGE:` footer.

**Examples:**
```
fix(systems): keep a buffered jump when landing on a moving platform
feat(editor): add a kill zone prefab
docs(contributing): explain the Jolt tests
```

---

## License

By contributing to Just Third Person Kit you agree that your contributions will be licensed under the [BSD-3-Clause License](LICENSE).
