import 'package:flutter/material.dart';
import 'admin_colors.dart';
import 'admin_spacing.dart';
import 'admin_typography.dart';

abstract final class AdminTheme {
  static ThemeData get light => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorScheme: ColorScheme.light(
          primary: AdminColors.primary,
          onPrimary: Colors.white,
          secondary: AdminColors.secondary,
          onSecondary: Colors.white,
          error: AdminColors.error,
          onError: Colors.white,
          surface: AdminColors.surfaceLight,
          onSurface: AdminColors.textPrimaryLight,
        ),
        scaffoldBackgroundColor: AdminColors.backgroundLight,
        cardTheme: CardThemeData(
          color: AdminColors.cardLight,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AdminSpacing.cardRadius),
            side: const BorderSide(color: AdminColors.borderLight),
          ),
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: AdminColors.surfaceLight,
          foregroundColor: AdminColors.textPrimaryLight,
          elevation: 0,
          centerTitle: false,
          titleTextStyle: AdminTypography.headlineMedium.copyWith(
            color: AdminColors.textPrimaryLight,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AdminColors.primary,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(
              horizontal: AdminSpacing.buttonPaddingH,
              vertical: AdminSpacing.buttonPaddingV,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AdminSpacing.buttonRadius),
            ),
            textStyle: AdminTypography.labelLarge,
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: AdminColors.primary,
            elevation: 0,
            padding: const EdgeInsets.symmetric(
              horizontal: AdminSpacing.buttonPaddingH,
              vertical: AdminSpacing.buttonPaddingV,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AdminSpacing.buttonRadius),
            ),
            side: const BorderSide(color: AdminColors.primary),
            textStyle: AdminTypography.labelLarge,
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: AdminColors.primary,
            padding: const EdgeInsets.symmetric(
              horizontal: AdminSpacing.sm,
              vertical: AdminSpacing.xs,
            ),
            textStyle: AdminTypography.labelLarge,
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AdminColors.surfaceLight,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AdminSpacing.inputRadius),
            borderSide: const BorderSide(color: AdminColors.borderLight),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AdminSpacing.inputRadius),
            borderSide: const BorderSide(color: AdminColors.borderLight),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AdminSpacing.inputRadius),
            borderSide: const BorderSide(color: AdminColors.primary, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AdminSpacing.inputRadius),
            borderSide: const BorderSide(color: AdminColors.error),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AdminSpacing.inputPaddingH,
            vertical: AdminSpacing.inputPaddingV,
          ),
          hintStyle: AdminTypography.bodyMedium.copyWith(
            color: AdminColors.textTertiaryLight,
          ),
        ),
        dividerTheme: const DividerThemeData(
          color: AdminColors.borderLight,
          thickness: 1,
          space: 1,
        ),
        textTheme: TextTheme(
          displayLarge: AdminTypography.displayLarge,
          displayMedium: AdminTypography.displayMedium,
          displaySmall: AdminTypography.displaySmall,
          headlineLarge: AdminTypography.headlineLarge,
          headlineMedium: AdminTypography.headlineMedium,
          headlineSmall: AdminTypography.headlineSmall,
          titleLarge: AdminTypography.titleLarge,
          titleMedium: AdminTypography.titleMedium,
          titleSmall: AdminTypography.titleSmall,
          bodyLarge: AdminTypography.bodyLarge,
          bodyMedium: AdminTypography.bodyMedium,
          bodySmall: AdminTypography.bodySmall,
          labelLarge: AdminTypography.labelLarge,
          labelMedium: AdminTypography.labelMedium,
          labelSmall: AdminTypography.labelSmall,
        ),
      );

  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.dark(
          primary: AdminColors.primaryLight,
          onPrimary: Colors.black,
          secondary: AdminColors.secondaryLight,
          onSecondary: Colors.black,
          error: AdminColors.error,
          onError: Colors.white,
          surface: AdminColors.surfaceDark,
          onSurface: AdminColors.textPrimaryDark,
        ),
        scaffoldBackgroundColor: AdminColors.backgroundDark,
        cardTheme: CardThemeData(
          color: AdminColors.cardDark,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AdminSpacing.cardRadius),
            side: const BorderSide(color: AdminColors.borderDark),
          ),
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: AdminColors.surfaceDark,
          foregroundColor: AdminColors.textPrimaryDark,
          elevation: 0,
          centerTitle: false,
          titleTextStyle: AdminTypography.headlineMedium.copyWith(
            color: AdminColors.textPrimaryDark,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AdminColors.primaryLight,
            foregroundColor: Colors.black,
            elevation: 0,
            padding: const EdgeInsets.symmetric(
              horizontal: AdminSpacing.buttonPaddingH,
              vertical: AdminSpacing.buttonPaddingV,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AdminSpacing.buttonRadius),
            ),
            textStyle: AdminTypography.labelLarge,
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: AdminColors.primaryLight,
            elevation: 0,
            padding: const EdgeInsets.symmetric(
              horizontal: AdminSpacing.buttonPaddingH,
              vertical: AdminSpacing.buttonPaddingV,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AdminSpacing.buttonRadius),
            ),
            side: const BorderSide(color: AdminColors.primaryLight),
            textStyle: AdminTypography.labelLarge,
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: AdminColors.primaryLight,
            padding: const EdgeInsets.symmetric(
              horizontal: AdminSpacing.sm,
              vertical: AdminSpacing.xs,
            ),
            textStyle: AdminTypography.labelLarge,
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AdminColors.surfaceDark,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AdminSpacing.inputRadius),
            borderSide: const BorderSide(color: AdminColors.borderDark),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AdminSpacing.inputRadius),
            borderSide: const BorderSide(color: AdminColors.borderDark),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AdminSpacing.inputRadius),
            borderSide: const BorderSide(color: AdminColors.primaryLight, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AdminSpacing.inputRadius),
            borderSide: const BorderSide(color: AdminColors.error),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AdminSpacing.inputPaddingH,
            vertical: AdminSpacing.inputPaddingV,
          ),
          hintStyle: AdminTypography.bodyMedium.copyWith(
            color: AdminColors.textTertiaryDark,
          ),
        ),
        dividerTheme: const DividerThemeData(
          color: AdminColors.borderDark,
          thickness: 1,
          space: 1,
        ),
        textTheme: TextTheme(
          displayLarge: AdminTypography.displayLarge,
          displayMedium: AdminTypography.displayMedium,
          displaySmall: AdminTypography.displaySmall,
          headlineLarge: AdminTypography.headlineLarge,
          headlineMedium: AdminTypography.headlineMedium,
          headlineSmall: AdminTypography.headlineSmall,
          titleLarge: AdminTypography.titleLarge,
          titleMedium: AdminTypography.titleMedium,
          titleSmall: AdminTypography.titleSmall,
          bodyLarge: AdminTypography.bodyLarge,
          bodyMedium: AdminTypography.bodyMedium,
          bodySmall: AdminTypography.bodySmall,
          labelLarge: AdminTypography.labelLarge,
          labelMedium: AdminTypography.labelMedium,
          labelSmall: AdminTypography.labelSmall,
        ),
      );
}
