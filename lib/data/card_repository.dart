import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';

import '../domain/commander.dart';
import 'database.dart';
import 'scryfall_client.dart';

/// Where a set of search results came from. The UI shows this so a player can
/// tell "no such commander" apart from "we're offline and it isn't cached".
enum CardSearchSource { network, cache, cacheAfterFailure }

class CardSearchResult {
  const CardSearchResult(this.cards, this.source);
  final List<MagicCard> cards;
  final CardSearchSource source;

  bool get isOffline => source != CardSearchSource.network;
}

/// Card lookup with an offline-first fallback.
///
/// Section 28 of the brief is firm that a lookup failure must never strand the
/// user on an error screen, so every network failure degrades to the local
/// cache instead of throwing.
class CardRepository {
  /// Positional rather than named because Dart forbids private named
  /// parameters, and these two fields want to stay private.
  const CardRepository(this._db, this._client);

  final PodWiseDatabase _db;
  final ScryfallClient _client;

  Future<CardSearchResult> search(
    String query, {
    bool legalOnly = false,
  }) async {
    final trimmed = query.trim();
    if (trimmed.length < 2) {
      return const CardSearchResult([], CardSearchSource.network);
    }

    try {
      final cards = await _client.searchCommanders(
        trimmed,
        legalOnly: legalOnly,
      );
      // Cache in the background — a slow write must not delay the results.
      unawaited(_cache(cards));
      return CardSearchResult(cards, CardSearchSource.network);
    } on ScryfallException catch (e) {
      // Logged rather than shown: the user gets cached results instead of an
      // error, but a silent fallback is very hard to diagnose without this.
      debugPrint('PodWise: Scryfall search failed — $e');
      return CardSearchResult(
        await _searchCache(trimmed, legalOnly: legalOnly),
        CardSearchSource.cacheAfterFailure,
      );
    } catch (e) {
      // Anything unexpected is still not worth an error screen at a table.
      debugPrint('PodWise: unexpected card search failure — $e');
      return CardSearchResult(
        await _searchCache(trimmed, legalOnly: legalOnly),
        CardSearchSource.cacheAfterFailure,
      );
    }
  }

  /// Cache-only search, for showing previously used commanders instantly while
  /// the network request is still in flight.
  Future<List<MagicCard>> searchCacheOnly(
    String query, {
    bool legalOnly = false,
  }) => _searchCache(query.trim(), legalOnly: legalOnly);

  /// Records that a card was actually chosen, which promotes it in offline
  /// search results.
  Future<void> markUsed(MagicCard card) async {
    await _cache([card]);
    await _db.recordCardUse(card.id);
  }

  Future<int> cachedCount() => _db.cachedCardCount();

  /// Fetches any of these cards this phone has never seen, and caches them.
  ///
  /// Used when a pod arrives from someone else's phone: their commanders are
  /// very unlikely to be in our cache, and without the real cards a borrowed
  /// pod shows no art and no per-commander damage tracking.
  ///
  /// Best effort by design. Each failure is skipped rather than aborting the
  /// import — a pod that arrives at a table with no signal must still be
  /// playable, just with plainer cards.
  Future<void> fetchMissing(List<String> cardIds) async {
    if (cardIds.isEmpty) return;
    final known = {
      for (final row in await _db.cachedCardsByIds(cardIds)) row.id,
    };

    for (final id in cardIds) {
      if (known.contains(id)) continue;
      try {
        // Sequential on purpose: the client paces itself against Scryfall's
        // rate limit, and a pod is at most a handful of cards.
        await _cache([await _client.cardById(id)]);
      } catch (e) {
        debugPrint('PodWise: could not fetch commander $id — $e');
      }
    }
  }

  /// Looks up who painted [card], for a card cached before the app recorded
  /// artists.
  ///
  /// Art is credited wherever it is shown, but cards are served from the
  /// cache and never refetched, so every card cached before schema v8 would
  /// keep its art and never acquire a credit. This fills that gap one card at
  /// a time, only when something is about to show that card's art.
  ///
  /// Returns null when the artist is already known, when there is no art to
  /// credit, or when the lookup fails — offline being the usual reason. The
  /// caller shows no credit in that case rather than waiting.
  Future<String?> artistOf(MagicCard card) async {
    if (card.artist != null) return card.artist;
    if (card.imageArtCrop == null) return null;
    try {
      final fresh = await _client.cardById(card.id);
      // Cached on the way past, so the next game pays nothing.
      await _cache([fresh]);
      return fresh.artist;
    } catch (e) {
      debugPrint('PodWise: could not look up the artist for ${card.name} — $e');
      return null;
    }
  }

  /// Rebuilds a saved deck's command zone from the offline cache.
  ///
  /// Cards are cached the moment they are chosen, so this normally succeeds
  /// without a network call. Any card that has since been evicted is simply
  /// dropped — a deck missing one of its partners still tracks life correctly,
  /// which matters more at a table than being exactly right about the
  /// command zone.
  Future<CommanderSet> commanderSet(List<String> cardIds) async {
    if (cardIds.isEmpty) return const CommanderSet.empty();
    final rows = await _db.cachedCardsByIds(cardIds);
    final byId = {for (final row in rows) row.id: _toCard(row)};

    var set = const CommanderSet.empty();
    // Rebuilt in the saved order, so the primary commander stays primary.
    for (final id in cardIds) {
      final card = byId[id];
      if (card != null) set = set.withCard(card);
    }
    return set;
  }

  Future<List<MagicCard>> _searchCache(
    String query, {
    bool legalOnly = false,
  }) async {
    final rows = await _db.searchCachedCards(query);
    // The offline path honours the same filter, or turning the setting on
    // would still surface silver-bordered cards the moment the network drops.
    return rows
        .where((row) => !legalOnly || row.commanderLegal)
        .map(_toCard)
        .toList();
  }

  /// Writes cards to the local cache. Failures are swallowed: a cache miss
  /// only costs a network round trip next time, and this runs unawaited.
  Future<void> _cache(List<MagicCard> cards) async {
    if (cards.isEmpty) return;
    final now = DateTime.now();
    try {
      await _db.cacheCards([
        for (final c in cards)
          CachedCardsCompanion.insert(
            id: c.id,
            name: c.name,
            searchName: c.name.toLowerCase(),
            typeLine: c.typeLine,
            cachedAt: now,
            colorIdentity: Value(
              c.colorIdentityString == 'C' ? '' : c.colorIdentityString,
            ),
            oracleText: Value(c.oracleText),
            manaCost: Value(c.manaCost),
            imageSmall: Value(c.imageSmall),
            imageNormal: Value(c.imageNormal),
            imageArtCrop: Value(c.imageArtCrop),
            scryfallUri: Value(c.scryfallUri),
            artist: Value(c.artist),
            commanderLegal: Value(c.commanderLegal),
          ),
      ]);
    } catch (_) {
      // Best effort only.
    }
  }

  MagicCard _toCard(CachedCardRow row) => MagicCard(
    id: row.id,
    name: row.name,
    typeLine: row.typeLine,
    colorIdentity: {
      for (final ch in row.colorIdentity.split('')) ?ManaColor.fromCode(ch),
    },
    oracleText: row.oracleText,
    manaCost: row.manaCost,
    imageSmall: row.imageSmall,
    imageNormal: row.imageNormal,
    imageArtCrop: row.imageArtCrop,
    scryfallUri: row.scryfallUri,
    artist: row.artist,
    commanderLegal: row.commanderLegal,
  );
}
