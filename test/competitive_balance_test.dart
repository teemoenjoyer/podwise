import 'package:flutter_test/flutter_test.dart';
import 'package:podwise/domain/pod.dart';
import 'package:podwise/domain/pod_builder.dart';

/// Competitive Balance puts the strongest decks at the same table.
///
/// It is the deliberate opposite of Casual Balance, which spreads them out.
/// The two used to share a scoring component, so both were quietly doing the
/// same thing.
void main() {
  DeckProfile deck(String name, int power) =>
      DeckProfile(playerId: name, playerName: name, power: power);

  /// The powers from the reported case: two 10s, a 9, four 5s and a 3.
  List<DeckProfile> theTable() => [
    deck('Taylor Smith', 3),
    deck('Avery', 10),
    deck('Ben', 5),
    deck('Robin', 9),
    deck('Jordan', 10),
    deck('Sydney', 5),
    deck('Dave', 5),
    deck('Morgan Bailey', 5),
  ];

  List<List<int>> powersOf(PodAssignment assignment) => [
    for (final pod in assignment.pods)
      [for (final m in pod.members) m.power]..sort(),
  ];

  group('competitive balance', () {
    test('the strongest decks end up together', () {
      final best = PodBuilder.build(
        players: theTable(),
        mode: PodMode.competitiveBalance,
      ).first;

      final strongest = best.pods.firstWhere(
        (p) => p.members.any((m) => m.power == 10),
      );

      // Both 10s and the 9 at one table — not split across two so that each
      // pod gets one, which is what evening power out would do.
      expect(
        strongest.members.where((m) => m.power >= 9).length,
        3,
        reason: 'powers were ${powersOf(best)}',
      );
      // And the weakest deck is not sitting with them.
      expect(strongest.members.any((m) => m.power == 3), isFalse);
    });

    test('the weakest decks end up together', () {
      final best = PodBuilder.build(
        players: theTable(),
        mode: PodMode.competitiveBalance,
      ).first;

      final weakest = best.pods.firstWhere(
        (p) => p.members.any((m) => m.power == 3),
      );
      expect(weakest.members.every((m) => m.power <= 5), isTrue);
    });

    test('it is the opposite of casual balance', () {
      final competitive = PodBuilder.build(
        players: theTable(),
        mode: PodMode.competitiveBalance,
      ).first;
      final casual = PodBuilder.build(
        players: theTable(),
        mode: PodMode.casualBalance,
      ).first;

      double gap(PodAssignment a) {
        final averages = [for (final p in a.pods) p.averagePower];
        averages.sort();
        return averages.last - averages.first;
      }

      // Casual keeps the pods close in average power; competitive pulls them
      // apart on purpose.
      expect(
        gap(competitive),
        greaterThan(gap(casual)),
        reason:
            'competitive ${powersOf(competitive)} '
            'vs casual ${powersOf(casual)}',
      );
    });

    test('a tiered split scores better than a mixed one', () {
      final tiered = PodBuilder.score(
        [
          Pod([deck('a', 10), deck('b', 10), deck('c', 9), deck('d', 9)]),
          Pod([deck('e', 4), deck('f', 4), deck('g', 3), deck('h', 3)]),
        ],
        PodMode.competitiveBalance,
        const {},
      );
      final mixed = PodBuilder.score(
        [
          Pod([deck('a', 10), deck('b', 3), deck('c', 9), deck('d', 4)]),
          Pod([deck('e', 10), deck('f', 4), deck('g', 9), deck('h', 3)]),
        ],
        PodMode.competitiveBalance,
        const {},
      );

      expect(tiered.powerTiering, greaterThan(mixed.powerTiering));
      expect(tiered.total, greaterThan(mixed.total));
      // The mixed split is the one that evens power out, so it should still
      // look good by the *other* measure — the two really are opposites.
      expect(mixed.powerBalance, greaterThan(tiered.powerBalance));
    });

    test('one table cannot be tiered, and is not marked down for it', () {
      final single = PodBuilder.score(
        [
          Pod([deck('a', 10), deck('b', 3), deck('c', 9), deck('d', 4)]),
        ],
        PodMode.competitiveBalance,
        const {},
      );

      // There is no second table to send anybody to, so this is a statement
      // about the situation rather than about the split.
      expect(single.powerTiering, 1);
    });
  });
}
