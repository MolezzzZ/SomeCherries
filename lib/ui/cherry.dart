import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../domain/cherry_state.dart';

/// A small pair of cherries optimized for tiny desktop-overlay rendering.
///
/// At 50-70px, believable "crayon" comes mostly from strong silhouettes,
/// saturated color, rough strokes, and readable bite shapes. This painter keeps
/// the geometry simple on purpose so the fruit does not turn into pixel mush.
class Cherry extends StatelessWidget {
  final CherryStatus status;
  final double bite;
  final double size;

  const Cherry({
    super.key,
    required this.status,
    this.bite = 0,
    this.size = 28,
  });

  double get _targetEaten {
    switch (status) {
      case CherryStatus.full:
        return 0;
      case CherryStatus.eating:
        return bite.clamp(0.06, 0.94);
      case CherryStatus.eaten:
        return 1;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size * 1.234,
      child: CustomPaint(painter: _CherryPainter(eaten: _targetEaten)),
    );
  }
}

class _CherryPainter extends CustomPainter {
  final double eaten;

  const _CherryPainter({required this.eaten});

  static const _redHot = Color(0xFFFF102A);
  static const _redMid = Color(0xFFE40022);
  static const _redDeep = Color(0xFF980016);
  static const _redInk = Color(0xFF6D0614);
  static const _redWax = Color(0xFFFF6C76);
  static const _pinkWax = Color(0xFFFFB9BE);

  static const _leafLight = Color(0xFFB9EA4D);
  static const _leafMid = Color(0xFF65B72D);
  static const _leafInk = Color(0xFF28751F);
  static const _stemDark = Color(0xFF3E7E20);
  static const _stemLight = Color(0xFF86D64A);
  static const _brown = Color(0xFF8A4A16);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final r = w * 0.305;

    final left = Offset(w * 0.35, h * 0.705);
    final right = Offset(w * 0.66, h * 0.685);
    final fork = Offset(w * 0.53, h * 0.225);
    final top = Offset(w * 0.56, h * 0.085);

    final ghost = eaten >= 0.985;
    final fruitAlpha = ghost ? 0.0 : 1.0;
    final stemAlpha = ghost ? 0.82 : 1.0;

    if (!ghost) _drawShadow(canvas, w, h, eaten);

    _drawLeaf(canvas, fork, Offset(w * 0.22, h * 0.118), alpha: stemAlpha);
    _drawLeaf(canvas, fork, Offset(w * 0.78, h * 0.132), alpha: stemAlpha);
    _drawStem(canvas, fork, Offset(left.dx, left.dy - r * 0.86),
        Offset(w * 0.41, h * 0.42), stemAlpha);
    _drawStem(canvas, fork, Offset(right.dx, right.dy - r * 0.86),
        Offset(w * 0.66, h * 0.40), stemAlpha);
    _drawTop(canvas, top, fork, stemAlpha);

    _drawCherry(
      canvas,
      right,
      r,
      side: 1,
      progress: (eaten / 0.58).clamp(0.0, 1.0),
      alpha: fruitAlpha,
      ghost: ghost,
    );
    _drawCherry(
      canvas,
      left,
      r,
      side: -1,
      progress: ((eaten - 0.36) / 0.64).clamp(0.0, 1.0),
      alpha: fruitAlpha,
      ghost: ghost,
    );
  }

  void _drawShadow(Canvas canvas, double w, double h, double t) {
    final alpha = (0.16 * (1 - t * 0.75)).clamp(0.0, 0.16).toDouble();
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.51, h * 0.94),
        width: w * 0.78,
        height: h * 0.095,
      ),
      Paint()
        ..color = Colors.black.withValues(alpha: alpha)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 0.035),
    );
  }

  void _drawLeaf(
    Canvas canvas,
    Offset base,
    Offset tip, {
    required double alpha,
  }) {
    final vector = tip - base;
    final length = vector.distance;
    final unit = vector / length;
    final normal = Offset(-unit.dy, unit.dx);
    final leafBase = base + unit * (length * 0.10);
    final leafTip = tip - unit * (length * 0.04);
    final width = length * 0.25;
    final side = tip.dx < base.dx ? -1.0 : 1.0;
    final path = Path()
      ..moveTo(leafBase.dx, leafBase.dy)
      ..cubicTo(
        (base + unit * (length * 0.28) + normal * width).dx,
        (base + unit * (length * 0.28) + normal * width).dy,
        (base + unit * (length * 0.70) + normal * (width * 0.82)).dx,
        (base + unit * (length * 0.70) + normal * (width * 0.82)).dy,
        (leafTip + normal * (width * 0.12)).dx,
        (leafTip + normal * (width * 0.12)).dy,
      )
      ..quadraticBezierTo(
        tip.dx,
        tip.dy,
        (leafTip - normal * (width * 0.12)).dx,
        (leafTip - normal * (width * 0.12)).dy,
      )
      ..cubicTo(
        (base + unit * (length * 0.70) - normal * (width * 0.78)).dx,
        (base + unit * (length * 0.70) - normal * (width * 0.78)).dy,
        (base + unit * (length * 0.26) - normal * (width * 0.70)).dx,
        (base + unit * (length * 0.26) - normal * (width * 0.70)).dy,
        leafBase.dx,
        leafBase.dy,
      )
      ..close();
    final bounds = path.getBounds();

    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _leafLight.withValues(alpha: alpha),
            _leafMid.withValues(alpha: alpha),
          ],
        ).createShader(bounds),
    );
    _drawWaxLines(
        canvas, path, _leafLight.withValues(alpha: 0.33 * alpha), bounds, 6,
        slope: -0.34 * side);
    _strokeSketch(canvas, path, _leafInk.withValues(alpha: alpha), 2.0,
        passes: 2);

    final vein = Path()
      ..moveTo(leafBase.dx, leafBase.dy)
      ..quadraticBezierTo(
        (leafBase.dx + leafTip.dx) / 2,
        (leafBase.dy + leafTip.dy) / 2 - length * 0.06,
        leafTip.dx,
        leafTip.dy,
      );
    _strokeSketch(canvas, vein, _leafInk.withValues(alpha: 0.72 * alpha), 1.15);

    for (final t in const [0.36, 0.56, 0.74]) {
      final start = Offset.lerp(leafBase, leafTip, t)!;
      final rib = Path()
        ..moveTo(start.dx, start.dy)
        ..lineTo(
          (start - normal * width * (0.20 - t * 0.08)).dx,
          (start - normal * width * (0.20 - t * 0.08)).dy,
        );
      _strokeSketch(
        canvas,
        rib,
        _leafInk.withValues(alpha: 0.38 * alpha),
        0.72,
      );
    }
  }

  void _drawStem(Canvas canvas, Offset a, Offset b, Offset c, double alpha) {
    final path = Path()
      ..moveTo(a.dx, a.dy)
      ..quadraticBezierTo(c.dx, c.dy, b.dx, b.dy);
    _strokeSketch(canvas, path, _stemDark.withValues(alpha: alpha), 3.35,
        passes: 2);
    _strokeSketch(
      canvas,
      path.shift(const Offset(-0.65, -0.45)),
      _stemLight.withValues(alpha: 0.66 * alpha),
      1.25,
    );
  }

  void _drawTop(Canvas canvas, Offset top, Offset fork, double alpha) {
    final path = Path()
      ..moveTo(fork.dx, fork.dy)
      ..quadraticBezierTo(top.dx + 1.5, (top.dy + fork.dy) / 2, top.dx, top.dy);
    _strokeSketch(canvas, path, _brown.withValues(alpha: alpha), 4.0,
        passes: 2);
    _strokeSketch(
      canvas,
      path.shift(const Offset(-0.8, 0)),
      const Color(0xFFD18936).withValues(alpha: 0.55 * alpha),
      1.5,
    );
  }

  void _drawCherry(
    Canvas canvas,
    Offset center,
    double r, {
    required int side,
    required double progress,
    required double alpha,
    required bool ghost,
  }) {
    final fruit = _fruitPath(center, r);
    if (ghost || progress >= 0.90) {
      _drawEatenOutline(canvas, fruit, r);
      return;
    }

    final remainingFruit = _nibbledFruitPath(
      fruit,
      center,
      r,
      side: side,
      progress: progress,
    );

    final fadeNearEmpty = ((progress - 0.78) / 0.12).clamp(0.0, 1.0) * 0.45;
    final visibleAlpha = alpha * (1 - fadeNearEmpty);
    final bounds = fruit.getBounds().inflate(r * 0.16);
    canvas.saveLayer(bounds, Paint());
    canvas.drawPath(
      remainingFruit,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.38, -0.45),
          radius: 1.05,
          colors: [
            _redWax.withValues(alpha: visibleAlpha),
            _redHot.withValues(alpha: visibleAlpha),
            _redMid.withValues(alpha: visibleAlpha),
            _redDeep.withValues(alpha: visibleAlpha),
          ],
          stops: const [0.0, 0.28, 0.67, 1.0],
        ).createShader(bounds),
    );

    _drawWaxLines(
      canvas,
      remainingFruit,
      _pinkWax.withValues(alpha: 0.28 * visibleAlpha),
      bounds,
      8,
      slope: -0.38,
    );
    _drawWaxLines(
      canvas,
      remainingFruit,
      _redInk.withValues(alpha: 0.18 * visibleAlpha),
      bounds,
      6,
      slope: -0.30,
      yOffset: r * 0.18,
    );
    canvas.save();
    canvas.clipPath(remainingFruit);
    _drawHighlight(canvas, center, r, visibleAlpha);
    canvas.restore();
    canvas.restore();

    _strokeSketch(
      canvas,
      fruit,
      _redInk.withValues(alpha: 0.96),
      2.45,
      passes: 2,
    );
    _strokeSketch(
      canvas,
      fruit.shift(Offset(-r * 0.03, -r * 0.035)),
      _redWax.withValues(alpha: 0.36),
      0.9,
    );
    if (progress > 0.005) {
      _drawBiteFront(canvas, fruit, center, r, side, progress);
    }
  }

  Path _fruitPath(Offset c, double r) {
    return Path()
      ..moveTo(c.dx - r * 0.03, c.dy - r * 0.92)
      ..cubicTo(c.dx - r * 0.68, c.dy - r * 1.05, c.dx - r * 1.04,
          c.dy - r * 0.45, c.dx - r * 0.96, c.dy + r * 0.18)
      ..cubicTo(c.dx - r * 0.86, c.dy + r * 0.85, c.dx - r * 0.16,
          c.dy + r * 1.08, c.dx + r * 0.08, c.dy + r * 0.92)
      ..cubicTo(c.dx + r * 0.55, c.dy + r * 1.11, c.dx + r * 1.02,
          c.dy + r * 0.55, c.dx + r * 0.93, c.dy - r * 0.10)
      ..cubicTo(c.dx + r * 0.84, c.dy - r * 0.74, c.dx + r * 0.34,
          c.dy - r * 1.08, c.dx + r * 0.06, c.dy - r * 0.86)
      ..quadraticBezierTo(
          c.dx + r * 0.02, c.dy - r * 0.77, c.dx - r * 0.03, c.dy - r * 0.92)
      ..close();
  }

  void _drawHighlight(Canvas canvas, Offset c, double r, double alpha) {
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(c.dx - r * 0.39, c.dy - r * 0.33),
        width: r * 0.42,
        height: r * 0.66,
      ),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.74 * alpha)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.035),
    );
    canvas.drawCircle(
      Offset(c.dx - r * 0.52, c.dy + r * 0.06),
      r * 0.115,
      Paint()..color = Colors.white.withValues(alpha: 0.68 * alpha),
    );
    canvas.drawCircle(
      Offset(c.dx - r * 0.47, c.dy + r * 0.34),
      r * 0.080,
      Paint()..color = Colors.white.withValues(alpha: 0.58 * alpha),
    );
  }

  Path _nibbledFruitPath(
    Path fruit,
    Offset center,
    double r, {
    required int side,
    required double progress,
  }) {
    final mask = _biteMask(center, r, side, progress);
    return Path.combine(PathOperation.difference, fruit, mask);
  }

  Path _biteMask(Offset center, double r, int side, double progress) {
    final outsideX = center.dx + side * r * 1.45;
    final baseX =
        center.dx + side * r * (1.16 - progress.clamp(0.0, 1.0) * 2.32);
    final top = center.dy - r * 1.20;
    final bottom = center.dy + r * 1.20;
    final mask = Path()
      ..moveTo(outsideX, top)
      ..lineTo(baseX, top);
    _traceBiteFront(mask, center, r, side, progress);
    mask
      ..lineTo(outsideX, bottom)
      ..close();
    return mask;
  }

  Path _biteFront(Offset center, double r, int side, double progress) {
    final path = Path();
    _traceBiteFront(path, center, r, side, progress, moveToStart: true);
    return path;
  }

  void _traceBiteFront(
    Path path,
    Offset center,
    double r,
    int side,
    double progress, {
    bool moveToStart = false,
  }) {
    final t = progress.clamp(0.0, 1.0);
    final baseX = center.dx + side * r * (1.16 - t * 2.32);
    final biteDepth =
        r * 0.25 * Curves.easeOutCubic.transform((t * 9).clamp(0.0, 1.0));
    final top = center.dy - r * 1.20;
    if (moveToStart) path.moveTo(baseX, top);
    path
      ..quadraticBezierTo(
        baseX - side * biteDepth * 0.82,
        center.dy - r * 0.84,
        baseX,
        center.dy - r * 0.48,
      )
      ..quadraticBezierTo(
        baseX - side * biteDepth * 0.62,
        center.dy - r * 0.20,
        baseX,
        center.dy + r * 0.08,
      )
      ..quadraticBezierTo(
        baseX - side * biteDepth,
        center.dy + r * 0.39,
        baseX,
        center.dy + r * 0.70,
      )
      ..quadraticBezierTo(
        baseX - side * biteDepth * 0.68,
        center.dy + r * 0.95,
        baseX,
        center.dy + r * 1.20,
      );
  }

  void _drawBiteFront(
    Canvas canvas,
    Path fruit,
    Offset center,
    double r,
    int side,
    double progress,
  ) {
    canvas.save();
    canvas.clipPath(fruit);
    final front = _biteFront(center, r, side, progress);
    _strokeSketch(
      canvas,
      front,
      _redInk.withValues(alpha: 0.88),
      math.max(1.2, r * 0.10),
      passes: 2,
    );
    _strokeSketch(
      canvas,
      front.shift(Offset(side * r * 0.055, 0)),
      _redWax.withValues(alpha: 0.48),
      math.max(0.75, r * 0.045),
    );
    canvas.restore();
  }

  void _drawEatenOutline(Canvas canvas, Path fruit, double r) {
    _dashedPath(
      canvas,
      fruit,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.45, r * 0.115)
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = _redInk.withValues(alpha: 0.78),
      dash: math.max(2.0, r * 0.24),
      gap: math.max(1.45, r * 0.17),
    );
    _dashedPath(
      canvas,
      fruit.shift(Offset(-r * 0.025, -r * 0.02)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(0.75, r * 0.045)
        ..strokeCap = StrokeCap.round
        ..color = _redWax.withValues(alpha: 0.42),
      dash: math.max(1.8, r * 0.18),
      gap: math.max(1.6, r * 0.20),
    );
  }

  void _drawWaxLines(
    Canvas canvas,
    Path clip,
    Color color,
    Rect bounds,
    int count, {
    required double slope,
    double yOffset = 0,
  }) {
    canvas.save();
    canvas.clipPath(clip);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = math.max(0.65, bounds.width * 0.035)
      ..color = color;
    for (var i = 0; i < count; i++) {
      final y = bounds.top + yOffset + bounds.height * (0.12 + i / (count + 1));
      final path = Path()
        ..moveTo(bounds.left + bounds.width * 0.10, y)
        ..quadraticBezierTo(
          bounds.center.dx,
          y + bounds.width * slope * 0.20,
          bounds.right - bounds.width * 0.08,
          y + bounds.width * slope,
        );
      canvas.drawPath(path, paint);
    }
    canvas.restore();
  }

  void _strokeSketch(
    Canvas canvas,
    Path path,
    Color color,
    double width, {
    int passes = 1,
  }) {
    for (var i = 0; i < passes; i++) {
      final offset =
          i == 0 ? Offset.zero : Offset(0.55 - i * 0.45, -0.35 + i * 0.25);
      canvas.drawPath(
        path.shift(offset),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = width * (1 - i * 0.12)
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = color.withValues(alpha: color.a * (1 - i * 0.18)),
      );
    }
  }

  void _dashedPath(
    Canvas canvas,
    Path path,
    Paint paint, {
    required double dash,
    required double gap,
  }) {
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final end = math.min(distance + dash, metric.length);
        canvas.drawPath(metric.extractPath(distance, end), paint);
        distance = end + gap;
      }
    }
  }

  @override
  bool shouldRepaint(_CherryPainter old) => old.eaten != eaten;
}
