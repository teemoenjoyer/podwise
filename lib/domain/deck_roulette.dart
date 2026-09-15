import 'dart:math';

import 'pod.dart';

/// Hands everybody somebody else's deck.
///
/// Two rules, both of which are the whole point of the mode:
///
/// * **Nobody plays their own deck.** Being handed your own list back is the
///   one outcome that makes the night not worth having.
/// * **No deck goes to two people.** A deck is a physical object sitting in
///   somebody's bag; it cannot be at two tables at once, or even at two seats.
///
/// Both can be impossible — three players where only one owns a deck cannot
/// all be given somebody else's. Rather than fail, this hands out what it can
/// and leaves the rest unassigned for the table to sort out, which the UI
/// says out loud.
abstract final class DeckRoulette {
  /// Deals decks to [playerIds] from [pool].
  ///
  /// Returns player id to the deck they are playing. A player who could not be
  /// given anything is absent from the map.
  static Map<String, DeckProfile> deal({
    required List<String> playerIds,
    required List<DeckProfile> pool,
    Random? random,
  }) {
    final rng = random ?? Random();
    final decks = [
      for (final deck in pool)
        if (deck.isSaved) deck,
    ]..shuffle(rng);
    final order = [...playerIds]..shuffle(rng);

    final dealt = <String, DeckProfile>{};
    final taken = <String>{};

    // Players with the fewest eligible decks are served first. Deal in an
    // arbitrary order and the last player is the one most likely to be left
    // with nothing but their own deck.
    order.sort(
      (a, b) => _eligible(
        a,
        decks,
        taken,
      ).length.compareTo(_eligible(b, decks, taken).length),
    );

    for (final playerId in order) {
      final options = _eligible(playerId, decks, taken);
      if (options.isEmpty) continue;
      final chosen = options[rng.nextInt(options.length)];
      dealt[playerId] = chosen;
      taken.add(chosen.deckId);
    }

    return dealt;
  }

  /// Deals one player a different deck, leaving everyone else alone.
  ///
  /// Returns the new assignment, or the one passed in when there is nothing
  /// else to give them.
  static Map<String, DeckProfile> reroll({
    required String playerId,
    required Map<String, DeckProfile> current,
    required List<DeckProfile> pool,
    Random? random,
  }) {
    final rng = random ?? Random();
    final taken = {
      for (final entry in current.entries)
        if (entry.key != playerId) entry.value.deckId,
    };

    final options = [
      for (final deck in pool)
        if (deck.isSaved &&
            deck.playerId != playerId &&
            !taken.contains(deck.deckId) &&
            // A re-roll that hands back the same deck looks broken, so it is
            // only allowed when there is genuinely nothing else.
            deck.deckId != current[playerId]?.deckId)
          deck,
    ];
    if (options.isEmpty) return current;

    return {...current, playerId: options[rng.nextInt(options.length)]};
  }

  static List<DeckProfile> _eligible(
    String playerId,
    List<DeckProfile> decks,
    Set<String> taken,
  ) => [
    for (final deck in decks)
      if (deck.playerId != playerId && !taken.contains(deck.deckId)) deck,
  ];
}
