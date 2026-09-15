import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../domain/commander.dart';
import '../../domain/models.dart';
import '../../state/providers.dart';

String formatDuration(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  if (h > 0) return '${h}h ${m}m';
  if (m > 0) return '${m}m';
  return '${d.inSeconds}s';
}

/// Shown once a game ends. The brief asks for this to feel social rather than
/// like a report, so the winner gets the whole top half.
class GameSummaryScreen extends ConsumerWidget {
  const GameSummaryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final game = ref.watch(activeGameProvider);
    if (game == null) {
      return const Scaffold(body: Center(child: Text('Nothing to show')));
    }

    final winner = game.seats
        .where((s) => s.profileId == game.winnerProfileId)
        .firstOrNull;
    // The same ordering that gets saved to history — not a second copy of it.
    // This screen used to sort by life, which quietly disagreed with the
    // positions written to the database for the very same game.
    final standings = game.rankedBy(game.winnerProfileId);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // The whole summary scrolls as one. The header alone is taller
            // than a landscape screen, and this screen is briefly landscape
            // on the way back from the board — or permanently, if the phone's
            // rotation is locked.
            Expanded(
              child: ListView(
                children: [
                  _WinnerHero(game: game, winner: winner),
                  for (var i = 0; i < standings.length; i++)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: _StandingRow(position: i + 1, seat: standings[i]),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: FilledButton(
                onPressed: () {
                  ref.read(activeGameProvider.notifier).clear();
                  Navigator.of(context).popUntil((r) => r.isFirst);
                },
                child: const Text('DONE'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The top of the screen: the winner, over their commander's art.
///
/// The art is a backdrop behind the existing header rather than a band of its
/// own with a fixed height. That is deliberate — this screen is briefly
/// landscape on the way back from the board, where it has overflowed once
/// already, and a backdrop can only ever be as tall as the text it sits
/// behind.
class _WinnerHero extends ConsumerWidget {
  const _WinnerHero({required this.game, required this.winner});

  final GameState game;
  final Seat? winner;

  /// The card whose art represents the winning deck, when there is one.
  ///
  /// Null covers more cases than it first looks: a game nobody won, a table
  /// that never entered commanders, and a pod borrowed from another phone —
  /// that payload carries card names but no image URLs, to keep the QR code
  /// scannable.
  MagicCard? get _art {
    final card = winner?.commanders.primary;
    return card?.imageArtCrop == null ? null : card;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final art = _art;
    final commanderName = winner?.commanderDisplayName;

    // Cards cached before the app recorded artists have art but no credit, so
    // this looks one up in the background. It resolves to null offline, and
    // the credit simply never appears.
    final artist = art == null
        ? null
        : ref.watch(cardArtistProvider(art)).valueOrNull ?? art.artist;

    return Stack(
      children: [
        if (art != null)
          Positioned.fill(child: _ArtBackdrop(url: art.imageArtCrop!)),
        Column(
          children: [
            const SizedBox(height: 24),
            Text(
              'GAME OVER',
              style: TextStyle(
                fontSize: 12,
                letterSpacing: 5,
                fontWeight: FontWeight.w700,
                color: Colors.white.withValues(alpha: 0.4),
              ),
            ),
            const SizedBox(height: 28),
            if (winner != null) ...[
              const Text('🏆', style: TextStyle(fontSize: 52)),
              const SizedBox(height: 10),
              Text(
                winner!.name,
                style: const TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                'wins with ${winner!.life} life',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.55)),
              ),
              // Named even when there is no art to go with it: a borrowed pod
              // knows the commander perfectly well, it just has no picture.
              if (commanderName != null && commanderName.isNotEmpty) ...[
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    commanderName.toUpperCase(),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      letterSpacing: 2,
                      fontWeight: FontWeight.w600,
                      color: PodWiseColors.accent.withValues(alpha: 0.85),
                    ),
                  ),
                ),
              ],
            ] else
              Text(
                'No winner recorded',
                style: TextStyle(
                  fontSize: 24,
                  color: Colors.white.withValues(alpha: 0.6),
                ),
              ),
            const SizedBox(height: 28),
            _StatStrip(game: game),
            // Inside the hero, so the art runs behind the credit and the
            // spacing above the divider is the same either way.
            if (artist != null)
              Padding(
                padding: const EdgeInsets.only(top: 14),
                child: Text(
                  'ART BY ${artist.toUpperCase()}',
                  style: TextStyle(
                    fontSize: 8,
                    letterSpacing: 1.5,
                    color: Colors.white.withValues(alpha: 0.35),
                  ),
                ),
              ),
            const Divider(height: 40),
          ],
        ),
      ],
    );
  }
}

/// Commander art, dimmed far enough that white text stays readable over it.
///
/// The art is somebody's painting of a scene, not a background chosen to have
/// words on it, so the scrim has to assume the worst case: a pale sky exactly
/// where the winner's name goes. Hence both a flat wash and a gradient that
/// closes to the page colour at the bottom, so the hero has no visible seam
/// where it meets the standings.
class _ArtBackdrop extends StatelessWidget {
  const _ArtBackdrop({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    final page = Theme.of(context).scaffoldBackgroundColor;

    return Stack(
      fit: StackFit.expand,
      children: [
        CachedNetworkImage(
          imageUrl: url,
          fit: BoxFit.cover,
          // Both fall back to nothing rather than to an icon. This is a
          // backdrop: a broken-image glyph behind the trophy would be far
          // worse than the plain header this screen has always had.
          placeholder: (_, _) => const SizedBox.shrink(),
          errorWidget: (_, _, _) => const SizedBox.shrink(),
          fadeInDuration: const Duration(milliseconds: 450),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                page.withValues(alpha: 0.82),
                page.withValues(alpha: 0.62),
                page.withValues(alpha: 0.92),
                page,
              ],
              stops: const [0, 0.45, 0.85, 1],
            ),
          ),
        ),
      ],
    );
  }
}

class _StatStrip extends StatelessWidget {
  const _StatStrip({required this.game});
  final GameState game;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _Stat(label: 'DURATION', value: formatDuration(game.elapsed)),
        _Stat(label: 'PLAYERS', value: '${game.seats.length}'),
        _Stat(label: 'STARTING LIFE', value: '${game.startingLife}'),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 18),
    child: Column(
      children: [
        Text(
          value,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 9,
            letterSpacing: 1.5,
            color: Colors.white.withValues(alpha: 0.4),
          ),
        ),
      ],
    ),
  );
}

class _StandingRow extends StatelessWidget {
  const _StandingRow({required this.position, required this.seat});
  final int position;
  final Seat seat;

  @override
  Widget build(BuildContext context) {
    final color =
        PodWiseColors.seats[seat.colorIndex % PodWiseColors.seats.length];
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text(
              '$position',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.white.withValues(alpha: 0.35),
              ),
            ),
          ),
          CircleAvatar(
            radius: 18,
            backgroundColor: color,
            child: Text(
              seat.initials,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(seat.name, style: const TextStyle(fontSize: 16)),
          ),
          Text(
            '${seat.life}',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w500,
              color: seat.eliminated
                  ? PodWiseColors.danger.withValues(alpha: 0.7)
                  : Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
