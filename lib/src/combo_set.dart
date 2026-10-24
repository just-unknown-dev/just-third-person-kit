import 'dart:convert';

/// One strike of a combo: a one-shot clip of the same name, when in it the
/// blow lands, and when a press may ask for the strike after it.
final class Strike {
  /// A strike called [name], [duration] seconds long, landing at [hit].
  const Strike({
    required this.name,
    required this.duration,
    required this.hit,
    this.comboWindow,
    this.next,
    this.then = '',
    this.move = '',
    this.limb = '',
  });

  /// Its name: the clip it plays, and the animator trigger that plays it.
  final String name;

  /// Seconds it lasts, start to end.
  final double duration;

  /// Seconds in when the blow lands: when game code applies its damage.
  final double hit;

  /// Seconds in, from and to, when a press asks for [next]; null for none.
  final ({double open, double close})? comboWindow;

  /// The strike a press in [comboWindow] chains to; null for a finisher.
  final String? next;

  /// What it ends in when nothing follows: the guard stance's clip.
  final String then;

  /// What it is, in words: "jab", "roundhouse".
  final String move;

  /// What it strikes with, in words: "left hand", "right foot".
  final String limb;

  /// Whether [time], seconds in, is inside its combo window.
  bool inWindow(double time) {
    final window = comboWindow;
    return window != null && time >= window.open && time <= window.close;
  }

  /// Reads one entry of a `.combos.json`'s `strikes`, called [name].
  /// Throws a [FormatException] naming the strike when a value has the wrong
  /// type (`"duration": "0.5"`).
  factory Strike.fromJson(String name, Map<String, dynamic> json) {
    try {
      return Strike._fromJson(name, json);
    } on TypeError catch (e) {
      throw FormatException('Strike "$name": a value has the wrong type ($e).');
    }
  }

  factory Strike._fromJson(String name, Map<String, dynamic> json) {
    final window = json['combo_window'];
    return Strike(
      name: name,
      duration: (json['duration'] as num?)?.toDouble() ?? 0,
      hit: (json['hit'] as num?)?.toDouble() ?? 0,
      comboWindow: window is List && window.length == 2
          ? (open: (window[0] as num).toDouble(), close: (window[1] as num).toDouble())
          : null,
      next: json['next'] as String?,
      then: json['then'] as String? ?? '',
      move: json['move'] as String? ?? '',
      limb: json['limb'] as String? ?? '',
    );
  }
}

/// A character's strikes and the chains they make: what a `.combos.json`
/// beside its model holds. A chain starts at its first strike; a press in
/// a strike's combo window goes on to its `next`.
final class ComboSet {
  /// [strikes] by name, [chains] of their names, ending in [guard].
  const ComboSet({this.guard = '', this.chains = const {}, this.strikes = const {}});

  /// The clip strikes start from and end in: the guard stance.
  final String guard;

  /// Each chain's strikes, first to last, by chain name.
  final Map<String, List<String>> chains;

  /// Every strike, by name.
  final Map<String, Strike> strikes;

  /// The first strike of the chain called [chain], or null.
  Strike? firstOf(String chain) {
    final names = chains[chain];
    return names == null || names.isEmpty ? null : strikes[names.first];
  }

  /// What is wrong with it, in words an author can act on; empty when
  /// nothing is.
  List<String> validate() {
    final problems = <String>[];
    for (final MapEntry(key: chain, value: names) in chains.entries) {
      if (names.isEmpty) problems.add('Chain "$chain" has no strikes.');
      for (final name in names) {
        if (!strikes.containsKey(name)) problems.add('Chain "$chain" names "$name", which is not a strike.');
      }
    }
    for (final s in strikes.values) {
      if (s.duration <= 0) problems.add('Strike "${s.name}" has no duration.');
      if (s.hit < 0 || s.hit > s.duration) problems.add('Strike "${s.name}" lands outside its duration.');
      final next = s.next;
      if (next != null && !strikes.containsKey(next)) {
        problems.add('Strike "${s.name}" goes on to "$next", which is not a strike.');
      }
      final window = s.comboWindow;
      if (window != null && (window.open > window.close || window.open < 0 || window.close > s.duration)) {
        problems.add('Strike "${s.name}" has a combo window outside its duration.');
      }
      if (next != null && window == null) problems.add('Strike "${s.name}" goes on to "$next" but has no combo window.');
    }
    return problems;
  }

  /// Reads a `.combos.json`: `guard`, `chains` (name to strike names) and
  /// `strikes` (name to `duration`, `hit`, `combo_window`, `next`, `then`,
  /// `move`, `limb`), times in seconds. Missing parts are empty. Throws a
  /// [FormatException] saying what has the wrong type.
  factory ComboSet.fromJson(Map<String, dynamic> json) {
    try {
      return ComboSet._fromJson(json);
    } on TypeError catch (e) {
      throw FormatException('A combo set has a value of the wrong type ($e).');
    }
  }

  factory ComboSet._fromJson(Map<String, dynamic> json) => ComboSet(
    guard: json['guard'] as String? ?? '',
    chains: {
      for (final MapEntry(:key, :value) in ((json['chains'] as Map?) ?? const {}).entries)
        if (value is List) key as String: [for (final name in value) name as String],
    },
    strikes: {
      for (final MapEntry(:key, :value) in ((json['strikes'] as Map?) ?? const {}).entries)
        if (value is Map) key as String: Strike.fromJson(key, value.cast<String, dynamic>()),
    },
  );

  /// Reads [source], the text of a `.combos.json`, as [ComboSet.fromJson]
  /// does. Throws a [FormatException] when it is not a JSON object.
  factory ComboSet.parse(String source) {
    final json = jsonDecode(source);
    if (json is! Map<String, dynamic>) throw FormatException('A combo set is a JSON object.', source);
    return ComboSet.fromJson(json);
  }
}
