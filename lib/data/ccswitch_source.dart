import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

import '../domain/usage.dart';
import 'usage_source.dart';

/// Reads token usage from cc-switch's SQLite database.
///
/// Important realities discovered about this DB (see plan):
///  - `created_at` in `proxy_request_logs` is epoch **seconds**.
///  - Newer cc-switch versions compute per-request costs themselves, so we
///    trust `total_cost_usd` and do not apply SomeCherries' pricing table.
///  - Fresh data lives in `proxy_request_logs`; `usage_daily_rollups` can lag
///    during the current day, so the overlay aggregates live logs directly.
///  - `session_id` equals the Claude Code session jsonl filename (a UUID),
///    which is how we scope to the current project.
class CcSwitchSource extends UsageSource {
  /// Absolute path to cc-switch.db. Defaults to ~/.cc-switch/cc-switch.db.
  final String dbPath;

  CcSwitchSource({String? dbPath}) : dbPath = dbPath ?? defaultDbPath();

  static String defaultDbPath() {
    final home = Platform.environment['HOME'] ??
        Platform.environment['USERPROFILE'] ??
        '';
    return p.join(home, '.cc-switch', 'cc-switch.db');
  }

  @override
  String get displayName => 'cc-switch';

  @override
  Future<bool> isAvailable() async => File(dbPath).existsSync();

  @override
  Future<List<String>> knownModels() async {
    if (!File(dbPath).existsSync()) return const [];
    final db = sqlite3.open('file:$dbPath?immutable=1', uri: true);
    try {
      // Distinct models ordered by most recent activity, so the ones the user
      // is actively burning tokens on surface first.
      final rs = db.select(
        'SELECT model, MAX(created_at) AS last FROM proxy_request_logs '
        "WHERE model IS NOT NULL AND model != '' "
        'GROUP BY model ORDER BY last DESC',
      );
      return [for (final row in rs) row['model'] as String];
    } catch (_) {
      return const [];
    } finally {
      db.dispose();
    }
  }

  @override
  Future<UsageSnapshot> read(UsageQuery query) async {
    final now = DateTime.now();
    final start = queryStart(query, now);

    if (!File(dbPath).existsSync()) {
      return UsageSnapshot.empty(query.period, start);
    }

    // Open read-only + immutable so we never contend with cc-switch's writer.
    final db = sqlite3.open('file:$dbPath?immutable=1', uri: true);
    try {
      final sessionFilter = query.scope == UsageScope.currentProject
          ? _projectSessionIds(query.projectPath)
          : null;

      // currentProject with no resolvable sessions => empty, not "everything".
      if (sessionFilter != null && sessionFilter.isEmpty) {
        return UsageSnapshot.empty(query.period, start);
      }

      final byModel = _aggregateLogs(
        db,
        startEpochSeconds: start.millisecondsSinceEpoch ~/ 1000,
        sessionIds: sessionFilter,
      );

      return UsageSnapshot(
        period: query.period,
        periodStart: start,
        takenAt: now,
        byModel: byModel,
      );
    } finally {
      db.dispose();
    }
  }

  List<ModelUsage> _aggregateLogs(
    Database db, {
    required int startEpochSeconds,
    required Set<String>? sessionIds,
  }) {
    final buffer = StringBuffer(
      'SELECT model, '
      'SUM(input_tokens) AS i, SUM(output_tokens) AS o, '
      'SUM(cache_read_tokens) AS cr, SUM(cache_creation_tokens) AS cc, '
      'SUM(CAST(total_cost_usd AS REAL)) AS cost '
      'FROM proxy_request_logs WHERE created_at >= ?',
    );
    final params = <Object?>[startEpochSeconds];

    if (sessionIds != null) {
      final placeholders = List.filled(sessionIds.length, '?').join(',');
      buffer.write(' AND session_id IN ($placeholders)');
      params.addAll(sessionIds);
    }
    buffer.write(' GROUP BY model');

    final rs = db.select(buffer.toString(), params);
    final out = <ModelUsage>[];
    for (final row in rs) {
      final model = (row['model'] as String?) ?? 'unknown';
      final input = _toInt(row['i']);
      final output = _toInt(row['o']);
      final cacheRead = _toInt(row['cr']);
      final cacheCreation = _toInt(row['cc']);
      if (input + output + cacheRead + cacheCreation == 0) continue;

      out.add(ModelUsage(
        model: model,
        inputTokens: input,
        outputTokens: output,
        cacheReadTokens: cacheRead,
        cacheCreationTokens: cacheCreation,
        costUsd: _toDouble(row['cost']),
      ));
    }
    out.sort((a, b) => b.costUsd.compareTo(a.costUsd));
    return out;
  }

  /// Session UUIDs belonging to a project, derived from the Claude Code logs
  /// dir. CC encodes the cwd as a folder name by replacing path separators and
  /// ':' with '-'. Each *.jsonl file is named for a session UUID.
  Set<String> _projectSessionIds(String? projectPath) {
    if (projectPath == null) return {};
    final home = Platform.environment['HOME'] ??
        Platform.environment['USERPROFILE'] ??
        '';
    final encoded = projectPath.replaceAll(RegExp(r'[\\/:]'), '-');
    final dir = Directory(p.join(home, '.claude', 'projects', encoded));
    if (!dir.existsSync()) return {};
    final ids = <String>{};
    for (final f in dir.listSync()) {
      if (f is File && f.path.endsWith('.jsonl')) {
        ids.add(p.basenameWithoutExtension(f.path));
      }
    }
    return ids;
  }

  static int _toInt(Object? v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }

  static double _toDouble(Object? v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }
}
