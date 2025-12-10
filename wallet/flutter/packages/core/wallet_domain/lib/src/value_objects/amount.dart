import 'package:decimal/decimal.dart';
import 'package:equatable/equatable.dart';

import '../errors/wallet_exception.dart';

/// Amount value object representing KAS/SOMPI values.
/// 1 KAS = 100,000,000 SOMPI (8 decimal places)
///
/// Uses BigInt internally to support the full u64 range from Rust
/// (max ~18.4 quintillion SOMPI = ~184 billion KAS).
class Amount extends Equatable implements Comparable<Amount> {
  /// Amount in SOMPI (smallest unit)
  final BigInt _sompiValue;

  static final BigInt sompiPerKas = BigInt.from(100000000);
  static const int maxDecimals = 8;

  const Amount._(this._sompiValue);

  /// Create from SOMPI value (BigInt)
  factory Amount.fromSompi(BigInt sompi) {
    if (sompi.isNegative) {
      throw InvalidAmountException(
        code: 'NEGATIVE_AMOUNT',
        message: 'Amount cannot be negative',
      );
    }
    return Amount._(sompi);
  }

  /// Create from SOMPI value (int) - convenience constructor
  factory Amount.fromSompiInt(int sompi) {
    return Amount.fromSompi(BigInt.from(sompi));
  }

  /// Create from KAS string value using Decimal for precision
  factory Amount.fromKas(String kas) {
    try {
      final decimal = Decimal.parse(kas);
      // Decimal 3.x: use comparison instead of .isNegative
      if (decimal < Decimal.zero) {
        throw InvalidAmountException(
          code: 'NEGATIVE_AMOUNT',
          message: 'Amount cannot be negative',
        );
      }
      final sompiDecimal = decimal * Decimal.fromBigInt(sompiPerKas);
      return Amount._(sompiDecimal.toBigInt());
    } on FormatException {
      throw InvalidAmountException(
        code: 'INVALID_FORMAT',
        message: 'Invalid KAS amount format: $kas',
      );
    }
  }

  /// Create from KAS double value - use with caution due to precision loss
  /// Prefer fromKas(String) for user input
  factory Amount.fromKasDouble(double kas) {
    if (kas < 0) {
      throw InvalidAmountException(
        code: 'NEGATIVE_AMOUNT',
        message: 'Amount cannot be negative',
      );
    }
    // Convert through string to avoid floating point precision issues
    return Amount.fromKas(kas.toStringAsFixed(8));
  }

  /// Create from string (supports both KAS and SOMPI notation)
  factory Amount.parse(String value) {
    final trimmed = value.trim().toLowerCase();

    // Check for SOMPI suffix
    if (trimmed.endsWith('sompi')) {
      final numStr = trimmed.replaceAll('sompi', '').trim();
      return Amount.fromSompi(BigInt.parse(numStr));
    }

    // Check for KAS suffix
    if (trimmed.endsWith('kas')) {
      final numStr = trimmed.replaceAll('kas', '').trim();
      return Amount.fromKas(numStr);
    }

    // Default: treat as KAS if has decimal, SOMPI otherwise
    if (trimmed.contains('.')) {
      return Amount.fromKas(trimmed);
    }
    return Amount.fromSompi(BigInt.parse(trimmed));
  }

  /// Zero amount
  static final Amount zero = Amount._(BigInt.zero);

  /// Get value in SOMPI as BigInt
  BigInt get sompiValue => _sompiValue;

  /// Get value in SOMPI as int (may overflow for very large amounts!)
  /// Use only when you're sure the value fits in int
  /// WARNING: Use sompiIntOrNull for safe conversion
  ///
  /// @deprecated Use [sompiValue] for full BigInt range or [sompiIntOrNull]
  /// for safe int conversion. This getter will throw if value exceeds int range.
  @Deprecated('Use sompiValue for BigInt or sompiIntOrNull for safe int. '
      'This getter now throws on overflow instead of silent corruption.')
  int get sompiInt {
    const maxInt = 0x7FFFFFFFFFFFFFFF; // 2^63 - 1
    if (_sompiValue > BigInt.from(maxInt)) {
      throw StateError(
        'Amount $this exceeds int64 max. Use sompiValue (BigInt) instead.',
      );
    }
    return _sompiValue.toInt();
  }

  /// Get value in SOMPI as int, or null if value exceeds int max
  /// Safe alternative to sompiInt
  int? get sompiIntOrNull {
    const maxInt = 0x7FFFFFFFFFFFFFFF; // 2^63 - 1
    if (_sompiValue > BigInt.from(maxInt)) return null;
    return _sompiValue.toInt();
  }

  /// Get value in KAS as Decimal (precise)
  /// Note: Decimal 3.x division returns Rational, so we convert back to Decimal
  Decimal get kasDecimal {
    final ratio =
        Decimal.fromBigInt(_sompiValue) / Decimal.fromBigInt(sompiPerKas);
    // Convert Rational back to Decimal with 8 decimal precision
    return ratio.toDecimal(scaleOnInfinitePrecision: maxDecimals);
  }

  /// Get value in KAS as double (for display only, may lose precision)
  double get kas => _sompiValue.toDouble() / sompiPerKas.toDouble();

  /// Whether this amount is zero
  bool get isZero => _sompiValue == BigInt.zero;

  /// Whether this amount is positive
  bool get isPositive => _sompiValue > BigInt.zero;

  /// Format as KAS string with specified decimals
  String formatKas({int decimals = 8, bool showSymbol = true}) {
    final kasWhole = _sompiValue ~/ sompiPerKas;
    final kasFraction = _sompiValue.remainder(sompiPerKas);

    String result;
    if (kasFraction == BigInt.zero) {
      result = '$kasWhole.0';
    } else {
      final fractionStr = kasFraction.abs().toString().padLeft(8, '0');
      final trimmed = fractionStr
          .substring(0, decimals.clamp(0, 8))
          .replaceAll(RegExp(r'0+$'), '');
      result = trimmed.isEmpty ? '$kasWhole.0' : '$kasWhole.$trimmed';
    }

    return showSymbol ? '$result KAS' : result;
  }

  /// Format as compact string (K, M, B suffixes)
  String formatCompact({bool showSymbol = true}) {
    final kasValue = kas;
    String result;
    if (kasValue >= 1e9) {
      result = '${(kasValue / 1e9).toStringAsFixed(2)}B';
    } else if (kasValue >= 1e6) {
      result = '${(kasValue / 1e6).toStringAsFixed(2)}M';
    } else if (kasValue >= 1e3) {
      result = '${(kasValue / 1e3).toStringAsFixed(2)}K';
    } else {
      result = kasValue.toStringAsFixed(2);
    }
    return showSymbol ? '$result KAS' : result;
  }

  /// Add another amount
  Amount operator +(Amount other) =>
      Amount._(_sompiValue + other._sompiValue);

  /// Subtract operator (throws if result would be negative)
  /// Equivalent to subtract()
  Amount operator -(Amount other) => subtract(other);

  /// Divide amount by integer divisor (integer division)
  /// Useful for fee splitting or distributing amounts
  Amount dividedBy(int divisor) {
    if (divisor <= 0) {
      throw ArgumentError('Divisor must be positive: $divisor');
    }
    return Amount._(_sompiValue ~/ BigInt.from(divisor));
  }

  /// Multiply amount by factor
  Amount operator *(int factor) {
    if (factor < 0) {
      throw ArgumentError('Factor cannot be negative: $factor');
    }
    return Amount._(_sompiValue * BigInt.from(factor));
  }

  /// Subtract another amount (throws if result would be negative)
  Amount subtract(Amount other) {
    if (other._sompiValue > _sompiValue) {
      throw InsufficientFundsException(
        code: 'INSUFFICIENT_FUNDS',
        message: 'Insufficient funds for subtraction',
        available: this,
        required: other,
      );
    }
    return Amount._(_sompiValue - other._sompiValue);
  }

  /// Subtract another amount (returns zero if result would be negative)
  Amount subtractSafe(Amount other) {
    if (other._sompiValue > _sompiValue) {
      return zero;
    }
    return Amount._(_sompiValue - other._sompiValue);
  }

  /// Compare amounts
  bool operator <(Amount other) => _sompiValue < other._sompiValue;
  bool operator <=(Amount other) => _sompiValue <= other._sompiValue;
  bool operator >(Amount other) => _sompiValue > other._sompiValue;
  bool operator >=(Amount other) => _sompiValue >= other._sompiValue;

  @override
  int compareTo(Amount other) => _sompiValue.compareTo(other._sompiValue);

  @override
  String toString() => formatKas();

  /// Convert to JSON-safe string
  String toJson() => _sompiValue.toString();

  /// Create from JSON string
  factory Amount.fromJson(String json) => Amount.fromSompi(BigInt.parse(json));

  @override
  List<Object?> get props => [_sompiValue];
}
