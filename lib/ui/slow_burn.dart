import 'dart:math' as math;

import 'package:flutter/material.dart';

typedef SlowBurnBuilder = Widget Function(
  BuildContext context,
  double displayedCost,
);

/// Smooths newly detected usage into one continuous, slow-moving burn.
///
/// The first snapshot is shown immediately. Later cost increases animate
/// linearly, and a new increase retargets from the exact current position so
/// consecutive polling updates extend the same motion instead of restarting it.
class SlowBurn extends StatefulWidget {
  final double? targetCost;
  final int? totalTokens;
  final double dollarsPerCherry;
  final int pollSeconds;
  final SlowBurnBuilder builder;

  const SlowBurn({
    super.key,
    required this.targetCost,
    required this.totalTokens,
    required this.dollarsPerCherry,
    required this.pollSeconds,
    required this.builder,
  });

  @override
  State<SlowBurn> createState() => _SlowBurnState();
}

class _SlowBurnState extends State<SlowBurn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late double _startCost;
  late double _endCost;

  double get _displayedCost =>
      _startCost + (_endCost - _startCost) * _controller.value;

  @override
  void initState() {
    super.initState();
    _endCost = math.max(0.0, widget.targetCost ?? 0);
    _startCost = _endCost;
    _controller = AnimationController(vsync: this, value: 1);
  }

  @override
  void didUpdateWidget(SlowBurn oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextCost = widget.targetCost;
    if (nextCost == null) return;

    final target = math.max(0.0, nextCost);
    final hasBaseline = oldWidget.targetCost != null;
    final tokenCountIncreased = widget.totalTokens != null &&
        oldWidget.totalTokens != null &&
        widget.totalTokens! > oldWidget.totalTokens!;

    if (!hasBaseline || target < _endCost) {
      _snapTo(target);
      return;
    }

    if (tokenCountIncreased && target > _endCost) {
      _animateTo(target);
    }
  }

  void _snapTo(double target) {
    _controller.stop();
    _startCost = target;
    _endCost = target;
    _controller.value = 1;
  }

  void _animateTo(double target) {
    final current = _displayedCost;
    _controller.stop();
    _startCost = current;
    _endCost = target;
    _controller.duration = slowBurnDuration(
      remainingCost: target - current,
      dollarsPerCherry: widget.dollarsPerCherry,
      pollSeconds: widget.pollSeconds,
    );
    _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => widget.builder(context, _displayedCost),
    );
  }
}

@visibleForTesting
Duration slowBurnDuration({
  required double remainingCost,
  required double dollarsPerCherry,
  required int pollSeconds,
}) {
  final pollingOverlapMs = (pollSeconds * 1400).clamp(4200, 8000).toInt();
  final cherries = dollarsPerCherry <= 0
      ? 0.0
      : math.max(0.0, remainingCost) / dollarsPerCherry;
  final progressMs = (cherries * 2200).round();
  final durationMs =
      math.max(pollingOverlapMs, progressMs).clamp(4200, 12000).toInt();
  return Duration(milliseconds: durationMs);
}
