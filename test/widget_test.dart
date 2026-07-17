import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

import 'package:cherry_token_monitor/data/ccswitch_source.dart';
import 'package:cherry_token_monitor/data/usage_source.dart';
import 'package:cherry_token_monitor/app/settings.dart';
import 'package:cherry_token_monitor/domain/cherry_state.dart';
import 'package:cherry_token_monitor/domain/pricing.dart';
import 'package:cherry_token_monitor/domain/usage.dart';
import 'package:cherry_token_monitor/ui/cherry.dart';
import 'package:cherry_token_monitor/ui/slow_burn.dart';
import 'package:cherry_token_monitor/ui/usage_warning_lights.dart';

void main() {
  group('CherryState.fromCost', () {
    const config = CherryConfig(dollarsPerCherry: 0.5, rows: 5, cols: 4);

    test('no cost leaves a full plate', () {
      final s = CherryState.fromCost(0, config);
      expect(s.eatenOnPlate, 0);
      expect(s.round, 0);
      expect(s.statusAt(0), CherryStatus.full);
    });

    test('partial cherry shows an eating cherry', () {
      final s = CherryState.fromCost(0.25, config);
      expect(s.eatenOnPlate, 0);
      expect(s.statusAt(0), CherryStatus.eating);
      expect(s.currentBite, closeTo(0.5, 1e-9));
    });

    test('whole cherries are eaten in order', () {
      final s = CherryState.fromCost(1.75, config);
      expect(s.eatenOnPlate, 3);
      expect(s.statusAt(0), CherryStatus.eaten);
      expect(s.statusAt(2), CherryStatus.eaten);
      expect(s.statusAt(3), CherryStatus.eating);
      expect(s.statusAt(4), CherryStatus.full);
    });

    test('an exact whole-dollar boundary leaves no partial cherry', () {
      final s = CherryState.fromCost(1.5, config);
      expect(s.eatenOnPlate, 3);
      expect(s.statusAt(3), CherryStatus.full);
    });

    test('eating a full plate regrows into the next round', () {
      // 20 cherries * $0.50 = $10 per plate.
      final s = CherryState.fromCost(10.0, config);
      expect(s.round, 1);
      expect(s.eatenOnPlate, 0);
    });
  });

  group('SlowBurn', () {
    test('keeps movement longer than the polling interval', () {
      expect(
        slowBurnDuration(
          remainingCost: 0.05,
          dollarsPerCherry: 0.5,
          pollSeconds: 3,
        ),
        const Duration(milliseconds: 4200),
      );
    });

    testWidgets('starts from the current value and burns toward new usage',
        (tester) async {
      Widget app({required double cost, required int tokens}) {
        return MaterialApp(
          home: SlowBurn(
            targetCost: cost,
            totalTokens: tokens,
            dollarsPerCherry: 0.5,
            pollSeconds: 3,
            builder: (_, displayedCost) => Text(displayedCost.toString()),
          ),
        );
      }

      await tester.pumpWidget(app(cost: 1, tokens: 100));
      expect(find.text('1.0'), findsOneWidget);

      await tester.pumpWidget(app(cost: 1.5, tokens: 200));
      await tester.pump(const Duration(milliseconds: 2100));
      final halfway =
          double.parse(tester.widget<Text>(find.byType(Text)).data!);
      expect(halfway, greaterThan(1));
      expect(halfway, lessThan(1.5));

      await tester.pump(const Duration(milliseconds: 2200));
      expect(find.text('1.5'), findsOneWidget);
    });
  });

  testWidgets('cherry painter supports partial nibble states', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: RepaintBoundary(
          child: Cherry(
            status: CherryStatus.eating,
            bite: 0.55,
            size: 54,
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });

  group('usage warning lights', () {
    test('alert thresholds survive a settings JSON round-trip', () {
      const settings = AppSettings(
        alerts: UsageAlertConfig(
          maxPlates: 12,
          halfHourTokenLimit: 25000000,
          dailyCostLimitUsd: 80,
        ),
      );
      final restored = AppSettings.fromJson(settings.toJson());
      expect(restored.alerts.maxPlates, 12);
      expect(restored.alerts.halfHourTokenLimit, 25000000);
      expect(restored.alerts.dailyCostLimitUsd, 80);
    });

    test('30-minute query uses a rolling boundary', () {
      final now = DateTime(2026, 7, 16, 15, 30);
      final start = queryStart(
        const UsageQuery(
          period: UsagePeriod.day,
          rollingWindow: Duration(minutes: 30),
        ),
        now,
      );
      expect(start, DateTime(2026, 7, 16, 15));
    });

    testWidgets('renders all three textured lamp segments', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Center(
            child: SizedBox(
              width: 280,
              child: UsageWarningLights(
                currentPlates: 4,
                recentTokens: 12000000,
                dailyCostUsd: 25,
                config: UsageAlertConfig(),
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));
      expect(tester.getSize(find.byType(UsageWarningLights)).height, 14);
      expect(
        tester.getSize(find.byType(FractionallySizedBox)).width,
        closeTo(257.6, 0.1),
      );
      final lamps = find.descendant(
        of: find.byType(UsageWarningLights),
        matching: find.byType(CustomPaint),
      );
      expect(lamps, findsNWidgets(3));
      expect(tester.getSize(lamps.at(0)).width, closeTo(103.0, 0.2));
      expect(tester.getSize(lamps.at(1)).width, closeTo(59.2, 0.2));
      expect(
        tester.getRect(lamps.at(1)).left - tester.getRect(lamps.at(0)).right,
        closeTo(12.9, 0.2),
      );
      expect(
        tester.getRect(lamps.at(2)).left - tester.getRect(lamps.at(1)).right,
        closeTo(12.9, 0.2),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('keeps repainting an over-limit lamp for slow breathing',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Center(
            child: SizedBox(
              width: 280,
              child: UsageWarningLights(
                currentPlates: 10,
                recentTokens: 20000000,
                dailyCostUsd: 50,
                config: UsageAlertConfig(),
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));
      final paints = find.descendant(
        of: find.byType(UsageWarningLights),
        matching: find.byType(CustomPaint),
      );
      final before = tester.widget<CustomPaint>(paints.at(1)).painter!;
      await tester.pump(const Duration(milliseconds: 600));
      final after = tester.widget<CustomPaint>(paints.at(1)).painter!;
      expect(after.shouldRepaint(before), isTrue);
      expect(tester.binding.hasScheduledFrame, isTrue);
    });
  });

  group('PricingConfig.priceFor', () {
    const config = PricingConfig();

    test('opus models match opus, unknown models are free by default', () {
      expect(config.priceFor('claude-opus-4-8').inputPerMillion,
          PricingConfig.defaultOpus.inputPerMillion);
      expect(config.priceFor('gpt-5.5').inputPerMillion, 0);
      expect(
        config.priceFor('gpt-5.5').cost(
              input: 1000000,
              output: 1000000,
              cacheRead: 1000000,
              cacheCreation: 1000000,
            ),
        0,
      );
    });

    test('matches sonnet and haiku tiers by name', () {
      expect(config.priceFor('claude-sonnet-4-6').outputPerMillion,
          PricingConfig.defaultSonnet.outputPerMillion);
      expect(config.priceFor('claude-haiku-4-5').outputPerMillion,
          PricingConfig.defaultHaiku.outputPerMillion);
    });

    test('user-edited tier prices take effect', () {
      final edited = const PricingConfig().copyWith(
        opus: const ModelPrice(
          inputPerMillion: 10,
          outputPerMillion: 50,
          cacheReadPerMillion: 1,
          cacheCreationPerMillion: 12.5,
        ),
      );
      final cost = edited.priceFor('claude-opus-4-8').cost(
            input: 1000000,
            output: 0,
            cacheRead: 0,
            cacheCreation: 0,
          );
      expect(cost, closeTo(10.0, 1e-9));
    });

    test('survives a JSON round-trip', () {
      final edited = const PricingConfig().copyWith(
        haiku: PricingConfig.defaultHaiku.copyWith(inputPerMillion: 0.8),
      );
      final restored = PricingConfig.fromJson(edited.toJson());
      expect(restored.haiku.inputPerMillion, 0.8);
      expect(restored.opus.outputPerMillion,
          PricingConfig.defaultOpus.outputPerMillion);
    });

    test('per-model override wins over the tier fallback', () {
      final cfg = const PricingConfig().copyWith(
        overrides: {
          'gpt-5.5': const ModelPrice(
            inputPerMillion: 2,
            outputPerMillion: 8,
            cacheReadPerMillion: 0.2,
            cacheCreationPerMillion: 2.5,
          ),
        },
      );
      // Exact id and substring match both resolve to the override, not opus.
      expect(cfg.priceFor('gpt-5.5').outputPerMillion, 8);
      expect(cfg.priceFor('relay/gpt-5.5-turbo').outputPerMillion, 8);
      // Unrelated models still use the tier fallback.
      expect(cfg.priceFor('claude-opus-4-8').outputPerMillion,
          PricingConfig.defaultOpus.outputPerMillion);
    });

    test('overrides survive a JSON round-trip', () {
      final cfg = const PricingConfig().copyWith(
        overrides: {
          'gpt-5.5': PricingConfig.defaultOpus.copyWith(inputPerMillion: 2),
        },
      );
      final restored = PricingConfig.fromJson(cfg.toJson());
      expect(restored.overrides['gpt-5.5']?.inputPerMillion, 2);
    });
  });

  group('CcSwitchSource', () {
    test('uses cc-switch stored total_cost_usd instead of local pricing',
        () async {
      final dir = await Directory.systemTemp.createTemp('ccswitch_source_test');
      final dbPath = '${dir.path}${Platform.pathSeparator}cc-switch.db';
      final db = sqlite3.open(dbPath);
      try {
        db.execute('''
CREATE TABLE proxy_request_logs (
  request_id TEXT PRIMARY KEY,
  model TEXT NOT NULL,
  input_tokens INTEGER NOT NULL DEFAULT 0,
  output_tokens INTEGER NOT NULL DEFAULT 0,
  cache_read_tokens INTEGER NOT NULL DEFAULT 0,
  cache_creation_tokens INTEGER NOT NULL DEFAULT 0,
  total_cost_usd TEXT NOT NULL DEFAULT '0',
  created_at INTEGER NOT NULL
)
''');
        final start = DateTime.now().copyWith(
          hour: 0,
          minute: 0,
          second: 0,
          millisecond: 0,
          microsecond: 0,
        );
        db.execute(
          '''
INSERT INTO proxy_request_logs (
  request_id, model, input_tokens, output_tokens, cache_read_tokens,
  cache_creation_tokens, total_cost_usd, created_at
) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
''',
          [
            'r1',
            'gpt-5.5',
            1000000,
            2000000,
            3000000,
            0,
            '1.2345',
            start.millisecondsSinceEpoch ~/ 1000,
          ],
        );
      } finally {
        db.dispose();
      }

      try {
        final snapshot = await CcSwitchSource(dbPath: dbPath).read(
          const UsageQuery(period: UsagePeriod.day),
        );

        expect(snapshot.byModel, hasLength(1));
        expect(snapshot.byModel.single.model, 'gpt-5.5');
        expect(snapshot.byModel.single.totalTokens, 6000000);
        expect(snapshot.totalCostUsd, closeTo(1.2345, 1e-9));
      } finally {
        await dir.delete(recursive: true);
      }
    });
  });
}
