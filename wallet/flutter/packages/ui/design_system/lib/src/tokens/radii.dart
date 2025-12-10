import 'package:flutter/material.dart';

/// Border radius tokens for consistent shapes.
abstract final class AppRadii {
  // === Radius Values ===

  /// 4px
  static const double xs = 4;

  /// 8px
  static const double sm = 8;

  /// 12px
  static const double md = 12;

  /// 16px
  static const double lg = 16;

  /// 20px
  static const double xl = 20;

  /// 24px
  static const double xxl = 24;

  /// 28px - for full rounded buttons
  static const double full = 28;

  // === BorderRadius Presets ===

  /// Extra small radius (4px)
  static const BorderRadius borderRadiusXs = BorderRadius.all(Radius.circular(xs));

  /// Small radius (8px)
  static const BorderRadius borderRadiusSm = BorderRadius.all(Radius.circular(sm));

  /// Medium radius (12px)
  static const BorderRadius borderRadiusMd = BorderRadius.all(Radius.circular(md));

  /// Large radius (16px)
  static const BorderRadius borderRadiusLg = BorderRadius.all(Radius.circular(lg));

  /// Extra large radius (20px)
  static const BorderRadius borderRadiusXl = BorderRadius.all(Radius.circular(xl));

  /// Full rounded (28px)
  static const BorderRadius borderRadiusFull = BorderRadius.all(Radius.circular(full));

  // === Component Specific ===

  /// Card border radius (16px)
  static const BorderRadius card = borderRadiusLg;

  /// Button border radius (12px)
  static const BorderRadius button = borderRadiusMd;

  /// Input field border radius (12px)
  static const BorderRadius input = borderRadiusMd;

  /// Chip border radius (8px)
  static const BorderRadius chip = borderRadiusSm;

  /// Bottom sheet top radius (24px)
  static const BorderRadius bottomSheet = BorderRadius.vertical(
    top: Radius.circular(xxl),
  );

  /// Dialog border radius (24px)
  static const BorderRadius dialog = BorderRadius.all(Radius.circular(xxl));
}
