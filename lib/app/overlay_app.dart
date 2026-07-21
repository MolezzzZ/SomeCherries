import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import '../data/ccswitch_source.dart';
import '../data/manual_source.dart';
import '../data/settings_repo.dart';
import '../data/usage_source.dart';
import '../domain/cherry_state.dart';
import '../domain/usage.dart';
import '../ui/cherry_grid.dart';
import '../ui/slow_burn.dart';
import '../ui/tooltip_card.dart';
import '../ui/usage_warning_lights.dart';
import 'l10n.dart';
import 'settings.dart';
import 'settings_window.dart';
import 'window_sizing.dart';

class OverlayApp extends StatelessWidget {
  final SettingsRepo repo;
  final AppSettings initialSettings;

  const OverlayApp({
    super.key,
    required this.repo,
    required this.initialSettings,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'ZCOOLKuaiLe',
        scaffoldBackgroundColor: Colors.transparent,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFE01E37),
          brightness: Brightness.dark,
        ),
      ),
      home: OverlayHome(repo: repo, initialSettings: initialSettings),
    );
  }
}

class OverlayHome extends StatefulWidget {
  final SettingsRepo repo;
  final AppSettings initialSettings;

  const OverlayHome({
    super.key,
    required this.repo,
    required this.initialSettings,
  });

  @override
  State<OverlayHome> createState() => _OverlayHomeState();
}

class _OverlayHomeState extends State<OverlayHome>
    with TrayListener, WindowListener {
  late AppSettings _settings;
  late UsageSource _source;
  StreamSubscription<UsageSnapshot>? _sub;

  UsageSnapshot? _snapshot;
  UsageSnapshot? _recentSnapshot;
  UsageSnapshot? _dailySnapshot;
  int _alertRequestSerial = 0;
  bool _hovering = false;
  bool _clickThrough = false;
  bool _showSettings = false;
  bool _placingOverlayWindow = false;
  bool _quitting = false;
  List<String> _detectedModels = const [];
  static const _hitTestChannel = MethodChannel('some_cherries/hit_test');

  void _showTooltipFromPlate() {
    if (_showSettings || _hovering) return;
    if (mounted) setState(() => _hovering = true);
  }

  void _hideTooltip() {
    if (mounted && _hovering) setState(() => _hovering = false);
  }

  @override
  void initState() {
    super.initState();
    _settings = widget.initialSettings;
    trayManager.addListener(this);
    windowManager.addListener(this);
    _source = _buildSource(_settings);
    _setupTray();
    _startPolling();
    _hitTestChannel.setMethodCallHandler(_handleNativeHitTestCall);
    // Enabling the Windows layered/click-through style before Flutter has
    // presented its first frame leaves the transparent window visually blank
    // until the first mouse-driven rebuild. Let the initial plate render first,
    // then enable the native hit-test hook.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(_configureOverlayHitTest(enabled: true));
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _hitTestChannel.setMethodCallHandler(null);
    _configureOverlayHitTest(enabled: false);
    trayManager.removeListener(this);
    windowManager.removeListener(this);
    super.dispose();
  }

  UsageSource _buildSource(AppSettings s) {
    switch (s.source) {
      case SourceKind.ccswitch:
        return CcSwitchSource(dbPath: s.dbPathOverride);
      case SourceKind.manual:
        return ManualSource(pricing: s.pricing);
    }
  }

  void _startPolling() {
    _sub?.cancel();
    final source = _source;
    final query = _settings.query;
    _sub = source
        .watch(query, interval: Duration(seconds: _settings.pollSeconds))
        .listen((snap) {
      if (!mounted || source != _source) return;
      setState(() => _snapshot = snap);
      _refreshAlertMetrics(source, query, snap);
    });
  }

  Future<void> _refreshAlertMetrics(
    UsageSource source,
    UsageQuery currentQuery,
    UsageSnapshot currentSnapshot,
  ) async {
    final serial = ++_alertRequestSerial;
    final base = UsageQuery(
      period: UsagePeriod.day,
      scope: currentQuery.scope,
      projectPath: currentQuery.projectPath,
    );
    try {
      final results = await Future.wait([
        source.read(base.copyWith(rollingWindow: const Duration(minutes: 30))),
        currentQuery.period == UsagePeriod.day &&
                currentQuery.rollingWindow == null
            ? Future.value(currentSnapshot)
            : source.read(base),
      ]);
      if (!mounted || source != _source || serial != _alertRequestSerial) {
        return;
      }
      setState(() {
        _recentSnapshot = results[0];
        _dailySnapshot = results[1];
      });
    } catch (_) {
      // A transient locked/missing data source should not interrupt the plate.
    }
  }

  // ---- Tray -----------------------------------------------------------------

  Future<void> _setupTray() async {
    try {
      final iconPath = await _materializeIcon();
      await trayManager.setIcon(iconPath);
      await trayManager.setToolTip('SomeCherries');
      await _refreshTrayMenu();
    } catch (_) {
      // No system tray (e.g. some Linux WMs). Right-click menu still works
      // while in draggable mode.
    }
  }

  Future<void> _refreshTrayMenu() async {
    final l = L10n(_settings.language);
    await trayManager.setContextMenu(Menu(items: [
      MenuItem(
        key: 'toggle_ct',
        label: _clickThrough ? l.disableClickThrough : l.enableClickThrough,
      ),
      MenuItem(key: 'settings', label: l.settingsMenu),
      MenuItem.separator(),
      MenuItem(key: 'quit', label: l.quit),
    ]));
  }

  Future<String> _materializeIcon() async {
    final asset =
        Platform.isWindows ? 'assets/cherry.ico' : 'assets/cherry.png';
    final bytes = await rootBundle.load(asset);
    final dir = await getApplicationSupportDirectory();
    await dir.create(recursive: true);
    final out = File(p.join(dir.path, p.basename(asset)));
    await out.writeAsBytes(bytes.buffer.asUint8List(), flush: true);
    return out.path;
  }

  @override
  void onTrayIconMouseDown() => trayManager.popUpContextMenu();

  @override
  void onTrayIconRightMouseDown() => trayManager.popUpContextMenu();

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    switch (menuItem.key) {
      case 'toggle_ct':
        _setClickThrough(!_clickThrough);
        break;
      case 'settings':
        _openSettings();
        break;
      case 'quit':
        unawaited(_quit());
        break;
    }
  }

  Future<void> _quit() async {
    if (_quitting) return;
    _quitting = true;
    _alertRequestSerial++;

    final subscription = _sub;
    _sub = null;
    if (subscription != null) {
      unawaited(subscription.cancel());
    }

    // On Windows windowManager.destroy() only posts WM_QUIT. That skips the
    // normal WM_CLOSE/WM_DESTROY sequence and leaves Flutter to tear down the
    // engine after the message loop has already stopped, which can take
    // several seconds. Remove the tray icon first, then close the window via
    // the normal native path so plugin and engine cleanup happens in order.
    try {
      await trayManager.destroy();
    } catch (_) {
      // The tray may be unavailable on this desktop; closing must still work.
    }
    await windowManager.close();
  }

  // ---- Window position persistence ------------------------------------------

  @override
  void onWindowMoved() async {
    if (_showSettings || _placingOverlayWindow) return;
    final pos = await windowManager.getPosition();
    final normalTopLeft =
        Platform.isWindows ? Offset(pos.dx, pos.dy + kTooltipReserve) : pos;
    _settings = _settings.copyWith(
        windowX: normalTopLeft.dx, windowY: normalTopLeft.dy);
    await widget.repo.save(_settings);
  }

  // ---- Interaction ----------------------------------------------------------

  Future<void> _setClickThrough(bool on) async {
    _clickThrough = on;
    if (on) {
      await _configureOverlayHitTest(enabled: false);
      await windowManager.setIgnoreMouseEvents(true, forward: true);
    } else {
      await windowManager.setIgnoreMouseEvents(false);
      await _configureOverlayHitTest(enabled: !_showSettings);
    }
    await _refreshTrayMenu();
    if (mounted) setState(() {});
  }

  Future<void> _openSettings() async {
    if (_clickThrough) await _setClickThrough(false);
    _hideTooltip();
    await _configureOverlayHitTest(enabled: false);
    _detectedModels = await _source.knownModels();
    setState(() => _showSettings = true);
    // Keep the frameless look (no OS title bar) but behave like an ordinary
    // window: shown in the taskbar, *not* always-on-top so other windows can
    // cover it, and movable by dragging the in-app header (DragToMoveArea).
    await windowManager.setAlwaysOnTop(false);
    await windowManager.setSkipTaskbar(false);
    await windowManager.setSize(const Size(440, 660));
    await windowManager.center();
    await windowManager.setIgnoreMouseEvents(false);
  }

  Future<void> _closeSettings(AppSettings updated) async {
    await _applySettings(updated);
    setState(() {
      _showSettings = false;
      _hovering = false;
    });
    // Restore the always-on-top overlay chrome. setAsFrameless() clears any
    // stray window border left behind by the OS.
    await windowManager.setAsFrameless();
    await windowManager.setAlwaysOnTop(true);
    await windowManager.setSkipTaskbar(true);
    _placingOverlayWindow = true;
    try {
      final overlaySize = Platform.isWindows
          ? computeTooltipWindowSize(_settings)
          : computeWindowSize(_settings);
      await windowManager.setSize(overlaySize);
      if (_settings.windowX != null && _settings.windowY != null) {
        final y = Platform.isWindows
            ? _settings.windowY! - kTooltipReserve
            : _settings.windowY!;
        await windowManager.setPosition(Offset(_settings.windowX!, y));
      } else {
        await windowManager.setAlignment(Alignment.bottomRight);
      }
    } finally {
      _placingOverlayWindow = false;
    }
    await _configureOverlayHitTest(enabled: true);
  }

  Future<void> _applySettings(AppSettings updated) async {
    final sourceChanged = updated.source != _settings.source ||
        updated.dbPathOverride != _settings.dbPathOverride ||
        (updated.source == SourceKind.manual &&
            updated.pricing.toJson().toString() !=
                _settings.pricing.toJson().toString());
    _settings = updated;
    await widget.repo.save(_settings);
    if (sourceChanged) _source = _buildSource(_settings);
    _startPolling();
  }

  Future<void> _configureOverlayHitTest({required bool enabled}) async {
    if (!Platform.isWindows) return;
    final content = overlayContentPixelSize(_settings);
    try {
      await _hitTestChannel.invokeMethod<void>('setOverlayHitTest', {
        'enabled': enabled,
        'topPassThroughHeight': kTooltipReserve,
        'interactiveWidth': content.width,
        'interactiveHeight': content.height,
        'bottomPadding': kOuterPadding,
      });
    } catch (_) {
      // Older builds simply won't have the native hook yet.
    }
  }

  Future<dynamic> _handleNativeHitTestCall(MethodCall call) async {
    if (call.method != 'hoverChanged') return null;
    if (_showSettings) return null;

    final hovering = call.arguments == true;
    if (!mounted || _hovering == hovering) return null;
    setState(() => _hovering = hovering);
    return null;
  }

  // ---- Build ----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    if (_showSettings) {
      return SettingsWindow(
        initial: _settings,
        onClose: _closeSettings,
        ccSwitchDefaultPath: CcSwitchSource.defaultDbPath(),
        detectedModels: _detectedModels,
      );
    }

    final targetCost = _snapshot?.totalCostUsd ?? 0;
    // Exact state for the tooltip; the plate itself eases toward it (below).
    final cherryState = CherryState.fromCost(targetCost, _settings.cherry);
    final content = overlayContentPixelSize(_settings);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Opacity(
        opacity: _settings.opacity,
        child: Stack(
          children: [
            // Tooltip floats in the reserved transparent band above the plate.
            // IgnorePointer keeps it from stealing hover events.
            if (_hovering && _snapshot != null)
              Positioned(
                left: kOuterPadding,
                right: kOuterPadding,
                bottom: content.height + kOuterPadding + 8,
                child: IgnorePointer(
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: TooltipCard(
                      snapshot: _snapshot!,
                      cherry: cherryState,
                      recentTokens: _recentSnapshot?.totalTokens ?? 0,
                      dailyCostUsd: _dailySnapshot?.totalCostUsd ?? 0,
                      alerts: _settings.alerts,
                      l10n: L10n(_settings.language),
                    ),
                  ),
                ),
              ),
            // Warning lights and plate sit together at the bottom of the window.
            Positioned(
              left: 0,
              right: 0,
              bottom: kOuterPadding,
              child: Center(
                child: SlowBurn(
                  targetCost: _snapshot?.totalCostUsd,
                  totalTokens: _snapshot?.totalTokens,
                  dollarsPerCherry: _settings.cherry.dollarsPerCherry,
                  pollSeconds: _settings.pollSeconds,
                  builder: (context, animatedCost) {
                    final animState =
                        CherryState.fromCost(animatedCost, _settings.cherry);
                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onPanStart: (_) async {
                        _hideTooltip();
                        await windowManager.startDragging();
                      },
                      onSecondaryTapUp: (d) =>
                          _showContextMenu(d.globalPosition),
                      child: MouseRegion(
                        onEnter: (_) => _showTooltipFromPlate(),
                        onExit: (_) => _hideTooltip(),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            UsageWarningLights(
                              currentPlates:
                                  _settings.cherry.dollarsPerPlate <= 0
                                      ? 0
                                      : animatedCost /
                                          _settings.cherry.dollarsPerPlate,
                              recentTokens: _recentSnapshot?.totalTokens ?? 0,
                              dailyCostUsd: _dailySnapshot?.totalCostUsd ?? 0,
                              config: _settings.alerts,
                              scale: _settings.scale,
                            ),
                            SizedBox(
                                height: kWarningLightsGap * _settings.scale),
                            CherryGrid(
                              state: animState,
                              cherrySize: kBaseCherrySize * _settings.scale,
                              spacing: kCherrySpacing,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showContextMenu(Offset globalPos) async {
    final l = L10n(_settings.language);
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final selected = await showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromLTWH(globalPos.dx, globalPos.dy, 0, 0),
        Offset.zero & overlay.size,
      ),
      items: [
        PopupMenuItem(value: 'settings', child: Text(l.settingsMenu)),
        PopupMenuItem(value: 'clickthrough', child: Text(l.enableClickThrough)),
        const PopupMenuDivider(),
        PopupMenuItem(value: 'quit', child: Text(l.quit)),
      ],
    );
    switch (selected) {
      case 'settings':
        _openSettings();
        break;
      case 'clickthrough':
        _setClickThrough(true);
        break;
      case 'quit':
        await _quit();
        break;
    }
  }
}
