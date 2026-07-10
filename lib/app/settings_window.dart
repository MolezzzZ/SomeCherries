import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import '../domain/cherry_state.dart';
import '../domain/pricing.dart';
import '../domain/usage.dart';
import 'l10n.dart';
import 'settings.dart';

/// In-window settings panel. Shown by temporarily resizing the overlay window
/// to an opaque form, returning the edited [AppSettings] via [onClose].
class SettingsWindow extends StatefulWidget {
  final AppSettings initial;
  final ValueChanged<AppSettings> onClose;
  final String ccSwitchDefaultPath;

  /// Model ids the active source has recently seen (Claude, GPT/Codex, …). Any
  /// non-Claude ones get a pre-filled price row so the user can set their rate.
  final List<String> detectedModels;

  const SettingsWindow({
    super.key,
    required this.initial,
    required this.onClose,
    required this.ccSwitchDefaultPath,
    this.detectedModels = const [],
  });

  @override
  State<SettingsWindow> createState() => _SettingsWindowState();
}

class _SettingsWindowState extends State<SettingsWindow> {
  late SourceKind _source;
  late UsagePeriod _period;
  late UsageScope _scope;
  late InteractionMode _interaction;
  late double _dollarsPerCherry;
  late int _rows;
  late int _cols;
  late double _scale;
  late double _opacity;
  late int _poll;

  late AppLanguage _language;
  late ModelPrice _opus;
  late ModelPrice _sonnet;
  late ModelPrice _haiku;

  late final TextEditingController _dbPath;
  late final TextEditingController _projectPath;

  // One flat, parallel list of models to price — Claude and GPT alike. Each row
  // is saved as a per-model override so every model stands on equal footing.
  final List<_OverrideRow> _overrides = [];

  @override
  void initState() {
    super.initState();
    final s = widget.initial;
    _source = s.source;
    _period = s.period;
    _scope = s.scope;
    _interaction = s.interaction;
    _dollarsPerCherry = s.cherry.dollarsPerCherry;
    _rows = s.cherry.rows;
    _cols = s.cherry.cols;
    _scale = s.scale;
    _opacity = s.opacity;
    _poll = s.pollSeconds;
    _language = s.language;
    _opus = s.pricing.opus;
    _sonnet = s.pricing.sonnet;
    _haiku = s.pricing.haiku;
    _dbPath = TextEditingController(text: s.dbPathOverride ?? '');
    _projectPath = TextEditingController(text: s.projectPath ?? '');
    // Build one flat list: every model — the ones already priced plus the ones
    // the source is actively using (Claude, GPT/Codex, …) — appears as a peer
    // row, prefilled with whatever price currently resolves.
    final seen = <String>{};
    s.pricing.overrides.forEach((id, m) {
      _overrides.add(_OverrideRow.from(id, m));
      seen.add(id.toLowerCase());
    });
    for (final model in widget.detectedModels) {
      final id = model.toLowerCase();
      if (id.isEmpty) continue;
      if (!seen.add(id)) continue;
      _overrides.add(_OverrideRow.from(model, s.pricing.priceFor(model)));
    }
  }

  @override
  void dispose() {
    _dbPath.dispose();
    _projectPath.dispose();
    for (final r in _overrides) {
      r.dispose();
    }
    super.dispose();
  }

  static String _numStr(double v) {
    if (v == v.roundToDouble()) return v.toInt().toString();
    return v.toString();
  }

  AppSettings _collect() {
    final db = _dbPath.text.trim();
    final proj = _projectPath.text.trim();
    final overrides = <String, ModelPrice>{};
    for (final r in _overrides) {
      final id = r.id.text.trim().toLowerCase();
      if (id.isEmpty) continue;
      overrides[id] = r.price;
    }
    return widget.initial.copyWith(
      source: _source,
      dbPathOverride: db.isEmpty ? null : db,
      cherry: CherryConfig(
        dollarsPerCherry: _dollarsPerCherry,
        rows: _rows,
        cols: _cols,
      ),
      pricing: PricingConfig(
        opus: _opus,
        sonnet: _sonnet,
        haiku: _haiku,
        overrides: overrides,
      ),
      period: _period,
      scope: _scope,
      projectPath: proj.isEmpty ? null : proj,
      language: _language,
      interaction: _interaction,
      scale: _scale,
      opacity: _opacity,
      pollSeconds: _poll,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = L10n(_language);
    return Material(
      color: const Color(0xFF1A1014),
      child: SafeArea(
        child: Column(
          children: [
            _header(l),
            const Divider(height: 1, color: Colors.white12),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                children: [
                  _sectionTitle(l.language),
                  _segmented<AppLanguage>(
                    value: _language,
                    options: const {
                      AppLanguage.zh: '中文',
                      AppLanguage.en: 'English',
                    },
                    onChanged: (v) => setState(() => _language = v),
                  ),
                  const SizedBox(height: 16),
                  _sectionTitle(l.dataSource),
                  _segmented<SourceKind>(
                    value: _source,
                    options: {
                      SourceKind.ccswitch: 'cc-switch',
                      SourceKind.manual: l.sourceManual,
                    },
                    onChanged: (v) => setState(() => _source = v),
                  ),
                  if (_source == SourceKind.ccswitch)
                    _textField(
                      _dbPath,
                      label: l.dbPathLabel,
                      hint: widget.ccSwitchDefaultPath,
                    ),
                  const SizedBox(height: 16),
                  _sectionTitle(l.anchoring),
                  _slider(
                    label: l.perCherry,
                    value: _dollarsPerCherry,
                    min: 0.05,
                    max: 5.0,
                    divisions: 99,
                    display: '\$${_dollarsPerCherry.toStringAsFixed(2)}',
                    onChanged: (v) => setState(() =>
                        _dollarsPerCherry = double.parse(v.toStringAsFixed(2))),
                  ),
                  Row(children: [
                    Expanded(
                        child: _stepper(l.rows, _rows, 1, 10,
                            (v) => setState(() => _rows = v))),
                    const SizedBox(width: 12),
                    Expanded(
                        child: _stepper(l.cols, _cols, 1, 10,
                            (v) => setState(() => _cols = v))),
                  ]),
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      l.plateSummary(
                        _rows * _cols,
                        (_dollarsPerCherry * _rows * _cols).toStringAsFixed(2),
                      ),
                      style:
                          const TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _sectionTitle(l.accounting),
                  _dropdown<UsagePeriod>(
                    label: l.period,
                    value: _period,
                    options: {
                      UsagePeriod.day: l.periodDay,
                      UsagePeriod.week: l.periodWeek,
                      UsagePeriod.month: l.periodMonth,
                      UsagePeriod.total: l.periodTotal,
                    },
                    onChanged: (v) => setState(() => _period = v),
                  ),
                  _dropdown<UsageScope>(
                    label: l.scope,
                    value: _scope,
                    options: {
                      UsageScope.global: l.scopeGlobal,
                      UsageScope.currentProject: l.scopeProject,
                    },
                    onChanged: (v) => setState(() => _scope = v),
                  ),
                  if (_scope == UsageScope.currentProject)
                    _textField(
                      _projectPath,
                      label: l.projectPathLabel,
                      hint: r'C:\path\to\project',
                    ),
                  const SizedBox(height: 16),
                  _sectionTitle(l.pricingTitle),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      l.pricingHelp,
                      style:
                          const TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  ),
                  ...List.generate(
                      _overrides.length, (i) => _overrideRow(_overrides[i], l)),
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: TextButton.icon(
                      onPressed: _addOverride,
                      icon: const Icon(Icons.add, size: 16),
                      label: Text(l.addModel),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _sectionTitle(l.appearance),
                  _dropdown<InteractionMode>(
                    label: l.interaction,
                    value: _interaction,
                    options: {
                      InteractionMode.draggable: l.interactionDraggable,
                      InteractionMode.clickThrough: l.interactionClickThrough,
                    },
                    onChanged: (v) => setState(() => _interaction = v),
                  ),
                  _slider(
                    label: l.scale,
                    value: _scale,
                    min: 0.5,
                    max: 2.0,
                    divisions: 15,
                    display: '${(_scale * 100).round()}%',
                    onChanged: (v) => setState(() => _scale = v),
                  ),
                  _slider(
                    label: l.opacity,
                    value: _opacity,
                    min: 0.2,
                    max: 1.0,
                    divisions: 16,
                    display: '${(_opacity * 100).round()}%',
                    onChanged: (v) => setState(() => _opacity = v),
                  ),
                  _slider(
                    label: l.refresh,
                    value: _poll.toDouble(),
                    min: 1,
                    max: 30,
                    divisions: 29,
                    display: '${_poll}s',
                    onChanged: (v) => setState(() => _poll = v.round()),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(L10n l) {
    // The window is frameless (no OS title bar), so the header doubles as the
    // drag handle — click-drag anywhere on it to move the window.
    return DragToMoveArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Row(
          children: [
            Text('🍒  ${l.settings}',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold)),
            const Spacer(),
            TextButton(
              onPressed: () => widget.onClose(widget.initial),
              child: Text(l.cancel),
            ),
            FilledButton(
              onPressed: () => widget.onClose(_collect()),
              child: Text(l.save),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(t,
            style: const TextStyle(
                color: Color(0xFFFF8FA0),
                fontWeight: FontWeight.bold,
                fontSize: 13)),
      );

  Widget _segmented<T>({
    required T value,
    required Map<T, String> options,
    required ValueChanged<T> onChanged,
  }) {
    return SegmentedButton<T>(
      segments: options.entries
          .map((e) => ButtonSegment(value: e.key, label: Text(e.value)))
          .toList(),
      selected: {value},
      onSelectionChanged: (s) => onChanged(s.first),
    );
  }

  Widget _dropdown<T>({
    required String label,
    required T value,
    required Map<T, String> options,
    required ValueChanged<T> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
              width: 120,
              child:
                  Text(label, style: const TextStyle(color: Colors.white70))),
          Expanded(
            child: DropdownButton<T>(
              value: value,
              isExpanded: true,
              dropdownColor: const Color(0xFF2A1A20),
              items: options.entries
                  .map((e) => DropdownMenuItem(
                      value: e.key,
                      child: Text(e.value,
                          style: const TextStyle(color: Colors.white))))
                  .toList(),
              onChanged: (v) => v == null ? null : onChanged(v),
            ),
          ),
        ],
      ),
    );
  }

  Widget _slider({
    required String label,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required String display,
    required ValueChanged<double> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
              width: 90,
              child:
                  Text(label, style: const TextStyle(color: Colors.white70))),
          Expanded(
            child: Slider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              divisions: divisions,
              label: display,
              onChanged: onChanged,
            ),
          ),
          SizedBox(
              width: 52,
              child: Text(display,
                  textAlign: TextAlign.right,
                  style: const TextStyle(color: Colors.white))),
        ],
      ),
    );
  }

  Widget _stepper(
      String label, int value, int min, int max, ValueChanged<int> onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.white24),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('$label  $value', style: const TextStyle(color: Colors.white)),
          Row(children: [
            IconButton(
              iconSize: 18,
              visualDensity: VisualDensity.compact,
              onPressed: value > min ? () => onChanged(value - 1) : null,
              icon: const Icon(Icons.remove, color: Colors.white70),
            ),
            IconButton(
              iconSize: 18,
              visualDensity: VisualDensity.compact,
              onPressed: value < max ? () => onChanged(value + 1) : null,
              icon: const Icon(Icons.add, color: Colors.white70),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _overrideRow(_OverrideRow r, L10n l) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: TextField(
                controller: r.id,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: l.modelIdHint,
                  hintStyle:
                      const TextStyle(color: Colors.white30, fontSize: 12),
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
                  enabledBorder: const OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.white24)),
                  focusedBorder: const OutlineInputBorder(
                      borderSide: BorderSide(color: Color(0xFFE01E37))),
                ),
              ),
            ),
            IconButton(
              iconSize: 18,
              visualDensity: VisualDensity.compact,
              onPressed: () => _removeOverride(r),
              icon: const Icon(Icons.delete_outline, color: Colors.white54),
            ),
          ]),
          const SizedBox(height: 4),
          Row(children: [
            _priceField(l.priceIn, r.inC, (_) {}),
            const SizedBox(width: 6),
            _priceField(l.priceOut, r.outC, (_) {}),
            const SizedBox(width: 6),
            _priceField(l.priceCacheRd, r.crC, (_) {}),
            const SizedBox(width: 6),
            _priceField(l.priceCacheWr, r.cwC, (_) {}),
          ]),
        ],
      ),
    );
  }

  void _addOverride() {
    setState(() =>
        _overrides.add(_OverrideRow.from('', PricingConfig.unrecognized)));
  }

  void _removeOverride(_OverrideRow r) {
    setState(() => _overrides.remove(r));
    r.dispose();
  }

  Widget _priceField(String label, TextEditingController controller,
      ValueChanged<double> onChanged) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(color: Colors.white54, fontSize: 11)),
          TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: const InputDecoration(
              isDense: true,
              prefixText: '\$',
              prefixStyle: TextStyle(color: Colors.white38, fontSize: 13),
              contentPadding: EdgeInsets.symmetric(vertical: 6, horizontal: 6),
              enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.white24)),
              focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFFE01E37))),
            ),
            onChanged: (t) {
              final v = double.tryParse(t.trim());
              if (v != null && v >= 0) onChanged(v);
            },
          ),
        ],
      ),
    );
  }

  Widget _textField(TextEditingController c,
      {required String label, String? hint}) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: TextField(
        controller: c,
        style: const TextStyle(color: Colors.white, fontSize: 13),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white70),
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.white30, fontSize: 12),
          enabledBorder: const OutlineInputBorder(
              borderSide: BorderSide(color: Colors.white24)),
          focusedBorder: const OutlineInputBorder(
              borderSide: BorderSide(color: Color(0xFFE01E37))),
        ),
      ),
    );
  }
}

/// Mutable holder backing one editable per-model price override row.
class _OverrideRow {
  final TextEditingController id;
  final TextEditingController inC;
  final TextEditingController outC;
  final TextEditingController crC;
  final TextEditingController cwC;

  _OverrideRow.from(String id, ModelPrice m)
      : id = TextEditingController(text: id),
        inC = TextEditingController(
            text: _SettingsWindowState._numStr(m.inputPerMillion)),
        outC = TextEditingController(
            text: _SettingsWindowState._numStr(m.outputPerMillion)),
        crC = TextEditingController(
            text: _SettingsWindowState._numStr(m.cacheReadPerMillion)),
        cwC = TextEditingController(
            text: _SettingsWindowState._numStr(m.cacheCreationPerMillion));

  ModelPrice get price => ModelPrice(
        inputPerMillion: double.tryParse(inC.text.trim()) ?? 0,
        outputPerMillion: double.tryParse(outC.text.trim()) ?? 0,
        cacheReadPerMillion: double.tryParse(crC.text.trim()) ?? 0,
        cacheCreationPerMillion: double.tryParse(cwC.text.trim()) ?? 0,
      );

  void dispose() {
    id.dispose();
    inC.dispose();
    outC.dispose();
    crC.dispose();
    cwC.dispose();
  }
}
