import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // ─── Brand Colors ────────────────────────────────────────────────────────────
  static const Color primary = Color(0xFF1A56DB); // Vibrant brand blue
  static const Color primaryDark = Color(0xFF0A3F8B); // Deep navy
  static const Color primaryLight = Color(0xFF3B82F6); // Sky blue
  static const Color primaryContainer = Color(0xFFDBEAFE); // Light blue tint

  static const Color accent = Color(0xFF00B4A6); // Vibrant teal
  static const Color accentLight = Color(0xFFCCF5F2); // Teal tint

  static const Color background = Color(0xFFF8FAFF); // Soft blue-white
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFF1F5FF); // Slight blue tint

  static const Color darkText = Color(0xFF0F172A); // Slate 900
  static const Color bodyText = Color(0xFF334155); // Slate 700
  static const Color subtitleText = Color(0xFF64748B); // Slate 500
  static const Color hintText = Color(0xFF94A3B8); // Slate 400

  static const Color border = Color(0xFFE2E8F0); // Slate 200
  static const Color divider = Color(0xFFF1F5F9); // Slate 100

  static const Color green = Color(0xFF10B981); // Emerald 500
  static const Color lightGreen = Color(0xFFD1FAE5); // Emerald 100
  static const Color amber = Color(0xFFF59E0B); // Amber 500
  static const Color lightAmber = Color(0xFFFEF3C7); // Amber 100
  static const Color red = Color(0xFFEF4444); // Red 500
  static const Color lightRed = Color(0xFFFEE2E2); // Red 100

  // Legacy aliases (keep existing code working)
  static const Color primaryPeach = primaryContainer;
  static const Color lightGray = surfaceVariant;

  // ─── Gradients ───────────────────────────────────────────────────────────────
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1A56DB), Color(0xFF0EA5E9)],
  );

  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF0A3F8B), Color(0xFF1A56DB), Color(0xFF0EA5E9)],
    stops: [0.0, 0.6, 1.0],
  );

  static const LinearGradient cardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1A56DB), Color(0xFF6366F1)],
  );

  static const LinearGradient accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF00B4A6), Color(0xFF10B981)],
  );

  // ─── MaterialApp ThemeData ───────────────────────────────────────────────────
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      textTheme: GoogleFonts.robotoTextTheme(),
      fontFamily: GoogleFonts.roboto().fontFamily,
      colorScheme: const ColorScheme(
        brightness: Brightness.light,
        primary: primary,
        onPrimary: Colors.white,
        primaryContainer: primaryContainer,
        onPrimaryContainer: primaryDark,
        secondary: accent,
        onSecondary: Colors.white,
        secondaryContainer: accentLight,
        onSecondaryContainer: Color(0xFF003733),
        surface: surface,
        onSurface: darkText,
        surfaceContainerHighest: surfaceVariant,
        onSurfaceVariant: subtitleText,
        outline: border,
        outlineVariant: divider,
        error: red,
        onError: Colors.white,
        errorContainer: lightRed,
        onErrorContainer: Color(0xFF7F1D1D),
        shadow: Color(0xFF000000),
        scrim: Color(0xFF000000),
        inverseSurface: darkText,
        onInverseSurface: Colors.white,
        inversePrimary: primaryLight,
      ),
      scaffoldBackgroundColor: background,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: darkText),
        titleTextStyle: TextStyle(
          color: darkText,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          side: const BorderSide(color: border, width: 1.5),
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceVariant,
        hintStyle: const TextStyle(color: hintText, fontSize: 14),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: border, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: primary, width: 1.8),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: red, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: red, width: 1.8),
        ),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: border, width: 1),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surfaceVariant,
        selectedColor: primaryContainer,
        labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        contentTextStyle: const TextStyle(color: Colors.white, fontSize: 14),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.transparent,
        elevation: 0,
        selectedItemColor: primary,
        unselectedItemColor: subtitleText,
        showUnselectedLabels: true,
        selectedLabelStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
        unselectedLabelStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
        type: BottomNavigationBarType.fixed,
      ),
    );
  }

  // ─── Decoration Helpers ──────────────────────────────────────────────────────

  /// Premium card with subtle shadow
  static BoxDecoration premiumCardDecoration({
    Color color = surface,
    double radius = 20.0,
    bool withShadow = true,
  }) {
    return BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: border, width: 1),
      boxShadow: withShadow
          ? [
              BoxShadow(
                color: const Color(0xFF1A56DB).withAlpha(12),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
              BoxShadow(
                color: Colors.black.withAlpha(6),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ]
          : null,
    );
  }

  /// Glassmorphism card
  static BoxDecoration glassDecoration({
    Color baseColor = Colors.white,
    double opacity = 0.12,
    double radius = 20.0,
  }) {
    return BoxDecoration(
      color: baseColor.withAlpha((opacity * 255).round()),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: Colors.white.withAlpha(50),
        width: 1,
      ),
    );
  }

  /// Gradient primary button decoration
  static BoxDecoration gradientButtonDecoration({double radius = 16}) {
    return BoxDecoration(
      gradient: primaryGradient,
      borderRadius: BorderRadius.circular(radius),
      boxShadow: [
        BoxShadow(
          color: primary.withAlpha(80),
          blurRadius: 16,
          offset: const Offset(0, 6),
        ),
      ],
    );
  }

  // ─── Input Decoration Helper ─────────────────────────────────────────────────
  static InputDecoration inputDecoration({
    required String hintText,
    required IconData prefixIcon,
    Widget? suffixIcon,
    String? labelText,
  }) {
    return InputDecoration(
      hintText: hintText,
      labelText: labelText,
      hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
      prefixIcon: Icon(prefixIcon, color: subtitleText, size: 20),
      suffixIcon: suffixIcon,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      filled: true,
      fillColor: surfaceVariant,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: border, width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: border, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: primary, width: 1.8),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: red, width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: red, width: 1.8),
      ),
    );
  }

  // ─── Typography Tokens ───────────────────────────────────────────────────────
  static const TextStyle brandLogoStyle = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w800,
    color: primary,
    letterSpacing: -0.8,
  );

  static const TextStyle screenTitleStyle = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w800,
    color: darkText,
    letterSpacing: -0.8,
  );

  static const TextStyle sectionTitleStyle = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    color: darkText,
    letterSpacing: -0.4,
  );

  static const TextStyle bodyBoldStyle = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    color: darkText,
  );

  static const TextStyle bodyMediumStyle = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: bodyText,
  );

  static const TextStyle captionStyle = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: subtitleText,
  );

  static const TextStyle labelStyle = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w700,
    color: subtitleText,
    letterSpacing: 0.8,
  );
}
