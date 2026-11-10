import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/gallery_provider.dart';
import 'providers/theme_provider.dart';
import 'screens/albums_screen.dart';
import 'screens/photos_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/search_screen.dart';

void main() {
  runApp(const MossApp());
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
          IndexedStack(index: _index, children: screens),
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
