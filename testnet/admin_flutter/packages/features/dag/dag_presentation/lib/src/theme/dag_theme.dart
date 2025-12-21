import 'package:flutter/material.dart';

/// DAG visualization theme based on kaspa-graph-inspector
/// Reference: https://github.com/kaspa-live/kaspa-graph-inspector/blob/master/web/src/dag/Theme.ts
class DagTheme {
  const DagTheme._();

  // Reference block size for scaling
  static const double referenceBlockSize = 88.0;

  // Block styling
  static const double blockRoundingRadius = 10.0;
  static const double blockBorderWidth = 2.0;
  static const double blockScaleDefault = 1.0;
  static const double blockScaleHover = 1.1;

  // Timeline layout
  static const int maxBlocksPerHeight = 12;
  static const double marginXMultiplier = 2.0;
  static const double minMarginYMultiplier = 1.0;
  static const int visibleHeightRangePadding = 2;

  // Edge styling
  static const double normalEdgeWidth = 2.0;
  static const double normalArrowRadius = 5.0;
  static const double virtualChainEdgeWidth = 7.0;
  static const double virtualChainArrowRadius = 9.0;

  // Text styling
  static const String fontFamily = 'monospace';
  static const double textSizeMultiplier = 0.26;
  static const double minFontSize = 14.0;
  static const double maxFontSize = 18.0;
  static const int maxTextLines = 3;

  /// Scale a measure based on block size relative to reference
  static double scale(double measure, double blockSize) {
    return measure * blockSize / referenceBlockSize;
  }
}

/// Block colors based on KGI light theme
class DagBlockColors {
  const DagBlockColors._();

  // Blue block (chain block)
  static const Color blueMain = Color(0xFF5581AA);
  static const Color blueHighlight = Color(0xFF85A2C1);
  static const Color blueContrastText = Color(0xFFFFFFFF);
  static const Color blueBorder = Color(0xFFFFFFFF);

  // Red block (off-chain block)
  static const Color redMain = Color(0xFFB34D50);
  static const Color redHighlight = Color(0xFFA06765);
  static const Color redContrastText = Color(0xFFFFFFFF);
  static const Color redBorder = Color(0xFFFFFFFF);

  // Gray block (unconfirmed/new block)
  static const Color grayMain = Color(0xFFF5F5F5);
  static const Color grayHighlight = Color(0xFF949494);
  static const Color grayContrastText = Color(0xFF666666);
  static const Color grayBorder = Color(0xFFAAAAAA);

  /// Get main color for block type
  static Color getMainColor({
    required bool isChainBlock,
    required bool isNew,
  }) {
    if (isNew) return grayMain;
    return isChainBlock ? blueMain : redMain;
  }

  /// Get border color for block type
  static Color getBorderColor({
    required bool isChainBlock,
    required bool isNew,
  }) {
    if (isNew) return grayBorder;
    return isChainBlock ? blueBorder : redBorder;
  }

  /// Get text color for block type
  static Color getTextColor({
    required bool isChainBlock,
    required bool isNew,
  }) {
    if (isNew) return grayContrastText;
    return isChainBlock ? blueContrastText : redContrastText;
  }

  /// Get highlight color for block type
  static Color getHighlightColor({
    required bool isChainBlock,
    required bool isNew,
  }) {
    if (isNew) return grayHighlight;
    return isChainBlock ? blueHighlight : redHighlight;
  }
}

/// Edge colors based on KGI theme
class DagEdgeColors {
  const DagEdgeColors._();

  // Normal edge
  static const Color normal = Color(0xFFAAAAAA);

  // Virtual chain (selected parent) edge
  static const Color virtualChain = Color(0xFF85A2C1);

  // Highlighted edges
  static const Color highlightedParent = Color(0xFFAAAAAA);
  static const Color highlightedChild = Color(0xFFAAAAAA);
  static const Color highlightedSelected = Color(0xFFAAAAAA);
}

/// Background colors
class DagBackgroundColors {
  const DagBackgroundColors._();

  static const Color light = Color(0xFFEEEEEE);
  static const Color dark = Color(0xFF2B2B2B);
}
