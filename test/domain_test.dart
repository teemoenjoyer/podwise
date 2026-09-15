import 'package:flutter_test/flutter_test.dart';
import 'package:podwise/domain/models.dart';

void main() {
  group('PlayerProfile.initials', () {
    PlayerProfile named(String name) => PlayerProfile(id: 'x', name: name);

    test('uses first and last initial for multi-word names', () {
      expect(named('Sarah Connor').initials, 'SC');
      expect(named('mary jane watson').initials, 'MW');
    });

    test('uses the first two characters of a single name', () {
      expect(named('Dave').initials, 'DA');
    });

    test('handles a single character', () {
      expect(named('D').initials, 'D');
    });

    test('tolerates padding and repeated spaces', () {
      expect(named('  josh   smith  ').initials, 'JS');
    });

    test('falls back rather than throwing on an empty name', () {
      expect(named('').initials, '?');
      expect(named('   ').initials, '?');
    });
  });

  group('GameState', () {
    Seat seat(String id, {int life = 40, bool out = false}) => Seat(
      profileId: id,
      name: id,
      colorIndex: 0,
      life: life,
      eliminated: out,
    );

    GameState gameWith(List<Seat> seats) => GameState(
      id: 'g',
      seats: seats,
      startingLife: 40,
      startedAt: DateTime(2026, 1, 1),
    );

    test('reports a sole survivor once everyone else is eliminated', () {
      final game = gameWith([
        seat('a'),
        seat('b', out: true),
        seat('c', out: true),
        seat('d', out: true),
      ]);
      expect(game.hasSoleSurvivor, isTrue);
      expect(game.survivors.single.profileId, 'a');
    });

    test('does not report a sole survivor while two players remain', () {
      final game = gameWith([seat('a'), seat('b'), seat('c', out: true)]);
      expect(game.hasSoleSurvivor, isFalse);
      expect(game.survivors, hasLength(2));
    });

    test('a single-player game is never a sole-survivor win', () {
      expect(gameWith([seat('a')]).hasSoleSurvivor, isFalse);
    });

    test('zero life does not eliminate a player on its own', () {
      // Commander has many loss conditions, so elimination stays explicit.
      final game = gameWith([seat('a', life: 0), seat('b')]);
      expect(game.survivors, hasLength(2));
      expect(game.hasSoleSurvivor, isFalse);
    });
  });

  group('Seat.copyWith', () {
    const original = Seat(
      profileId: 'a',
      name: 'Dave',
      colorIndex: 2,
      life: 40,
      eliminated: true,
      eliminationOrder: 3,
    );

    test('preserves untouched fields', () {
      final next = original.copyWith(life: 12);
      expect(next.life, 12);
      expect(next.name, 'Dave');
      expect(next.colorIndex, 2);
      expect(next.eliminationOrder, 3);
    });

    test('clears elimination order when explicitly asked', () {
      final revived = original.copyWith(
        eliminated: false,
        clearEliminationOrder: true,
      );
      expect(revived.eliminated, isFalse);
      expect(revived.eliminationOrder, isNull);
    });

    test('life can go negative', () {
      // Life below zero is legal and worth showing; the player stays in the
      // game until someone eliminates them.
      expect(original.copyWith(life: -7).life, -7);
    });
  });
}
