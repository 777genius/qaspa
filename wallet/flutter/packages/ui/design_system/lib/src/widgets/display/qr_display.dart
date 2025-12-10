import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../tokens/colors.dart';
import '../../tokens/spacing.dart';
import '../../tokens/radii.dart';

/// QR code display widget for addresses.
class QrDisplay extends StatelessWidget {
  final String data;
  final double size;
  final Color? foregroundColor;
  final Color? backgroundColor;
  final String? label;

  const QrDisplay({
    super.key,
    required this.data,
    this.size = 200,
    this.foregroundColor,
    this.backgroundColor,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            color: backgroundColor ?? Colors.white,
            borderRadius: AppRadii.borderRadiusMd,
          ),
          child: QrImageView(
            data: data,
            version: QrVersions.auto,
            size: size,
            backgroundColor: Colors.white,
            eyeStyle: QrEyeStyle(
              eyeShape: QrEyeShape.square,
              color: foregroundColor ?? AppColors.kaspaDark,
            ),
            dataModuleStyle: QrDataModuleStyle(
              dataModuleShape: QrDataModuleShape.square,
              color: foregroundColor ?? AppColors.kaspaDark,
            ),
          ),
        ),
        if (label != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            label!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}
