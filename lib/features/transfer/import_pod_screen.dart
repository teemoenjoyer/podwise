import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../domain/commander.dart';
import '../../domain/transfer.dart';
import '../../state/providers.dart';
import '../../state/transfer_providers.dart';
import '../game/game_screen.dart';
import '../setup/starting_life_field.dart';

/// Confirms a pod that has just arrived from another phone, then seats it.
class ImportPodScreen extends ConsumerStatefulWidget {
  const ImportPodScreen({super.key, required this.pod});

  final PodTransfer pod;

  @override
  ConsumerState<ImportPodScreen> createState() => _ImportPodScreenState();
}

class _ImportPodScreenState extends ConsumerState<ImportPodScreen> {
  /// A pod carries who is playing, but not what they are playing for — that is
  /// decided at the table, after the pods are built.
  int _startingLife = commanderStartingLife;

  Map<String, CommanderSet>? _commanders;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  Future<void> _resolve() async {
    final commanders = await ref
        .read(transferServiceProvider)
        .resolveCommanders(widget.pod);
    if (!mounted) return;
    setState(() {
      _commanders = commanders;
      _loading = false;
    });
  }

  Future<void> _start() async {
    final service = ref.read(transferServiceProvider);

    // The phone may already be keeping score for something. Nothing about an
    // active game is written down until it finishes, so overwriting one is
    // unrecoverable and must never happen quietly.
    final existing = ref.read(activeGameProvider);
    if (existing != null && !existing.isFinished) {
      final replace = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: PodWiseColors.surfaceRaised,
          title: const Text('Replace the game in progress?'),
          content: Text(
            existing.isBorrowed
                ? 'You are already keeping score for a borrowed pod. Starting '
                      'this one discards it, and its result cannot be '
                      'recovered.'
                : 'You have a game in progress. Starting this pod discards it, '
                      'and it will not be saved to history.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('KEEP PLAYING'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: PodWiseColors.danger,
              ),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('DISCARD IT'),
            ),
          ],
        ),
      );
      if (replace != true || !mounted) return;
    }

    ref
        .read(activeGameProvider.notifier)
        .start(
          players: service.seatsAsPlayers(widget.pod),
          startingLife: _startingLife,
          commanders: _commanders ?? const {},
          // The pod carries a label for any seat whose commander it could not
          // send as cards, so a borrowed deck still has something to call it.
          commanderLabels: {
            for (final seat in widget.pod.seats)
              if (seat.label case final label? when label.isNotEmpty)
                seat.playerId: label,
          },
          deckIds: {
            for (final seat in widget.pod.seats)
              if (seat.deckId != null) seat.playerId: seat.deckId!,
          },
          borrowedFrom: widget.pod.sourceDeviceId,
        );

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => const GameScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pod received')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: PodWiseColors.accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'You are keeping score for someone else\'s pod. This '
                      'game will not be added to your own history — when it '
                      'finishes you get a code to hand back.',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.5,
                        color: PodWiseColors.accent.withValues(alpha: 0.95),
                      ),
                    ),
                  ),
                  const SizedBox(height: 26),
                  const _Label('STARTING LIFE'),
                  const SizedBox(height: 12),
                  StartingLifeField(
                    value: _startingLife,
                    onChanged: (v) => setState(() => _startingLife = v),
                  ),
                  const SizedBox(height: 28),
                  _Label('PLAYERS  ·  ${widget.pod.seats.length}'),
                  const SizedBox(height: 12),
                  for (final seat in widget.pod.seats)
                    _SeatTile(
                      seat: seat,
                      resolved: _commanders?[seat.playerId],
                      loading: _loading,
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: FilledButton(
                onPressed: _loading ? null : _start,
                child: Text(
                  _loading
                      ? 'LOOKING UP COMMANDERS…'
                      : 'START  ·  ${widget.pod.seats.length} PLAYERS',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w700,
      letterSpacing: 2,
      color: Colors.white.withValues(alpha: 0.45),
    ),
  );
}

class _SeatTile extends StatelessWidget {
  const _SeatTile({
    required this.seat,
    required this.resolved,
    required this.loading,
  });

  final TransferSeat seat;
  final CommanderSet? resolved;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final colour =
        PodWiseColors.seats[seat.colorIndex % PodWiseColors.seats.length];

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: PodWiseColors.surfaceRaised,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: colour.withValues(alpha: 0.3),
              child: Text(
                _initials(seat.name),
                style: TextStyle(fontWeight: FontWeight.w700, color: colour),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    seat.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (seat.displayName.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        seat.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.55),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (loading)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else if (_artMissing)
              // Says plainly that the card could not be looked up, rather than
              // leaving a blank where the art should be. Damage tracking still
              // works — the name came across in the code.
              Tooltip(
                message: 'Card details unavailable offline',
                child: Icon(
                  Icons.cloud_off_rounded,
                  size: 16,
                  color: Colors.white.withValues(alpha: 0.35),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// True when a commander came through as a name-only placeholder.
  bool get _artMissing =>
      resolved != null && resolved!.cards.any((c) => c.imageSmall == null);

  static String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      return parts.first.length == 1
          ? parts.first.toUpperCase()
          : parts.first.substring(0, 2).toUpperCase();
    }
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }
}
