import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../app/settings.dart';

/// Loads and saves [AppSettings] as JSON under the app support directory.
class SettingsRepo {
  File? _file;

  Future<File> _resolveFile() async {
    if (_file != null) return _file!;
    final dir = await getApplicationSupportDirectory();
    await dir.create(recursive: true);
    return _file = File(p.join(dir.path, 'settings.json'));
  }

  Future<AppSettings> load() async {
    try {
      final f = await _resolveFile();
      if (!f.existsSync()) return const AppSettings();
      final raw = await f.readAsString();
      if (raw.trim().isEmpty) return const AppSettings();
      return AppSettings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      // Corrupt or unreadable config should never crash the overlay.
      return const AppSettings();
    }
  }

  Future<void> save(AppSettings settings) async {
    final f = await _resolveFile();
    await f.writeAsString(
      const JsonEncoder.withIndent('  ').convert(settings.toJson()),
    );
  }
}
