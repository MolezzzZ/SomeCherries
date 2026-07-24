import 'package:flutter/widgets.dart';

import 'settings.dart';

/// Base cherry cell size before user scale. The cell renders a detailed pair
/// sprite, so it needs to be reasonably large or the art turns mushy.
const double kBaseCherrySize = 54;
const double kCherrySpacing = 4;
const double kOuterPadding = 12;
const double kWarningLightsHeight = 14;
const double kWarningLightsGap = 4;

/// A cherry cell renders a *pair* sprite (286 × 353), so it's taller than the
/// base size. These must match the SizedBox in [Cherry.build] and the sprite's
/// aspect ratio (353 / 286 ≈ 1.234) so the art is never stretched.
const double kCellWidthFactor = 1.0;
const double kCellHeightFactor = 1.234;

/// Base vertical room reserved above the plate for the hover tooltip.
///
/// The card can contain four model rows. Its maximum normal-text height is
/// about 358 logical pixels, so the old 320-pixel reserve clipped its rounded
/// top edge. Keep extra room for the shadow and small font-metric differences.
const double kTooltipReserve = 380;
const double kMinWidth = 250;

/// Text accessibility scaling changes Flutter layout in logical pixels,
/// independently of the monitor's DPI. Scale the transparent reserve with it
/// so a larger card still remains inside the native window.
double tooltipReserveFor(double textScaleFactor) {
  final safeScale = textScaleFactor.isFinite
      ? textScaleFactor.clamp(1.0, 3.0).toDouble()
      : 1.0;
  return kTooltipReserve * safeScale;
}

Size gridPixelSize(AppSettings s) {
  final size = kBaseCherrySize * s.scale;
  final cellW = size * kCellWidthFactor;
  final cellH = size * kCellHeightFactor;
  final w = s.cherry.cols * cellW + (s.cherry.cols - 1) * kCherrySpacing;
  final h = s.cherry.rows * cellH + (s.cherry.rows - 1) * kCherrySpacing;
  return Size(w, h);
}

Size overlayContentPixelSize(AppSettings s) {
  final grid = gridPixelSize(s);
  return Size(
    grid.width,
    grid.height + (kWarningLightsHeight + kWarningLightsGap) * s.scale,
  );
}

/// Normal overlay window: only the cherry plate exists, so transparent space
/// above it does not intercept clicks intended for applications underneath.
Size computeWindowSize(AppSettings s) {
  final content = overlayContentPixelSize(s);
  final w =
      (content.width + kOuterPadding * 2).clamp(kMinWidth, 1200).toDouble();
  final h = content.height + kOuterPadding * 2;
  return Size(w, h);
}

/// Temporary expanded window while hovering the plate, giving the tooltip room
/// to render above the cherries. The top edge is moved up by the value returned
/// by [tooltipReserveFor], keeping the plate fixed on screen.
Size computeTooltipWindowSize(
  AppSettings s, {
  double textScaleFactor = 1.0,
}) {
  final base = computeWindowSize(s);
  return Size(
    base.width,
    base.height + tooltipReserveFor(textScaleFactor),
  );
}
