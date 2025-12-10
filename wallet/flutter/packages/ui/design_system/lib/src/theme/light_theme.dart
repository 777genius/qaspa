import 'package:flutter/material.dart';

import '../tokens/colors.dart';
import '../tokens/typography.dart';
import '../tokens/radii.dart';

/// Light theme configuration.
ThemeData createLightTheme() {
  final colorScheme = ColorScheme.light(
    primary: AppColors.primary,
    onPrimary: AppColors.onPrimary,
    primaryContainer: AppColors.primaryContainer,
    onPrimaryContainer: AppColors.onPrimaryContainer,
    secondary: AppColors.secondary,
    onSecondary: AppColors.onSecondary,
    secondaryContainer: AppColors.secondaryContainer,
    onSecondaryContainer: AppColors.onSecondaryContainer,
    tertiary: AppColors.tertiary,
    onTertiary: AppColors.onTertiary,
    tertiaryContainer: AppColors.tertiaryContainer,
    onTertiaryContainer: AppColors.onTertiaryContainer,
    error: AppColors.error,
    onError: AppColors.onError,
    errorContainer: AppColors.errorContainer,
    onErrorContainer: AppColors.onErrorContainer,
    surface: AppColors.surfaceLight,
    onSurface: AppColors.onSurfaceLight,
    surfaceContainerHighest: AppColors.surfaceContainerHighLight,
    onSurfaceVariant: AppColors.onSurfaceVariantLight,
    outline: AppColors.outlineLight,
    outlineVariant: AppColors.outlineVariantLight,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: colorScheme,
    textTheme: AppTypography.textTheme,

    // AppBar
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.surfaceLight,
      foregroundColor: AppColors.onSurfaceLight,
      elevation: 0,
      scrolledUnderElevation: 1,
      centerTitle: true,
      titleTextStyle: AppTypography.textTheme.titleLarge?.copyWith(
        color: AppColors.onSurfaceLight,
      ),
    ),

    // Scaffold
    scaffoldBackgroundColor: AppColors.backgroundLight,

    // Card
    cardTheme: CardThemeData(
      color: AppColors.surfaceContainerLight,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: AppRadii.card),
      margin: EdgeInsets.zero,
    ),

    // Elevated Button
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: AppRadii.button),
        textStyle: AppTypography.textTheme.labelLarge,
      ),
    ),

    // Filled Button
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: AppRadii.button),
        textStyle: AppTypography.textTheme.labelLarge,
      ),
    ),

    // Outlined Button
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: AppRadii.button),
        side: const BorderSide(color: AppColors.primary),
        textStyle: AppTypography.textTheme.labelLarge,
      ),
    ),

    // Text Button
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primary,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: AppRadii.button),
        textStyle: AppTypography.textTheme.labelLarge,
      ),
    ),

    // Input Decoration
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surfaceContainerLight,
      border: OutlineInputBorder(
        borderRadius: AppRadii.input,
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: AppRadii.input,
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: AppRadii.input,
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: AppRadii.input,
        borderSide: const BorderSide(color: AppColors.error, width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: AppRadii.input,
        borderSide: const BorderSide(color: AppColors.error, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      hintStyle: AppTypography.textTheme.bodyLarge?.copyWith(
        color: AppColors.onSurfaceVariantLight,
      ),
    ),

    // Icon Button
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        foregroundColor: AppColors.onSurfaceLight,
      ),
    ),

    // Bottom Navigation
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: AppColors.surfaceLight,
      selectedItemColor: AppColors.primary,
      unselectedItemColor: AppColors.onSurfaceVariantLight,
      type: BottomNavigationBarType.fixed,
      elevation: 0,
    ),

    // Navigation Bar (M3)
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.surfaceContainerLight,
      indicatorColor: AppColors.primaryContainer,
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const IconThemeData(color: AppColors.onPrimaryContainer);
        }
        return const IconThemeData(color: AppColors.onSurfaceVariantLight);
      }),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return AppTypography.textTheme.labelMedium?.copyWith(
            color: AppColors.onSurfaceLight,
          );
        }
        return AppTypography.textTheme.labelMedium?.copyWith(
          color: AppColors.onSurfaceVariantLight,
        );
      }),
    ),

    // Divider
    dividerTheme: const DividerThemeData(
      color: AppColors.outlineVariantLight,
      thickness: 1,
      space: 1,
    ),

    // Chip
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.surfaceContainerLight,
      selectedColor: AppColors.primaryContainer,
      labelStyle: AppTypography.textTheme.labelMedium,
      shape: RoundedRectangleBorder(borderRadius: AppRadii.chip),
      side: BorderSide.none,
    ),

    // Floating Action Button
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: AppColors.primary,
      foregroundColor: AppColors.onPrimary,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: AppRadii.borderRadiusLg),
    ),

    // Bottom Sheet
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.surfaceLight,
      shape: RoundedRectangleBorder(borderRadius: AppRadii.bottomSheet),
      showDragHandle: true,
    ),

    // Dialog
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.surfaceLight,
      shape: RoundedRectangleBorder(borderRadius: AppRadii.dialog),
      titleTextStyle: AppTypography.textTheme.headlineSmall?.copyWith(
        color: AppColors.onSurfaceLight,
      ),
    ),

    // Snackbar
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.onSurfaceLight,
      contentTextStyle: AppTypography.textTheme.bodyMedium?.copyWith(
        color: AppColors.surfaceLight,
      ),
      shape: RoundedRectangleBorder(borderRadius: AppRadii.borderRadiusSm),
      behavior: SnackBarBehavior.floating,
    ),
  );
}
