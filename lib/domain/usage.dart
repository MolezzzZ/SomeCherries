/// Token accounting period.
enum UsagePeriod { day, week, month, total }

/// Which sessions to count.
enum UsageScope { global, currentProject }

/// A query describing what slice of usage to read.
class UsageQuery {
  final UsagePeriod period;
  final UsageScope scope;

  /// Only used when [scope] is currentProject. The cwd whose sessions we count.
  final String? projectPath;

  const UsageQuery({
    this.period = UsagePeriod.day,
    this.scope = UsageScope.global,
    this.projectPath,
  });

  UsageQuery copyWith({
    UsagePeriod? period,
    UsageScope? scope,
    String? projectPath,
  }) =>
      UsageQuery(
        period: period ?? this.period,
        scope: scope ?? this.scope,
        projectPath: projectPath ?? this.projectPath,
      );
}

/// Per-model token totals plus the cost we computed for it.
class ModelUsage {
  final String model;
  final int inputTokens;
  final int outputTokens;
  final int cacheReadTokens;
  final int cacheCreationTokens;
  final double costUsd;

  const ModelUsage({
    required this.model,
    required this.inputTokens,
    required this.outputTokens,
    required this.cacheReadTokens,
    required this.cacheCreationTokens,
    required this.costUsd,
  });

  int get totalTokens =>
      inputTokens + outputTokens + cacheReadTokens + cacheCreationTokens;
}

/// Aggregated usage for a period: total cost (the burn metric the cherries
/// track) plus a per-model breakdown for the hover tooltip.
class UsageSnapshot {
  final UsagePeriod period;
  final DateTime periodStart;
  final DateTime takenAt;
  final List<ModelUsage> byModel;

  const UsageSnapshot({
    required this.period,
    required this.periodStart,
    required this.takenAt,
    required this.byModel,
  });

  double get totalCostUsd =>
      byModel.fold(0.0, (sum, m) => sum + m.costUsd);

  int get totalInput =>
      byModel.fold(0, (sum, m) => sum + m.inputTokens);
  int get totalOutput =>
      byModel.fold(0, (sum, m) => sum + m.outputTokens);
  int get totalCacheRead =>
      byModel.fold(0, (sum, m) => sum + m.cacheReadTokens);
  int get totalCacheCreation =>
      byModel.fold(0, (sum, m) => sum + m.cacheCreationTokens);
  int get totalTokens =>
      byModel.fold(0, (sum, m) => sum + m.totalTokens);

  static UsageSnapshot empty(UsagePeriod period, DateTime periodStart) =>
      UsageSnapshot(
        period: period,
        periodStart: periodStart,
        takenAt: DateTime.now(),
        byModel: const [],
      );
}
