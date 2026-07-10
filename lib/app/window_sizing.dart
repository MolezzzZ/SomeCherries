import 'package:flutter/widgets.dart';

import 'settings.dart';

/// Base cherry cell size before user scale. The cell renders a detailed pair
/// sprite, so it needs to be reasonably large or the art turns mushy.
const double kBaseCherrySize = 54;
const double kCherrySpacing = 4;
const double kOuterPadding = 12;

/// A cherry cell renders a *pair* sprite (286 × 353), so it's taller than the
/// base size. These must match the SizedBox in [Cherry.build] and the sprite's
/// aspect ratio (353 / 286 ≈ 1.234) so the art is never stretched.
const double kCellWidthFactor = 1.0;
const double kCellHeightFactor = 1.234;

/// Vertical room reserved above the plate so the hover tooltip isn't clipped
/// by the (transparent) window bounds.
const double kTooltipReserve = 320;
const double kMinWidth = 250;

Size gridPixelSize(AppSettings s) {
  final size = kBaseCherrySize * s.scale;
  final cellW = size * kCellWidthFactor;
  final cellH = size * kCellHeightFactor;
  final w = s.cherry.cols * cellW + (s.cherry.cols - 1) * kCherrySpacing;
  final h = s.cherry.rows * cellH + (s.cherry.rows - 1) * kCherrySpacing;
  return Size(w, h);
}

/// Normal overlay window: only the cherry plate exists, so transparent space
/// above it does not intercept clicks intended for applications underneath.
Size computeWindowSize(AppSettings s) {
  final grid = gridPixelSize(s);
  final w = (grid.width + kOuterPadding * 2).clamp(kMinWidth, 1200).toDouble();
  final h = grid.height + kOuterPadding * 2;
  return Size(w, h);
}

/// Temporary expanded window while hovering the plate, giving the tooltip room
/// to render above the cherries. The top edge is moved up by [kTooltipReserve],
/// keeping the plate fixed on screen.
Size computeTooltipWindowSize(AppSettings s) {
  final base = computeWindowSize(s);
  return Size(base.width, base.height + kTooltipReserve);
}
