import 'package:flutter/material.dart';

/// A numeric counter attached to a player.
///
/// The presets cover what most Commander games need, but the brief is explicit
/// that players must be able to invent their own — "Treasure", "Spore", or
/// anything else a deck cares about.
@immutable
class CounterType {
  const CounterType({
    required this.id,
    required this.label,
    required this.icon,
    this.color,
    this.lethalAt,
    this.startsAt = 0,
  });

  final String id;
  final String label;
  final IconData icon;
  final Color? color;

  /// Value at which this counter kills its owner, if any. Poison is 10 in
  /// Commander, not the 15 some players expect from other formats.
  final int? lethalAt;

  /// Most counters start at zero; commander tax starts at zero but climbs in
  /// twos, which the UI handles via its step size rather than here.
  final int startsAt;

  bool isLethal(int value) => lethalAt != null && value >= lethalAt!;

  /// How much a single tap changes this counter.
  int get step => id == 'commander_tax' ? 2 : 1;
}

/// The preset counters offered before a player creates their own.
abstract final class CounterPresets {
  /// Ten poison counters is lethal in Commander, matching normal constructed
  /// play rather than the 15 used in some casual variants.
  static const poison = CounterType(
    id: 'poison',
    label: 'Poison',
    icon: Icons.coronavirus_rounded,
    color: Color(0xFF7FA650),
    lethalAt: 10,
  );

  static const energy = CounterType(
    id: 'energy',
    label: 'Energy',
    icon: Icons.bolt_rounded,
    color: Color(0xFF6BA5D6),
  );

  static const experience = CounterType(
    id: 'experience',
    label: 'Experience',
    icon: Icons.star_rounded,
    color: Color(0xFFC9A227),
  );

  static const rad = CounterType(
    id: 'rad',
    label: 'Rad',
    icon: Icons.radar_rounded,
    color: Color(0xFF8FB63F),
  );

  static const storm = CounterType(
    id: 'storm',
    label: 'Storm',
    icon: Icons.cyclone_rounded,
    color: Color(0xFFB07FD1),
  );

  /// Commander tax rises by two each time a commander is recast, so its step
  /// size differs from every other counter.
  static const commanderTax = CounterType(
    id: 'commander_tax',
    label: 'Commander tax',
    icon: Icons.account_balance_rounded,
    color: Color(0xFFAD9C7A),
  );

  static const ringTemptation = CounterType(
    id: 'ring_temptation',
    label: 'Ring temptations',
    icon: Icons.circle_outlined,
    color: Color(0xFFD4B483),
    // The Ring tempts you at most four times.
    lethalAt: null,
  );

  static const treasure = CounterType(
    id: 'treasure',
    label: 'Treasure',
    icon: Icons.diamond_rounded,
    color: Color(0xFFD9B44A),
  );

  static const all = <CounterType>[
    poison,
    energy,
    experience,
    rad,
    storm,
    commanderTax,
    ringTemptation,
    treasure,
  ];

  static CounterType? byId(String id) {
    for (final c in all) {
      if (c.id == id) return c;
    }
    return null;
  }

  /// Builds a counter type for a name the user invented.
  static CounterType custom(String label) => CounterType(
    id: 'custom:${label.toLowerCase().trim()}',
    label: label.trim(),
    icon: Icons.add_circle_outline_rounded,
  );
}

/// A non-numeric board state a player either has or doesn't.
///
/// Kept separate from counters because these are binary and, for the ones that
/// only one player can hold, exclusive across the table.
@immutable
class StatusEffect {
  const StatusEffect({
    required this.id,
    required this.label,
    required this.icon,
    required this.color,
    this.exclusive = false,
  });

  final String id;
  final String label;
  final IconData icon;
  final Color color;

  /// True when only one player at the table can hold this at a time — taking
  /// the Monarch from someone removes it from them.
  final bool exclusive;
}

abstract final class StatusPresets {
  static const monarch = StatusEffect(
    id: 'monarch',
    label: 'Monarch',
    icon: Icons.workspace_premium_rounded,
    color: Color(0xFFC9A227),
    exclusive: true,
  );

  static const initiative = StatusEffect(
    id: 'initiative',
    label: 'Initiative',
    icon: Icons.flag_rounded,
    color: Color(0xFFB5544A),
    exclusive: true,
  );

  static const citysBlessing = StatusEffect(
    id: 'citys_blessing',
    label: "City's Blessing",
    icon: Icons.location_city_rounded,
    color: Color(0xFF9B6BB5),
  );

  /// Day and Night are a property of the game, not a player, but tracking them
  /// on whoever is keeping score is the pragmatic choice — and they are
  /// mutually exclusive with each other.
  static const day = StatusEffect(
    id: 'day',
    label: 'Day',
    icon: Icons.light_mode_rounded,
    color: Color(0xFFE0C068),
    exclusive: true,
  );

  static const night = StatusEffect(
    id: 'night',
    label: 'Night',
    icon: Icons.dark_mode_rounded,
    color: Color(0xFF6E7FA6),
    exclusive: true,
  );

  static const all = <StatusEffect>[
    monarch,
    initiative,
    citysBlessing,
    day,
    night,
  ];

  static StatusEffect? byId(String id) {
    for (final s in all) {
      if (s.id == id) return s;
    }
    return null;
  }

  static StatusEffect custom(String label) => StatusEffect(
    id: 'custom:${label.toLowerCase().trim()}',
    label: label.trim(),
    icon: Icons.label_rounded,
    color: const Color(0xFF8A8F98),
  );

  /// Day and Night cannot both be true, so setting one clears the other.
  static String? opposite(String id) => switch (id) {
    'day' => 'night',
    'night' => 'day',
    _ => null,
  };
}
