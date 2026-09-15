import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../data/database.dart';
import '../domain/commander.dart';
import '../domain/models.dart';
import '../domain/pod.dart';
import '../domain/transfer.dart';
import 'providers.dart';

const _uuid = Uuid();

/// Identifies this install, so a result can only be taken home by the phone
/// that sent the pod out.
///
/// Generated once and kept in the settings table. Without it, scanning any
/// stranger's result would write their players into this phone's history and
/// statistics, where nothing would ever remove them.
final transferDeviceIdProvider = FutureProvider<String>((ref) async {
  const key = 'transferDeviceId';
  final db = ref.watch(databaseProvider);

  final existing = (await db.allSettings())[key];
  if (existing != null && existing.isNotEmpty) return existing;

  final created = _uuid.v4();
  await db.putSetting(key, created);
  return created;
});

/// Turns pods and finished games into codes, and codes back into games.
final transferServiceProvider = Provider((ref) => TransferService(ref));

class TransferService {
  TransferService(this._ref);
  final Ref _ref;

  PodWiseDatabase get _db => _ref.read(databaseProvider);

  // ---- Sending ------------------------------------------------------------

  /// Packs a built pod for another phone.
  Future<PodTransfer> packPod(Pod pod) async {
    final deviceId = await _ref.read(transferDeviceIdProvider.future);
    final cards = await _commanderCardsFor(pod);

    return PodTransfer(
      sourceDeviceId: deviceId,
      seats: [
        for (final member in pod.members)
          TransferSeat(
            playerId: member.playerId,
            name: member.playerName,
            colorIndex: _colorIndexFor(member.playerId),
            // Empty means "no saved deck", and must not travel as an empty
            // string — the per-deck records are keyed on this.
            deckId: member.isSaved ? member.deckId : null,
            commanders: [
              for (final id in member.commanderIds)
                if (cards[id] case final card?)
                  TransferCard(id: card.id, name: card.name),
            ],
            // Only needed when the card names cannot speak for the deck.
            label: member.commanderIds.isEmpty ? member.displayName : null,
          ),
      ],
    );
  }

  /// Packs a finished borrowed game to send home.
  ResultTransfer packResult(GameState game) {
    final winner = game.winnerProfileId;
    final ranked = game.rankedBy(winner);

    return ResultTransfer(
      sourceDeviceId: game.borrowedFrom!,
      gameId: game.id,
      startedAt: game.startedAt,
      finishedAt: game.finishedAt ?? DateTime.now(),
      startingLife: game.startingLife,
      winnerPlayerId: winner,
      results: [
        for (var i = 0; i < ranked.length; i++)
          TransferResult(
            playerId: ranked[i].profileId,
            name: ranked[i].name,
            colorIndex: ranked[i].colorIndex,
            // Where they sat, not where they finished.
            seatIndex: game.seats.indexWhere(
              (s) => s.profileId == ranked[i].profileId,
            ),
            position: i + 1,
            finalLife: ranked[i].life,
            deckId: ranked[i].deckId,
            eliminated: ranked[i].eliminated,
          ),
      ],
    );
  }

  // ---- Receiving ----------------------------------------------------------

  /// Rebuilds each seat's command zone for a pod that has just arrived.
  ///
  /// Three tiers, because this phone has never seen the other group's decks:
  /// the local cache first, then Scryfall for anything missing, and finally a
  /// placeholder built from the name in the code. That last tier matters —
  /// commander damage is tracked per card, so a seat whose cards cannot be
  /// resolved at all would have nothing to track damage against.
  Future<Map<String, CommanderSet>> resolveCommanders(PodTransfer pod) async {
    final repository = _ref.read(cardRepositoryProvider);
    final resolved = <String, CommanderSet>{};

    for (final seat in pod.seats) {
      if (seat.commanders.isEmpty) continue;

      final ids = [for (final card in seat.commanders) card.id];
      var set = await repository.commanderSet(ids);

      if (set.cards.length < ids.length) {
        // Anything still missing is worth one look online; failures fall
        // through to the placeholder below rather than stopping the import.
        await repository.fetchMissing(ids);
        set = await repository.commanderSet(ids);
      }

      final found = {for (final card in set.cards) card.id};
      for (final card in seat.commanders) {
        if (found.contains(card.id)) continue;
        set = set.withCard(
          MagicCard(
            id: card.id,
            name: card.name,
            typeLine: 'Legendary Creature',
            colorIdentity: const {},
          ),
        );
      }

      resolved[seat.playerId] = set;
    }

    return resolved;
  }

  /// Seats a borrowed pod as in-memory players. Nothing is written: these
  /// people belong to another phone's playgroup.
  List<PlayerProfile> seatsAsPlayers(PodTransfer pod) => [
    for (final seat in pod.seats)
      PlayerProfile(
        id: seat.playerId,
        name: seat.name,
        colorIndex: seat.colorIndex,
      ),
  ];

  /// Takes a returning result and writes it to history.
  ///
  /// Returns what happened, so the screen can tell the difference between "we
  /// already had this" and "saved" rather than silently doing nothing.
  Future<ImportOutcome> importResult(ResultTransfer result) async {
    final deviceId = await _ref.read(transferDeviceIdProvider.future);
    if (result.sourceDeviceId != deviceId) return ImportOutcome.notOurs;

    final saved = await _db.importFinishedGame(
      game: GameRow(
        id: result.gameId,
        startedAt: result.startedAt,
        finishedAt: result.finishedAt,
        startingLife: result.startingLife,
        deckRoulette: false,
        winnerProfileId: result.winnerPlayerId,
      ),
      participants: [
        for (final entry in result.results)
          GameParticipantsCompanion(
            gameId: Value(result.gameId),
            profileId: Value(entry.playerId),
            name: Value(entry.name),
            seatIndex: Value(entry.seatIndex),
            colorIndex: Value(entry.colorIndex),
            finalLife: Value(entry.finalLife),
            deckId: Value(entry.deckId),
            position: Value(entry.position),
            eliminated: Value(entry.eliminated),
          ),
      ],
    );

    if (!saved) return ImportOutcome.alreadyHave;

    _ref.invalidate(gameHistoryProvider);
    _ref.invalidate(playerProfilesProvider);
    return ImportOutcome.saved;
  }

  // ---- Helpers ------------------------------------------------------------

  int _colorIndexFor(String playerId) {
    final players = _ref.read(playerProfilesProvider).valueOrNull ?? const [];
    return players
            .where((p) => p.id == playerId)
            .map((p) => p.colorIndex)
            .firstOrNull ??
        0;
  }

  /// Card details for every commander in the pod, so their names can travel
  /// with them.
  Future<Map<String, MagicCard>> _commanderCardsFor(Pod pod) async {
    final repository = _ref.read(cardRepositoryProvider);
    final cards = <String, MagicCard>{};

    for (final member in pod.members) {
      final set = await repository.commanderSet(member.commanderIds);
      for (final card in set.cards) {
        cards[card.id] = card;
      }
    }
    return cards;
  }
}

/// What became of a scanned result.
enum ImportOutcome {
  saved,

  /// Already in history. Re-importing would double everybody's record.
  alreadyHave,

  /// From a pod this phone never sent, so its players mean nothing here.
  notOurs,
}
