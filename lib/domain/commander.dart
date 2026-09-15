import 'package:flutter/foundation.dart';

/// Magic's five colours. Kept as a plain enum rather than strings so colour
/// identity can be compared and, in Phase 4, scored for pod diversity.
enum ManaColor {
  white('W'),
  blue('U'),
  black('B'),
  red('R'),
  green('G');

  const ManaColor(this.code);
  final String code;

  static ManaColor? fromCode(String code) {
    for (final c in ManaColor.values) {
      if (c.code == code.toUpperCase()) return c;
    }
    return null;
  }
}

/// How a commander slot is filled.
///
/// Commander is not "one legendary creature" — partners, backgrounds and
/// Doctor/companion pairings all put two cards in the command zone, and the
/// brief is explicit that the app must not assume otherwise.
enum CommanderPairing {
  /// A single commander, the common case.
  single,

  /// Two commanders that both say "Partner".
  partner,

  /// A specific named pairing, e.g. "Partner with Kydele".
  partnerWith,

  /// A creature that can "choose a Background", plus its Background.
  background,

  /// Anything else valid that doesn't fit the above.
  other,
}

/// A Magic card as PodWise needs it — a deliberately small subset of what
/// Scryfall returns, so cached rows stay compact and stable across API changes.
@immutable
class MagicCard {
  const MagicCard({
    required this.id,
    required this.name,
    required this.typeLine,
    required this.colorIdentity,
    this.oracleText,
    this.manaCost,
    this.imageSmall,
    this.imageNormal,
    this.imageArtCrop,
    this.scryfallUri,
    this.artist,
    this.commanderLegal = true,
  });

  final String id;
  final String name;
  final String typeLine;

  /// Colour identity, not casting cost — this is what governs deck legality
  /// and what pod diversity scoring will use.
  final Set<ManaColor> colorIdentity;

  final String? oracleText;
  final String? manaCost;
  final String? imageSmall;
  final String? imageNormal;
  final String? imageArtCrop;
  final String? scryfallUri;

  /// Who painted it. Shown wherever the art is, because Scryfall's
  /// guidelines ask for the artist to be credited and the illustration is
  /// somebody's work, not decoration the app made.
  final String? artist;

  /// Whether this card is legal as a commander in sanctioned play.
  ///
  /// False for silver-bordered Secret Lairs and similar. They are still
  /// offered — Rule 0 decides at the table — but the UI says so plainly.
  final bool commanderLegal;

  bool get isColorless => colorIdentity.isEmpty;

  /// WUBRG order, as Magic players expect to read it.
  String get colorIdentityString => colorIdentity.isEmpty
      ? 'C'
      : ManaColor.values
            .where(colorIdentity.contains)
            .map((c) => c.code)
            .join();

  /// Whether this card can legally be a commander at all.
  bool get canBeCommander =>
      typeLine.contains('Legendary') && typeLine.contains('Creature') ||
      (oracleText?.contains('can be your commander') ?? false);

  bool get isBackground => typeLine.contains('Background');

  bool get hasPartner => oracleText?.contains('Partner') ?? false;

  bool get canChooseBackground =>
      oracleText?.contains('Choose a Background') ?? false;

  factory MagicCard.fromScryfall(Map<String, dynamic> json) {
    // Double-faced cards keep their images on the faces rather than the card.
    final faces = json['card_faces'] as List<dynamic>?;
    final imageSource =
        (json['image_uris'] as Map<String, dynamic>?) ??
        (faces != null && faces.isNotEmpty
            ? faces.first['image_uris'] as Map<String, dynamic>?
            : null);

    return MagicCard(
      id: json['id'] as String,
      name: json['name'] as String,
      typeLine: json['type_line'] as String? ?? '',
      colorIdentity: {
        for (final c in (json['color_identity'] as List<dynamic>? ?? []))
          ?ManaColor.fromCode(c as String),
      },
      oracleText:
          json['oracle_text'] as String? ??
          (faces != null && faces.isNotEmpty
              ? faces.first['oracle_text'] as String?
              : null),
      manaCost: json['mana_cost'] as String?,
      imageSmall: imageSource?['small'] as String?,
      imageNormal: imageSource?['normal'] as String?,
      imageArtCrop: imageSource?['art_crop'] as String?,
      scryfallUri: json['scryfall_uri'] as String?,
      // Double-faced cards can have a different artist per face, so this
      // follows the same face the image came from.
      artist:
          json['artist'] as String? ??
          (faces != null && faces.isNotEmpty
              ? faces.first['artist'] as String?
              : null),
      // Absent legality is treated as legal. A missing field means the API
      // didn't say, and badging an unknown card "NOT LEGAL" is a false
      // warning — only an explicit non-legal ruling should raise it.
      commanderLegal: switch ((json['legalities']
          as Map<String, dynamic>?)?['commander']) {
        null => true,
        'legal' => true,
        _ => false,
      },
    );
  }

  @override
  bool operator ==(Object other) => other is MagicCard && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// What a player has in the command zone — one card, or two for partners and
/// backgrounds.
@immutable
class CommanderSet {
  const CommanderSet({
    required this.cards,
    this.pairing = CommanderPairing.single,
  });

  const CommanderSet.empty()
    : cards = const [],
      pairing = CommanderPairing.single;

  final List<MagicCard> cards;
  final CommanderPairing pairing;

  bool get isEmpty => cards.isEmpty;
  bool get isNotEmpty => cards.isNotEmpty;

  /// Combined colour identity of every card in the command zone — a partner
  /// pair's deck may run any colour either commander contributes.
  Set<ManaColor> get colorIdentity => {
    for (final c in cards) ...c.colorIdentity,
  };

  String get colorIdentityString => colorIdentity.isEmpty
      ? 'C'
      : ManaColor.values
            .where(colorIdentity.contains)
            .map((c) => c.code)
            .join();

  /// "Tymna the Weaver + Thrasios, Triton Hero"
  String get displayName =>
      cards.isEmpty ? 'No commander' : cards.map((c) => c.name).join(' + ');

  /// The card whose art represents this set.
  MagicCard? get primary => cards.isEmpty ? null : cards.first;

  /// Commander damage is tracked per commander, not per player, so each card
  /// in the set needs its own tracker.
  List<MagicCard> get damageSources => cards;

  CommanderSet withCard(MagicCard card) {
    if (cards.any((c) => c.id == card.id)) return this;
    return CommanderSet(
      cards: [...cards, card],
      pairing: _inferPairing([...cards, card]),
    );
  }

  CommanderSet withoutCard(String cardId) {
    final remaining = cards.where((c) => c.id != cardId).toList();
    return CommanderSet(cards: remaining, pairing: _inferPairing(remaining));
  }

  static CommanderPairing _inferPairing(List<MagicCard> cards) {
    if (cards.length < 2) return CommanderPairing.single;
    if (cards.any((c) => c.isBackground)) return CommanderPairing.background;
    if (cards.every((c) => c.hasPartner)) return CommanderPairing.partner;
    return CommanderPairing.other;
  }
}
