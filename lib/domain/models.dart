import 'package:flutter/foundation.dart';

import 'commander.dart';
import 'game_timer.dart';

/// A person who plays, independent of any single game. Saved so the group
/// doesn't retype names every session.
@immutable
class PlayerProfile {
  const PlayerProfile({
    required this.id,
    required this.name,
    this.colorIndex = 0,
    this.gamesPlayed = 0,
    this.wins = 0,
    this.lastPlayedAt,
  });

  final String id;
  final String name;
  final int colorIndex;
  final int gamesPlayed;
  final int wins;
  final DateTime? lastPlayedAt;

  /// Initials for the avatar. Two letters where the name has two words,
  /// otherwise the first two characters.
  String get initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      final single = parts.first;
      return single.length == 1
          ? single.toUpperCase()
          : single.substring(0, 2).toUpperCase();
    }
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  double get winRate => gamesPlayed == 0 ? 0 : wins / gamesPlayed;

  PlayerProfile copyWith({String? name, int? colorIndex}) => PlayerProfile(
    id: id,
    name: name ?? this.name,
    colorIndex: colorIndex ?? this.colorIndex,
    gamesPlayed: gamesPlayed,
    wins: wins,
    lastPlayedAt: lastPlayedAt,
  );
}

/// A player as they exist *within one game*: their seat, life, and status.
@immutable
class Seat {
  const Seat({
    required this.profileId,
    required this.name,
    required this.colorIndex,
    required this.life,
    this.deckId,
    this.commanders = const CommanderSet.empty(),
    this.commanderLabel,
    this.counters = const {},
    this.statuses = const {},
    this.eliminated = false,
    this.eliminationOrder,
  });

  final String profileId;
  final String name;
  final int colorIndex;
  final int life;

  /// Which of the player's saved decks this is, when they brought one. Null
  /// for a game started without picking a commander, so results from it are
  /// attributed to the player but to no particular deck.
  final String? deckId;

  /// What this player has in the command zone. May be empty — the brief is
  /// explicit that a game can start without picking commanders.
  final CommanderSet commanders;

  /// What to call this player's commander when there are no cards for it.
  ///
  /// A deck can name its commander without the app holding the card: decks
  /// carried over from before card ids existed are the common case, and a pod
  /// borrowed from another phone is the other. Used only when [commanders] is
  /// empty, so a real command zone always wins.
  final String? commanderLabel;

  /// Numeric counters by counter-type id. Absent means zero.
  final Map<String, int> counters;

  /// Status effect ids currently active on this player.
  final Set<String> statuses;

  /// Commander has many loss conditions, so elimination is always explicit —
  /// never inferred from life reaching zero.
  final bool eliminated;

  /// 0 = knocked out first. Null while still alive. Drives finishing position.
  final int? eliminationOrder;

  String get initials => PlayerProfile(id: profileId, name: name).initials;

  /// The id used for this player's commander when they have not named one.
  ///
  /// Namespaced so it can never collide with a Scryfall id.
  String get unnamedCommanderId => 'seat:$profileId';

  /// What this player's commander is called, or null if nothing names it.
  ///
  /// The cards win when there are any, because they are the only thing that
  /// can be right about partners.
  String? get commanderDisplayName =>
      commanders.isNotEmpty ? commanders.displayName : commanderLabel;

  /// Everything this player can deal commander damage with.
  ///
  /// A player who has not chosen a commander still has one sitting in their
  /// command zone — the app just does not know what it is. They get a single
  /// stand-in source rather than being unable to deal commander damage at
  /// all, which is the common case at a table that has not bothered entering
  /// commanders. Named after the deck's commander when the deck knows it, so
  /// the sheet reads "Shao Jun" rather than "Jordan's commander".
  List<MagicCard> get damageSources => commanders.isNotEmpty
      ? commanders.damageSources
      : [
          MagicCard(
            id: unnamedCommanderId,
            name: commanderLabel ?? "$name's commander",
            typeLine: '',
            colorIdentity: const {},
          ),
        ];

  Seat copyWith({
    int? life,
    CommanderSet? commanders,
    Map<String, int>? counters,
    Set<String>? statuses,
    bool? eliminated,
    int? eliminationOrder,
    bool clearEliminationOrder = false,
  }) => Seat(
    profileId: profileId,
    name: name,
    colorIndex: colorIndex,
    life: life ?? this.life,
    deckId: deckId,
    commanders: commanders ?? this.commanders,
    commanderLabel: commanderLabel,
    counters: counters ?? this.counters,
    statuses: statuses ?? this.statuses,
    eliminated: eliminated ?? this.eliminated,
    eliminationOrder: clearEliminationOrder
        ? null
        : (eliminationOrder ?? this.eliminationOrder),
  );
}

/// Identifies one commander-damage relationship: damage dealt *by a specific
/// commander card* *to a specific player*.
///
/// Section 11 of the brief is emphatic about this. "Bob has 12 commander
/// damage" is wrong — the 21-damage threshold applies per commander, so
/// Sarah's Atraxa hitting Bob for 12 and Chris for 6 are separate totals, and
/// a player with two partners tracks each one independently.
@immutable
class CommanderDamageKey {
  const CommanderDamageKey({
    required this.sourceCardId,
    required this.targetProfileId,
  });

  /// The Scryfall id of the commander dealing the damage.
  final String sourceCardId;

  /// The profile id of the player receiving it.
  final String targetProfileId;

  @override
  bool operator ==(Object other) =>
      other is CommanderDamageKey &&
      other.sourceCardId == sourceCardId &&
      other.targetProfileId == targetProfileId;

  @override
  int get hashCode => Object.hash(sourceCardId, targetProfileId);

  @override
  String toString() => '$sourceCardId->$targetProfileId';
}

/// The damage threshold at which commander damage alone eliminates a player.
const commanderDamageThreshold = 21;

/// The live state of a game in progress.
@immutable
class GameState {
  const GameState({
    required this.id,
    required this.seats,
    required this.startingLife,
    required this.startedAt,
    this.commanderDamage = const {},
    this.timer = const GameTimer(),
    this.finishedAt,
    this.winnerProfileId,
    this.borrowedFrom,
    this.firstPlayerId,
    this.firstPlayerAsked = false,
    this.deckRoulette = false,
    this.farRowSeats,
  });

  final String id;
  final List<Seat> seats;
  final int startingLife;
  final DateTime startedAt;

  /// Every commander-damage total in the game, keyed by source commander and
  /// target player. Absent entries are zero.
  final Map<CommanderDamageKey, int> commanderDamage;

  /// Optional stopwatch for the game.
  final GameTimer timer;

  final DateTime? finishedAt;
  final String? winnerProfileId;

  /// The device id of the phone whose pod this is, when the game was handed
  /// over from somewhere else. Null for a game this phone owns.
  ///
  /// A borrowed game is tracked but never written to this phone's history —
  /// the players in it belong to someone else's playgroup, and recording them
  /// here would put strangers into these statistics permanently. The result
  /// goes home as a code instead.
  final String? borrowedFrom;

  bool get isBorrowed => borrowedFrom != null;

  /// How many players sit on the far side of the phone, when the table has
  /// said. Null means the balanced default for this many players.
  ///
  /// Held on the game rather than in settings because it describes the table
  /// this game is being played at, not a preference: the same group sits
  /// differently in a booth than around a kitchen table.
  final int? farRowSeats;

  /// Who was drawn to take the first turn, once somebody has been.
  ///
  /// Recorded only so the draw is not offered twice for the same game. The
  /// app deliberately does not track turns beyond this.
  final String? firstPlayerId;

  bool get hasFirstPlayer => firstPlayerId != null;

  /// Everybody is playing somebody else's deck, so the result counts for the
  /// players but never for the decks.
  final bool deckRoulette;

  /// Whether the draw has been put to the table for this game, however they
  /// answered. Skipping is an answer: a table that would rather sort the first
  /// turn out themselves should not be asked again every time somebody leaves
  /// the board and comes back.
  final bool firstPlayerAsked;

  bool get isFinished => finishedAt != null;

  int damageFrom(String sourceCardId, String targetProfileId) =>
      commanderDamage[CommanderDamageKey(
        sourceCardId: sourceCardId,
        targetProfileId: targetProfileId,
      )] ??
      0;

  /// Commander damage this player has taken, highest first, for display.
  List<MapEntry<CommanderDamageKey, int>> damageTakenBy(String profileId) {
    final taken =
        commanderDamage.entries
            .where((e) => e.key.targetProfileId == profileId && e.value > 0)
            .toList()
          ..sort((a, b) => b.value.compareTo(a.value));
    return taken;
  }

  /// Whether any single commander has dealt this player lethal damage.
  bool isLethalCommanderDamage(String profileId) => commanderDamage.entries.any(
    (e) =>
        e.key.targetProfileId == profileId &&
        e.value >= commanderDamageThreshold,
  );

  List<Seat> get survivors => seats.where((s) => !s.eliminated).toList();

  /// A game resolves itself once exactly one player remains. The user can also
  /// end it manually, since a win can happen with several players still alive.
  bool get hasSoleSurvivor => survivors.length == 1 && seats.length > 1;

  Duration get elapsed => (finishedAt ?? DateTime.now()).difference(startedAt);

  /// Seats in finishing order: the winner, anyone still standing, then the
  /// knocked-out in reverse order of their exit.
  ///
  /// **Position comes from the order people were eliminated, never from life
  /// totals.** Whoever went out first finishes last, whoever went out second
  /// finishes second-last, and so on. Life is a poor proxy for it: a player
  /// can be knocked out from 38 while somebody else limps to the end on 2, and
  /// ranking by life would put them the wrong way round.
  ///
  /// Built by parts rather than sorted with a comparator, because Dart's sort
  /// is not stable — genuine ties would otherwise come out in an arbitrary
  /// order that could differ between runs.
  List<Seat> rankedBy(String? winnerProfileId) {
    final winner = seats
        .where((s) => s.profileId == winnerProfileId)
        .firstOrNull;

    bool isWinner(Seat s) => s.profileId == winner?.profileId;

    // Survivors keep their seat order. There is nothing left to rank them by
    // except life, and life is exactly what this must not use.
    final standing = [
      for (final seat in seats)
        if (!seat.eliminated && !isWinner(seat)) seat,
    ];

    final knockedOut =
        [
          for (final seat in seats)
            if (seat.eliminated && !isWinner(seat)) seat,
        ]..sort(
          // Highest elimination order first: the last player out finishes best.
          (a, b) =>
              (b.eliminationOrder ?? 0).compareTo(a.eliminationOrder ?? 0),
        );

    return [?winner, ...standing, ...knockedOut];
  }

  /// Who won, taking an explicit choice first and falling back to a sole
  /// survivor. Null is a legitimate answer — a game can end with nobody
  /// recorded as having won.
  String? resolveWinner(String? chosen) =>
      chosen ?? (hasSoleSurvivor ? survivors.single.profileId : null);

  GameState copyWith({
    List<Seat>? seats,
    Map<CommanderDamageKey, int>? commanderDamage,
    GameTimer? timer,
    DateTime? finishedAt,
    String? winnerProfileId,
    String? firstPlayerId,
    bool? firstPlayerAsked,
    int? farRowSeats,
  }) => GameState(
    id: id,
    borrowedFrom: borrowedFrom,
    deckRoulette: deckRoulette,
    firstPlayerId: firstPlayerId ?? this.firstPlayerId,
    firstPlayerAsked: firstPlayerAsked ?? this.firstPlayerAsked,
    seats: seats ?? this.seats,
    startingLife: startingLife,
    startedAt: startedAt,
    commanderDamage: commanderDamage ?? this.commanderDamage,
    timer: timer ?? this.timer,
    finishedAt: finishedAt ?? this.finishedAt,
    winnerProfileId: winnerProfileId ?? this.winnerProfileId,
    farRowSeats: farRowSeats ?? this.farRowSeats,
  );
}

/// A finished game, as stored in history.
@immutable
class GameRecord {
  const GameRecord({
    required this.id,
    required this.startedAt,
    required this.finishedAt,
    required this.startingLife,
    required this.results,
    this.winnerProfileId,
  });

  final String id;
  final DateTime startedAt;
  final DateTime finishedAt;
  final int startingLife;
  final List<GameResult> results;
  final String? winnerProfileId;

  Duration get duration => finishedAt.difference(startedAt);

  GameResult? get winner {
    for (final r in results) {
      if (r.profileId == winnerProfileId) return r;
    }
    return null;
  }
}

/// One player's outcome in a finished game.
@immutable
class GameResult {
  const GameResult({
    required this.profileId,
    required this.name,
    required this.finalLife,
    required this.position,
    required this.won,
  });

  final String profileId;
  final String name;
  final int finalLife;

  /// 1 = won. Higher numbers finished earlier.
  final int position;
  final bool won;
}
