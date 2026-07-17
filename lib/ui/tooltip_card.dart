import 'package:flutter/material.dart';

import '../app/l10n.dart';
import '../app/settings.dart';
import '../domain/cherry_state.dart';
import '../domain/usage.dart';

/// Hover card: exact token + cost detail for the current period.
class TooltipCard extends StatelessWidget {
  final UsageSnapshot snapshot;
  final CherryState cherry;
  final int recentTokens;
  final double dailyCostUsd;
  final UsageAlertConfig alerts;
  final L10n l10n;

  const TooltipCard({
    super.key,
    required this.snapshot,
    required this.cherry,
    this.recentTokens = 0,
    this.dailyCostUsd = 0,
    this.alerts = const UsageAlertConfig(),
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    final l = l10n;
    final periodLabel = switch (snapshot.period) {
      UsagePeriod.day => l.today,
      UsagePeriod.week => l.thisWeek,
      UsagePeriod.month => l.thisMonth,
      UsagePeriod.total => l.allTime,
    };

    return Container(
      constraints: const BoxConstraints(maxWidth: 280),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xF21E1116),
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: const Color(0xFFE01E37).withValues(alpha: 0.5)),
        boxShadow: const [
          BoxShadow(
              color: Colors.black54, blurRadius: 16, offset: Offset(0, 6)),
        ],
      ),
      child: DefaultTextStyle(
        style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            height: 1.35,
            fontFamily: 'ZCOOLKuaiLe'),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('$periodLabel · ${l.burn}',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, color: Color(0xFFFF8FA0))),
                Text('\$${snapshot.totalCostUsd.toStringAsFixed(2)}',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, color: Colors.white)),
              ],
            ),
            const SizedBox(height: 6),
            _line(
                l.cherriesEaten,
                '${cherry.eatenOnPlate}/${cherry.config.cherriesPerPlate}'
                '${cherry.round > 0 ? '  ${l.plateSuffix(cherry.round + 1)}' : ''}'),
            _line(l.perCherryShort,
                '\$${cherry.config.dollarsPerCherry.toStringAsFixed(2)}'),
            const Divider(height: 14, color: Colors.white24),
            Text(l.warningLights,
                style: const TextStyle(
                    color: Color(0xFFE0B6D3), fontWeight: FontWeight.bold)),
            _line(
              l.currentPlates,
              '${(cherry.periodCost / cherry.config.dollarsPerPlate).toStringAsFixed(1)}'
              ' / ${alerts.maxPlates.toStringAsFixed(0)} ${l.platesUnit}',
            ),
            _line(
              l.halfHourSpeed,
              '${_fmt(recentTokens)} / ${_fmt(alerts.halfHourTokenLimit)}',
            ),
            _line(
              l.dailySpend,
              '\$${dailyCostUsd.toStringAsFixed(2)} / '
              '\$${alerts.dailyCostLimitUsd.toStringAsFixed(0)}',
            ),
            const Divider(height: 14, color: Colors.white24),
            _line(l.tokIn, _fmt(snapshot.totalInput)),
            _line(l.tokOut, _fmt(snapshot.totalOutput)),
            _line(l.tokCacheRead, _fmt(snapshot.totalCacheRead)),
            _line(l.tokCacheWrite, _fmt(snapshot.totalCacheCreation)),
            _line(l.tokTotal, _fmt(snapshot.totalTokens), bold: true),
            if (snapshot.byModel.isNotEmpty) ...[
              const Divider(height: 14, color: Colors.white24),
              ...snapshot.byModel.take(4).map((m) => _line(
                    _shortModel(m.model),
                    '\$${m.costUsd.toStringAsFixed(2)}',
                  )),
            ],
          ],
        ),
      ),
    );
  }

  Widget _line(String label, String value, {bool bold = false}) {
    final style = TextStyle(
      color: bold ? Colors.white : Colors.white70,
      fontWeight: bold ? FontWeight.bold : FontWeight.normal,
      fontSize: 12,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
              child:
                  Text(label, style: style, overflow: TextOverflow.ellipsis)),
          const SizedBox(width: 10),
          Text(value, style: style),
        ],
      ),
    );
  }

  static String _shortModel(String m) {
    return m.replaceAll('claude-', '').replaceAll('-20', ' 20');
  }

  static String _fmt(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(2)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
    return '$n';
  }
}
