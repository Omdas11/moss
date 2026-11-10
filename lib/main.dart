import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/gallery_provider.dart';
import 'providers/theme_provider.dart';
import 'screens/albums_screen.dart';
import 'screens/photos_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/search_screen.dart';
import 'services/diagnostics.dart';

void main() {
  // A widget that throws during build renders as a blank grey screen in
  // release mode (v1.1.0 Photos tab). Never let that happen silently
  // again: log every widget/provider error, and replace the failed
  // subtree with a visible error screen that offers a retry.
  FlutterError.onError = (details) {
    MossLog().log(
      'error',
      'Widget error: ${details.exceptionAsString()}',
      level: 'error',
    );
    FlutterError.presentError(details);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    MossLog().log('error', 'Uncaught error: $error', level: 'error');
    return true;
  };
  ErrorWidget.builder = (details) => _TabErrorView(details: details);
  MossLog().log('app', 'Moss $kMossVersion+$kMossBuild started');
  runApp(const MossApp());
}

/// Incremented when the user taps "Try again" on a tab error screen:
/// the shell remounts the tab screens, so a transient failure recovers
/// instead of staying blank.
class MossErrorRecovery {
  static final ValueNotifier<int> tick = ValueNotifier<int>(0);

  static void requestRebuild() => tick.value++;
}

/// Shown in place of any widget subtree that fails to build, instead of
/// Flutter's blank grey box. Includes the error and a retry button.
class _TabErrorView extends StatelessWidget {
  const _TabErrorView({required this.details});

  final FlutterErrorDetails details;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48),
            const SizedBox(height: 12),
            const Text(
              'Something went wrong in this tab',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              details.exceptionAsString(),
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: MossErrorRecovery.requestRebuild,
              child: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}

class MossApp extends StatelessWidget {
  const MossApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()..load()),
        ChangeNotifierProvider(create: (_) => GalleryProvider()..init()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          final brightness = MediaQuery.platformBrightnessOf(context);
          return MaterialApp(
            title: 'Moss',
            debugShowCheckedModeBanner: false,
            theme: themeProvider.resolve(brightness),
            home: const MainShell(),
          );
        },
      ),
    );
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  void _goToPhotos() => setState(() => _index = 0);

  @override
  Widget build(BuildContext context) {
    final screens = [
      const PhotosScreen(),
      AlbumsScreen(onGoToPhotos: _goToPhotos),
      const SearchScreen(),
      const ProfileScreen(),
    ];

    return Scaffold(
      // No top AppBar here: each tab owns its header (Photos uses a
      // SliverAppBar, the others a plain AppBar). The bottom nav is a
      // floating pill dock — content scrolls underneath it.
      body: Stack(
        children: [
          ValueListenableBuilder<int>(
            valueListenable: MossErrorRecovery.tick,
            builder: (_, tick, _) => IndexedStack(
              // Changing the key remounts the tabs after a "Try again"
              // on an error screen.
              key: ValueKey<int>(tick),
              index: _index,
              children: screens,
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: SafeArea(
              top: false,
              child: _FloatingNav(
                index: _index,
                onSelect: (i) => setState(() => _index = i),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Floating pill dock: a rounded container ~16px above the bottom, with a
/// shadow, so page content scrolls underneath it. Selection animates.
class _FloatingNav extends StatelessWidget {
  const _FloatingNav({required this.index, required this.onSelect});

  final int index;
  final void Function(int) onSelect;

  static const _items = [
    (Icons.photo_library_outlined, Icons.photo_library, 'Photos'),
    (Icons.folder_outlined, Icons.folder, 'Albums'),
    (Icons.search_outlined, Icons.search, 'Search'),
    (Icons.person_outlined, Icons.person, 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      elevation: 8,
      shadowColor: Colors.black.withValues(alpha: 0.25),
      color: scheme.surfaceContainerHigh,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(32),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          children: [
            for (var i = 0; i < _items.length; i++)
              Expanded(
                child: _NavItem(
                  icon: _items[i].$1,
                  selectedIcon: _items[i].$2,
                  label: _items[i].$3,
                  selected: index == i,
                  onTap: () => onSelect(i),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? scheme.secondaryContainer
              : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedScale(
              scale: selected ? 1.12 : 1.0,
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              child: Icon(
                selected ? selectedIcon : icon,
                color: selected
                    ? scheme.onSecondaryContainer
                    : scheme.onSurfaceVariant,
                size: 22,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight:
                    selected ? FontWeight.w700 : FontWeight.w500,
                color: selected
                    ? scheme.onSecondaryContainer
                    : scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
