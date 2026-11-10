import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Moss version shown in Profile and written into the log.
const kMossVersion = '1.1.1';
const kMossBuild = 3;

/// One diagnostic log entry.
class LogEntry {
  LogEntry({
    required this.timestamp,
    required this.level,
    required this.tag,
    required this.message,
  });

  factory LogEntry.fromJson(Map<String, dynamic> j) => LogEntry(
        timestamp: DateTime.fromMillisecondsSinceEpoch(j['ts'] as int),
        level: j['level'] as String? ?? 'info',
        tag: j['tag'] as String? ?? '',
        message: j['message'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
        'ts': timestamp.millisecondsSinceEpoch,
        'level': level,
        'tag': tag,
        'message': message,
      };

  /// One line, e.g. `2026-11-10 22:15:03 [library] First page loaded…`.
  String get line =>
      '${timestamp.toIso8601String().replaceFirst('T', ' ').substring(0, 19)} '
      '[$tag] $message';

  final DateTime timestamp;
  final String level;
  final String tag;
  final String message;
}

/// Persistent in-app diagnostic log.
///
/// A ring buffer of the last [maxEntries] timestamped entries, kept in
/// memory and persisted to a JSON file in the app's documents folder.
/// This is what lets us diagnose a blank screen next time without
/// guessing: app start, permission results, library load progress and
/// errors, scan start/stop/finish, and caught widget/provider errors
/// are all recorded here.
///
/// Logging never blocks the UI and never throws: persistence failures
/// (e.g. in tests, where path_provider has no platform channel) just
/// leave the log memory-only.
class MossLog {
  MossLog._();

  static final MossLog _instance = MossLog._();

  factory MossLog() => _instance;

  static const int maxEntries = 500;
  static const String fileName = 'moss_diagnostics.json';

  final List<LogEntry> _entries = [];
  bool _loaded = false;
  Timer? _saveTimer;

  List<LogEntry> get entries => List.unmodifiable(_entries);

  void log(String tag, String message, {String level = 'info'}) {
    final entry = LogEntry(
      timestamp: DateTime.now(),
      level: level,
      tag: tag,
      message: message,
    );
    _entries.add(entry);
    if (_entries.length > maxEntries) {
      _entries.removeRange(0, _entries.length - maxEntries);
    }
    debugPrint('[Moss][$tag] $message');
    _scheduleSave();
  }

  /// Loads persisted entries (oldest first) and merges them with any
  /// entries already logged in memory this session.
  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final file = await _logFile();
      if (!await file.exists()) return;
      final raw = jsonDecode(await file.readAsString()) as List;
      final saved = raw
          .map((e) => LogEntry.fromJson(e as Map<String, dynamic>))
          .toList();
      final lastSavedMs = saved.isEmpty
          ? 0
          : saved.last.timestamp.millisecondsSinceEpoch;
      final fresh = _entries
          .where(
            (e) => e.timestamp.millisecondsSinceEpoch > lastSavedMs,
          )
          .toList();
      _entries
        ..clear()
        ..addAll(saved)
        ..addAll(fresh);
      if (_entries.length > maxEntries) {
        _entries.removeRange(0, _entries.length - maxEntries);
      }
    } catch (_) {
      // No persisted log (or corrupt) — memory-only is fine.
    }
  }

  /// Whole log as plain text, oldest first, for copy/share/export.
  Future<String> exportText() async {
    await load();
    return entries.map((e) => e.line).join('\n');
  }

  Future<void> clear() async {
    _entries.clear();
    try {
      final file = await _logFile();
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }

  void _scheduleSave() {
    // No persistence under flutter_test: the fake-async zone fails
    // tests with a pending 500ms timer, and tests only need the
    // in-memory log.
    if (Platform.environment.containsKey('FLUTTER_TEST')) return;
    // Debounced: a burst of log lines writes the file once, not per line.
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 500), () {
      unawaited(_saveNow());
    });
  }

  Future<void> _saveNow() async {
    try {
      final file = await _logFile();
      await file.writeAsString(
        jsonEncode(_entries.map((e) => e.toJson()).toList()),
      );
    } catch (_) {}
  }

  Future<File> _logFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$fileName');
  }
}
