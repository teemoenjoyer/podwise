import 'package:flutter/foundation.dart';

/// What the app can work out about a player from saved games.
///
/// Every figure here is derived from recorded results — nothing is estimated.
/// Where a statistic needs data the app doesn't have, it is absent rather than
/// guessed at.
@immutable
class PlayerStats {
  const PlayerStats({
    required this.profileId,
    required this.name,
    required this.gamesPlayed,
    required this.wins,
    required this.totalPosition,
    required this.totalDuration,
    required this.opponentCounts,
  });

  final String profileId;
  final String name;
  final int gamesPlayed;
  final int wins;

  /// Sum of finishing positions, for the average.
  final int totalPosition;

  final Duration totalDuration;

  /// How many games shared with each other player.
  final Map<String, int> opponentCounts;

  double get winRate => gamesPlayed == 0 ? 0 : wins / gamesPlayed;

  double? get averagePosition =>
      gamesPlayed == 0 ? null : totalPosition / gamesPlayed;

  Duration? get averageDuration => gamesPlayed == 0
      ? null
      : Duration(milliseconds: totalDuration.inMilliseconds ~/ gamesPlayed);

  /// The player met most often, if there is one.
  MapEntry<String, int>? get mostCommonOpponent {
    if (opponentCounts.isEmpty) return null;
    return opponentCounts.entries.reduce((a, b) => b.value > a.value ? b : a);
  }

  /// Enough games for the numbers to mean anything.
  ///
  /// Below this a single game swings the win rate by a wide margin, and
  /// showing "100% win rate" after one night is worse than showing nothing.
  static const meaningfulSampleSize = 5;

  bool get hasMeaningfulSample => gamesPlayed >= meaningfulSampleSize;
}
