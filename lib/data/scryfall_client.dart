import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../domain/commander.dart';

/// Raised when Scryfall is reachable but unhappy. Callers are expected to fall
/// back to the local cache rather than surface this to the table.
class ScryfallException implements Exception {
  const ScryfallException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;

  @override
  String toString() => 'ScryfallException($statusCode): $message';
}

/// Talks to the Scryfall API.
///
/// Scryfall asks API consumers for two things, both honoured here: a real
/// User-Agent identifying the client, and no more than ~10 requests a second.
/// Ignoring either is how applications get blocked.
class ScryfallClient {
  ScryfallClient({http.Client? httpClient})
    : _http = httpClient ?? http.Client();

  final http.Client _http;

  static const _base = 'https://api.scryfall.com';

  /// Scryfall asks for 50–100ms between requests. 110ms keeps us comfortably
  /// inside that even when the clock is imprecise.
  static const _minRequestGap = Duration(milliseconds: 110);

  static const _headers = {
    'User-Agent': 'PodWise/1.0 (Android; Commander companion app)',
    'Accept': 'application/json',
  };

  DateTime _lastRequest = DateTime.fromMillisecondsSinceEpoch(0);
  Future<void> _rateLimitGate = Future.value();

  /// Serialises requests and spaces them out, so concurrent callers (a fast
  /// typist triggering several searches) cannot burst past the rate limit.
  Future<T> _throttled<T>(Future<T> Function() request) {
    final completer = Completer<T>();
    _rateLimitGate = _rateLimitGate.then((_) async {
      final since = DateTime.now().difference(_lastRequest);
      if (since < _minRequestGap) {
        await Future<void>.delayed(_minRequestGap - since);
      }
      _lastRequest = DateTime.now();
      try {
        completer.complete(await request());
      } catch (e, st) {
        completer.completeError(e, st);
      }
    });
    return completer.future;
  }

  Future<Map<String, dynamic>> _getJson(Uri uri) async {
    // Logged so a surprising result set can be traced back to the exact query
    // that produced it, rather than guessed at.
    debugPrint('PodWise: GET $uri');
    late final http.Response response;
    try {
      response = await _http
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 10));
    } on TimeoutException {
      throw const ScryfallException('Scryfall took too long to respond');
    } catch (e) {
      throw ScryfallException('Could not reach Scryfall: $e');
    }

    // A search with no matches is a normal outcome, not an error.
    if (response.statusCode == 404) return const {'data': <dynamic>[]};

    if (response.statusCode != 200) {
      // Include the body: Scryfall explains *why* a query was rejected, and
      // without it a 400 is impossible to diagnose from a log line.
      throw ScryfallException(
        'Scryfall returned ${response.statusCode} — '
        '${utf8.decode(response.bodyBytes)}',
        statusCode: response.statusCode,
      );
    }

    // Decode the raw bytes as UTF-8 rather than trusting `response.body`,
    // which falls back to latin1 when the server omits a charset. Card names
    // are full of non-ASCII — Jötun Grunt, Lim-Dûl, Márton Stromgald — and
    // latin1 would mangle every one of them.
    return jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
  }

  /// Searches for cards that can legally be commanders.
  ///
  /// The query restricts to the commander format and to cards that may be a
  /// commander, so a search for "atra" returns Atraxa rather than every card
  /// with those letters in its text.
  Future<List<MagicCard>> searchCommanders(
    String query, {
    bool legalOnly = false,
  }) async {
    final trimmed = query.trim();
    if (trimmed.length < 2) return const [];

    final search = Uri.parse('$_base/cards/search').replace(
      queryParameters: {
        // `name:` restricts to the card name. A bare term also matches oracle
        // text, so "atra" would return popular commanders with no "atra" in
        // their name at all — and edhrec ordering then ranks them above
        // Atraxa, which is the opposite of what someone typing "atra" wants.
        // `type:background`, not `is:background` — Scryfall has no `is:`
        // predicate for Backgrounds and silently *ignores* the expression,
        // which quietly made every Background unfindable.
        //
        // Legality is only filtered when the user asks for it. Commander is a
        // Rule 0 format and playgroups routinely run silver-bordered Secret
        // Lairs — Pinkie Pie is a Legendary Creature that Scryfall marks
        // `commander: not_legal`, and excluding it by default made the app
        // disagree with how people actually play. Unfiltered results carry a
        // badge instead. `game:paper` keeps Arena-only digital cards out.
        'q':
            'name:$trimmed (is:commander or type:background) game:paper'
            '${legalOnly ? ' legal:commander' : ''}',
        'unique': 'cards',
        // Most-played first among genuine name matches.
        'order': 'edhrec',
      },
    );

    final json = await _throttled(() => _getJson(search));
    final data = json['data'] as List<dynamic>? ?? const [];
    final cards = [
      for (final card in data)
        MagicCard.fromScryfall(card as Map<String, dynamic>),
    ];

    return rankByNameRelevance(cards, trimmed);
  }

  /// Re-ranks results so the name the user actually sees drives the order.
  ///
  /// Scryfall's `name:` also matches *flavour* names — searching "atra" returns
  /// Kutzil, Malamet Exemplar because one Secret Lair printing is called
  /// "Catra, Force Captain". That is a legitimate match but a baffling first
  /// result, so cards whose displayed name matches are promoted above it.
  ///
  /// Within each tier the API's own popularity order is preserved.
  static List<MagicCard> rankByNameRelevance(
    List<MagicCard> cards,
    String query,
  ) {
    final needle = query.toLowerCase();

    int tier(MagicCard card) {
      final name = card.name.toLowerCase();
      if (name.startsWith(needle)) return 0;
      // Matches the start of any word, so "grand" finds "Atraxa, Grand
      // Unifier" ahead of a card with "grand" buried mid-word.
      if (name.split(RegExp(r'[\s,]+')).any((w) => w.startsWith(needle))) {
        return 1;
      }
      if (name.contains(needle)) return 2;
      // Matched only through a flavour name or similar.
      return 3;
    }

    final indexed =
        [for (var i = 0; i < cards.length; i++) (card: cards[i], order: i)]
          ..sort((a, b) {
            final byTier = tier(a.card).compareTo(tier(b.card));
            return byTier != 0 ? byTier : a.order.compareTo(b.order);
          });

    return [for (final entry in indexed) entry.card];
  }

  /// Fetches one card by its Scryfall id, for refreshing a cached entry.
  Future<MagicCard> cardById(String id) async {
    final json = await _throttled(
      () => _getJson(Uri.parse('$_base/cards/$id')),
    );
    return MagicCard.fromScryfall(json);
  }

  void dispose() => _http.close();
}
