import 'package:flutter/material.dart';

/// 🎨 BLOOD APP THEME - Soft, Light & Eye-Pleasing
class BloodAppTheme {
  // ═══════════════════════════════════════════════════════════════
  // 🎨 PRIMARY COLORS - Soft Teal (Calming & Professional)
  // ═══════════════════════════════════════════════════════════════

  static const Color primary = Color(0xFF5DADE2); // Soft Sky Blue
  static const Color primaryLight = Color(0xFF85C1E9);
  static const Color primaryDark = Color(0xFF3498DB);

  // Soft Rose for Recipient/Blood theme (not harsh red)
  static const Color accent = Color(0xFFE8A0BF); // Soft Rose Pink
  static const Color accentLight = Color(0xFFF5B7CD);
  static const Color accentDark = Color(0xFFD980A8);

  // ═══════════════════════════════════════════════════════════════
  // 🎨 STATUS COLORS - Softer Pastels
  // ═══════════════════════════════════════════════════════════════

  static const Color success = Color(0xFF7DCEA0); // Soft Mint Green
  static const Color warning = Color(0xFFF8C471); // Soft Amber
  static const Color error = Color(0xFFE57373); // Soft Coral Red
  static const Color info = Color(0xFF7FB3D5); // Soft Blue

  // ═══════════════════════════════════════════════════════════════
  // 🎨 URGENCY COLORS - Lighter Shades
  // ═══════════════════════════════════════════════════════════════

  static const Color emergency = Color(0xFFEC7063); // Soft Coral
  static const Color urgent = Color(0xFFF5B041); // Soft Orange
  static const Color normal = Color(0xFF5DADE2); // Soft Blue
  static const Color low = Color(0xFF58D68D); // Soft Green

  // ═══════════════════════════════════════════════════════════════
  // 🎨 BACKGROUND COLORS - Clean & Light
  // ═══════════════════════════════════════════════════════════════

  static const Color background = Color(0xFFF8FAFC); // Very Light Gray-Blue
  static const Color surface = Colors.white;
  static const Color cardBackground = Colors.white;

  // ═══════════════════════════════════════════════════════════════
  // 🎨 TEXT COLORS - Soft & Readable
  // ═══════════════════════════════════════════════════════════════

  static const Color textPrimary = Color(0xFF2C3E50); // Soft Dark Blue
  static const Color textSecondary = Color(0xFF7F8C8D); // Soft Gray
  static const Color textHint = Color(0xFFBDC3C7); // Light Gray

  // ═══════════════════════════════════════════════════════════════
  // 🩸 BLOOD TYPE COLORS - Softer Palette
  // ═══════════════════════════════════════════════════════════════

  static Color getBloodTypeColor(String bloodType) {
    switch (bloodType) {
      case 'A+':
        return const Color(0xFFE57373); // Soft Red
      case 'A-':
        return const Color(0xFFEF5350);
      case 'B+':
        return const Color(0xFF64B5F6); // Soft Blue
      case 'B-':
        return const Color(0xFF42A5F5);
      case 'AB+':
        return const Color(0xFFBA68C8); // Soft Purple
      case 'AB-':
        return const Color(0xFFAB47BC);
      case 'O+':
        return const Color(0xFF81C784); // Soft Green
      case 'O-':
        return const Color(0xFF66BB6A);
      default:
        return const Color(0xFF90A4AE); // Soft Gray
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // 🎨 GRADIENTS - Soft & Elegant
  // ═══════════════════════════════════════════════════════════════

  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF5DADE2), Color(0xFF3498DB)],
  );

  static const LinearGradient accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFE8A0BF), Color(0xFFD980A8)],
  );

  // Soft gradient for recipient (rose theme)
  static const LinearGradient recipientGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFE8A0BF), Color(0xFFD980A8)],
  );

  // Soft gradient for donor (teal theme)
  static const LinearGradient donorGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF5DADE2), Color(0xFF3498DB)],
  );

  static LinearGradient cardGradient(String urgency) {
    switch (urgency) {
      case 'emergency':
        return const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFEC7063), Color(0xFFE74C3C)],
        );
      case 'high':
        return const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF5B041), Color(0xFFF39C12)],
        );
      case 'normal':
        return const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF5DADE2), Color(0xFF3498DB)],
        );
      default:
        return const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF58D68D), Color(0xFF2ECC71)],
        );
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // 📐 SPACING
  // ═══════════════════════════════════════════════════════════════

  static const double spacingXs = 4;
  static const double spacingSm = 8;
  static const double spacingMd = 16;
  static const double spacingLg = 24;
  static const double spacingXl = 32;

  // ═══════════════════════════════════════════════════════════════
  // 📐 BORDER RADIUS
  // ═══════════════════════════════════════════════════════════════

  static const double radiusSm = 8;
  static const double radiusMd = 12;
  static const double radiusLg = 16;
  static const double radiusXl = 24;

  // ═══════════════════════════════════════════════════════════════
  // 🎯 SHADOWS - Subtle & Soft
  // ═══════════════════════════════════════════════════════════════

  static List<BoxShadow> cardShadow = [
    BoxShadow(
      color: Colors.black.withOpacity(0.05),
      blurRadius: 10,
      offset: const Offset(0, 4),
    ),
  ];

  static List<BoxShadow> elevatedShadow = [
    BoxShadow(
      color: Colors.black.withOpacity(0.08),
      blurRadius: 20,
      offset: const Offset(0, 8),
    ),
  ];

  // ═══════════════════════════════════════════════════════════════
  // 🔤 TEXT STYLES
  // ═══════════════════════════════════════════════════════════════

  static const TextStyle headingLarge = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.bold,
    color: textPrimary,
    letterSpacing: -0.5,
  );

  static const TextStyle headingMedium = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.bold,
    color: textPrimary,
  );

  static const TextStyle headingSmall = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: textPrimary,
  );

  static const TextStyle bodyLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.normal,
    color: textPrimary,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.normal,
    color: textSecondary,
  );

  static const TextStyle bodySmall = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.normal,
    color: textHint,
  );

  static const TextStyle labelMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: textPrimary,
  );

  // ═══════════════════════════════════════════════════════════════
  // 🎨 THEME DATA
  // ═══════════════════════════════════════════════════════════════

  static ThemeData get lightTheme => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primary,
      primary: primary,
      secondary: accent,
      background: background,
      surface: surface,
    ),
    scaffoldBackgroundColor: background,
    appBarTheme: const AppBarTheme(
      backgroundColor: primary,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radiusLg),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: primary,
        side: const BorderSide(color: primary),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.grey.shade50,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusMd),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusMd),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusMd),
        borderSide: const BorderSide(color: primary, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
  );
}
