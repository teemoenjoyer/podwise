import 'package:flutter/material.dart';

import '../../core/feedback.dart';
import '../../core/theme.dart';
import '../../domain/counters.dart';
import '../../domain/models.dart';

/// One player's life panel.
///
/// Panels on the far side of the table are rendered upside-down so the player
/// sitting there reads them the right way up. This is the single biggest
/// usability win for a phone lying flat in the middle of a pod.
class PlayerPanel extends StatelessWidget {
  const PlayerPanel({
    super.key,
    required this.seat,
    required this.pending,
    required this.flipped,
    required this.compact,
    this.spansFullWidth = false,
    this.worstCommanderDamage = 0,
    required this.onAdjust,
    required this.onFeedback,
    required this.onOpenDetail,
    required this.onOpenCommanderDamage,
  });

  final Seat seat;

  /// Uncommitted life change; 0 when there is nothing in the edit window.
  final int pending;
  final bool flipped;

  /// True when several panels share the screen and type must shrink.
  final bool compact;

  /// True when this panel is the only one in its row, so it runs the whole
  /// width of the screen.
  ///
  /// Its centre line then coincides with the middle of the board, which is
  /// where the menu button and clock sit — so anything normally drawn on that
  /// line has to move out of the way.
  final bool spansFullWidth;

  /// Highest commander damage this player has taken from any single commander.
  /// Only the worst one matters, because that is the one that can reach 21.
  final int worstCommanderDamage;

  final void Function(int delta) onAdjust;

  /// Fires haptics and sounds, subject to the user's settings.
  final void Function(FeedbackEvent) onFeedback;

  final VoidCallback onOpenDetail;

  /// Straight to this player's commander damage, skipping the detail sheet.
  ///
  /// It is the most-used thing behind that sheet by a distance, and a phone
  /// flat on a table is an awkward place to go three taps deep.
  final VoidCallback onOpenCommanderDamage;

  bool get _hasDamage => worstCommanderDamage > 0 && !seat.eliminated;

  /// Everything that normally sits on the panel's centre line has to move to
  /// the near edge on a full-width panel, where the menu button would cover
  /// it. The badge did already; these are the rest.
  bool get _showsEliminatedHere => seat.eliminated;
  bool get _showsPendingHere => pending != 0;

  Widget get _eliminatedLabel => Text(
    'ELIMINATED',
    textAlign: TextAlign.center,
    style: TextStyle(
      fontSize: 10,
      fontWeight: FontWeight.w700,
      letterSpacing: 2,
      color: PodWiseColors.danger.withValues(alpha: 0.8),
    ),
  );

  Widget get _pendingPill => AnimatedOpacity(
    opacity: 1,
    duration: const Duration(milliseconds: 120),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: pending > 0 ? PodWiseColors.healthy : PodWiseColors.danger,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        pending > 0 ? '+$pending' : '$pending',
        style: PodWiseText.pendingDelta.copyWith(
          fontSize: compact ? 18 : 24,
          color: Colors.white,
        ),
      ),
    ),
  );

  Color get _color =>
      PodWiseColors.seats[seat.colorIndex % PodWiseColors.seats.length];

  @override
  Widget build(BuildContext context) {
    final panel = _buildPanel(context);
    return flipped ? RotatedBox(quarterTurns: 2, child: panel) : panel;
  }

  /// Below this width the −/number/+ row cannot fit, so the panel stacks
  /// instead: name and life at the top, both adjust zones along the bottom.
  ///
  /// Two 72-wide zones leave nothing for the number once a landscape board is
  /// split six ways, which is where the row began overflowing. Measured
  /// rather than counted, so a narrow phone gets the same treatment one seat
  /// earlier instead of overflowing.
  static const _stackedBelow = _AdjustZone.width * 2 + 24;

  /// The player's name, and whatever has to sit beside it.
  ///
  /// [beside] pulls the badge, the elimination label and the pending total in
  /// next to the name instead of leaving them on the panel's centre line —
  /// which is where the menu button is on a full-width panel, and where the
  /// life total is on a stacked one.
  Widget _nameBlock(bool dimmed, {required bool beside}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!dimmed) _StatusAndCounterStrip(seat: seat),
        if (beside && _showsEliminatedHere) ...[
          _eliminatedLabel,
          const SizedBox(height: 2),
        ],
        Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (beside && _showsPendingHere) ...[
              _pendingPill,
              const SizedBox(width: 8),
            ],
            if (beside && _hasDamage) ...[
              _CommanderDamageBadge(
                damage: worstCommanderDamage,
                compact: compact,
              ),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Text(
                seat.name.toUpperCase(),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: compact ? 11 : 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                  color: Colors.white.withValues(alpha: dimmed ? 0.3 : 0.75),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// The life total, which doubles as the tap target for the two sheets.
  Widget _lifeNumber(bool dimmed, {required bool stacked}) {
    return GestureDetector(
      onTap: onOpenDetail,
      // The ±10 long-press lives on the adjust zones, so the number is free
      // for the shortcut.
      onLongPress: () {
        onFeedback(FeedbackEvent.selection);
        onOpenCommanderDamage();
      },
      behavior: HitTestBehavior.opaque,
      // The number scales to whatever space the panel has rather than a fixed
      // size, so a tall portrait panel and a wide landscape one are both
      // filled.
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: 4,
          vertical: stacked ? 4 : (compact ? 26 : 34),
        ),
        child: FittedBox(
          fit: BoxFit.contain,
          child: Text(
            '${seat.life}',
            style: PodWiseText.lifeHuge.copyWith(
              color: dimmed
                  ? Colors.white.withValues(alpha: 0.25)
                  : Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPanel(BuildContext context) {
    final dimmed = seat.eliminated;

    return Container(
      margin: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: dimmed
            ? PodWiseColors.surfaceRaised
            : _color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: dimmed ? PodWiseColors.outline : _color.withValues(alpha: 0.5),
          width: 1.5,
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) => constraints.maxWidth < _stackedBelow
            ? _stacked(dimmed)
            : _sideBySide(dimmed),
      ),
    );
  }

  /// The usual panel: hold-to-ten either side of a life total that fills the
  /// space, with the name along the near edge.
  Widget _sideBySide(bool dimmed) {
    return Stack(
      children: [
        Row(
          children: [
            SizedBox(
              width: _AdjustZone.width,
              child: _AdjustZone(
                label: '−',
                onTap: () => _adjust(-1),
                onLongPress: () => _adjust(-10),
                enabled: !dimmed,
              ),
            ),
            Expanded(child: _lifeNumber(dimmed, stacked: false)),
            SizedBox(
              width: _AdjustZone.width,
              child: _AdjustZone(
                label: '+',
                onTap: () => _adjust(1),
                onLongPress: () => _adjust(10),
                enabled: !dimmed,
              ),
            ),
          ],
        ),
        // Name sits at the panel's *near* edge — the side facing whoever
        // owns it. Because far-side panels are rotated 180°, a panel's
        // bottom is always the edge closest to its player, and its top
        // always faces the middle of the table. Putting the name at the top
        // stacked every name around the centre, where the menu and clock
        // live, and hid them.
        Positioned(
          bottom: 8,
          left: 8,
          right: 8,
          child: IgnorePointer(
            child: _nameBlock(dimmed, beside: spansFullWidth),
          ),
        ),
        // Facing the middle of the table, so opponents can see who is one
        // swing from dying. Hidden here on a full-width panel, where it
        // would sit under the menu button — it moves next to the name
        // instead.
        if (!spansFullWidth && _hasDamage && pending == 0)
          Positioned(
            top: 8,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: Center(
                child: _CommanderDamageBadge(
                  damage: worstCommanderDamage,
                  compact: compact,
                ),
              ),
            ),
          ),
        if (_showsEliminatedHere && !spansFullWidth)
          Positioned(
            top: 10,
            left: 0,
            right: 0,
            child: IgnorePointer(child: _eliminatedLabel),
          ),
        if (_showsPendingHere && !spansFullWidth)
          Positioned(
            // Sits opposite the name so the two never overlap.
            top: 10,
            right: 0,
            left: 0,
            child: Center(child: _pendingPill),
          ),
      ],
    );
  }

  /// The narrow panel: name and life at the top, both adjust zones along the
  /// bottom.
  ///
  /// Used when the panel is too narrow to put anything either side of the
  /// number — a table all sitting down one side of the phone, which at six or
  /// more leaves each seat about 150 pixels wide. Stacking is the only way to
  /// keep a readable life total and two honest tap targets in that space.
  ///
  /// The name goes at the panel's top rather than its near edge as usual:
  /// far-side panels are rotated with everything in them, so each player
  /// still reads their own name above their own life total.
  Widget _stacked(bool dimmed) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
          child: _nameBlock(dimmed, beside: true),
        ),
        Expanded(child: _lifeNumber(dimmed, stacked: true)),
        SizedBox(
          height: 56,
          child: Row(
            children: [
              Expanded(
                child: _AdjustZone(
                  label: '−',
                  onTap: () => _adjust(-1),
                  onLongPress: () => _adjust(-10),
                  enabled: !dimmed,
                ),
              ),
              Expanded(
                child: _AdjustZone(
                  label: '+',
                  onTap: () => _adjust(1),
                  onLongPress: () => _adjust(10),
                  enabled: !dimmed,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
  void _adjust(int delta) {
    // Weight the feedback to the size of the change: a single point should
    // feel lighter than a ten-point swing.
    onFeedback(
      delta.abs() >= 10 ? FeedbackEvent.bigSwing : FeedbackEvent.lifeTick,
    );
    onAdjust(delta);
  }
}

/// A large, imprecise tap target. Tap for 1, hold for 10 — this keeps the
/// panel free of four separate small buttons.
class _AdjustZone extends StatelessWidget {
  const _AdjustZone({
    required this.label,
    required this.onTap,
    required this.onLongPress,
    required this.enabled,
  });

  /// How wide the zone is when a panel has room to put one either side of
  /// the life total.
  static const width = 72.0;

  final String label;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onTap : null,
          onLongPress: enabled ? onLongPress : null,
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 40,
                fontWeight: FontWeight.w300,
                color: Colors.white.withValues(alpha: enabled ? 0.55 : 0.12),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Compact row of status icons and counter values under a player's name.
///
/// Deliberately icon-only: the panel's job is the life total, and this must
/// stay glanceable rather than becoming a second read.
class _StatusAndCounterStrip extends StatelessWidget {
  const _StatusAndCounterStrip({required this.seat});

  final Seat seat;

  @override
  Widget build(BuildContext context) {
    final statuses = [for (final id in seat.statuses) ?StatusPresets.byId(id)];
    final counters = seat.counters.entries.where((e) => e.value > 0).toList();
    if (statuses.isEmpty && counters.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 6,
        runSpacing: 2,
        children: [
          for (final s in statuses) Icon(s.icon, size: 13, color: s.color),
          for (final entry in counters)
            Builder(
              builder: (_) {
                final type = CounterPresets.byId(entry.key);
                final lethal = type?.isLethal(entry.value) ?? false;
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      type?.icon ?? Icons.label_rounded,
                      size: 12,
                      color: lethal
                          ? PodWiseColors.danger
                          : (type?.color ?? Colors.white54),
                    ),
                    const SizedBox(width: 2),
                    Text(
                      '${entry.value}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: lethal
                            ? PodWiseColors.danger
                            : Colors.white.withValues(alpha: 0.75),
                      ),
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }
}

/// How close this player is to losing to a single commander.
///
/// Only the worst source is shown: 21 from one commander is lethal, so the
/// others do not change what anybody needs to know.
class _CommanderDamageBadge extends StatelessWidget {
  const _CommanderDamageBadge({required this.damage, required this.compact});

  final int damage;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final lethal = damage >= commanderDamageThreshold;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: lethal
            ? PodWiseColors.danger
            : PodWiseColors.surfaceHigh.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '⚔ $damage/$commanderDamageThreshold',
        style: TextStyle(
          fontSize: compact ? 10 : 12,
          fontWeight: FontWeight.w600,
          color: damage >= commanderDamageThreshold - 5
              ? Colors.white
              : Colors.white.withValues(alpha: 0.65),
        ),
      ),
    );
  }
}
