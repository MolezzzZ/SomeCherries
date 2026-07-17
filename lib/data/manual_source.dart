import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../domain/pricing.dart';
import '../domain/usage.dart';
import 'usage_source.dart';

/// v1 stub source for users who don't run cc-switch (or for CI / external
/// reporters). Reads a local JSON file `manual_usage.json` in the app support
/// dir. The same shape is what a future CloudSource would return, so wiring it
/// now keeps the [UsageSource] contract honest.
///
/// File format:
/// {
///   "entries": [
///     {"model": "claude-opus-4-8", "input": 1000, "output": 500,
///      "cacheRead": 0, "cacheCreation": 0, "ts": 1782725952}
///   ]
/// }
/// `ts` is epoch seconds; entries outside the queried period are ignored.
class ManualSource extends UsageSource {
  /// User-editable pricing, shared with the cc-switch source.
  final PricingConfig pricing;

  String? _path;

  ManualSource({this.pricing = const PricingConfig()});

  @override
  String get displayName => 'manual (local JSON)';

  Future<File> _file() async {
    if (_path != null) return File(_path!);
    final dir = await getApplicationSupportDirectory();
    await dir.create(recursive: true);
    final f = File(p.join(dir.path, 'manual_usage.json'));
    _path = f.path;
    return f;
  }

  @override
  Future<bool> isAvailable() async => (await _file()).existsSync();

  @override
  Future<UsageSnapshot> read(UsageQuery query) async {
    final now = DateTime.now();
    final start = queryStart(query, now);
    final f = await _file();
    if (!f.existsSync()) return UsageSnapshot.empty(query.period, start);

    final startSec = start.millisecondsSinceEpoch ~/ 1000;
    final agg = <String, _Acc>{};

    try {
      final data = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
      final entries = (data['entries'] as List?) ?? const [];
      for (final e in entries) {
        final m = e as Map<String, dynamic>;
        final ts = (m['ts'] as num?)?.toInt() ?? startSec;
        if (ts < startSec) continue;
        final model = (m['model'] as String?) ?? 'unknown';
        final acc = agg.putIfAbsent(model, () => _Acc());
        acc.input += (m['input'] as num?)?.toInt() ?? 0;
        acc.output += (m['output'] as num?)?.toInt() ?? 0;
        acc.cacheRead += (m['cacheRead'] as num?)?.toInt() ?? 0;
        acc.cacheCreation += (m['cacheCreation'] as num?)?.toInt() ?? 0;
      }
    } catch (_) {
      return UsageSnapshot.empty(query.period, start);
    }

    final byModel = <ModelUsage>[];
    agg.forEach((model, a) {
      final price = pricing.priceFor(model);
      byModel.add(ModelUsage(
        model: model,
        inputTokens: a.input,
        outputTokens: a.output,
        cacheReadTokens: a.cacheRead,
        cacheCreationTokens: a.cacheCreation,
        costUsd: price.cost(
          input: a.input,
          output: a.output,
          cacheRead: a.cacheRead,
          cacheCreation: a.cacheCreation,
        ),
      ));
    });
    byModel.sort((a, b) => b.costUsd.compareTo(a.costUsd));
    return UsageSnapshot(
      period: query.period,
      periodStart: start,
      takenAt: now,
      byModel: byModel,
    );
  }
}

class _Acc {
  int input = 0;
  int output = 0;
  int cacheRead = 0;
  int cacheCreation = 0;
}
