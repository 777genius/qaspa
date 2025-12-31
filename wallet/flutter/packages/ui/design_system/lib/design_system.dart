/// Shared Material 3 design system with brand color scheme.
///
/// This package provides:
/// - Color tokens (brand theme)
/// - Typography tokens
/// - Spacing constants
/// - Light and dark themes
/// - Reusable atomic widgets
library design_system;

// Tokens
export 'src/tokens/colors.dart';
export 'src/tokens/typography.dart';
export 'src/tokens/spacing.dart';
export 'src/tokens/radii.dart';

// Theme
export 'src/theme/app_theme.dart';
export 'src/theme/light_theme.dart';
export 'src/theme/dark_theme.dart';

// Widgets - Buttons
export 'src/widgets/buttons/primary_button.dart';
export 'src/widgets/buttons/secondary_button.dart';
export 'src/widgets/buttons/text_button.dart';
export 'src/widgets/buttons/icon_action_button.dart';

// Widgets - Inputs
export 'src/widgets/inputs/app_text_field.dart';
export 'src/widgets/inputs/pin_input.dart';
export 'src/widgets/inputs/amount_input.dart';
export 'src/widgets/inputs/search_field.dart';

// Widgets - Cards
export 'src/widgets/cards/info_card.dart';

// Widgets - Feedback
export 'src/widgets/feedback/loading_indicator.dart';
export 'src/widgets/feedback/error_message.dart';
export 'src/widgets/feedback/success_message.dart';
export 'src/widgets/feedback/empty_state.dart';

// Widgets - Display
export 'src/widgets/display/mnemonic_word_chip.dart';
export 'src/widgets/display/mnemonic_grid.dart';
export 'src/widgets/display/address_display.dart';
export 'src/widgets/display/amount_display.dart';
export 'src/widgets/display/balance_card_label.dart';
export 'src/widgets/display/balance_card_main_balance.dart';
export 'src/widgets/display/balance_card_fiat_value.dart';
export 'src/widgets/display/balance_card_pending.dart';

// Widgets - Layout
export 'src/widgets/layout/screen_container.dart';
export 'src/widgets/layout/scrollable_screen_container.dart';
export 'src/widgets/layout/section_header.dart';
export 'src/widgets/layout/action_row.dart';
export 'src/widgets/layout/bottom_action_bar.dart';
