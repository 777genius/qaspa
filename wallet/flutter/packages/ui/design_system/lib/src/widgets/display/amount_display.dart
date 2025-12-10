import 'package:flutter/material.dart';

import '../../tokens/colors.dart';
import '../../tokens/typography.dart';

/// SOMPI per KAS constant
final BigInt _sompiPerKas = BigInt.from(100000000);

/// Amount display with KAS formatting.
///
/// Supports both [double] (for simple displays) and [BigInt] SOMPI values
/// (for precision-critical displays).
///
/// When [compact] is true, large amounts are abbreviated with "~" prefix
/// to indicate approximation (e.g., "~1.23M KAS").
class AmountDisplay extends StatelessWidget {
  /// Amount in KAS (double).
  /// WARNING: May lose precision for amounts > 9M KAS.
  /// Use [sompiAmount] for precision-critical displays.
  final double? amount;

  /// Amount in SOMPI (BigInt) for full precision.
  /// Takes precedence over [amount] if both are provided.
  final BigInt? sompiAmount;

  final bool showSign;
  final bool isIncoming;
  final TextStyle? style;
  final bool compact;

  const AmountDisplay({
    super.key,
    this.amount,
    this.sompiAmount,
    this.showSign = false,
    this.isIncoming = true,
    this.style,
    this.compact = false,
  }) : assert(
          amount != null || sompiAmount != null,
          'Either amount or sompiAmount must be provided',
        );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = showSign
        ? (isIncoming ? AppColors.incoming : AppColors.outgoing)
        : theme.colorScheme.onSurface;

    final formattedAmount = _formatAmount();
    final sign = showSign ? (isIncoming ? '+' : '-') : '';

    return Text(
      '$sign$formattedAmount KAS',
      style: (style ?? AppTypography.mono).copyWith(color: color),
    );
  }

  String _formatAmount() {
    // Use SOMPI if available for full precision
    if (sompiAmount != null) {
      return _formatSompi(sompiAmount!.abs());
    }

    // Fallback to double (may lose precision for large amounts)
    return _formatDouble(amount!.abs());
  }

  /// Format BigInt SOMPI amount - full precision
  String _formatSompi(BigInt sompi) {
    if (sompi == BigInt.zero) return '0';

    final kas = sompi ~/ _sompiPerKas;
    final fraction = sompi.remainder(_sompiPerKas);

    if (compact) {
      // Show approximation indicator for compact mode
      final kasDouble = sompi.toDouble() / _sompiPerKas.toDouble();
      if (kasDouble >= 1000000) {
        return '~${(kasDouble / 1000000).toStringAsFixed(2)}M';
      }
      if (kasDouble >= 1000) {
        return '~${(kasDouble / 1000).toStringAsFixed(2)}K';
      }
    }

    if (fraction == BigInt.zero) {
      return '$kas.00';
    }

    // Format fraction with proper padding
    final fractionStr = fraction.toString().padLeft(8, '0');
    final trimmed = fractionStr.substring(0, 2); // Show 2 decimal places

    return '$kas.$trimmed';
  }

  /// Format double amount - may lose precision for large amounts
  String _formatDouble(double value) {
    if (compact) {
      // Show approximation indicator for compact mode
      if (value >= 1000000) {
        return '~${(value / 1000000).toStringAsFixed(2)}M';
      }
      if (value >= 1000) {
        return '~${(value / 1000).toStringAsFixed(2)}K';
      }
    }

    if (value == 0) return '0';
    if (value >= 1) return value.toStringAsFixed(2);
    return value.toStringAsFixed(8).replaceAll(RegExp(r'0+$'), '');
  }
}
