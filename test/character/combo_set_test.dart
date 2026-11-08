// A `.combos.json`: what it reads, what it finds wrong, and a value of the
// wrong type said plainly.
import 'package:flutter_test/flutter_test.dart';
import 'package:just_third_person_kit/just_third_person_kit.dart';

void main() {
  test('a combo set reads its file: chains, strikes, hits and windows', () {
    final combos = ComboSet.parse('''{
      "fps": 30,
      "guard": "combat_idle",
      "chains": {"kick_combo": ["kick_1", "kick_2"]},
      "strikes": {
        "kick_1": {"move": "front kick", "limb": "left foot", "duration": 0.6667, "hit": 0.2667,
                   "combo_window": [0.3333, 0.5667], "next": "kick_2", "then": "combat_idle"},
        "kick_2": {"move": "roundhouse", "limb": "right foot", "duration": 0.8667, "hit": 0.3,
                   "combo_window": null, "next": null, "then": "combat_idle"}
      }
    }''');
    expect(combos.guard, 'combat_idle');
    expect(combos.chains, {
      'kick_combo': ['kick_1', 'kick_2'],
    });
    expect(combos.firstOf('kick_combo')?.name, 'kick_1');
    final kick = combos.strikes['kick_1']!;
    expect(
      (kick.move, kick.limb, kick.duration, kick.hit, kick.next, kick.then),
      ('front kick', 'left foot', 0.6667, 0.2667, 'kick_2', 'combat_idle'),
    );
    expect(kick.comboWindow, (open: 0.3333, close: 0.5667));
    expect(
      [kick.inWindow(0.3), kick.inWindow(0.4), kick.inWindow(0.6)],
      [false, true, false],
    );
    expect(combos.strikes['kick_2']!.comboWindow, isNull);
    expect(combos.validate(), isEmpty);

    final broken = ComboSet(
      chains: const {
        'c': ['a', 'x'],
      },
      strikes: const {
        'a': Strike(name: 'a', duration: 0.5, hit: 0.7, next: 'b'),
      },
    );
    expect(broken.validate(), [
      'Chain "c" names "x", which is not a strike.',
      'Strike "a" lands outside its duration.',
      'Strike "a" goes on to "b", which is not a strike.',
      'Strike "a" goes on to "b" but has no combo window.',
    ]);
  });

  test(
    'a combo set with a value of the wrong type is a FormatException naming it',
    () {
      expect(
        () => ComboSet.parse('{"strikes": {"jab": {"duration": "0.5"}}}'),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('jab'),
          ),
        ),
      );
    },
  );
}
