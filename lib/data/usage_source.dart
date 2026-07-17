import 'dart:async';

import '../domain/usage.dart';

/// Abstract source of token usage. Implementations:
///  - [CcSwitchSource]   reads ~/.cc-switch/cc-switch.db (default)
///  - ManualSource       (v1 stub) local JSON / localhost report
///  - CloudSource        (v2) desktop uploads, phone pulls — same interface
///
/// Keeping this interface stable is what lets the phone widget (v2) reuse the
/// exact same domain + UI by swapping only the implementation.
abstract class UsageSource {
  /// One-shot read of the usage for [query].
  Future<UsageSnapshot> read(UsageQuery query);

  /// Periodic stream of snapshots. Default implementation polls [read] every
  /// [interval]; sources with push semantics may override.
  Stream<UsageSnapshot> watch(
    UsageQuery query, {
    Duration interval = const Duration(seconds: 3),
  }) async* {
    yield await read(query);
    yield* Stream.periodic(interval).asyncMap((_) => read(query));
  }

  /// Human-readable name for the settings panel.
  String get displayName;

  /// Whether this source can currently produce data (e.g. db file exists).
  Future<bool> isAvailable();

  /// Distinct model ids this source has recently seen, most-recent first. Used
  /// by Settings to pre-populate per-model pricing rows so the user doesn't have
  /// to type ids they're already using (Claude, GPT/Codex, etc.). Sources with
  /// no notion of models return an empty list.
  Future<List<String>> knownModels() async => const [];
}

/// Computes the local start instant for a period.
DateTime periodStart(UsagePeriod period, DateTime now) {
  switch (period) {
    case UsagePeriod.day:
      return DateTime(now.year, now.month, now.day);
    case UsagePeriod.week:
      // ISO week start (Monday) at local midnight.
      final monday = now.subtract(Duration(days: now.weekday - 1));
      return DateTime(monday.year, monday.month, monday.day);
    case UsagePeriod.month:
      return DateTime(now.year, now.month, 1);
    case UsagePeriod.total:
      return DateTime.fromMillisecondsSinceEpoch(0);
  }
}

/// Resolves either a calendar boundary or a rolling-window boundary.
DateTime queryStart(UsageQuery query, DateTime now) =>
    query.rollingWindow == null
        ? periodStart(query.period, now)
        : now.subtract(query.rollingWindow!);
