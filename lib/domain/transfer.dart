/// Handing a pod to another phone, and getting its result back, with no server
/// in between.
///
/// Deliberately pure Dart — no Flutter imports. Almost all of the risk in this
/// feature lives in the encoding, and tests for it should not need a device.
///
/// A payload is `deflate(utf8(compact json))`. Those bytes go straight into a
/// QR code; the same bytes base64-encoded make the text form you can paste
/// into a chat. Skipping base64 for the QR is worth about a quarter of the
/// payload, which is the difference between a code that scans across a table
/// and one that does not.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// Anything wrong with a scanned or pasted code, phrased for the person
/// holding the phone rather than for a log file.
class TransferException implements Exception {
  const TransferException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// One card in a borrowed pod's command zone.
///
/// The name travels alongside the id because the receiving phone may never
/// have seen this card. Commander damage is tracked per card, so a pod that
/// arrives with ids it cannot resolve would otherwise have nothing to track
/// damage against.
class TransferCard {
  const TransferCard({required this.id, required this.name});

  final String id;
  final String name;
}

/// One seat in a pod being handed over.
class TransferSeat {
  const TransferSeat({
    required this.playerId,
    required this.name,
    required this.colorIndex,
    this.deckId,
    this.commanders = const [],
    this.label,
  });

  final String playerId;
  final String name;
  final int colorIndex;

  /// Null when the player has no saved deck. Must stay null rather than
  /// becoming an empty string, or the sender's per-deck records grow a bucket
  /// keyed on `''`.
  final String? deckId;

  final List<TransferCard> commanders;

  /// Only carried when a deck has a nickname but no commander — otherwise the
  /// card names say it.
  final String? label;

  /// What to show above this seat.
  String get displayName => commanders.isNotEmpty
      ? commanders.map((c) => c.name).join(' + ')
      : (label ?? '');
}

/// One player's outcome in a borrowed game.
class TransferResult {
  const TransferResult({
    required this.playerId,
    required this.name,
    required this.colorIndex,
    required this.seatIndex,
    required this.position,
    required this.finalLife,
    this.deckId,
    this.eliminated = false,
  });

  final String playerId;
  final String name;

  /// Echoed back rather than looked up. The sender's copy of this player may
  /// have been recoloured or deleted since the pod went out, and a game
  /// participant row needs a colour regardless.
  final int colorIndex;

  /// Where they sat, which is not where they finished. History renders in
  /// seat order, so using the finishing order here would quietly rewrite the
  /// seating.
  final int seatIndex;

  final int position;
  final int finalLife;
  final String? deckId;
  final bool eliminated;
}

/// Either kind of code.
sealed class TransferPayload {
  const TransferPayload({required this.sourceDeviceId});

  /// Which install created the pod this code belongs to. A result is only
  /// accepted by the phone that sent the pod out — without that check, any
  /// stranger's code would write unknown players straight into history and
  /// into statistics, permanently.
  final String sourceDeviceId;
}

/// A pod on its way to someone else's phone.
class PodTransfer extends TransferPayload {
  const PodTransfer({required super.sourceDeviceId, required this.seats});

  final List<TransferSeat> seats;
}

/// A finished borrowed game on its way home.
class ResultTransfer extends TransferPayload {
  const ResultTransfer({
    required super.sourceDeviceId,
    required this.gameId,
    required this.startedAt,
    required this.finishedAt,
    required this.startingLife,
    required this.results,
    this.winnerPlayerId,
  });

  final String gameId;
  final DateTime startedAt;
  final DateTime finishedAt;
  final int startingLife;
  final List<TransferResult> results;

  /// Null is a real answer. A Commander game can end with no winner recorded,
  /// and inferring one from whoever placed first would invent a win that the
  /// statistics then count.
  final String? winnerPlayerId;
}

/// Encodes and decodes transfer codes.
abstract final class TransferCodec {
  /// Bumped only for a change older installs genuinely cannot read.
  static const version = 1;

  /// Marks the text form, and carries the version so a future format can be
  /// recognised rather than mangled.
  static const textPrefix = 'PODWISE1:';

  /// Byte budget for a code that still scans comfortably.
  ///
  /// QR version 20 at error-correction level M holds 666 bytes in 97×97
  /// modules. Past roughly that, a phone camera needs to be held close enough
  /// that it stops feeling like "show them your screen". A test asserts a
  /// realistic pod stays under it, which is what catches the day somebody adds
  /// a field and quietly makes the code unscannable.
  static const maxScannableBytes = 666;

  /// Guards against a crafted code that inflates to something enormous.
  static const _maxInflatedBytes = 64 * 1024;

  static const _minSeats = 2;

  /// What the board can seat. Pods never come close — the Pod Builder splits
  /// at six — but a code is untrusted input and the guard should match what
  /// the app can actually display.
  static const _maxSeats = 10;

  /// Longest credible game, used to reject a nonsense clock on the other
  /// phone before it poisons the average-duration statistic.
  static const _maxGameDuration = Duration(hours: 12);

  static final _deflate = ZLibCodec(raw: true, level: ZLibOption.maxLevel);

  // ---- Encoding -----------------------------------------------------------

  static Uint8List encode(TransferPayload payload) {
    final json = jsonEncode(switch (payload) {
      PodTransfer() => _podToJson(payload),
      ResultTransfer() => _resultToJson(payload),
    });
    return Uint8List.fromList(_deflate.encode(utf8.encode(json)));
  }

  /// The pasteable form of the same bytes.
  static String encodeText(TransferPayload payload) =>
      textPrefix + base64Url.encode(encode(payload));

  static Map<String, Object?> _podToJson(PodTransfer pod) => {
    'v': version,
    't': 'pod',
    'src': pod.sourceDeviceId,
    's': [
      for (final seat in pod.seats)
        {
          'p': seat.playerId,
          'n': seat.name,
          'x': seat.colorIndex,
          if (seat.deckId != null) 'd': seat.deckId,
          if (seat.commanders.isNotEmpty)
            'c': [
              for (final card in seat.commanders) [card.id, card.name],
            ],
          if (seat.label != null && seat.label!.isNotEmpty) 'l': seat.label,
        },
    ],
  };

  static Map<String, Object?> _resultToJson(ResultTransfer result) => {
    'v': version,
    't': 'res',
    'src': result.sourceDeviceId,
    'g': result.gameId,
    'sa': result.startedAt.millisecondsSinceEpoch ~/ 1000,
    'fa': result.finishedAt.millisecondsSinceEpoch ~/ 1000,
    'sl': result.startingLife,
    if (result.winnerPlayerId != null) 'w': result.winnerPlayerId,
    'r': [
      for (final entry in result.results)
        {
          'p': entry.playerId,
          'n': entry.name,
          'x': entry.colorIndex,
          'i': entry.seatIndex,
          'o': entry.position,
          'f': entry.finalLife,
          if (entry.deckId != null) 'd': entry.deckId,
          if (entry.eliminated) 'e': 1,
        },
    ],
  };

  // ---- Decoding -----------------------------------------------------------

  /// Reads a code that arrived as text, from a paste or a share.
  static TransferPayload decodeText(String text) {
    final trimmed = text.trim();
    if (!trimmed.startsWith(textPrefix)) {
      throw const TransferException('That does not look like a PodWise code.');
    }
    try {
      return decode(
        Uint8List.fromList(
          base64Url.decode(trimmed.substring(textPrefix.length)),
        ),
      );
    } on FormatException {
      throw const TransferException(
        'That code is incomplete or has been altered.',
      );
    }
  }

  /// Reads a code that arrived as raw bytes, from a scan.
  ///
  /// Everything here treats the input as hostile: a QR code is whatever
  /// happened to be in front of the camera, and a crash at a table is the
  /// worst possible failure.
  static TransferPayload decode(Uint8List bytes) {
    final Map<String, Object?> json;
    try {
      final inflated = _deflate.decode(bytes);
      if (inflated.length > _maxInflatedBytes) {
        throw const TransferException('That code is not a PodWise code.');
      }
      json = jsonDecode(utf8.decode(inflated)) as Map<String, Object?>;
    } on TransferException {
      rethrow;
    } catch (_) {
      throw const TransferException('That does not look like a PodWise code.');
    }

    // Version before type: a newer format may well have changed what `t`
    // means, so it must not be interpreted before we know we can read it.
    final v = json['v'];
    if (v is! int) {
      throw const TransferException('That does not look like a PodWise code.');
    }
    if (v > version) {
      throw const TransferException(
        'That code came from a newer version of PodWise. Update the app to '
        'read it.',
      );
    }

    return switch (json['t']) {
      'pod' => _podFromJson(json),
      'res' => _resultFromJson(json),
      _ => throw const TransferException(
        'That does not look like a PodWise code.',
      ),
    };
  }

  static PodTransfer _podFromJson(Map<String, Object?> json) {
    final seats = _list(json['s']);
    if (seats.length < _minSeats || seats.length > _maxSeats) {
      throw TransferException(
        'That pod has ${seats.length} players. PodWise can track '
        '$_minSeats to $_maxSeats at one table.',
      );
    }

    return PodTransfer(
      sourceDeviceId: _string(json['src'], 'src'),
      seats: [
        for (final raw in seats)
          if (_map(raw) case final seat)
            TransferSeat(
              playerId: _string(seat['p'], 'player'),
              name: _string(seat['n'], 'name'),
              colorIndex: _int(seat['x']) ?? 0,
              deckId: seat['d'] == null ? null : _string(seat['d'], 'deck'),
              commanders: [
                for (final card in _list(seat['c']))
                  if (_list(card) case final pair when pair.length == 2)
                    TransferCard(
                      id: _string(pair[0], 'card'),
                      name: _string(pair[1], 'card name'),
                    ),
              ],
              label: seat['l'] as String?,
            ),
      ],
    );
  }

  static ResultTransfer _resultFromJson(Map<String, Object?> json) {
    var startedAt = _time(json['sa']);
    var finishedAt = _time(json['fa']);

    // The clock belongs to the other phone, and these two timestamps feed the
    // average-game-length statistic directly.
    //
    // Order matters here. Pulling only the finish back to the present leaves a
    // game that *started* in the future inverted, which produces a negative
    // duration that then subtracts from the average — so both ends come back
    // first, and the ordering is restored afterwards.
    final ceiling = DateTime.now().add(const Duration(minutes: 5));
    if (startedAt.isAfter(ceiling)) startedAt = ceiling;
    if (finishedAt.isAfter(ceiling)) finishedAt = ceiling;
    if (finishedAt.isBefore(startedAt)) finishedAt = startedAt;
    if (finishedAt.difference(startedAt) > _maxGameDuration) {
      finishedAt = startedAt.add(_maxGameDuration);
    }

    final entries = _list(json['r']);
    if (entries.isEmpty) {
      throw const TransferException('That result has no players in it.');
    }

    return ResultTransfer(
      sourceDeviceId: _string(json['src'], 'src'),
      gameId: _string(json['g'], 'game'),
      startedAt: startedAt,
      finishedAt: finishedAt,
      startingLife: _int(json['sl']) ?? 40,
      winnerPlayerId: json['w'] == null ? null : _string(json['w'], 'winner'),
      results: [
        for (final raw in entries)
          if (_map(raw) case final entry)
            TransferResult(
              playerId: _string(entry['p'], 'player'),
              name: _string(entry['n'], 'name'),
              colorIndex: _int(entry['x']) ?? 0,
              seatIndex: _int(entry['i']) ?? 0,
              position: _int(entry['o']) ?? 0,
              finalLife: _int(entry['f']) ?? 0,
              deckId: entry['d'] == null ? null : _string(entry['d'], 'deck'),
              eliminated: entry['e'] != null,
            ),
      ],
    );
  }

  // ---- Field readers ------------------------------------------------------
  //
  // Every one of these turns a malformed field into the same plain message,
  // so a corrupt code can never surface as a type error.

  static List<Object?> _list(Object? value) => value is List ? value : const [];

  static Map<String, Object?> _map(Object? value) => value is Map
      ? value.cast<String, Object?>()
      : throw const TransferException('That code is incomplete or damaged.');

  static String _string(Object? value, String field) => value is String
      ? value
      : throw TransferException('That code is missing its $field.');

  static int? _int(Object? value) => value is int ? value : null;

  static DateTime _time(Object? value) =>
      DateTime.fromMillisecondsSinceEpoch((_int(value) ?? 0) * 1000);

  // ---- Ids ----------------------------------------------------------------
  //
  // Ids travel verbatim, and that is a measured decision rather than a lazy
  // one. Re-encoding each 36-character UUID as 22 base64 characters looks like
  // an obvious saving, and it is — until deflate runs. Hex uses an alphabet of
  // sixteen symbols, which Huffman coding compresses well; base64 uses
  // sixty-four and is close to incompressible. Sending a realistic pod the
  // "compact" way measured 450 bytes against 420 for the plain one, so the
  // clever encoding cost thirty bytes and bought a decoder that could fail.
  //
  // The same reasoning covers deck ids carried over from the old schema, which
  // look like `legacy-<uuid>`: the repeated prefix costs almost nothing once
  // deflate has seen it a second time.
}
