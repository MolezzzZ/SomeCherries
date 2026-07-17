import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app/settings.dart';

/// Three crayon-textured warning lamps for plate usage, rolling token speed,
/// and today's total cost.
class UsageWarningLights extends StatefulWidget {
  final double currentPlates;
  final int recentTokens;
  final double dailyCostUsd;
  final UsageAlertConfig config;
  final double scale;

  const UsageWarningLights({
    super.key,
    required this.currentPlates,
    required this.recentTokens,
    required this.dailyCostUsd,
    required this.config,
    this.scale = 1,
  });

  @override
  State<UsageWarningLights> createState() => _UsageWarningLightsState();
}

class _UsageWarningLightsState extends State<UsageWarningLights>
    with SingleTickerProviderStateMixin {
  late final AnimationController _breath = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  );

  bool get _hasAlert =>
      widget.recentTokens >= widget.config.halfHourTokenLimit ||
      widget.dailyCostUsd >= widget.config.dailyCostLimitUsd;

  @override
  void initState() {
    super.initState();
    _syncBreathing();
  }

  @override
  void didUpdateWidget(covariant UsageWarningLights oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncBreathing();
  }

  void _syncBreathing() {
    if (_hasAlert) {
      if (!_breath.isAnimating) _breath.repeat(reverse: true);
    } else {
      _breath.stop();
      _breath.value = 0;
    }
  }

  @override
  void dispose() {
    _breath.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final height = 14.0 * widget.scale;
    final current = _ratio(widget.currentPlates, widget.config.maxPlates);
    final speed = _ratio(
      widget.recentTokens.toDouble(),
      widget.config.halfHourTokenLimit.toDouble(),
    );
    final daily = _ratio(widget.dailyCostUsd, widget.config.dailyCostLimitUsd);

    return SizedBox(
      height: height,
      child: AnimatedBuilder(
        animation: _breath,
        builder: (context, _) {
          final breath = Curves.easeInOutSine.transform(_breath.value);
          return Align(
            alignment: Alignment.center,
            child: FractionallySizedBox(
              widthFactor: 0.92,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  return Stack(
                    alignment: Alignment.center,
                    clipBehavior: Clip.none,
                    children: [
                      Positioned(
                        left: width * 0.02,
                        top: 0,
                        bottom: 0,
                        width: width * 0.40,
                        child: _Lamp(
                          progress: current,
                          palette: _LampPalette.consumption,
                          pulse: 0,
                          semanticLabel:
                              'Current usage ${widget.currentPlates.toStringAsFixed(1)} plates',
                        ),
                      ),
                      Positioned(
                        left: width * 0.47,
                        top: 0,
                        bottom: 0,
                        width: width * 0.23,
                        child: _Lamp(
                          progress: speed,
                          palette: _LampPalette.speed,
                          isAlert: speed >= 1,
                          pulse: speed >= 1 ? breath : 0,
                          semanticLabel:
                              'Last 30 minutes ${widget.recentTokens} tokens',
                        ),
                      ),
                      Positioned(
                        right: width * 0.02,
                        top: 0,
                        bottom: 0,
                        width: width * 0.23,
                        child: _Lamp(
                          progress: daily,
                          palette: _LampPalette.daily,
                          isAlert: daily >= 1,
                          pulse: daily >= 1 ? breath : 0,
                          semanticLabel:
                              'Today ${widget.dailyCostUsd.toStringAsFixed(2)} dollars',
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }

  static double _ratio(double value, double limit) =>
      limit <= 0 ? 0 : (value / limit).clamp(0.0, 1.0).toDouble();
}

enum _LampPalette { consumption, speed, daily }

class _Lamp extends StatelessWidget {
  final double progress;
  final _LampPalette palette;
  final bool isAlert;
  final double pulse;
  final String semanticLabel;

  const _Lamp({
    required this.progress,
    required this.palette,
    this.isAlert = false,
    required this.pulse,
    required this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel,
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: progress),
        duration: const Duration(milliseconds: 900),
        curve: Curves.easeOutCubic,
        builder: (context, value, _) => CustomPaint(
          painter: _LampPainter(
            progress: value,
            palette: palette,
            isAlert: isAlert,
            pulse: pulse,
          ),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _LampPainter extends CustomPainter {
  final double progress;
  final _LampPalette palette;
  final bool isAlert;
  final double pulse;

  const _LampPainter({
    required this.progress,
    required this.palette,
    required this.isAlert,
    required this.pulse,
  });

  static const _consumption = [
    Color(0xFFF5B94F),
    Color(0xFFE05C43),
    Color(0xFFA15376),
    Color(0xFF3D668F),
    Color(0xFF142A42),
  ];
  static const _speed = [
    Color(0xFFFFE69A),
    Color(0xFFFFC34F),
    Color(0xFFF57B32),
    Color(0xFFE73D32),
    Color(0xFFD41436),
  ];
  static const _daily = [
    Color(0xFFD9D5D4),
    Color(0xFFC9A7BC),
    Color(0xFFA9689B),
    Color(0xFF74407E),
    Color(0xFF351542),
  ];

  List<Color> get _colors => switch (palette) {
        _LampPalette.consumption => _consumption,
        _LampPalette.speed => _speed,
        _LampPalette.daily => _daily,
      };

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final t = progress.clamp(0.0, 1.0);
    final paletteBase = _paletteColor(_colors, t);
    final alertDark = palette == _LampPalette.speed
        ? const Color(0xFFA90E30)
        : const Color(0xFF351542);
    final alertBright = palette == _LampPalette.speed
        ? const Color(0xFFF13A4D)
        : const Color(0xFF9850B8);
    final base = isAlert
        ? Color.lerp(alertDark, alertBright, 0.22 + pulse * 0.64)!
        : paletteBase;
    var accent = isAlert
        ? Color.lerp(base, alertBright, 0.22)!
        : _paletteColor(_colors, (t + 0.17).clamp(0.0, 1.0));
    if (!isAlert && palette == _LampPalette.consumption && t > 0.68) {
      final cold = ((t - 0.68) / 0.32).clamp(0.0, 1.0);
      accent = Color.lerp(accent, const Color(0xFF557E9E), 0.35 + cold * 0.45)!;
    }
    final glowStrength = isAlert ? 0.28 + pulse * 0.42 : 0.06;

    final housing =
        Rect.fromLTWH(0, size.height * 0.22, size.width, size.height * 0.56);
    final housingRadius = Radius.circular(size.height * 0.14);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          housing.inflate(size.height * (isAlert ? 0.12 : 0.05)),
          housingRadius),
      Paint()
        ..color = base.withValues(alpha: glowStrength)
        ..maskFilter = MaskFilter.blur(
          BlurStyle.normal,
          size.height * (isAlert ? 0.21 : 0.08),
        ),
    );
    if (isAlert) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          housing.inflate(size.height * 0.025),
          housingRadius,
        ),
        Paint()
          ..color = alertBright.withValues(alpha: 0.12 + pulse * 0.18)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, size.height * 0.08),
      );
    }

    // A subtly uneven body keeps the tiny lamp in the same hand-drawn world as
    // the cherries without making the silhouette look damaged or noisy.
    final ink = Color.lerp(const Color(0xFF35242A), base, 0.14)!;
    final housingPath = _sketchRoundedRect(
      housing,
      size.height * 0.13,
    );
    canvas.drawPath(
      housingPath,
      Paint()..color = ink.withValues(alpha: 0.90),
    );
    final basePaint = Paint()
      ..color = ink.withValues(alpha: 0.78)
      ..strokeWidth = math.max(0.48, size.height * 0.035)
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(size.width * 0.08, size.height * 0.82),
      Offset(size.width * 0.92, size.height * 0.81),
      basePaint,
    );

    final lens = Rect.fromLTWH(
      size.height * 0.065,
      size.height * 0.265,
      size.width - size.height * 0.13,
      size.height * 0.47,
    );
    final lensPath = _sketchRoundedRect(
      lens,
      size.height * 0.09,
    );
    canvas.drawPath(
      lensPath,
      Paint()
        ..shader = LinearGradient(
          colors: [
            Color.lerp(base, accent, 0.35)!,
            base,
            accent,
            Color.lerp(
              accent,
              const Color(0xFF24111E),
              isAlert ? 0.10 : 0.20,
            )!,
          ],
          stops: const [0, 0.32, 0.72, 1],
        ).createShader(lens),
    );

    canvas.save();
    canvas.clipPath(lensPath);
    _drawCrayonBands(canvas, lens, base, accent);
    _drawCrayonStrokes(canvas, lens, base);
    final highlight = palette == _LampPalette.consumption && t > 0.68
        ? const Color(0xFF557E9E)
        : Color.lerp(accent, Colors.white, 0.40)!;
    canvas.drawLine(
      Offset(lens.left + lens.width * 0.07, lens.top + lens.height * 0.20),
      Offset(lens.left + lens.width * 0.70, lens.top + lens.height * 0.17),
      Paint()
        ..color = highlight.withValues(
          alpha: (isAlert ? 0.20 : 0.15) + pulse * 0.16,
        )
        ..strokeWidth = math.max(0.55, lens.height * 0.09)
        ..strokeCap = StrokeCap.round,
    );
    canvas.restore();

    final outline = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(0.42, size.height * 0.025)
      ..color = ink.withValues(alpha: 0.70);
    canvas.drawPath(lensPath, outline);
    canvas.drawPath(
      housingPath.shift(Offset(size.height * 0.012, -size.height * 0.010)),
      outline..color = ink.withValues(alpha: 0.40),
    );
  }

  void _drawCrayonBands(
    Canvas canvas,
    Rect lens,
    Color base,
    Color accent,
  ) {
    const widths = [0.27, 0.21, 0.29, 0.23];
    var x = lens.left;
    for (var i = 0; i < widths.length; i++) {
      final width = lens.width * widths[i];
      final color = i.isEven ? base : accent;
      canvas.drawRect(
        Rect.fromLTWH(x - 0.5, lens.top, width + 1, lens.height),
        Paint()..color = color.withValues(alpha: i.isEven ? 0.13 : 0.23),
      );
      x += width;
    }
  }

  void _drawCrayonStrokes(Canvas canvas, Rect lens, Color base) {
    for (var i = 0; i < 4; i++) {
      final y = lens.top + lens.height * (0.20 + i * 0.19);
      final path = Path()
        ..moveTo(lens.left - lens.width * 0.03, y)
        ..quadraticBezierTo(
          lens.left + lens.width * 0.48,
          y - lens.height * (i.isEven ? 0.11 : 0.04),
          lens.right + lens.width * 0.03,
          y + lens.height * 0.035,
        );
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(0.68, lens.height * 0.10)
          ..strokeCap = StrokeCap.round
          ..color = (i.isEven ? Colors.white : const Color(0xFF38202C))
              .withValues(alpha: i.isEven ? 0.085 : 0.105),
      );
    }
    canvas.drawLine(
      Offset(lens.left + lens.width * 0.02, lens.bottom - lens.height * 0.08),
      Offset(lens.right - lens.width * 0.05, lens.top + lens.height * 0.20),
      Paint()
        ..color = base.withValues(alpha: 0.16)
        ..strokeWidth = math.max(0.72, lens.height * 0.08)
        ..strokeCap = StrokeCap.round,
    );
  }

  Path _sketchRoundedRect(Rect rect, double radius) {
    final wobble = math.min(0.34, rect.height * 0.045);
    return Path()
      ..moveTo(rect.left + radius * 0.92, rect.top + wobble)
      ..lineTo(rect.right - radius * 1.05, rect.top)
      ..quadraticBezierTo(
        rect.right - wobble * 0.15,
        rect.top + radius * 0.10,
        rect.right,
        rect.top + radius * 0.96,
      )
      ..lineTo(rect.right - wobble, rect.bottom - radius * 0.88)
      ..quadraticBezierTo(
        rect.right - radius * 0.12,
        rect.bottom,
        rect.right - radius,
        rect.bottom - wobble * 0.15,
      )
      ..lineTo(rect.left + radius * 1.08, rect.bottom)
      ..quadraticBezierTo(
        rect.left + wobble * 0.15,
        rect.bottom - radius * 0.08,
        rect.left,
        rect.bottom - radius,
      )
      ..lineTo(rect.left + wobble, rect.top + radius * 0.90)
      ..quadraticBezierTo(
        rect.left + radius * 0.10,
        rect.top + wobble,
        rect.left + radius * 0.92,
        rect.top + wobble,
      )
      ..close();
  }

  static Color _paletteColor(List<Color> colors, double t) {
    if (t <= 0) return colors.first;
    if (t >= 1) return colors.last;
    final scaled = t * (colors.length - 1);
    final index = scaled.floor();
    return Color.lerp(colors[index], colors[index + 1], scaled - index)!;
  }

  @override
  bool shouldRepaint(covariant _LampPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.palette != palette ||
      oldDelegate.isAlert != isAlert ||
      oldDelegate.pulse != pulse;
}
