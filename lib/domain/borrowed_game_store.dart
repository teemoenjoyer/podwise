/// Saving a borrowed game across a restart.
///
/// A game this phone owns is only written when it finishes, and that is fine —
/// its owner is the one holding the phone. A *borrowed* pod is different: it
/// runs for an hour or two on a phone whose owner will answer messages and
/// let Android reap the process, and if the state goes, the pod's result is
/// gone outright. Nobody else has a copy, and the phone that sent the pod has
/// no way of finding out.
///
/// Only the scoreboard is kept. Card art and oracle text are not — they are
/// recoverable from the card cache or from Scryfall, and are far bigger than
/// everything else here combined.
library;

import 'dart:convert';

import 'commander.dart';
import 'game_timer.dart';
import 'models.dart';

abstract final class BorrowedGameStore {
  /// Settings key holding the game, if there is one.
  static const key = 'borrowedGame';

  static String encode(GameState game) => jsonEncode({
    'id': game.id,
    'from': game.borrowedFrom,
    'life': game.startingLife,
    'startedAt': game.startedAt.millisecondsSinceEpoch,
    'finishedAt': game.finishedAt?.millisecondsSinceEpoch,
    'winner': game.winnerProfileId,
    'first': game.firstPlayerId,
    'firstAsked': game.firstPlayerAsked,
    'timer': {
      'accumulated': game.timer.accumulated.inMilliseconds,
      'since': game.timer.runningSince?.millisecondsSinceEpoch,
    },
    'damage': [
      for (final entry in game.commanderDamage.entries)
        {
          'src': entry.key.sourceCardId,
          'tgt': entry.key.targetProfileId,
          'n': entry.value,
        },
    ],
    'seats': [
      for (final seat in game.seats)
        {
          'id': seat.profileId,
          'name': seat.name,
          'colour': seat.colorIndex,
          'life': seat.life,
          'deck': seat.deckId,
          'out': seat.eliminated,
          'order': seat.eliminationOrder,
          'counters': seat.counters,
          'statuses': seat.statuses.toList(),
          'cards': [
            for (final card in seat.commanders.cards)
              {'id': card.id, 'name': card.name, 'type': card.typeLine},
          ],
        },
    ],
  });

  /// Reads a saved game back, or null if there is nothing readable there.
  ///
  /// A stored game that cannot be parsed is treated as absent rather than as
  /// an error: the app has moved on since it was written, and refusing to
  /// start is a far worse outcome than losing one scoreboard.
  static GameState? decode(String? raw) {
    if (raw == null || raw.isEmpty) return null;

    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;

      return GameState(
        id: json['id'] as String,
        borrowedFrom: json['from'] as String?,
        startingLife: json['life'] as int,
        startedAt: _time(json['startedAt'])!,
        finishedAt: _time(json['finishedAt']),
        winnerProfileId: json['winner'] as String?,
        firstPlayerId: json['first'] as String?,
        firstPlayerAsked: json['firstAsked'] as bool? ?? false,
        timer: GameTimer(
          accumulated: Duration(
            milliseconds: (json['timer']?['accumulated'] as int?) ?? 0,
          ),
          runningSince: _time(json['timer']?['since']),
        ),
        commanderDamage: {
          for (final entry in (json['damage'] as List? ?? []))
            CommanderDamageKey(
              sourceCardId: entry['src'] as String,
              targetProfileId: entry['tgt'] as String,
            ): entry['n'] as int,
        },
        seats: [
          for (final seat in (json['seats'] as List? ?? []))
            Seat(
              profileId: seat['id'] as String,
              name: seat['name'] as String,
              colorIndex: seat['colour'] as int,
              life: seat['life'] as int,
              deckId: seat['deck'] as String?,
              eliminated: seat['out'] as bool? ?? false,
              eliminationOrder: seat['order'] as int?,
              counters: {
                for (final e in (seat['counters'] as Map? ?? {}).entries)
                  e.key as String: e.value as int,
              },
              statuses: {
                for (final s in (seat['statuses'] as List? ?? [])) s as String,
              },
              commanders: _commanders(seat['cards'] as List? ?? const []),
            ),
        ],
      );
    } catch (_) {
      return null;
    }
  }

  /// Rebuilds the command zone from names alone.
  ///
  /// Enough for the board and for per-commander damage, which is what a
  /// scoreboard actually needs. Art is left behind deliberately.
  static CommanderSet _commanders(List<dynamic> cards) {
    var set = const CommanderSet.empty();
    for (final card in cards) {
      set = set.withCard(
        MagicCard(
          id: card['id'] as String,
          name: card['name'] as String,
          typeLine: card['type'] as String? ?? '',
          colorIdentity: const {},
        ),
      );
    }
    return set;
  }

  static DateTime? _time(Object? value) =>
      value is int ? DateTime.fromMillisecondsSinceEpoch(value) : null;
}
