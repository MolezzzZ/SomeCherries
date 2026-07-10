import '../domain/cherry_state.dart';
import '../domain/pricing.dart';
import '../domain/usage.dart';
import 'l10n.dart';

enum SourceKind { ccswitch, manual }

/// Default mouse behavior of the overlay.
enum InteractionMode {
  /// Window is draggable; hovering shows the tooltip.
  draggable,

  /// Clicks pass through to apps behind; a hotkey temporarily re-activates.
  clickThrough,
}

/// All persisted user configuration.
class AppSettings {
  final SourceKind source;

  /// Optional override for the cc-switch db path. Null = default location.
  final String? dbPathOverride;

  final CherryConfig cherry;

  /// User-editable per-tier token pricing.
  final PricingConfig pricing;

  final UsagePeriod period;
  final UsageScope scope;
  final String? projectPath;

  final AppLanguage language;
  final InteractionMode interaction;
  final double scale; // 0.5 .. 2.0 render scale
  final double opacity; // 0.2 .. 1.0
  final int pollSeconds;

  /// Saved window top-left. Null = snap to bottom-right on first run.
  final double? windowX;
  final double? windowY;

  const AppSettings({
    this.source = SourceKind.ccswitch,
    this.dbPathOverride,
    this.cherry = const CherryConfig(),
    this.pricing = const PricingConfig(),
    this.period = UsagePeriod.day,
    this.scope = UsageScope.global,
    this.projectPath,
    this.language = AppLanguage.zh,
    this.interaction = InteractionMode.draggable,
    this.scale = 1.0,
    this.opacity = 1.0,
    this.pollSeconds = 3,
    this.windowX,
    this.windowY,
  });

  UsageQuery get query =>
      UsageQuery(period: period, scope: scope, projectPath: projectPath);

  AppSettings copyWith({
    SourceKind? source,
    String? dbPathOverride,
    CherryConfig? cherry,
    PricingConfig? pricing,
    UsagePeriod? period,
    UsageScope? scope,
    String? projectPath,
    AppLanguage? language,
    InteractionMode? interaction,
    double? scale,
    double? opacity,
    int? pollSeconds,
    double? windowX,
    double? windowY,
  }) =>
      AppSettings(
        source: source ?? this.source,
        dbPathOverride: dbPathOverride ?? this.dbPathOverride,
        cherry: cherry ?? this.cherry,
        pricing: pricing ?? this.pricing,
        period: period ?? this.period,
        scope: scope ?? this.scope,
        projectPath: projectPath ?? this.projectPath,
        language: language ?? this.language,
        interaction: interaction ?? this.interaction,
        scale: scale ?? this.scale,
        opacity: opacity ?? this.opacity,
        pollSeconds: pollSeconds ?? this.pollSeconds,
        windowX: windowX ?? this.windowX,
        windowY: windowY ?? this.windowY,
      );

  Map<String, dynamic> toJson() => {
        'source': source.name,
        'dbPathOverride': dbPathOverride,
        'dollarsPerCherry': cherry.dollarsPerCherry,
        'rows': cherry.rows,
        'cols': cherry.cols,
        'pricing': pricing.toJson(),
        'period': period.name,
        'scope': scope.name,
        'projectPath': projectPath,
        'language': language.name,
        'interaction': interaction.name,
        'scale': scale,
        'opacity': opacity,
        'pollSeconds': pollSeconds,
        'windowX': windowX,
        'windowY': windowY,
      };

  factory AppSettings.fromJson(Map<String, dynamic> j) => AppSettings(
        source: _enumByName(SourceKind.values, j['source'], SourceKind.ccswitch),
        dbPathOverride: j['dbPathOverride'] as String?,
        cherry: CherryConfig(
          dollarsPerCherry: (j['dollarsPerCherry'] as num?)?.toDouble() ?? 0.50,
          rows: (j['rows'] as num?)?.toInt() ?? 5,
          cols: (j['cols'] as num?)?.toInt() ?? 4,
        ),
        pricing: j['pricing'] is Map<String, dynamic>
            ? PricingConfig.fromJson(j['pricing'] as Map<String, dynamic>)
            : const PricingConfig(),
        period: _enumByName(UsagePeriod.values, j['period'], UsagePeriod.day),
        scope: _enumByName(UsageScope.values, j['scope'], UsageScope.global),
        projectPath: j['projectPath'] as String?,
        language: _enumByName(AppLanguage.values, j['language'], AppLanguage.zh),
        interaction: _enumByName(
            InteractionMode.values, j['interaction'], InteractionMode.draggable),
        scale: (j['scale'] as num?)?.toDouble() ?? 1.0,
        opacity: (j['opacity'] as num?)?.toDouble() ?? 1.0,
        pollSeconds: (j['pollSeconds'] as num?)?.toInt() ?? 3,
        windowX: (j['windowX'] as num?)?.toDouble(),
        windowY: (j['windowY'] as num?)?.toDouble(),
      );

  static T _enumByName<T extends Enum>(List<T> values, Object? name, T fallback) {
    for (final v in values) {
      if (v.name == name) return v;
    }
    return fallback;
  }
}
