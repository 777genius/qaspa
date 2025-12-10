import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';

/// Scaffold wrapper for onboarding pages.
///
/// Provides consistent layout with:
/// - Optional back button
/// - Title
/// - Scrollable content area
/// - Bottom action area
class OnboardingScaffold extends StatelessWidget {
  /// Page title shown in app bar
  final String title;

  /// Main content of the page
  final Widget child;

  /// Bottom action widgets (buttons)
  final Widget? bottomActions;

  /// Whether to show back button
  final bool showBackButton;

  /// Custom back button callback
  final VoidCallback? onBack;

  /// Whether content should be scrollable
  final bool scrollable;

  const OnboardingScaffold({
    super.key,
    required this.title,
    required this.child,
    this.bottomActions,
    this.showBackButton = true,
    this.onBack,
    this.scrollable = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        centerTitle: true,
        leading: showBackButton
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: onBack ?? () => Navigator.of(context).maybePop(),
                tooltip: 'Back',
              )
            : null,
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: scrollable
                  ? SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.screenHorizontal,
                        vertical: AppSpacing.screenVertical,
                      ),
                      child: child,
                    )
                  : Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.screenHorizontal,
                        vertical: AppSpacing.screenVertical,
                      ),
                      child: child,
                    ),
            ),
            if (bottomActions != null)
              Container(
                padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  border: Border(
                    top: BorderSide(
                      color: theme.colorScheme.outlineVariant,
                      width: 0.5,
                    ),
                  ),
                ),
                child: SafeArea(
                  top: false,
                  child: bottomActions!,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
