import 'package:flutter/material.dart';

class AppColors {
  // Brand Accent Colors
  static const Color primary = Color(0xFF7C3AED); // Vibrant Purple / Violet
  static const Color primaryHover = Color(0xFF6D28D9);
  static const Color primaryLight = Color(0xFFEDE9FE);
  static const Color primaryDark = Color(0xFF5B21B6);
  static const Color primaryNeon = Color(0xFF8B5CF6);
  
  static const Color accentBlue = Color(0xFF2563EB);
  static const Color accentCyan = Color(0xFF06B6D4);
  static const Color accentEmerald = Color(0xFF10B981);
  static const Color accentGreen = Color(0xFF10B981);
  static const Color accentRose = Color(0xFFF43F5E);
  static const Color accentAmber = Color(0xFFF59E0B);
  static const Color accentViolet = Color(0xFFA855F7);
  static const Color accentIndigo = Color(0xFF6366F1);

  // Modern Brand Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF7C3AED), Color(0xFF4F46E5), Color(0xFF2563EB)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient cyberGradient = LinearGradient(
    colors: [Color(0xFF8B5CF6), Color(0xFF3B82F6), Color(0xFF06B6D4)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient heroGradient = LinearGradient(
    colors: [Color(0xFF1E1435), Color(0xFF161F38), Color(0xFF0E1A2D)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient audioGradient = LinearGradient(
    colors: [Color(0xFFFF2E93), Color(0xFFFF5C00)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient successGradient = LinearGradient(
    colors: [Color(0xFF10B981), Color(0xFF059669)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Social Platform Brand Colors & Gradients
  static const Color ytRed = Color(0xFFFF0000);
  static const LinearGradient ytGradient = LinearGradient(
    colors: [Color(0xFFFF0000), Color(0xFFCC0000)],
  );

  static const LinearGradient instaGradient = LinearGradient(
    colors: [Color(0xFF833AB4), Color(0xFFFD1D1D), Color(0xFFFCB045)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient tiktokGradient = LinearGradient(
    colors: [Color(0xFF00F2FE), Color(0xFF4FACFE), Color(0xFFFE2C55)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient xTwitterGradient = LinearGradient(
    colors: [Color(0xFF1D283A), Color(0xFF0F172A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient facebookGradient = LinearGradient(
    colors: [Color(0xFF1877F2), Color(0xFF0866FF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Light Theme Colors
  static const Color lightBackground = Color(0xFFF8FAFC);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceHover = Color(0xFFF1F5F9);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightBorder = Color(0xFFE2E8F0);
  static const Color lightDivider = Color(0xFFEEF2F6);
  
  static const Color lightTextPrimary = Color(0xFF0F172A);
  static const Color lightTextSecondary = Color(0xFF64748B);
  static const Color lightTextMuted = Color(0xFF94A3B8);

  // Dark Theme Colors (Deep Obsidian & Glassmorphism)
  static const Color darkBackground = Color(0xFF080B11); // Deepest Obsidian
  static const Color darkSurface = Color(0xFF0F1420);    // Dark Sapphire Surface
  static const Color darkSurfaceHover = Color(0xFF172033);
  static const Color darkCard = Color(0xFF131A29);
  static const Color darkCardElevated = Color(0xFF1A2338);
  static const Color darkBorder = Color(0xFF222C40);
  static const Color darkDivider = Color(0xFF172033);

  static const Color darkTextPrimary = Color(0xFFF8FAFC);
  static const Color darkTextSecondary = Color(0xFF94A3B8);
  static const Color darkTextMuted = Color(0xFF64748B);

  // Glassmorphism Tints
  static final Color glassDarkSurface = const Color(0xFF0F1420).withValues(alpha: 0.85);
  static final Color glassLightSurface = const Color(0xFFFFFFFF).withValues(alpha: 0.85);
  static final Color glassBorder = const Color(0xFFFFFFFF).withValues(alpha: 0.08);

  // Status & Utility Colors
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);
}
