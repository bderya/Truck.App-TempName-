import 'package:flutter/material.dart';

/// Dark theme with blue and gold accents for the admin dashboard.
class AdminTheme {
  AdminTheme._();

  static const Color _bluePrimary = Color(0xFF1E88E5);
  static const Color _blueDark = Color(0xFF0D47A1);
  static const Color _goldAccent = Color(0xFFD4AF37);
  static const Color _goldLight = Color(0xFFF5D547);
  static const Color _surfaceDark = Color(0xFF121212);
  static const Color _surfaceVariant = Color(0xFF1E1E1E);
  static const Color _surfaceCard = Color(0xFF252525);

  static ThemeData get dark {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.dark(
        primary: _bluePrimary,
        onPrimary: Colors.white,
        primaryContainer: _blueDark,
        onPrimaryContainer: Colors.white70,
        secondary: _goldAccent,
        onSecondary: Colors.black87,
        secondaryContainer: const Color(0xFF3D3520),
        onSecondaryContainer: _goldLight,
        surface: _surfaceDark,
        onSurface: Colors.white,
        surfaceContainerHighest: _surfaceVariant,
        onSurfaceVariant: Colors.white70,
        outline: Colors.white24,
        error: const Color(0xFFCF6679),
        onError: Colors.black,
      ),
      scaffoldBackgroundColor: _surfaceDark,
      appBarTheme: const AppBarTheme(
        backgroundColor: _surfaceVariant,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      cardTheme: CardTheme(
        color: _surfaceCard,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _bluePrimary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: _goldAccent,
          side: const BorderSide(color: _goldAccent),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return _goldAccent;
          return Colors.white54;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return _goldAccent.withValues(alpha: 0.5);
          return Colors.white24;
        }),
      ),
      dataTableTheme: DataTableThemeData(
        headingRowColor: WidgetStateProperty.all(_surfaceVariant),
        dataRowBorder: BorderSide(color: Colors.white10),
        headingTextStyle: const TextStyle(
          fontWeight: FontWeight.w600,
          color: _goldAccent,
        ),
      ),
    );
  }
}
