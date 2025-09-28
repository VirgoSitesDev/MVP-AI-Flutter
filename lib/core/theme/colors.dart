import 'package:flutter/material.dart';

class AppColors {
  // Primary colors dal design
  static const Color primary = Color(0xFF000000); // Nero per il logo
  static const Color secondary = Color.fromARGB(255, 62, 62, 62); // Grigio per testi secondari
  static const Color success = Color(0xFF10B981); // Verde per i badge G DRIVE
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFDC2626);
  static const Color pink = Color.fromARGB(255, 255, 229, 232); // Rosa per il badge beta

  // Surface colors
  static const Color surface = Color(0xFFFAFAFA);
  static const Color background = Color(0xFFFFFFFF); // Bianco puro
  static const Color outline = Color(0xFFE5E7EB); // Grigio bordi dal design
  static const Color divider = Color(0xFFE5E7EB); // Stesso grigio per divisori

  // Text colors
  static const Color textPrimary = Color(0xFF000000); // Nero per testi principali
  static const Color textSecondary = Color.fromARGB(255, 43, 43, 44); // Grigio per testi secondari
  static const Color textTertiary = Color.fromARGB(255, 67, 67, 68); // Grigio chiaro

  // Chat specific colors dal design
  static const Color chatBubbleBg = Color(0xFFF3F4F6); // Grigio chiaro per le chat bubble
  static const Color userMessageBg = Color(0xFFF3F4F6);
  static const Color assistantMessageBg = Color(0xFFF3F4F6);

  // Dark mode colors (manteniamo per compatibilità)
  static const Color darkSurface = Color(0xFF1E293B);
  static const Color darkBackground = Color(0xFF0F172A);
  static const Color darkOutline = Color(0xFF334155);
  static const Color darkTextPrimary = Color(0xFFE2E8F0);
  static const Color darkTextSecondary = Color(0xFFCBD5E1);

  // Chat specific dark colors
  static const Color userMessageBgDark = Color(0xFF3730A3);
  static const Color assistantMessageBgDark = Color(0xFF1E293B);

  // Pin colors
  static const Color pinActive = Color(0xFF10B981); // Verde come nel design
  static const Color pinInactive = Color(0xFF6B7280);
  static const Color pinHover = Color(0xFFF9FAFB);

  // File type colors
  static const Color fileDocument = Color(0xFF3B82F6);
  static const Color fileImage = Color(0xFF8B5CF6);
  static const Color fileSpreadsheet = Color(0xFF10B981);
  static const Color filePresentation = Color(0xFFF59E0B);
  static const Color fileOther = Color(0xFF6B7280);

  // Badge colors dal design
  static const Color badgeGoogleDrive = Color(0xFF10B981); // Verde per G DRIVE
  static const Color badgeLocal = Color(0xFF6B7280); // Grigio per LOCAL
  static const Color badgeBeta = Color.fromARGB(255, 255, 229, 232); // Rosa per beta

  // Input field colors
  static const Color inputBackground = Color(0xFFFFFFFF);
  static const Color inputBorder = Color(0xFFE5E7EB);
  static const Color inputFocused = Color(0xFF3B82F6);

  // Hover states
  static const Color hoverLight = Color(0xFFF9FAFB);
  static const Color hoverMedium = Color(0xFFF3F4F6);

  // Icon colors
  static const Color iconPrimary = Color.fromARGB(255, 50, 51, 51);
  static const Color iconSecondary = Color.fromARGB(255, 82, 82, 83);
  static const Color iconSuccess = Color(0xFF10B981);
  static const Color iconError = Color(0xFFDC2626);

  // Specific UI element colors
  static const Color sidebarBackground = Color(0xFFFFFFFF);
  static const Color sidebarBorder = Color(0xFFE5E7EB);
  static const Color previewBackground = Color(0xFFF9FAFB);
  static const Color previewBorder = Color(0xFFE5E7EB);
}