import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:podwise/domain/transfer.dart';

/// A pod code is scanned off a phone screen by a camera, so two things matter
/// beyond "does it round-trip": it must stay small enough to actually scan,
/// and it must never crash on whatever else happened to be in front of the
/// lens.
void main() {
  group('pod round trip', () {
    test('a pod survives the journey intact', () {
      final decoded = _roundTrip(_pod()) as PodTransfer;

      expect(decoded.sourceDeviceId, _device);
      expect(decoded.seats, hasLength(5));

      final first = decoded.seats.first;
      expect(first.playerId, '69587ff4-a8d1-4176-b652-719f336c6304');
      expect(first.name, 'Dave');
      expect(first.colorIndex, 0);
      expect(first.commanders.single.name, 'Atraxa, Praetors\' Voice');
      expect(
        first.commanders.single.id,
        '11111111-2222-3333-4444-555555555555',
      );
    });

    test('a partner pair keeps both cards, in order', () {
      final decoded = _roundTrip(_pod()) as PodTransfer;
      final partners = decoded.seats[3];

      expect(partners.commanders.map((c) => c.name), [
        'Tymna the Weaver',
        'Thrasios, Triton Hero',
      ]);
      // Commander damage is tracked per card, so both ids have to arrive.
      expect(partners.commanders.map((c) => c.id).toSet(), hasLength(2));
      expect(partners.displayName, 'Tymna the Weaver + Thrasios, Triton Hero');
    });

    test('a player with no saved deck keeps a null deck id', () {
      final decoded = _roundTrip(_pod()) as PodTransfer;
      // Never the empty string: the sender keys per-deck records on this, and
      // '' would quietly become a deck that everybody shares.
      expect(decoded.seats[4].deckId, isNull);
    });

    test('a deck carried over from the old schema survives', () {
      // These ids look like `legacy-<uuid>` rather than a bare UUID, which is
      // the shape most likely to trip up an id encoding.
      final decoded = _roundTrip(_pod()) as PodTransfer;
      expect(decoded.seats[2].deckId, 'legacy-$_uuidC');
    });

    test('a nicknamed deck with no commander still has something to show', () {
      final decoded = _roundTrip(_pod()) as PodTransfer;
      expect(decoded.seats[4].commanders, isEmpty);
      expect(decoded.seats[4].displayName, 'The pile');
    });
  });

  group('result round trip', () {
    test('a result survives the journey intact', () {
      final decoded = _roundTrip(_result()) as ResultTransfer;

      expect(decoded.gameId, _uuidG);
      expect(decoded.startingLife, 40);
      expect(decoded.winnerPlayerId, _uuidA);
      expect(decoded.results, hasLength(3));

      final winner = decoded.results.first;
      expect(winner.name, 'Dave');
      expect(winner.position, 1);
      expect(winner.finalLife, 22);
      expect(winner.colorIndex, 3);
      expect(winner.eliminated, isFalse);
    });

    test('seating order is preserved independently of finishing order', () {
      final decoded = _roundTrip(_result()) as ResultTransfer;
      // Dave finished first from seat 2; Ben finished last from seat 0.
      // History renders by seat, so confusing the two would reseat the table.
      expect(decoded.results[0].position, 1);
      expect(decoded.results[0].seatIndex, 2);
      expect(decoded.results[2].position, 3);
      expect(decoded.results[2].seatIndex, 0);
    });

    test('a game with no winner round-trips as having no winner', () {
      final decoded = _roundTrip(_result(winner: null)) as ResultTransfer;
      // Inferring the winner from whoever placed first would fabricate a win
      // that the statistics then count for ever.
      expect(decoded.winnerPlayerId, isNull);
    });

    test('elimination flags survive', () {
      final decoded = _roundTrip(_result()) as ResultTransfer;
      expect(decoded.results[0].eliminated, isFalse);
      expect(decoded.results[2].eliminated, isTrue);
    });
  });

  group('the other phone had a bad clock', () {
    test('a finish before the start is pulled back to the start', () {
      final decoded = _roundTrip(
        _result(
          startedAt: DateTime(2026, 9, 13, 20),
          finishedAt: DateTime(2026, 9, 13, 18),
        ),
      ) as ResultTransfer;

      // A negative duration would subtract from the average game length.
      expect(decoded.finishedAt, DateTime(2026, 9, 13, 20));
      expect(decoded.finishedAt.difference(decoded.startedAt), Duration.zero);
    });

    test('an absurdly long game is clamped', () {
      final decoded = _roundTrip(
        _result(
          startedAt: DateTime(2026, 9, 13, 20),
          finishedAt: DateTime(2026, 9, 13, 20).add(const Duration(days: 30)),
        ),
      ) as ResultTransfer;

      expect(
        decoded.finishedAt.difference(decoded.startedAt),
        const Duration(hours: 12),
      );
    });

    test('a game finishing in the future is pulled back to now', () {
      final start = DateTime.now().subtract(const Duration(hours: 1));
      final decoded = _roundTrip(
        _result(
          startedAt: start,
          finishedAt: start.add(const Duration(hours: 6)),
        ),
      ) as ResultTransfer;

      // Otherwise it pins itself to the top of history permanently.
      expect(
        decoded.finishedAt.isAfter(
          DateTime.now().add(const Duration(minutes: 6)),
        ),
        isFalse,
      );
    });
  });

  group('hostile input', () {
    test('random bytes are refused, not thrown at the user', () {
      expect(
        () => TransferCodec.decode(Uint8List.fromList([1, 2, 3, 4, 5])),
        throwsA(isA<TransferException>()),
      );
    });

    test('a truncated code is refused', () {
      final full = TransferCodec.encode(_pod());
      expect(
        () => TransferCodec.decode(full.sublist(0, full.length ~/ 2)),
        throwsA(isA<TransferException>()),
      );
    });

    test('text without the prefix is refused', () {
      expect(
        () => TransferCodec.decodeText('https://example.com'),
        throwsA(isA<TransferException>()),
      );
    });

    test('a code from a newer version says so, rather than misreading it', () {
      final future = _encodeJson({'v': 99, 't': 'pod', 'src': '~d', 's': []});

      expect(
        () => TransferCodec.decode(future),
        throwsA(
          isA<TransferException>().having(
            (e) => e.message,
            'message',
            contains('newer version'),
          ),
        ),
      );
    });

    test('an unknown payload type is refused', () {
      expect(
        () => TransferCodec.decode(_encodeJson({'v': 1, 't': 'wat'})),
        throwsA(isA<TransferException>()),
      );
    });

    test('a decompression bomb is refused before it is parsed', () {
      final bomb = _encodeJson({
        'v': 1,
        't': 'pod',
        'src': '~d',
        'padding': 'A' * 200000,
        's': <Object?>[],
      });
      // Highly compressible, so the code itself is small — the guard has to
      // be on the inflated size, not the scanned size.
      expect(bomb.length, lessThan(2000));
      expect(
        () => TransferCodec.decode(bomb),
        throwsA(isA<TransferException>()),
      );
    });

    test('a pod that would not fit on the board is refused', () {
      final tooMany = _encodeJson({
        'v': 1,
        't': 'pod',
        'src': '~d',
        's': [
          for (var i = 0; i < 12; i++) {'p': '~p$i', 'n': 'P$i', 'x': i},
        ],
      });

      expect(
        () => TransferCodec.decode(tooMany),
        throwsA(
          isA<TransferException>().having(
            (e) => e.message,
            'message',
            contains('12 players'),
          ),
        ),
      );
    });

    test('a result with no players is refused', () {
      expect(
        () => TransferCodec.decode(
          _encodeJson({
            'v': 1,
            't': 'res',
            'src': '~d',
            'g': '~g',
            'sa': 1,
            'fa': 2,
            'sl': 40,
            'r': <Object?>[],
          }),
        ),
        throwsA(isA<TransferException>()),
      );
    });

    test('a missing required field is refused rather than crashing', () {
      expect(
        () => TransferCodec.decode(
          _encodeJson({
            'v': 1,
            't': 'pod',
            'src': '~d',
            's': [
              {'n': 'Dave', 'x': 0},
              {'n': 'Ben', 'x': 1},
            ],
          }),
        ),
        throwsA(isA<TransferException>()),
      );
    });
  });

  group('size budget', () {
    test('a realistic five-player pod stays comfortably scannable', () {
      final encoded = TransferCodec.encode(_pod());

      // This is the test that matters most. Past the budget the QR needs more
      // modules than a phone camera can resolve at conversational distance,
      // and the failure is a vague "it won't scan" rather than an error.
      expect(
        encoded.length,
        lessThan(TransferCodec.maxScannableBytes),
        reason:
            'A pod code of ${encoded.length} bytes needs a denser QR than '
            'will reliably scan. Shrink the payload rather than raising this.',
      );
    });

    test('a five-player result stays comfortably scannable', () {
      expect(
        TransferCodec.encode(_result()).length,
        lessThan(TransferCodec.maxScannableBytes),
      );
    });

    test('shortening ids would make the code bigger, not smaller', () {
      // Records a measurement that contradicts the obvious intuition, so that
      // nobody "optimises" it back. Re-encoding each 36-character UUID as 22
      // base64 characters shrinks the JSON, but deflate more than gives it
      // back: hex has a sixteen-symbol alphabet that Huffman coding eats,
      // while base64's sixty-four symbols are close to incompressible.
      final asSent = TransferCodec.encode(_pod());
      final shortened = _deflated(_shortenedIdJson());

      expect(shortened.length, greaterThan(asSent.length));
    });

    test('the text form is pasteable and prefixed', () {
      final text = TransferCodec.encodeText(_pod());

      expect(text, startsWith(TransferCodec.textPrefix));
      // No characters that a chat app will mangle or line-wrap oddly.
      expect(RegExp(r'^PODWISE1:[A-Za-z0-9_\-=]+$').hasMatch(text), isTrue);
      expect(
        (TransferCodec.decodeText(text) as PodTransfer).seats,
        hasLength(5),
      );
    });
  });
}

// ---- Fixtures -------------------------------------------------------------

const _device = 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee';
const _uuidA = '69587ff4-a8d1-4176-b652-719f336c6304';
const _uuidB = 'd9897c33-44e9-4cb2-b46e-24b5f5fbbc29';
const _uuidC = '204cfd36-6844-4c94-9628-5ec690420831';
const _uuidD = '29357043-2baf-4ce8-9163-9699d90f1e29';
const _uuidE = '2cd5be80-59b1-46fb-b573-729243dc79e4';
const _uuidG = '52586a15-489a-4411-a716-d7c30c276566';

TransferPayload _roundTrip(TransferPayload payload) =>
    TransferCodec.decode(TransferCodec.encode(payload));

Uint8List _encodeJson(Map<String, Object?> json) => _deflated(json);

Uint8List _deflated(Map<String, Object?> json) => Uint8List.fromList(
  ZLibCodec(raw: true, level: 9).encode(utf8.encode(jsonEncode(json))),
);

/// A pod shaped like one this app actually produces: five seats, a partner
/// pair, a deck carried over from the old schema, and somebody who has not
/// saved a deck at all.
PodTransfer _pod() => PodTransfer(
  sourceDeviceId: _device,
  seats: [
    TransferSeat(
      playerId: _uuidA,
      name: 'Dave',
      colorIndex: 0,
      deckId: _uuidB,
      commanders: const [
        TransferCard(
          id: '11111111-2222-3333-4444-555555555555',
          name: 'Atraxa, Praetors\' Voice',
        ),
      ],
    ),
    TransferSeat(
      playerId: _uuidB,
      name: 'Ben',
      colorIndex: 1,
      deckId: _uuidC,
      commanders: const [
        TransferCard(
          id: '22222222-3333-4444-5555-666666666666',
          name: 'Krenko, Mob Boss',
        ),
      ],
    ),
    TransferSeat(
      playerId: _uuidC,
      name: 'Jordan',
      colorIndex: 2,
      deckId: 'legacy-$_uuidC',
      commanders: const [
        TransferCard(
          id: '33333333-4444-5555-6666-777777777777',
          name: 'Shao Jun',
        ),
      ],
    ),
    TransferSeat(
      playerId: _uuidD,
      name: 'Taylor Smith',
      colorIndex: 3,
      deckId: _uuidE,
      commanders: const [
        TransferCard(
          id: '44444444-5555-6666-7777-888888888888',
          name: 'Tymna the Weaver',
        ),
        TransferCard(
          id: '55555555-6666-7777-8888-999999999999',
          name: 'Thrasios, Triton Hero',
        ),
      ],
    ),
    const TransferSeat(
      playerId: _uuidE,
      name: 'Morgan Bailey',
      colorIndex: 4,
      label: 'The pile',
    ),
  ],
);

ResultTransfer _result({
  String? winner = _uuidA,
  DateTime? startedAt,
  DateTime? finishedAt,
}) => ResultTransfer(
  sourceDeviceId: _device,
  gameId: _uuidG,
  startedAt: startedAt ?? DateTime(2026, 9, 13, 19),
  finishedAt: finishedAt ?? DateTime(2026, 9, 13, 20, 10),
  startingLife: 40,
  winnerPlayerId: winner,
  results: const [
    TransferResult(
      playerId: _uuidA,
      name: 'Dave',
      colorIndex: 3,
      seatIndex: 2,
      position: 1,
      finalLife: 22,
      deckId: _uuidB,
    ),
    TransferResult(
      playerId: _uuidB,
      name: 'Ben',
      colorIndex: 1,
      seatIndex: 1,
      position: 2,
      finalLife: 0,
      deckId: _uuidC,
      eliminated: true,
    ),
    TransferResult(
      playerId: _uuidC,
      name: 'Jordan',
      colorIndex: 0,
      seatIndex: 0,
      position: 3,
      finalLife: -4,
      eliminated: true,
    ),
  ],
);

/// The same pod with UUIDs re-encoded as 22 base64 characters, for the
/// measurement that shows this is a false economy.
Map<String, Object?> _shortenedIdJson() {
  String short(String id) {
    final hex = id.replaceAll('-', '');
    if (hex.length != 32) return id;
    return base64Url
        .encode([
          for (var i = 0; i < 16; i++)
            int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16),
        ])
        .substring(0, 22);
  }

  return {
    'v': 1,
    't': 'pod',
    'src': short(_device),
    's': [
      for (final seat in _pod().seats)
        {
          'p': short(seat.playerId),
          'n': seat.name,
          'x': seat.colorIndex,
          if (seat.deckId != null) 'd': short(seat.deckId!),
          if (seat.commanders.isNotEmpty)
            'c': [
              for (final card in seat.commanders) [short(card.id), card.name],
            ],
          if (seat.label != null) 'l': seat.label,
        },
    ],
  };
}
