import 'dart:io';

import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import 'app/overlay_app.dart';
import 'app/settings.dart';
import 'app/window_sizing.dart';
import 'data/settings_repo.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();

  final repo = SettingsRepo();
  final settings = await repo.load();
  final implicitView = WidgetsBinding.instance.platformDispatcher.implicitView;
  final textScaleFactor = implicitView == null
      ? 1.0
      : MediaQueryData.fromView(implicitView).textScaler.scale(12) / 12;
  final tooltipReserve = tooltipReserveFor(textScaleFactor);

  final size = Platform.isWindows
      ? computeTooltipWindowSize(
          settings,
          textScaleFactor: textScaleFactor,
        )
      : computeWindowSize(settings);
  final options = WindowOptions(
    size: size,
    backgroundColor: Colors.transparent,
    skipTaskbar: true,
    titleBarStyle: TitleBarStyle.hidden,
    windowButtonVisibility: false,
  );

  await windowManager.waitUntilReadyToShow(options, () async {
    await windowManager.setAsFrameless();
    await windowManager.setBackgroundColor(Colors.transparent);
    await windowManager.setAlwaysOnTop(true);
    await windowManager.setSkipTaskbar(true);
    await windowManager.setResizable(false);
    if (!Platform.isLinux) {
      await windowManager.setHasShadow(false);
    }
    await _positionWindow(settings, tooltipReserve);
    await windowManager.show();
  });

  runApp(OverlayApp(
    repo: repo,
    initialSettings: settings,
    initialTextScaleFactor: textScaleFactor,
  ));
}

Future<void> _positionWindow(
  AppSettings s,
  double tooltipReserve,
) async {
  if (s.windowX != null && s.windowY != null) {
    final y = Platform.isWindows ? s.windowY! - tooltipReserve : s.windowY!;
    await windowManager.setPosition(Offset(s.windowX!, y));
  } else {
    // Snap to bottom-right of the primary display on first run.
    await windowManager.setAlignment(Alignment.bottomRight);
  }
}
