import 'package:flutter/material.dart';

import '../models/training_summary.dart';

class AnimatedSummaryTotals extends StatefulWidget {
  final TrainingSummary summary;
  final bool isSaved;

  const AnimatedSummaryTotals({
    super.key,
    required this.summary,
    required this.isSaved,
  });

  @override
  State<AnimatedSummaryTotals> createState() => _AnimatedSummaryTotalsState();
}

class _AnimatedSummaryTotalsState extends State<AnimatedSummaryTotals>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<Offset> _position;

  bool _reduceMotion = false;
  bool _started = false;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );

    _opacity = _controller.drive(CurveTween(curve: Curves.easeOut));

    _position = _controller.drive(
      Tween<Offset>(
        begin: const Offset(0, 0.08),
        end: Offset.zero,
      ).chain(CurveTween(curve: Curves.easeOutCubic)),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    _reduceMotion = MediaQuery.disableAnimationsOf(context);

    if (_reduceMotion) {
      _controller.value = 1;
      _started = true;
    } else if (!_started) {
      _started = true;
      _controller.forward();
    }
  }

  @override
  void didUpdateWidget(covariant AnimatedSummaryTotals oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (!identical(oldWidget.summary, widget.summary)) {
      if (_reduceMotion) {
        _controller.value = 1;
      } else {
        _controller.forward(from: 0);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final summary = widget.summary;

    return AnimatedContainer(
      duration: _reduceMotion
          ? Duration.zero
          : const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: widget.isSaved
            ? colors.secondaryContainer
            : colors.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: FadeTransition(
        opacity: _opacity,
        child: SlideTransition(
          position: _position,
          child: DefaultTextStyle.merge(
            style: TextStyle(
              color: widget.isSaved
                  ? colors.onSecondaryContainer
                  : colors.onPrimaryContainer,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  widget.isSaved ? 'Saved file snapshot' : 'Generated snapshot',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text('Completed sessions: ${summary.completedSessions}'),
                Text('Unfinished sessions: ${summary.unfinishedSessions}'),
                Text('Total sets: ${summary.totalSets}'),
                Text('Total repetitions: ${summary.totalRepetitions}'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
