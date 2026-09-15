import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/feedback.dart';
import '../../core/theme.dart';
import '../../domain/celebration.dart';
import '../../domain/dice.dart';
import '../../domain/models.dart';

/// Draws who takes the first turn.
///
/// Pops the chosen profile id, or null if the table would rather decide it
/// themselves.
///
/// Laid out as a wrapped grid of names rather than a list: this appears over
/// the board, which is landscape-only and leaves about 400 logical pixels of
/// height for six players plus buttons.
class FirstPlayerDialog extends StatefulWidget {
  const FirstPlayerDialog({
    super.key,
    required this.seats,
    required this.feedback,
    this.random,
  });

  final List<Seat> seats;
  final FeedbackService feedback;

  /// Injectable so a test can pin who wins.
  final Random? random;

  @override
  State<FirstPlayerDialog> createState() => _FirstPlayerDialogState();
}

/// Where the dialog is up to.
enum _Phase {
  /// Asking whether to roll at all. The table may already have decided.
  ready,

  spinning,
  settled,
}

class _FirstPlayerDialogState extends State<FirstPlayerDialog>
    with TickerProviderStateMixin {
  late final Random _random = widget.random ?? Random();

  late final AnimationController _controller = AnimationController(
    // Long enough that the sweep is worth watching, short enough that six
    // people are not left waiting on a phone.
    duration: const Duration(milliseconds: 2700),
    vsync: this,
  );

  /// The burst after it lands. Separate from the spin so the sparks can still
  /// be in the air while the name sits there settled.
  late final AnimationController _celebration = AnimationController(
    duration: const Duration(milliseconds: 1400),
    vsync: this,
  );

  /// How the winning pill pops: overshoots, then settles a little enlarged.
  late final Animation<double> _winnerScale =
      Tween<double>(begin: 1.5, end: 1.08).animate(
        CurvedAnimation(
          parent: _celebration,
          // Only the front of the burst — the sparks outlive the pop.
          curve: const Interval(0, 0.45, curve: Curves.easeOutBack),
        ),
      );

  List<Spark> _sparks = const [];

  /// Where the burst comes from, in the overlay's coordinates. Null until the
  /// winning pill has been laid out and measured.
  Offset? _burstOrigin;

  final GlobalKey _overlayKey = GlobalKey();
  final GlobalKey _winnerKey = GlobalKey();

  /// Meaningless until the spin has finished; only read once settled.
  int _landsOn = 0;

  /// The name the ratchet last clicked on, so each one ticks exactly once.
  int _lastTicked = -1;

  _Phase _phase = _Phase.ready;

  @override
  void initState() {
    super.initState();
    // A click per name as the spinner passes it. The sweep decelerates, so
    // these arrive as a ratchet slowing down rather than an even buzz — which
    // is most of what makes a draw feel like a draw.
    _controller.addListener(_tick);
    _controller.addStatusListener((status) {
      if (status != AnimationStatus.completed) return;
      setState(() => _phase = _Phase.settled);
      _celebrate();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _celebration.dispose();
    super.dispose();
  }

  void _tick() {
    if (_phase != _Phase.spinning) return;
    final index = _highlighted;
    if (index == _lastTicked) return;
    _lastTicked = index;
    widget.feedback.fire(FeedbackEvent.selection);
  }

  void _celebrate() {
    _sparks = sparkBurst(count: 22, random: _random);
    _celebration.forward(from: 0);
    widget.feedback.fire(FeedbackEvent.victory);

    // The pill cannot be measured until it has been laid out as the winner,
    // which is this frame's job, so the origin arrives one frame late. Every
    // spark is still at the origin then, so nothing jumps.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final pill = _winnerKey.currentContext?.findRenderObject() as RenderBox?;
      final overlay =
          _overlayKey.currentContext?.findRenderObject() as RenderBox?;
      if (pill == null || overlay == null) return;
      final centre = pill.localToGlobal(
        pill.size.center(Offset.zero),
        ancestor: overlay,
      );
      setState(() => _burstOrigin = centre);
    });
  }

  void _spin() {
    _landsOn = pickSeatIndex(widget.seats.length, _random);
    _lastTicked = -1;
    setState(() {
      _phase = _Phase.spinning;
      _sparks = const [];
      _burstOrigin = null;
    });
    _celebration.value = 0;
    _controller.forward(from: 0);
  }

  /// Decelerating, so it slows into its answer instead of stopping dead.
  double get _progress => Curves.easeOutQuart.transform(_controller.value);

  int get _highlighted => spinIndexAt(
    progress: _progress,
    seatCount: widget.seats.length,
    landsOn: _landsOn,
  );

  bool get _settled => _phase == _Phase.settled;

  @override
  Widget build(BuildContext context) {
    final chosen = _settled ? widget.seats[_landsOn] : null;
    final chosenColour = chosen == null
        ? PodWiseColors.accent
        : PodWiseColors.seats[chosen.colorIndex % PodWiseColors.seats.length];

    return AlertDialog(
      backgroundColor: PodWiseColors.surfaceRaised,
      // The answer replaces the question rather than being added below it.
      // A landscape dialog has about 330 usable pixels once the board's insets
      // and the buttons are accounted for, and an extra line of body text was
      // enough to push the reveal under the fold.
      title: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        child: Text(
          switch (_phase) {
            _Phase.ready => 'Roll for who goes first?',
            _Phase.spinning => 'Rolling…',
            _Phase.settled => '${chosen!.name} goes first',
          },
          // Keyed so the switcher sees a new line as a new widget to cross-fade
          // to, rather than as the same one repainting.
          key: ValueKey(_phase),
          style: TextStyle(color: _settled ? PodWiseColors.accent : null),
        ),
      ),
      // The sparks sit beside the content rather than inside it, so a burst
      // can neither change the dialog's height nor be clipped by the scroll
      // view the names live in.
      content: Stack(
        key: _overlayKey,
        clipBehavior: Clip.none,
        children: [
          // Still scrollable: six players wrap to three rows of pills.
          SingleChildScrollView(
            child: AnimatedBuilder(
              animation: Listenable.merge([_controller, _celebration]),
              builder: (context, _) => Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (var i = 0; i < widget.seats.length; i++)
                        _NamePill(
                          key: _settled && i == _landsOn ? _winnerKey : null,
                          seat: widget.seats[i],
                          lit: _phase != _Phase.ready && i == _highlighted,
                          settled: _settled && i == _landsOn,
                          // Reading the pop before it settles would have the
                          // pill start out at half again its size.
                          scale: _settled && i == _landsOn
                              ? _winnerScale.value
                              : 1,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (_sparks.isNotEmpty)
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _celebration,
                  builder: (context, _) => CustomPaint(
                    painter: _SparkPainter(
                      sparks: _sparks,
                      progress: _celebration.value,
                      origin: _burstOrigin,
                      // Weighted towards the bright end: on the
                      // dark surface the seat colour alone barely reads.
                      palette: [
                        chosenColour,
                        PodWiseColors.accent,
                        Colors.white,
                        PodWiseColors.accent,
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('SKIP'),
        ),
        // Nothing rolls until somebody asks for it. Plenty of tables settle
        // this with a die or by whoever shuffled last, and the board should
        // not decide on their behalf the moment it opens.
        if (_phase == _Phase.ready)
          FilledButton(onPressed: _spin, child: const Text('ROLL'))
        else ...[
          TextButton(
            // Disabled mid-spin, or an impatient tap restarts it and it never
            // finishes.
            onPressed: _settled ? _spin : null,
            child: const Text('AGAIN'),
          ),
          FilledButton(
            onPressed: _settled
                ? () => Navigator.of(context).pop(chosen!.profileId)
                : null,
            child: const Text('START'),
          ),
        ],
      ],
    );
  }
}

/// Throws [sparks] out from [origin], measured in this painter's own
/// coordinates.
class _SparkPainter extends CustomPainter {
  const _SparkPainter({
    required this.sparks,
    required this.progress,
    required this.origin,
    required this.palette,
  });

  final List<Spark> sparks;
  final double progress;
  final Offset? origin;
  final List<Color> palette;

  @override
  void paint(Canvas canvas, Size size) {
    // Until the winning pill has been measured, burst from the middle — which
    // is only ever the first frame, when every spark is still at the origin
    // and invisible anyway.
    final from = origin ?? size.center(Offset.zero);

    // Scaled to the dialog rather than fixed, so the burst is the same shape
    // at a two-player table as at a six-player one.
    final radius = size.shortestSide.clamp(80.0, 220.0);

    for (final spark in sparks) {
      final frame = sparkAt(spark, progress);
      if (frame.opacity <= 0 || frame.scale <= 0) continue;

      canvas.save();
      canvas.translate(from.dx + frame.dx * radius, from.dy + frame.dy * radius);
      canvas.rotate(frame.turns * 2 * pi);

      final length = 13 * spark.size * frame.scale;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset.zero,
            width: length,
            height: length * 0.45,
          ),
          Radius.circular(length * 0.2),
        ),
        Paint()
          ..color = palette[spark.colorIndex % palette.length].withValues(
            alpha: frame.opacity.clamp(0.0, 1.0),
          ),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_SparkPainter old) =>
      old.progress != progress ||
      old.origin != origin ||
      !identical(old.sparks, sparks);
}

class _NamePill extends StatelessWidget {
  const _NamePill({
    super.key,
    required this.seat,
    required this.lit,
    required this.settled,
    required this.scale,
  });

  final Seat seat;

  /// The spinner is passing over this name right now.
  final bool lit;

  /// The spinner stopped here.
  final bool settled;

  /// Driven by the celebration once settled; 1 the rest of the time.
  final double scale;

  @override
  Widget build(BuildContext context) {
    final colour =
        PodWiseColors.seats[seat.colorIndex % PodWiseColors.seats.length];
    final active = lit || settled;

    return AnimatedScale(
      // Lifting each name a little as the spinner passes gives the sweep
      // something to read as movement; once settled the pop takes over.
      scale: lit && !settled ? 1.07 : 1,
      duration: const Duration(milliseconds: 120),
      child: Transform.scale(
        scale: settled ? scale : 1,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: active
                ? colour.withValues(alpha: settled ? 0.9 : 0.45)
                : PodWiseColors.surfaceHigh,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: active ? colour : Colors.transparent,
              width: 1.5,
            ),
            // The lit name glows as the spinner crosses it, and the winner
            // keeps a steadier one.
            boxShadow: active
                ? [
                    BoxShadow(
                      color: colour.withValues(alpha: settled ? 0.55 : 0.3),
                      blurRadius: settled ? 22 : 12,
                      spreadRadius: settled ? 2 : 0,
                    ),
                  ]
                : null,
          ),
          child: Text(
            seat.name,
            style: TextStyle(
              fontSize: 14,
              fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              color: settled ? Colors.black : Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}
