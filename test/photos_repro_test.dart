// Regression tests for the v1.1.0 blank Photos tab (Moto G40, 2026-11-10):
// with permission granted and a real library, the Photos tab rendered a
// completely blank grey screen — no header, no skeleton, no text, no error.
// These tests pump the REAL PhotosScreen with a fake loaded library and
// fail loudly if any widget in the Photos path throws during build/layout.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:moss/providers/gallery_provider.dart';
import 'package:moss/providers/theme_provider.dart';
import 'package:moss/screens/photos_screen.dart';

/// GalleryProvider with permission forced on, so the loaded path renders
/// without touching the photo_manager platform channel.
class _LoadedGallery extends GalleryProvider {
  @override
  bool get hasPermission => true;
}

AssetEntity _fakeAsset(
  String id, {
  required int typeInt,
  required DateTime taken,
  String folder = 'DCIM/Camera',
}) {
  return AssetEntity(
    id: id,
    typeInt: typeInt,
    width: 4000,
    height: 3000,
    title: 'IMG_$id.jpg',
    createDateSecond: taken.millisecondsSinceEpoch ~/ 1000,
    relativePath: '$folder/',
  );
}

/// A realistic library: several days with different group sizes, including
/// single-photo days and a big day, images + videos.
List<AssetEntity> _fakeLibrary() {
  final assets = <AssetEntity>[];
  var n = 0;
  // Day sizes: 1, 2, 3, 4, 5, 7, 10, 100 — the quilted grid pattern is
  // built per day-group, so every size must lay out without throwing.
  for (final daySize in [1, 2, 3, 4, 5, 7, 10, 100]) {
    final day = DateTime(2026, 11, 10).subtract(Duration(days: n));
    for (var i = 0; i < daySize; i++) {
      assets.add(_fakeAsset(
        'a${n}_$i',
        // typeInt follows AssetType.values: 0 = image, 1 = video.
        typeInt: i % 9 == 0 ? 1 : 0,
        taken: day.subtract(Duration(minutes: i)),
      ));
    }
    n++;
  }
  // An asset with no date at all (createDateSecond null -> epoch 1970).
  assets.add(AssetEntity(
    id: 'nodate',
    typeInt: 0,
    width: 100,
    height: 100,
    title: 'nodate.jpg',
    relativePath: 'DCIM/Camera/',
  ));
  return assets;
}

Future<void> _pumpPhotos(
  WidgetTester tester,
  GalleryProvider gallery,
) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.5;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: MultiProvider(
          providers: [
            ChangeNotifierProvider<ThemeProvider>(
              create: (_) => ThemeProvider(),
            ),
            ChangeNotifierProvider<GalleryProvider>.value(value: gallery),
          ],
          child: const PhotosScreen(),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  testWidgets('Photos tab renders header + grid with a loaded library',
      (tester) async {
    final gallery = _LoadedGallery()..assets = _fakeLibrary();
    await _pumpPhotos(tester, gallery);

    // The build must not have thrown (in release a throw = blank grey).
    expect(tester.takeException(), isNull);
    // Header + counts visible.
    expect(find.text('Moss'), findsOneWidget);
    expect(find.textContaining('photos'), findsWidgets);
    // Date headers visible.
    expect(find.textContaining('Nov 2026'), findsWidgets);
    // No blank-screen states.
    expect(
      find.text('No photos or videos found on this device.'),
      findsNothing,
    );
  });

  testWidgets('Photos tab renders in list and compact views too',
      (tester) async {
    for (final view in [MossView.list, MossView.compact, MossView.grid]) {
      final gallery = _LoadedGallery()
        ..assets = _fakeLibrary()
        ..photosView = view;
      await _pumpPhotos(tester, gallery);
      expect(
        tester.takeException(),
        isNull,
        reason: 'Photos tab threw in $view view',
      );
      expect(find.text('Moss'), findsOneWidget);
    }
  });

  testWidgets('Photos tab with pinch columns 2..6 renders',
      (tester) async {
    for (var columns = 2; columns <= 6; columns++) {
      final gallery = _LoadedGallery()
        ..assets = _fakeLibrary()
        ..columns = columns;
      await _pumpPhotos(tester, gallery);
      expect(
        tester.takeException(),
        isNull,
        reason: 'Photos tab threw with $columns columns',
      );
    }
  });

  testWidgets('Photos tab loading state shows title + progress text',
      (tester) async {
    final gallery = _LoadedGallery()..loading = true;
    await _pumpPhotos(tester, gallery);
    expect(tester.takeException(), isNull);
    expect(find.text('Moss'), findsOneWidget);
    expect(find.textContaining('Loading'), findsWidgets);
  });

  testWidgets('Photos tab denied state shows allow + settings buttons',
      (tester) async {
    final gallery = GalleryProvider(); // permission notDetermined
    await _pumpPhotos(tester, gallery);
    expect(tester.takeException(), isNull);
    expect(find.text('Moss needs access to your photos'), findsOneWidget);
    expect(find.text('Allow photo access'), findsOneWidget);
  });

  testWidgets('Photos tab error state shows message + retry',
      (tester) async {
    final gallery = _LoadedGallery()
      ..loading = false
      ..error = 'PlatformException(permission, denied, null, null)';
    await _pumpPhotos(tester, gallery);
    expect(tester.takeException(), isNull);
    expect(find.textContaining('Couldn'), findsWidgets);
    expect(find.text('Try again'), findsOneWidget);
  });

  testWidgets('Photos tab empty library shows empty text',
      (tester) async {
    final gallery = _LoadedGallery()..loading = false;
    await _pumpPhotos(tester, gallery);
    expect(tester.takeException(), isNull);
    expect(
      find.text('No photos or videos found on this device.'),
      findsOneWidget,
    );
  });
}
