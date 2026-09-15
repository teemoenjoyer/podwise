import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/feedback.dart';
import '../../core/theme.dart';
import '../../domain/dice.dart';

/// Rolls a die at the table.
///
/// Commander needs one often enough — coin flips, Chaos Warp, deciding who
/// deals with the problem — that reaching for a phone's calculator or a
/// separate app is a nuisance.
class DiceSheet extends StatefulWidget {
  const DiceSheet({super.key, required this.feedback, this.random});

  final FeedbackService feedback;

  /// Injectable so a test can pin the roll.
  final Random? random;

  @override
  State<DiceSheet> createState() => _DiceSheetState();
}

class _DiceSheetState extends State<DiceSheet>
    with SingleTickerProviderStateMixin {
  late final Random _random = widget.random ?? Random();

  late final AnimationController _controller = AnimationController(
    duration: const Duration(milliseconds: 550),
    vsync: this,
  );

  DieType _die = DieType.d20;
  int? _result;

  /// What the tumbling number shows mid-roll. Not the result — that is drawn
  /// once and kept, so the animation can never disagree with the answer.
  int _showing = 1;

  /// The last few rolls of the current die, newest first. Useful when the
  /// table is rolling off against each other and nobody can remember what
  /// anyone got.
  final List<int> _history = [];

  @override
  void initState() {
    super.initState();
    _controller.addListener(_tumble);
    _controller.addStatusListener((status) {
      if (status != AnimationStatus.completed) return;
      setState(() {
        _showing = _result!;
        _history.insert(0, _result!);
        if (_history.length > 6) _history.removeLast();
      });
      widget.feedback.fire(FeedbackEvent.bigSwing);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _tumble() {
    if (_controller.isCompleted) return;
    // Slows as it settles, so it reads as a die coming to rest.
    final step = (_controller.value * 14).floor();
    if (step == _lastStep) return;
    _lastStep = step;
    setState(() => _showing = rollDie(_die, _random));
  }

  int _lastStep = -1;

  void _roll() {
    setState(() {
      _result = rollDie(_die, _random);
      _lastStep = -1;
    });
    _controller.forward(from: 0);
  }

  void _selectDie(DieType die) {
    setState(() {
      _die = die;
      _result = null;
      _showing = 1;
      // A d6 history means nothing once you switch to a d20.
      _history.clear();
    });
  }

  bool get _rolling => _controller.isAnimating;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Roll a die',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  for (final die in DieType.values) ...[
                    Expanded(
                      child: _DieButton(
                        die: die,
                        selected: die == _die,
                        onTap: () => _selectDie(die),
                      ),
                    ),
                    if (die != DieType.values.last) const SizedBox(width: 8),
                  ],
                ],
              ),
              const SizedBox(height: 16),
              Center(
                child: _Result(
                  value: _result == null ? null : _showing,
                  rolling: _rolling,
                  die: _die,
                ),
              ),
              if (_history.length > 1) ...[
                const SizedBox(height: 10),
                Center(
                  child: Text(
                    'Before that: ${_history.skip(1).join(', ')}',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.white.withValues(alpha: 0.45),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _rolling ? null : _roll,
                  child: Text(
                    _result == null ? 'ROLL ${_die.label}' : 'ROLL AGAIN',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DieButton extends StatelessWidget {
  const _DieButton({
    required this.die,
    required this.selected,
    required this.onTap,
  });

  final DieType die;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: selected ? PodWiseColors.accent : PodWiseColors.surfaceHigh,
    borderRadius: BorderRadius.circular(12),
    child: InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Center(
          child: Text(
            die.label,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: selected ? Colors.black : Colors.white70,
            ),
          ),
        ),
      ),
    ),
  );
}

class _Result extends StatelessWidget {
  const _Result({
    required this.value,
    required this.rolling,
    required this.die,
  });

  final int? value;
  final bool rolling;
  final DieType die;

  @override
  Widget build(BuildContext context) {
    // A fixed box, so the sheet does not change height between a blank slate,
    // a tumbling number and a result.
    return SizedBox(
      height: 74,
      child: Center(
        child: value == null
            ? Text(
                'Nothing rolled yet',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.white.withValues(alpha: 0.4),
                ),
              )
            : Text(
                '$value',
                style: TextStyle(
                  fontSize: 62,
                  height: 1,
                  fontWeight: FontWeight.w700,
                  // Dimmed while tumbling so it is obvious the number is not
                  // the answer yet.
                  color: rolling
                      ? Colors.white.withValues(alpha: 0.35)
                      : PodWiseColors.accent,
                ),
              ),
      ),
    );
  }
}
