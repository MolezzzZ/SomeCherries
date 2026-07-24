import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:some_cherries/app/l10n.dart';
import 'package:some_cherries/app/settings.dart';
import 'package:some_cherries/app/window_sizing.dart';
import 'package:some_cherries/domain/cherry_state.dart';
import 'package:some_cherries/domain/usage.dart';
import 'package:some_cherries/ui/tooltip_card.dart';

void main() {
  testWidgets('maximum tooltip content stays inside the reserved window area',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final now = DateTime(2026, 7, 24);
    final snapshot = UsageSnapshot(
      period: UsagePeriod.day,
      periodStart: now,
      takenAt: now,
      byModel: List.generate(
        4,
        (index) => ModelUsage(
          model: 'model-$index',
          inputTokens: 1000000,
          outputTokens: 1000000,
          cacheReadTokens: 1000000,
          cacheCreationTokens: 1000000,
          costUsd: 1,
        ),
      ),
    );

    const settings = AppSettings();
    final content = overlayContentPixelSize(settings);

    for (final scale in [1.0, 1.25, 1.5, 2.0]) {
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(scale),
            ),
            child: child!,
          ),
          home: Center(
            child: SizedBox(
              width: computeWindowSize(settings).width - kOuterPadding * 2,
              child: TooltipCard(
                snapshot: snapshot,
                cherry: CherryState.fromCost(4, const CherryConfig()),
                recentTokens: 12000000,
                dailyCostUsd: 25,
                alerts: const UsageAlertConfig(),
                l10n: const L10n(AppLanguage.zh),
              ),
            ),
          ),
        ),
      );

      final cardHeight = tester.getSize(find.byType(TooltipCard)).height;
      final windowHeight = computeTooltipWindowSize(
        settings,
        textScaleFactor: scale,
      ).height;
      final availableHeight = windowHeight - content.height - kOuterPadding - 8;

      expect(
        availableHeight - cardHeight,
        greaterThanOrEqualTo(12),
        reason: 'the card and its top shadow need room at text scale $scale',
      );
      expect(tester.takeException(), isNull);
    }
  });
}
