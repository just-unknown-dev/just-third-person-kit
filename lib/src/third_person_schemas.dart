import 'package:flutter/material.dart' show IconData, Icons;
import 'package:flutter/painting.dart';
import 'package:just_game_engine/just_game_engine.dart';

import 'third_person_components.dart';

/// How the kit's components are saved, loaded and shown: all 3-D, in the
/// group "Third Person".
abstract final class ThirdPersonSchemas {
  static const String _group = 'Third Person';
  static const Color _accent = Color(0xFF7E57C2);

  /// Every one.
  static List<ComponentSchema> get all => [controller, combat, camera, pickup, movingPlatform, checkpoint, killZone];

  static ComponentHints _hints(String name, String description, IconData icon, Map<String, FieldHint> fields) =>
      ComponentHints(
        dimensions: Dimensions.threeD,
        name: name,
        group: _group,
        description: description,
        icon: icon,
        accentColor: _accent,
        fields: fields,
      );

  static FieldHint _num(String label, String suffix, {double step = 0.1, int digits = 2, String? description}) =>
      FieldHint(
        label: label,
        description: description,
        scrub: ScrubHint(step: step, fractionDigits: digits, suffix: suffix),
      );

  /// [ThirdPersonController].
  static ComponentSchema<ThirdPersonController> get controller => ComponentSchema<ThirdPersonController>(
    type: 'ThirdPersonController',
    id: 'third_person_controller_3d_8c51a0d2',
    create: ThirdPersonController.new,
    hints: _hints(
      'Third Person Controller',
      'Moves a character from its input, relative to where the camera looks: walk, sprint, crouch (ducking its body), jump (with coyote time and an optional wind-up), turning to face the way it runs.',
      Icons.directions_run,
      {
        'walkSpeed': _num('Walk', 'm/s'),
        'sprintSpeed': _num('Sprint', 'm/s'),
        'crouchSpeed': _num('Crouch', 'm/s'),
        'crouchHeight': _num('Crouch height', 'm', description: "Its body's height while crouching; it stands again only where there is room."),
        'acceleration': _num('Accel.', 'm/s²', step: 1, digits: 0),
        'airAcceleration': _num('Air accel.', 'm/s²', step: 1, digits: 0),
        'jumpSpeed': _num('Jump', 'm/s'),
        'jumpDelay': _num('Wind-up', 's', step: 0.01, description: 'How long a jump crouches before it leaves the ground: 0 leaves at once.'),
        'coyoteTime': _num('Coyote', 's', step: 0.01, description: 'How long after an edge a jump still works.'),
        'jumpBuffer': _num('Buffer', 's', step: 0.01, description: 'How long a jump pressed early is remembered.'),
        'turnSpeed': _num('Turn', 'rad/s', step: 0.5, digits: 1),
        'facingOffset': _num('Facing', 'rad', description: 'Added to the way it faces: π for a glTF character.'),
        'fallLimit': _num('Fall limit', 'm', step: 1, digits: 0, description: 'How far below its spawn it may fall before it is put back.'),
      },
    ),
    fields: [
      _decimal<ThirdPersonController>('walkSpeed', (c) => c.walkSpeed, (c, v) => c.walkSpeed = v),
      _decimal<ThirdPersonController>('sprintSpeed', (c) => c.sprintSpeed, (c, v) => c.sprintSpeed = v),
      _decimal<ThirdPersonController>('crouchSpeed', (c) => c.crouchSpeed, (c, v) => c.crouchSpeed = v),
      _decimal<ThirdPersonController>('crouchHeight', (c) => c.crouchHeight, (c, v) => c.crouchHeight = v),
      _decimal<ThirdPersonController>('acceleration', (c) => c.acceleration, (c, v) => c.acceleration = v),
      _decimal<ThirdPersonController>('airAcceleration', (c) => c.airAcceleration, (c, v) => c.airAcceleration = v),
      _decimal<ThirdPersonController>('jumpSpeed', (c) => c.jumpSpeed, (c, v) => c.jumpSpeed = v),
      _decimal<ThirdPersonController>('jumpDelay', (c) => c.jumpDelay, (c, v) => c.jumpDelay = v),
      _decimal<ThirdPersonController>('coyoteTime', (c) => c.coyoteTime, (c, v) => c.coyoteTime = v),
      _decimal<ThirdPersonController>('jumpBuffer', (c) => c.jumpBuffer, (c, v) => c.jumpBuffer = v),
      _decimal<ThirdPersonController>('turnSpeed', (c) => c.turnSpeed, (c, v) => c.turnSpeed = v),
      _decimal<ThirdPersonController>('facingOffset', (c) => c.facingOffset, (c, v) => c.facingOffset = v),
      _decimal<ThirdPersonController>('fallLimit', (c) => c.fallLimit, (c, v) => c.fallLimit = v),
      _text<ThirdPersonController>('moveAction', (c) => c.moveAction, (c, v) => c.moveAction = v),
      _text<ThirdPersonController>('jumpAction', (c) => c.jumpAction, (c, v) => c.jumpAction = v),
      _text<ThirdPersonController>('sprintAction', (c) => c.sprintAction, (c, v) => c.sprintAction = v),
      _text<ThirdPersonController>('crouchAction', (c) => c.crouchAction, (c, v) => c.crouchAction = v),
    ],
  );

  /// [ThirdPersonCombat].
  static ComponentSchema<ThirdPersonCombat> get combat => ComponentSchema<ThirdPersonCombat>(
    type: 'ThirdPersonCombat',
    id: 'third_person_combat_3d_d41e7c25',
    create: ThirdPersonCombat.new,
    hints: _hints(
      'Third Person Combat',
      'Punch and kick chains from a combo set: a press in a strike\'s combo window chains the next; each blow lands at its hit time.',
      Icons.sports_mma,
      {
        'combosPath': const FieldHint(label: 'Combos', fileExtensions: ['combos.json', 'json']),
        'guardTime': _num('Guard', 's', description: 'How long it keeps its guard after a strike, standing still.'),
      },
    ),
    fields: [
      SchemaField(
        name: 'combosPath',
        kind: FieldTypes.assetRef,
        read: (c) => (c as ThirdPersonCombat).combosPath,
        write: (c, v) => (c as ThirdPersonCombat).combosPath = v as String,
      ),
      _text<ThirdPersonCombat>('punchAction', (c) => c.punchAction, (c, v) => c.punchAction = v),
      _text<ThirdPersonCombat>('kickAction', (c) => c.kickAction, (c, v) => c.kickAction = v),
      _text<ThirdPersonCombat>('punchChain', (c) => c.punchChain, (c, v) => c.punchChain = v),
      _text<ThirdPersonCombat>('kickChain', (c) => c.kickChain, (c, v) => c.kickChain = v),
      _decimal<ThirdPersonCombat>('guardTime', (c) => c.guardTime, (c, v) => c.guardTime = v),
    ],
  );

  /// [ThirdPersonCamera].
  static ComponentSchema<ThirdPersonCamera> get camera => ComponentSchema<ThirdPersonCamera>(
    type: 'ThirdPersonCamera',
    id: 'third_person_camera_3d_4e2f9b17',
    create: ThirdPersonCamera.new,
    hints: _hints(
      'Third Person Camera',
      "The player's turn and zoom for an orbit-follow camera: the look actions turn it, the zoom axis moves it in and out.",
      Icons.threesixty,
      {
        'sensitivity': _num('Sensitivity', '×'),
        'invertY': const FieldHint(label: 'Invert Y'),
        'zoomSpeed': _num('Zoom', '/s'),
      },
    ),
    fields: [
      _decimal<ThirdPersonCamera>('sensitivity', (c) => c.sensitivity, (c, v) => c.sensitivity = v),
      _bool<ThirdPersonCamera>('invertY', (c) => c.invertY, (c, v) => c.invertY = v),
      _decimal<ThirdPersonCamera>('zoomSpeed', (c) => c.zoomSpeed, (c, v) => c.zoomSpeed = v),
      _text<ThirdPersonCamera>('zoomAction', (c) => c.zoomAction, (c, v) => c.zoomAction = v),
    ],
  );

  /// [Pickup3D].
  static ComponentSchema<Pickup3D> get pickup => ComponentSchema<Pickup3D>(
    type: 'Pickup3D',
    id: 'pickup_3d_b7d03c45',
    create: Pickup3D.new,
    hints: _hints(
      'Pickup 3D',
      'Taken by a player who touches it (give it a sensor collider), counting its value. Spins and bobs.',
      Icons.star_outline,
      {
        'value': const FieldHint(label: 'Value'),
        'spinSpeed': _num('Spin', 'rad/s'),
        'bobHeight': _num('Bob', 'm', step: 0.01),
        'bobSpeed': _num('Bob speed', 'rad/s'),
      },
    ),
    fields: [
      SchemaField(
        name: 'value',
        kind: FieldTypes.integer,
        read: (c) => (c as Pickup3D).value,
        write: (c, v) => (c as Pickup3D).value = (v as num).toInt(),
      ),
      _decimal<Pickup3D>('spinSpeed', (c) => c.spinSpeed, (c, v) => c.spinSpeed = v),
      _decimal<Pickup3D>('bobHeight', (c) => c.bobHeight, (c, v) => c.bobHeight = v),
      _decimal<Pickup3D>('bobSpeed', (c) => c.bobSpeed, (c, v) => c.bobSpeed = v),
    ],
  );

  /// [MovingPlatform3D].
  static ComponentSchema<MovingPlatform3D> get movingPlatform => ComponentSchema<MovingPlatform3D>(
    type: 'MovingPlatform3D',
    id: 'moving_platform_3d_2a9e61f8',
    create: MovingPlatform3D.new,
    hints: _hints(
      'Moving Platform 3D',
      'Goes to its travel and back (give it a kinematic body); what stands on it rides along.',
      Icons.swap_horiz,
      {
        'travel': const FieldHint(label: 'Travel', description: 'Where it goes, from where it starts (metres; -Y is up).'),
        'speed': _num('Speed', 'm/s'),
        'wait': _num('Rest', 's'),
      },
    ),
    fields: [
      SchemaField(
        name: 'travel',
        kind: FieldTypes.vector3,
        read: (c) => (c as MovingPlatform3D).travel,
        write: (c, v) => (c as MovingPlatform3D).travel = Vector3.copy(v as Vector3),
      ),
      _decimal<MovingPlatform3D>('speed', (c) => c.speed, (c, v) => c.speed = v),
      _decimal<MovingPlatform3D>('wait', (c) => c.wait, (c, v) => c.wait = v),
    ],
  );

  /// [Checkpoint3D].
  static ComponentSchema<Checkpoint3D> get checkpoint => ComponentSchema<Checkpoint3D>(
    type: 'Checkpoint3D',
    id: 'checkpoint_3d_6f1c8e93',
    create: Checkpoint3D.new,
    hints: _hints(
      'Checkpoint 3D',
      'Reached by a player (give it a sensor collider), it is where the player comes back after a fall.',
      Icons.flag_outlined,
      {'order': const FieldHint(label: 'Order', description: 'An earlier one reached later does not move the spawn back.')},
    ),
    fields: [
      SchemaField(
        name: 'order',
        kind: FieldTypes.integer,
        read: (c) => (c as Checkpoint3D).order,
        write: (c, v) => (c as Checkpoint3D).order = (v as num).toInt(),
      ),
    ],
  );

  /// [KillZone3D].
  static ComponentSchema<KillZone3D> get killZone => ComponentSchema<KillZone3D>(
    type: 'KillZone3D',
    id: 'kill_zone_3d_93d4b2a6',
    create: KillZone3D.new,
    hints: _hints(
      'Kill Zone 3D',
      'A player touching it (give it a sensor collider) is sent back to its spawn point.',
      Icons.dangerous_outlined,
      const {},
    ),
    fields: const [],
  );

  static SchemaField _decimal<T extends Component>(
    String name,
    double Function(T c) read,
    void Function(T c, double v) write,
  ) => SchemaField(
    name: name,
    kind: FieldTypes.decimal,
    read: (c) => read(c as T),
    write: (c, v) => write(c as T, (v as num).toDouble()),
  );

  static SchemaField _bool<T extends Component>(
    String name,
    bool Function(T c) read,
    void Function(T c, bool v) write,
  ) => SchemaField(
    name: name,
    kind: FieldTypes.boolean,
    read: (c) => read(c as T),
    write: (c, v) => write(c as T, v as bool),
  );

  static SchemaField _text<T extends Component>(
    String name,
    String Function(T c) read,
    void Function(T c, String v) write,
  ) => SchemaField(
    name: name,
    kind: FieldTypes.text,
    read: (c) => read(c as T),
    write: (c, v) => write(c as T, v as String),
  );
}
