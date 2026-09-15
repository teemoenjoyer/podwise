import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:podwise/data/scryfall_client.dart';
import 'package:podwise/domain/commander.dart';

/// A trimmed Scryfall response, shaped exactly like the real one.
Map<String, dynamic> _atraxaPayload() => {
  'object': 'list',
  'data': [
    {
      'id': 'd0d33d52-3d28-4635-b985-51e126289259',
      'name': 'Atraxa, Praetors\' Voice',
      'type_line': 'Legendary Creature — Phyrexian Angel Horror',
      'color_identity': ['W', 'U', 'B', 'G'],
      'oracle_text': 'Flying, vigilance, deathtouch, lifelink',
      'mana_cost': '{G}{W}{U}{B}',
      'image_uris': {
        'small': 'https://example.test/small.jpg',
        'normal': 'https://example.test/normal.jpg',
        'art_crop': 'https://example.test/art.jpg',
      },
      'scryfall_uri': 'https://scryfall.com/card/atraxa',
    },
  ],
};

void main() {
  group('MagicCard.fromScryfall', () {
    test('parses a normal card', () {
      final card = MagicCard.fromScryfall(
        _atraxaPayload()['data']![0] as Map<String, dynamic>,
      );

      expect(card.name, "Atraxa, Praetors' Voice");
      expect(card.colorIdentity, {
        ManaColor.white,
        ManaColor.blue,
        ManaColor.black,
        ManaColor.green,
      });
      // WUBRG order, not the order Scryfall happened to send.
      expect(card.colorIdentityString, 'WUBG');
      expect(card.canBeCommander, isTrue);
      expect(card.imageNormal, 'https://example.test/normal.jpg');
    });

    test('reads images and text from the front face of a two-faced card', () {
      final card = MagicCard.fromScryfall({
        'id': 'x',
        'name': 'Front // Back',
        'type_line': 'Legendary Creature — Human',
        'color_identity': ['R'],
        'card_faces': [
          {
            'oracle_text': 'Front face text',
            'image_uris': {'normal': 'https://example.test/front.jpg'},
          },
          {'oracle_text': 'Back face text'},
        ],
      });

      expect(card.imageNormal, 'https://example.test/front.jpg');
      expect(card.oracleText, 'Front face text');
    });

    test('treats a colourless commander as C, not empty', () {
      final card = MagicCard.fromScryfall({
        'id': 'k',
        'name': 'Kozilek',
        'type_line': 'Legendary Creature — Eldrazi',
        'color_identity': <String>[],
      });

      expect(card.isColorless, isTrue);
      expect(card.colorIdentityString, 'C');
    });

    test('survives a card with fields missing', () {
      final card = MagicCard.fromScryfall({'id': 'z', 'name': 'Mystery'});
      expect(card.typeLine, '');
      expect(card.colorIdentity, isEmpty);
      expect(card.canBeCommander, isFalse);
    });
  });

  group('ScryfallClient', () {
    test('sends a User-Agent, as Scryfall requires', () async {
      String? sentAgent;
      final client = ScryfallClient(
        httpClient: MockClient((req) async {
          sentAgent = req.headers['User-Agent'];
          return http.Response.bytes(
            utf8.encode(jsonEncode(_atraxaPayload())),
            200,
          );
        }),
      );

      await client.searchCommanders('atra');
      expect(sentAgent, isNotNull);
      expect(sentAgent, contains('PodWise'));
    });

    test('scopes the query to paper commanders and backgrounds', () async {
      Uri? sentUri;
      final client = ScryfallClient(
        httpClient: MockClient((req) async {
          sentUri = req.url;
          return http.Response.bytes(
            utf8.encode(jsonEncode(_atraxaPayload())),
            200,
          );
        }),
      );

      await client.searchCommanders('atra');
      final q = sentUri!.queryParameters['q']!;
      // Name-scoped: a bare term also matches oracle text, which buries the
      // card the user is actually typing the name of.
      expect(q, contains('name:atra'));
      expect(q, contains('is:commander'));
      // Backgrounds are found by type. Scryfall has no `is:background` and
      // silently ignores it, which made every Background unfindable.
      expect(q, contains('type:background'));
      expect(
        q,
        isNot(contains('is:background')),
        reason: 'is:background is not a valid Scryfall expression',
      );
      // Silver-bordered Secret Lairs like Pinkie Pie are marked
      // `commander: not_legal` but are played under Rule 0 all the time.
      expect(
        q,
        isNot(contains('legal:commander')),
        reason: 'legality must not hide cards a playgroup chooses to allow',
      );
      // Arena-only cards have no physical printing, so they stay out.
      expect(q, contains('game:paper'));
    });

    test('records whether a card is commander legal', () {
      final legal = MagicCard.fromScryfall({
        'id': 'a',
        'name': 'Atraxa',
        'type_line': 'Legendary Creature',
        'legalities': {'commander': 'legal'},
      });
      // Pinkie Pie's actual legality block.
      final silverBordered = MagicCard.fromScryfall({
        'id': 'p',
        'name': 'Pinkie Pie',
        'type_line': 'Legendary Creature — Pony',
        'legalities': {'commander': 'not_legal'},
      });

      expect(legal.commanderLegal, isTrue);
      expect(silverBordered.commanderLegal, isFalse);
    });

    test('assumes legal when the API omits legalities', () {
      // Better to under-warn than to badge every cached card as suspect.
      final card = MagicCard.fromScryfall({'id': 'x', 'name': 'Mystery'});
      expect(card.commanderLegal, isTrue);
    });

    test('decodes accented card names as UTF-8', () async {
      // Scryfall is full of these — Jötun Grunt, Lim-Dûl, Márton Stromgald,
      // Æther Vial. Falling back to latin1 corrupts every one.
      final payload = {
        'data': [
          {
            'id': 'j',
            'name': 'Jötun Grunt',
            'type_line': 'Legendary Creature — Giant Soldier',
            'color_identity': ['W'],
          },
        ],
      };
      final client = ScryfallClient(
        httpClient: MockClient(
          (_) async => http.Response.bytes(
            utf8.encode(jsonEncode(payload)),
            200,
            // Deliberately no charset, which is what triggers the latin1
            // fallback in http's `response.body`.
            headers: {'content-type': 'application/json'},
          ),
        ),
      );

      final results = await client.searchCommanders('jotun');
      expect(results.single.name, 'Jötun Grunt');
      expect(results.single.typeLine, contains('—'));
    });

    test('ignores queries shorter than two characters', () async {
      var called = false;
      final client = ScryfallClient(
        httpClient: MockClient((_) async {
          called = true;
          return http.Response('{}', 200);
        }),
      );

      expect(await client.searchCommanders('a'), isEmpty);
      expect(await client.searchCommanders(' '), isEmpty);
      expect(called, isFalse, reason: 'should not hit the network');
    });

    test('treats a 404 as no results rather than an error', () async {
      final client = ScryfallClient(
        httpClient: MockClient((_) async => http.Response('not found', 404)),
      );

      expect(await client.searchCommanders('zzzznotacard'), isEmpty);
    });

    test('throws ScryfallException on a server error', () async {
      final client = ScryfallClient(
        httpClient: MockClient((_) async => http.Response('boom', 500)),
      );

      expect(
        () => client.searchCommanders('atra'),
        throwsA(isA<ScryfallException>()),
      );
    });

    test('spaces consecutive requests to respect the rate limit', () async {
      final timestamps = <DateTime>[];
      final client = ScryfallClient(
        httpClient: MockClient((_) async {
          timestamps.add(DateTime.now());
          return http.Response.bytes(
            utf8.encode(jsonEncode(_atraxaPayload())),
            200,
          );
        }),
      );

      await Future.wait([
        client.searchCommanders('one'),
        client.searchCommanders('two'),
        client.searchCommanders('three'),
      ]);

      expect(timestamps, hasLength(3));
      for (var i = 1; i < timestamps.length; i++) {
        final gap = timestamps[i].difference(timestamps[i - 1]);
        expect(
          gap.inMilliseconds,
          // The client paces at 110ms. The tolerance is for the clock, not
          // the client: Windows' timer granularity is around 15ms, so both
          // endpoints quantise and a genuine 110ms gap can measure as ~95.
          // A client that was not pacing at all would show gaps near zero,
          // which this still catches.
          greaterThanOrEqualTo(90),
          reason: 'Scryfall asks for ~10 requests per second at most',
        );
      }
    });
  });

  group('name relevance ranking', () {
    MagicCard named(String name) =>
        MagicCard(id: name, name: name, typeLine: '', colorIdentity: const {});

    test('promotes real name matches above flavour-name matches', () {
      // Scryfall returns Kutzil first for "atra" because one of its printings
      // is flavour-named "Catra, Force Captain". The user never sees that
      // name, so it must not outrank Atraxa.
      final ranked = ScryfallClient.rankByNameRelevance([
        named('Kutzil, Malamet Exemplar'),
        named("Atraxa, Praetors' Voice"),
        named('Atraxa, Grand Unifier'),
      ], 'atra');

      expect(ranked.first.name, startsWith('Atraxa'));
      expect(ranked.last.name, 'Kutzil, Malamet Exemplar');
    });

    test('a name starting with the query wins outright', () {
      final ranked = ScryfallClient.rankByNameRelevance([
        named('Ixhel, Scion of Atraxa'),
        named('Atraxa, Grand Unifier'),
      ], 'atra');

      expect(ranked.first.name, 'Atraxa, Grand Unifier');
    });

    test('matches at the start of any word beat mid-word matches', () {
      final ranked = ScryfallClient.rankByNameRelevance([
        named('Hapatra, Vizier of Poisons'),
        named('Ixhel, Scion of Atraxa'),
      ], 'atra');

      // "Atraxa" starts a word; "Hapatra" only contains the letters.
      expect(ranked.first.name, 'Ixhel, Scion of Atraxa');
    });

    test("preserves Scryfall's popularity order within a tier", () {
      final ranked = ScryfallClient.rankByNameRelevance([
        named('Atraxa, Grand Unifier'),
        named("Atraxa, Praetors' Voice"),
      ], 'atra');

      // Both start with the query, so the API's own ordering stands.
      expect(ranked.map((c) => c.name), [
        'Atraxa, Grand Unifier',
        "Atraxa, Praetors' Voice",
      ]);
    });

    test('is case insensitive', () {
      final ranked = ScryfallClient.rankByNameRelevance([
        named('Kutzil, Malamet Exemplar'),
        named('Atraxa, Grand Unifier'),
      ], 'ATRA');

      expect(ranked.first.name, 'Atraxa, Grand Unifier');
    });

    test('leaves an empty result set alone', () {
      expect(ScryfallClient.rankByNameRelevance(const [], 'atra'), isEmpty);
    });
  });

  group('CommanderSet', () {
    MagicCard card(
      String id,
      String name, {
      Set<ManaColor> colors = const {},
      String type = 'Legendary Creature',
      String? text,
    }) => MagicCard(
      id: id,
      name: name,
      typeLine: type,
      colorIdentity: colors,
      oracleText: text,
    );

    test('combines colour identity across a partner pair', () {
      final set = const CommanderSet.empty()
          .withCard(
            card(
              '1',
              'Tymna the Weaver',
              colors: {ManaColor.white, ManaColor.black},
              text: 'Partner',
            ),
          )
          .withCard(
            card(
              '2',
              'Thrasios, Triton Hero',
              colors: {ManaColor.blue, ManaColor.green},
              text: 'Partner',
            ),
          );

      expect(set.colorIdentityString, 'WUBG');
      expect(set.pairing, CommanderPairing.partner);
      expect(set.displayName, 'Tymna the Weaver + Thrasios, Triton Hero');
      // Each commander deals its own damage, so both are tracked separately.
      expect(set.damageSources, hasLength(2));
    });

    test('detects a background pairing', () {
      final set = const CommanderSet.empty()
          .withCard(
            card(
              '1',
              'Wilson',
              colors: {ManaColor.green},
              text: 'Choose a Background',
            ),
          )
          .withCard(
            card(
              '2',
              'Raised by Giants',
              type: 'Legendary Enchantment — Background',
            ),
          );

      expect(set.pairing, CommanderPairing.background);
    });

    test('refuses to add the same card twice', () {
      final one = const CommanderSet.empty().withCard(card('1', 'Atraxa'));
      expect(one.withCard(card('1', 'Atraxa')).cards, hasLength(1));
    });

    test('removing a card downgrades the pairing back to single', () {
      final set = const CommanderSet.empty()
          .withCard(card('1', 'A', text: 'Partner'))
          .withCard(card('2', 'B', text: 'Partner'));

      expect(set.pairing, CommanderPairing.partner);
      expect(set.withoutCard('2').pairing, CommanderPairing.single);
    });

    test('an empty set reports no commander', () {
      expect(const CommanderSet.empty().displayName, 'No commander');
      expect(const CommanderSet.empty().colorIdentityString, 'C');
    });
  });
}
