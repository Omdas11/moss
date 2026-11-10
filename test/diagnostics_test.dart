// Diagnostics log + local notifications: unit tests.
// The log is a ring buffer (last 500 entries) and must never throw,
// even when persistence is unavailable (as in tests, where
// path_provider has no platform channel). Notifications must also
// never throw when the plugin has no platform channel.
import 'package:flutter_test/flutter_test.dart';

import 'package:moss/services/diagnostics.dart';
import 'package:moss/services/notifications.dart';

void main() {
  test('MossLog keeps the last 500 entries', () async {
    await MossLog().clear();
    for (var i = 0; i < 520; i++) {
      MossLog().log('test', 'entry $i');
    }
    expect(MossLog().entries.length, MossLog.maxEntries);
    expect(MossLog().entries.first.message, 'entry 20');
    expect(MossLog().entries.last.message, 'entry 519');
  });

  test('MossLog export text is timestamped lines', () async {
    await MossLog().clear();
    MossLog().log('library', 'Load finished: 42 assets');
    final text = await MossLog().exportText();
    expect(text, contains('[library] Load finished: 42 assets'));
    expect(text, contains('2026-'));
  });

  test('MossLog clear empties the log', () async {
    MossLog().log('test', 'something');
    await MossLog().clear();
    expect(MossLog().entries, isEmpty);
  });

  test('Notifications never throw without a platform channel', () async {
    await MossNotifications().showScanComplete(
      groups: 3,
      similar: 5,
      blurry: 1,
    );
    await MossNotifications().showExportSaved('Collage');
    await MossNotifications().showLibraryLoadFailed('test failure');
  });
}
