import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Paleta moderna por defecto (Azul Eléctrico / Slate Profesional)
  static const Color primary = Color(0xFF2563EB);
  static const Color brandPrimary = primary; // Royal Blue moderno
  static const Color secondary = Color(0xFF0EA5E9); // Sky Cyan
  static const Color accent = Color(0xFF10B981); // Emerald
  static const Color background = Color(0xFFF8FAFC); // Slate 50 limpio
  static const Color surface = Color(0xFFFFFFFF);
  static const Color cardBg = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFF0F172A); // Slate 900
  static const Color textSecondary = Color(0xFF64748B); // Slate 500

  // Colores para Modo Oscuro
  static const Color darkBackground = Color(0xFF090D16); // Slate 950 Deep
  static const Color darkSurface = Color(0xFF1E293B); // Slate 800
  static const Color darkCardBg = Color(0xFF1E293B);
  static const Color darkTextPrimary = Color(0xFFF8FAFC);
  static const Color darkTextSecondary = Color(0xFF94A3B8);

  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF2563EB), Color(0xFF38BDF8)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient salesGradient = LinearGradient(
    colors: [Color(0xFF10B981), Color(0xFF34D399)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient stockGradient = LinearGradient(
    colors: [Color(0xFF6366F1), Color(0xFF818CF8)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient productionGradient = LinearGradient(
    colors: [Color(0xFFF59E0B), Color(0xFFFBBF24)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static Color parseHexColor(String? hexString, {Color defaultColor = primary}) {
    if (hexString == null || hexString.isEmpty) return defaultColor;
    try {
      final buffer = StringBuffer();
      if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
      buffer.write(hexString.replaceFirst('#', ''));
      return Color(int.parse(buffer.toString(), radix: 16));
    } catch (_) {
      return defaultColor;
    }
  }

  static LinearGradient createCustomGradient(Color color) {
    return LinearGradient(
      colors: [color, color.withValues(alpha: 0.8)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }

  static final Map<String, ThemeData> _themeCache = {};

  /// ThemeData es costoso de construir (GoogleFonts). Se memoriza por color/modo
  /// para que cambiar entre claro y oscuro no reconstruya nada.
  static ThemeData getTheme([Color brandColor = primary, bool isDark = false]) {
    final key = '${brandColor.toARGB32()}_$isDark';
    return _themeCache.putIfAbsent(key, () => _buildTheme(brandColor, isDark));
  }

  static ThemeData _buildTheme(Color brandColor, bool isDark) {
    final baseBg = isDark ? darkBackground : background;
    final baseSurface = isDark ? darkSurface : surface;
    final txtPrimary = isDark ? darkTextPrimary : textPrimary;
    final txtSecondary = isDark ? darkTextSecondary : textSecondary;

    final baseTextTheme = GoogleFonts.plusJakartaSansTextTheme(
      isDark ? ThemeData.dark().textTheme : ThemeData.light().textTheme,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: isDark ? Brightness.dark : Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: brandColor,
        brightness: isDark ? Brightness.dark : Brightness.light,
        surface: baseSurface,
      ).copyWith(primary: brandColor, surface: baseSurface),
      scaffoldBackgroundColor: baseBg,
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.fuchsia: FadeForwardsPageTransitionsBuilder(),
      }),
      dialogTheme: DialogThemeData(
        backgroundColor: baseSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: baseSurface,
        modalBackgroundColor: baseSurface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: isDark ? const Color(0xFF38BDF8) : brandColor,
        unselectedLabelColor: txtSecondary,
        indicatorColor: isDark ? const Color(0xFF38BDF8) : brandColor,
        dividerColor: Colors.transparent,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: brandColor),
      dividerTheme: DividerThemeData(
        color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
      ),
      textTheme: baseTextTheme.copyWith(
        bodyLarge: baseTextTheme.bodyLarge?.copyWith(color: txtPrimary),
        bodyMedium: baseTextTheme.bodyMedium?.copyWith(color: txtPrimary),
        titleLarge: baseTextTheme.titleLarge?.copyWith(color: txtPrimary, fontWeight: FontWeight.w700),
        titleMedium: baseTextTheme.titleMedium?.copyWith(color: txtPrimary, fontWeight: FontWeight.w600),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        titleTextStyle: GoogleFonts.plusJakartaSans(
          color: txtPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
        iconTheme: IconThemeData(color: txtPrimary),
      ),
      cardTheme: CardThemeData(
        color: baseSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        labelStyle: TextStyle(
          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
          fontWeight: FontWeight.w500,
        ),
        floatingLabelStyle: TextStyle(
          color: isDark ? const Color(0xFF38BDF8) : brandColor,
          fontWeight: FontWeight.w600,
        ),
        hintStyle: TextStyle(
          color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: isDark ? const Color(0xFF334155) : Colors.transparent,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: isDark ? const Color(0xFF334155) : Colors.transparent,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: isDark ? const Color(0xFF38BDF8) : brandColor,
            width: 2,
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: brandColor,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }

  static ThemeData get theme => getTheme(primary, false);
}

/// Colores que se adaptan a modo claro/oscuro y al color de marca del negocio.
extension AppColors on BuildContext {
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
  Color get brand => Theme.of(this).colorScheme.primary;
  Color get surfaceColor => Theme.of(this).colorScheme.surface;
  Color get scaffoldBg => isDark ? AppTheme.darkBackground : AppTheme.background;
  Color get textMain => isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary;
  Color get textMuted => isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary;
  Color get borderColor => isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
}
