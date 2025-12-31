import 'package:flutter/material.dart';

import '../../tokens/colors.dart';
import '../../tokens/typography.dart';

/// Universal amount display widget.
///
/// Displays a pre-formatted amount value with optional currency symbol.
/// All formatting logic should be handled externally (in domain layer).
///
/// Example:
/// ```dart
/// AmountDisplay(
///   value: '1,234.56',
///   currency: 'KAS',
///   showSign: true,
///   isPositive: true,
/// )
/// ```
class AmountDisplay extends StatelessWidget {
  const AmountDisplay({
    super.key,
    required this.value,
    this.currency,
    this.showSign = false,
    this.isPositive = true,
    this.style,
  });

  /// Pre-formatted amount value (e.g., "1,234.56", "~1.23M")
  final String value;

  /// Optional currency symbol (e.g., "KAS", "USD", "BTC")
  final String? currency;

  /// Whether to show +/- sign
  final bool showSign;

  /// Whether the amount is positive (used with showSign)
  final bool isPositive;

  /// Custom text style
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = showSign
        ? (isPositive ? AppColors.incoming : AppColors.outgoing)
        : theme.colorScheme.onSurface;

    final sign = showSign ? (isPositive ? '+' : '-') : '';
    final currencySuffix = currency != null ? ' $currency' : '';

    return Text(
      '$sign$value$currencySuffix',
      style: (style ?? AppTypography.mono).copyWith(color: color),
    );
  }
}
