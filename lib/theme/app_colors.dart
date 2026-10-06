import 'package:flutter/material.dart';
import 'app_theme.dart';

/// Constants for colors used in the app, specifically for the onboarding flow.
/// Adapted to match the app's existing theme (Orange) instead of the blue from the design.
class AppColors {
  // Primary color adapted from AppTheme (replaces blue #2F6BDE)
  static const Color primary = AppTheme.primary;
  
  // Skip button background (replaces light blue #5B8FF9)
  // Using a slightly lighter shade of the primary orange
  static const Color skipButtonBg = Color(0xFFFF8C33); 
  static const Color skipButtonText = Colors.white;

  // Placeholder and inactive indicator color
  static const Color imagePlaceholder = Color(0xFFD9D9D9);
  static const Color indicatorInactive = Color(0xFFD9D9D9);

  // Text colors
  static const Color textTitle = AppTheme.primary;
  static const Color textDescription = AppTheme.textGrey;

  // Dialog colors
  static const Color successBg = Color(0xFFEAF1FF);
  static const Color successIcon = Color(0xFF2F6BDE);
  static const Color error = Color(0xFFE53935);
  static const Color errorBg = Color(0xFFFDECEA);
}
