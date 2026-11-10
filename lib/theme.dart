import 'package:flutter/material.dart';

/// Moss custom theme — organic, soft, nature-inspired. NOT Material 3
/// Expressive: layered soft surfaces, generous rounded shapes (24px cards,
/// 20px buttons, 28px sheets), calm system typography (no runtime font
/// fetching — fully offline, the platform default font is used).
///
/// Six selectable themes, each with light + dark. AMOLED black is a mode
/// on top of any theme: surfaces go pure black.
class MossThemeDef {
  const MossThemeDef({
    required this.id,
    required this.name,
    required this.seed,
    required this.swatchLight,
    required this.swatchDark,
  });

  final String id;
  final String name;
  final Color seed;

  /// Swatch colours shown in the theme picker (light / dark preview).
  final Color swatchLight;
  final Color swatchDark;
}

class MossThemes {
  static const List<MossThemeDef> all = [
    MossThemeDef(
      id: 'emerald',
      name: 'Moss Emerald',
      seed: Color(0xFF10B981),
      swatchLight: Color(0xFF10B981),
      swatchDark: Color(0xFF34D399),
    ),
    MossThemeDef(
      id: 'forest',
      name: 'Forest',
      seed: Color(0xFF2D6A4F),
      swatchLight: Color(0xFF2D6A4F),
      swatchDark: Color(0xFF74C69D),
    ),
    MossThemeDef(
      id: 'dusk',
      name: 'Dusk',
      seed: Color(0xFF7C5CBF),
      swatchLight: Color(0xFF7C5CBF),
      swatchDark: Color(0xFFB79CED),
    ),
    MossThemeDef(
      id: 'sand',
      name: 'Sand',
      seed: Color(0xFFA97C50),
      swatchLight: Color(0xFFA97C50),
      swatchDark: Color(0xFFD9B48F),
    ),
    MossThemeDef(
      id: 'midnight',
      name: 'Midnight',
      seed: Color(0xFF2563EB),
      swatchLight: Color(0xFF2563EB),
      swatchDark: Color(0xFF7AA5F8),
    ),
    MossThemeDef(
      id: 'meadow',
      name: 'Meadow',
      seed: Color(0xFF65A30D),
      swatchLight: Color(0xFF65A30D),
      swatchDark: Color(0xFFA3E635),
    ),
  ];

  static MossThemeDef byId(String id) => all.firstWhere(
        (t) => t.id == id,
        orElse: () => all.first,
      );

  static ThemeData themeFor(
    MossThemeDef def, {
    required Brightness brightness,
    bool amoled = false,
  }) {
    final scheme = ColorScheme.fromSeed(
      seedColor: def.seed,
      brightness: brightness,
    );
    final base = brightness == Brightness.dark
        ? ThemeData.dark(useMaterial3: true)
        : ThemeData.light(useMaterial3: true);

    // Layered surfaces: soft tinted surface, deeper container for cards.
    final scaffold = amoled
        ? Colors.black
        : brightness == Brightness.dark
            ? scheme.surface
            : const Color(0xFFF6F8F5); // soft moss-tinted paper
    final card = amoled
        ? const Color(0xFF121212)
        : brightness == Brightness.dark
            ? scheme.surfaceContainerLow
            : Colors.white;

    // Calm system typography: default platform font, tighter display
    // headings, generous body leading. No downloaded fonts.
    final text = base.textTheme.copyWith(
      displayLarge: base.textTheme.displayLarge?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: -0.5,
      ),
      displayMedium: base.textTheme.displayMedium?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: -0.5,
      ),
      headlineLarge: base.textTheme.headlineLarge?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: -0.5,
      ),
      headlineMedium: base.textTheme.headlineMedium?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: -0.25,
      ),
      titleLarge: base.textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: -0.25,
      ),
      titleMedium: base.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w700,
      ),
      titleSmall: base.textTheme.titleSmall?.copyWith(
        fontWeight: FontWeight.w700,
      ),
      bodyLarge: base.textTheme.bodyLarge?.copyWith(height: 1.45),
      bodyMedium: base.textTheme.bodyMedium?.copyWith(height: 1.45),
    );

    return base.copyWith(
      colorScheme: scheme,
      textTheme: text,
      scaffoldBackgroundColor: scaffold,
      canvasColor: scaffold,
      cardColor: card,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: scaffold,
        foregroundColor: scheme.onSurface,
        titleTextStyle: text.titleLarge?.copyWith(
          color: scheme.onSurface,
          fontSize: 22,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: card,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: TextStyle(color: scheme.onInverseSurface),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        elevation: 0,
        backgroundColor: Colors.transparent,
        indicatorColor: scheme.secondaryContainer,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
            );
          }
          return const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
          );
        }),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        side: BorderSide.none,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: brightness == Brightness.dark
            ? scheme.surfaceContainerHighest
            : scheme.surfaceContainerLow,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide.none,
        ),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant.withValues(alpha: 0.5),
        space: 1,
      ),
    );
  }
}
