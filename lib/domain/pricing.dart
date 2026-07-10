/// Model pricing in USD per 1,000,000 tokens.
///
/// Costs are computed by us from token counts rather than read from
/// cc-switch's stored `total_cost_usd` (which is often '0' for newer models).
/// Prices are fully user-configurable (see [PricingConfig]) because relay /
/// proxy stations charge different rates than Anthropic's list price.
class ModelPrice {
  final double inputPerMillion;
  final double outputPerMillion;
  final double cacheReadPerMillion;
  final double cacheCreationPerMillion;

  const ModelPrice({
    required this.inputPerMillion,
    required this.outputPerMillion,
    required this.cacheReadPerMillion,
    required this.cacheCreationPerMillion,
  });

  /// Cost in USD for a bundle of token counts.
  double cost({
    required int input,
    required int output,
    required int cacheRead,
    required int cacheCreation,
  }) {
    const m = 1000000.0;
    return input / m * inputPerMillion +
        output / m * outputPerMillion +
        cacheRead / m * cacheReadPerMillion +
        cacheCreation / m * cacheCreationPerMillion;
  }

  ModelPrice copyWith({
    double? inputPerMillion,
    double? outputPerMillion,
    double? cacheReadPerMillion,
    double? cacheCreationPerMillion,
  }) =>
      ModelPrice(
        inputPerMillion: inputPerMillion ?? this.inputPerMillion,
        outputPerMillion: outputPerMillion ?? this.outputPerMillion,
        cacheReadPerMillion: cacheReadPerMillion ?? this.cacheReadPerMillion,
        cacheCreationPerMillion:
            cacheCreationPerMillion ?? this.cacheCreationPerMillion,
      );

  Map<String, dynamic> toJson() => {
        'input': inputPerMillion,
        'output': outputPerMillion,
        'cacheRead': cacheReadPerMillion,
        'cacheCreation': cacheCreationPerMillion,
      };

  factory ModelPrice.fromJson(Map<String, dynamic> j, ModelPrice fallback) =>
      ModelPrice(
        inputPerMillion:
            (j['input'] as num?)?.toDouble() ?? fallback.inputPerMillion,
        outputPerMillion:
            (j['output'] as num?)?.toDouble() ?? fallback.outputPerMillion,
        cacheReadPerMillion: (j['cacheRead'] as num?)?.toDouble() ??
            fallback.cacheReadPerMillion,
        cacheCreationPerMillion: (j['cacheCreation'] as num?)?.toDouble() ??
            fallback.cacheCreationPerMillion,
      );
}

/// User-editable pricing, one [ModelPrice] per Claude tier.
///
/// A model id is mapped to a tier by name (substring match). Anything
/// unrecognized is priced at zero until the user explicitly sets a rate; this
/// avoids silently treating brand-new or non-Claude models as Opus.
///
/// Defaults are Anthropic's public list price for the current generation
/// (Opus 4.x $5/$25, Sonnet 4.6 $3/$15, Haiku 4.5 $1/$5; cache read ≈ 10% of
/// input, cache write ≈ 1.25× input). Users override these in Settings.
class PricingConfig {
  final ModelPrice opus;
  final ModelPrice sonnet;
  final ModelPrice haiku;

  /// Per-model overrides keyed by a lowercase model id (or fragment). Checked
  /// before the tier fallback, so a user can price non-Claude models (gpt-*)
  /// or a specific relay model exactly.
  final Map<String, ModelPrice> overrides;

  const PricingConfig({
    this.opus = defaultOpus,
    this.sonnet = defaultSonnet,
    this.haiku = defaultHaiku,
    this.overrides = const {},
  });

  static const defaultOpus = ModelPrice(
    inputPerMillion: 5,
    outputPerMillion: 25,
    cacheReadPerMillion: 0.5,
    cacheCreationPerMillion: 6.25,
  );
  static const defaultSonnet = ModelPrice(
    inputPerMillion: 3,
    outputPerMillion: 15,
    cacheReadPerMillion: 0.3,
    cacheCreationPerMillion: 3.75,
  );
  static const defaultHaiku = ModelPrice(
    inputPerMillion: 1,
    outputPerMillion: 5,
    cacheReadPerMillion: 0.1,
    cacheCreationPerMillion: 1.25,
  );
  static const unrecognized = ModelPrice(
    inputPerMillion: 0,
    outputPerMillion: 0,
    cacheReadPerMillion: 0,
    cacheCreationPerMillion: 0,
  );

  ModelPrice priceFor(String modelId) {
    final m = modelId.toLowerCase();
    // Per-model overrides win: exact id first, then substring match.
    final exact = overrides[m];
    if (exact != null) return exact;
    for (final e in overrides.entries) {
      if (e.key.isNotEmpty && m.contains(e.key)) return e.value;
    }
    if (m.contains('opus')) return opus;
    if (m.contains('sonnet')) return sonnet;
    if (m.contains('haiku')) return haiku;
    // Unknown models are free until the user explicitly prices them.
    return unrecognized;
  }

  PricingConfig copyWith({
    ModelPrice? opus,
    ModelPrice? sonnet,
    ModelPrice? haiku,
    Map<String, ModelPrice>? overrides,
  }) =>
      PricingConfig(
        opus: opus ?? this.opus,
        sonnet: sonnet ?? this.sonnet,
        haiku: haiku ?? this.haiku,
        overrides: overrides ?? this.overrides,
      );

  Map<String, dynamic> toJson() => {
        'opus': opus.toJson(),
        'sonnet': sonnet.toJson(),
        'haiku': haiku.toJson(),
        'overrides': {
          for (final e in overrides.entries) e.key: e.value.toJson(),
        },
      };

  factory PricingConfig.fromJson(Map<String, dynamic> j) => PricingConfig(
        opus: _tier(j['opus'], defaultOpus),
        sonnet: _tier(j['sonnet'], defaultSonnet),
        haiku: _tier(j['haiku'], defaultHaiku),
        overrides: _overrides(j['overrides']),
      );

  static Map<String, ModelPrice> _overrides(Object? v) {
    if (v is! Map) return const {};
    final out = <String, ModelPrice>{};
    v.forEach((key, val) {
      if (val is Map<String, dynamic>) {
        out[key.toString().toLowerCase()] =
            ModelPrice.fromJson(val, unrecognized);
      }
    });
    return out;
  }

  static ModelPrice _tier(Object? v, ModelPrice fallback) =>
      v is Map<String, dynamic> ? ModelPrice.fromJson(v, fallback) : fallback;
}
