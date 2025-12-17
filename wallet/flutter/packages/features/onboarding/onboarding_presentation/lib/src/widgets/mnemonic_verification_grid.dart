import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';

/// Grid of options for mnemonic word verification.
///
/// Displays 4 word options for the user to select the correct one.
class MnemonicVerificationGrid extends StatelessWidget {
  /// List of word options to choose from
  final List<String> options;

  /// Called when user selects an option
  final ValueChanged<String> onOptionSelected;

  /// Currently selected option (if any)
  final String? selectedOption;

  /// Index of the correct option (for showing result)
  final int? correctOptionIndex;

  /// Whether the selection has been made and result shown
  final bool showResult;

  const MnemonicVerificationGrid({
    super.key,
    required this.options,
    required this.onOptionSelected,
    this.selectedOption,
    this.correctOptionIndex,
    this.showResult = false,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: AppSpacing.xs,
        crossAxisSpacing: AppSpacing.xs,
        childAspectRatio: 2.5,
      ),
      itemCount: options.length,
      itemBuilder: (context, index) {
        final word = options[index];
        final isSelected = selectedOption == word;
        final isCorrect = correctOptionIndex == index;

        return VerificationOptionCard(
          key: ValueKey('option_$index\_$word'),
          word: word,
          index: index,
          isSelected: isSelected,
          isCorrect: showResult && isCorrect,
          isIncorrect: showResult && isSelected && !isCorrect,
          onTap: showResult ? null : () => onOptionSelected(word),
        );
      },
    );
  }
}

/// Individual option card in the verification grid.
class VerificationOptionCard extends StatelessWidget {
  final String word;
  final int index;
  final bool isSelected;
  final bool isCorrect;
  final bool isIncorrect;
  final VoidCallback? onTap;

  const VerificationOptionCard({
    super.key,
    required this.word,
    required this.index,
    this.isSelected = false,
    this.isCorrect = false,
    this.isIncorrect = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Color backgroundColor;
    Color borderColor;
    Color textColor;

    if (isCorrect) {
      backgroundColor = AppColors.success.withValues(alpha: 0.15);
      borderColor = AppColors.success;
      textColor = AppColors.success;
    } else if (isIncorrect) {
      backgroundColor = AppColors.error.withValues(alpha: 0.15);
      borderColor = AppColors.error;
      textColor = AppColors.error;
    } else if (isSelected) {
      backgroundColor = theme.colorScheme.primaryContainer;
      borderColor = theme.colorScheme.primary;
      textColor = theme.colorScheme.onPrimaryContainer;
    } else {
      backgroundColor = theme.colorScheme.surfaceContainerHighest;
      borderColor = theme.colorScheme.outline;
      textColor = theme.colorScheme.onSurface;
    }

    return Semantics(
      button: true,
      label: 'Option ${index + 1}: $word',
      selected: isSelected,
      child: Material(
        color: backgroundColor,
        borderRadius: AppRadii.borderRadiusMd,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadii.borderRadiusMd,
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: borderColor,
                width: isSelected || isCorrect || isIncorrect ? 2 : 1,
              ),
              borderRadius: AppRadii.borderRadiusMd,
            ),
            alignment: Alignment.center,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isCorrect)
                  Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.xxs),
                    child: Icon(
                      Icons.check_circle_rounded,
                      size: 18,
                      color: textColor,
                    ),
                  ),
                if (isIncorrect)
                  Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.xxs),
                    child: Icon(
                      Icons.cancel_rounded,
                      size: 18,
                      color: textColor,
                    ),
                  ),
                Text(
                  word,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: textColor,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
