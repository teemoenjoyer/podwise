import 'package:flutter/foundation.dart';

import 'commander.dart';

/// Broad deck strategies, used for the diversity scoring the brief asks for —
/// specifically to avoid "four graveyard decks together" when a better split
/// exists.
///
/// Deliberately coarse. A finer taxonomy would be more accurate in principle
/// and far less accurate in practice, because a human has to pick from it in a
/// few seconds before a game night.
enum DeckArchetype {
  aggro('Aggro'),
  control('Control'),
  combo('Combo'),
  midrange('Midrange'),
  aristocrats('Aristocrats'),
  graveyard('Graveyard'),
  tokens('Tokens'),
  voltron('Voltron'),
  stax('Stax'),
  ramp('Big mana'),
  spellslinger('Spellslinger'),
  lands('Lands'),
  groupHug('Group hug'),
  theft('Theft'),
  blink('Blink'),
  artifacts('Artifacts'),
  tribal('Tribal'),
  superfriends('Superfriends');

  const DeckArchetype(this.label);
  final String label;
}

/// Kinds of interaction a deck can bring.
///
/// Section 5 asks whether a pod has reasonable access to answers. This is a
/// self-reported heuristic and is treated as one — it nudges scoring rather
/// than deciding it.
enum InteractionType {
  creatureRemoval('Creature removal'),
  artifactEnchantmentRemoval('Artifact / enchantment removal'),
  graveyardHate('Graveyard hate'),
  boardWipe('Board wipes'),
  stackInteraction('Counterspells');

  const InteractionType(this.label);
  final String label;
}

/// What the group knows about one deck.
///
/// A player may own several, so this is a deck first and a person second —
/// power, archetypes and results all describe the deck. Power is entered by
/// hand and then nudged by that deck's own results over time; Scryfall
/// describes the commander, never the 99 cards behind it.
@immutable
class DeckProfile {
  const DeckProfile({
    required this.playerId,
    required this.playerName,
    this.deckId = '',
    this.deckName = '',
    this.commanderName = '',
    this.commanderIds = const [],
    this.colorIdentity = const {},
    this.power = 5,
    this.archetypes = const {},
    this.interaction = const {},
    this.gamesPlayed = 0,
    this.wins = 0,
    this.lastPlayedAt,
  });

  final String playerId;
  final String playerName;

  /// Empty for a deck that exists only in memory — the placeholder shown for
  /// a player who has not saved one yet. Saving gives it an id.
  final String deckId;

  /// Optional nickname. Most decks go by their commander instead.
  final String deckName;

  final String commanderName;

  /// Scryfall ids of the command zone, so the actual cards can be recovered
  /// for commander-damage tracking when this deck is brought to a game.
  final List<String> commanderIds;

  final Set<ManaColor> colorIdentity;

  /// 1–10, as judged by the group. 5 is an unremarkable mid-power deck.
  final int power;

  final Set<DeckArchetype> archetypes;
  final Set<InteractionType> interaction;

  /// This deck's record, not the player's.
  final int gamesPlayed;
  final int wins;

  final DateTime? lastPlayedAt;

  /// Whether this deck has been written to the database.
  bool get isSaved => deckId.isNotEmpty;

  /// What to call this deck on screen.
  String get displayName => deckName.isNotEmpty
      ? deckName
      : (commanderName.isNotEmpty ? commanderName : 'Untitled deck');

  /// True once somebody has actually told the app something about the deck.
  /// An untouched deck is scored neutrally rather than as a weak one.
  bool get isRated => power != 5 || archetypes.isNotEmpty;

  double get winRate => gamesPlayed == 0 ? 0.25 : wins / gamesPlayed;

  /// WUBRG order, as Magic players read it. "C" when colourless.
  String get colorIdentityString => colorIdentity.isEmpty
      ? 'C'
      : ManaColor.values
            .where(colorIdentity.contains)
            .map((c) => c.code)
            .join();

  /// Power after correcting for how the deck has actually performed.
  ///
  /// A deck rated 6 that wins half its games is playing above its rating; one
  /// that never wins is playing below it. The correction is capped at ±1.5 so
  /// a couple of lucky nights cannot overrule the group's own judgement, and
  /// it needs a handful of games before it does anything at all.
  double get effectivePower {
    if (gamesPlayed < 4) return power.toDouble();
    // 25% is par in a four-player pod.
    const expected = 0.25;
    final delta = (winRate - expected) / expected; // -1 .. +3
    return (power + (delta * 1.5).clamp(-1.5, 1.5)).clamp(1, 10);
  }

  DeckProfile copyWith({
    String? deckId,
    String? deckName,
    String? commanderName,
    List<String>? commanderIds,
    Set<ManaColor>? colorIdentity,
    int? power,
    Set<DeckArchetype>? archetypes,
    Set<InteractionType>? interaction,
  }) => DeckProfile(
    playerId: playerId,
    playerName: playerName,
    deckId: deckId ?? this.deckId,
    deckName: deckName ?? this.deckName,
    commanderName: commanderName ?? this.commanderName,
    commanderIds: commanderIds ?? this.commanderIds,
    colorIdentity: colorIdentity ?? this.colorIdentity,
    power: power ?? this.power,
    archetypes: archetypes ?? this.archetypes,
    interaction: interaction ?? this.interaction,
    gamesPlayed: gamesPlayed,
    wins: wins,
    lastPlayedAt: lastPlayedAt,
  );
}

/// How the user wants pods built.
enum PodMode {
  random('Random', 'Pure shuffle. No balancing at all.'),
  fairest('Fairest', 'Evens out estimated deck power between pods.'),
  diverse(
    'Diverse',
    'Maximises variety of colours, commanders and strategies.',
  ),
  freshMatchups(
    'Fresh Matchups',
    'Separates people who keep playing each other.',
  ),
  casualBalance(
    'Casual Balance',
    'Stops the strongest decks stacking into one pod.',
  ),
  competitiveBalance(
    'Competitive Balance',
    'Puts the strongest decks at the same table, and the rest at another.',
  ),
  smartPods(
    'Smart Pods',
    'Weighs everything: power, variety, history and answers.',
  ),
  deckRoulette(
    'Deck Roulette',
    "Random pods, and everyone plays somebody else's deck.",
  );

  /// Whether this mode hands players each other's decks.
  bool get swapsDecks => this == PodMode.deckRoulette;

  const PodMode(this.label, this.description);
  final String label;
  final String description;
}

/// One pod's worth of players.
@immutable
class Pod {
  const Pod(this.members);
  final List<DeckProfile> members;

  int get size => members.length;

  double get totalPower =>
      members.fold(0.0, (sum, d) => sum + d.effectivePower);

  double get averagePower => members.isEmpty ? 0 : totalPower / members.length;

  Set<ManaColor> get colors => {for (final m in members) ...m.colorIdentity};

  Set<DeckArchetype> get archetypes => {
    for (final m in members) ...m.archetypes,
  };

  Set<InteractionType> get interaction => {
    for (final m in members) ...m.interaction,
  };

  /// Interaction types nobody in this pod brings.
  Set<InteractionType> get missingInteraction =>
      InteractionType.values.toSet().difference(interaction);
}

/// A complete assignment of every player to a pod, with its score.
@immutable
class PodAssignment {
  const PodAssignment({required this.pods, required this.score});

  final List<Pod> pods;
  final PodScore score;
}

/// The breakdown behind an assignment, so the app can explain itself rather
/// than just presenting a list of names.
///
/// Every component runs 0–1, where 1 is better, which keeps the weights in
/// [PodMode] meaningful and comparable.
@immutable
class PodScore {
  const PodScore({
    required this.powerBalance,
    required this.powerTiering,
    required this.colorDiversity,
    required this.archetypeDiversity,
    required this.freshMatchups,
    required this.interactionCoverage,
    required this.playerBalance,
    required this.total,
  });

  /// 1 when every pod's power is spread evenly against the others.
  final double powerBalance;

  /// 1 when each pod's members are close to each other in power — which is
  /// what puts the strongest decks at one table and the precons at another.
  ///
  /// The opposite of [powerBalance], and deliberately so: Casual Balance wants
  /// the strong decks spread out, Competitive Balance wants them together.
  final double powerTiering;
  final double colorDiversity;
  final double archetypeDiversity;
  final double freshMatchups;
  final double interactionCoverage;
  final double playerBalance;
  final double total;

  /// Plain-language rating, for the "Why these pods?" panel.
  static String describe(double value) => switch (value) {
    >= 0.85 => 'Excellent',
    >= 0.7 => 'Good',
    >= 0.5 => 'Fair',
    >= 0.3 => 'Poor',
    _ => 'Very poor',
  };
}
