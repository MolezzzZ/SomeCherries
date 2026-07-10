import 'package:flutter/material.dart';

import '../domain/cherry_state.dart';
import 'cherry.dart';

/// Lays out the plate of cherries in rows × cols, eaten in reading order.
class CherryGrid extends StatelessWidget {
  final CherryState state;
  final double cherrySize;
  final double spacing;

  const CherryGrid({
    super.key,
    required this.state,
    this.cherrySize = 28,
    this.spacing = 4,
  });

  @override
  Widget build(BuildContext context) {
    final cfg = state.config;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(cfg.rows, (row) {
        return Padding(
          padding: EdgeInsets.only(bottom: row == cfg.rows - 1 ? 0 : spacing),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(cfg.cols, (col) {
              final i = row * cfg.cols + col;
              return Padding(
                padding:
                    EdgeInsets.only(right: col == cfg.cols - 1 ? 0 : spacing),
                child: Cherry(
                  status: state.statusAt(i),
                  bite: state.currentBite,
                  size: cherrySize,
                ),
              );
            }),
          ),
        );
      }),
    );
  }
}
