// Moss smoke tests: the app boots to the Photos tab without crashing.
// Note: on a device without photo permission it shows the permission prompt;
// in tests (no permission) the app still builds the shell.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:moss/main.dart';
import 'package:moss/theme.dart';

void main() {
  testWidgets('Moss boots with floating nav and permission prompt',
      (tester) async {
    await tester.pumpWidget(const MossApp());
    await tester.pump();
    // Floating pill nav: 4 tabs.
    expect(find.text('Photos'), findsOneWidget);
    expect(find.text('Albums'), findsOneWidget);
    expect(find.text('Search'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);
    // No photo permission in tests -> permission prompt.
    expect(find.text('Moss needs access to your photos'), findsOneWidget);
  });

  testWidgets('Profile tab shows theme picker', (tester) async {
    await tester.pumpWidget(const MossApp());
    await tester.pump();
    await tester.tap(find.text('Profile'));
    // No pumpAndSettle: the Profile screen shows an indeterminate
    // "scanning sizes" spinner while sizes are incomplete.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Theme'), findsOneWidget);
    expect(find.text('Moss Emerald'), findsOneWidget);
    expect(find.text('Version 1.1.1'), findsOneWidget);
  });

  test('Six themes, each resolvable to light and dark', () {
    expect(MossThemes.all.length, 6);
    for (final def in MossThemes.all) {
      expect(MossThemes.byId(def.id), def);
      final light = MossThemes.themeFor(def, brightness: Brightness.light);
      final dark = MossThemes.themeFor(def, brightness: Brightness.dark);
      expect(light.brightness, Brightness.light);
      expect(dark.brightness, Brightness.dark);
    }
    expect(MossThemes.byId('nope').id, 'emerald');
  });
}
