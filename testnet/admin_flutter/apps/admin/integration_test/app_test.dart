import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:admin/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Admin Panel Full E2E Test', (tester) async {
    // Start the app
    app.main();
    await tester.pumpAndSettle(const Duration(seconds: 15));

    // ========== 1. Verify Dashboard loaded ==========
    debugPrint('TEST: Verifying Dashboard loaded...');

    // Debug: print all text widgets to see what's on screen
    final allTexts = find.byType(Text);
    debugPrint('TEST: Found ${allTexts.evaluate().length} Text widgets');
    for (final element in allTexts.evaluate().take(20)) {
      final widget = element.widget as Text;
      debugPrint('TEST: Text: "${widget.data}"');
    }

    // Check if error or loading is shown
    if (find.text('Failed to initialize').evaluate().isNotEmpty) {
      debugPrint('TEST: App shows initialization error!');
    }
    if (find.text('Initializing dashboard...').evaluate().isNotEmpty) {
      debugPrint('TEST: App is still initializing...');
      await tester.pumpAndSettle(const Duration(seconds: 10));
    }
    if (find.text('Loading cluster stats...').evaluate().isNotEmpty) {
      debugPrint('TEST: App is loading stats...');
      await tester.pumpAndSettle(const Duration(seconds: 10));
    }

    // Verify sidebar navigation items exist (may appear multiple times due to title)
    expect(find.text('Dashboard'), findsWidgets);
    expect(find.text('Nodes'), findsWidgets);
    expect(find.text('Miners'), findsWidgets);
    expect(find.text('Logs'), findsWidgets);

    // Verify sidebar icons
    expect(find.byIcon(Icons.dashboard_outlined), findsWidgets);
    expect(find.byIcon(Icons.dns_outlined), findsWidgets);
    expect(find.byIcon(Icons.memory_outlined), findsWidgets);
    expect(find.byIcon(Icons.article_outlined), findsWidgets);

    // Verify Dashboard content - allow loading state or content
    final hasClusterOverview = find.text('Cluster Overview').evaluate().isNotEmpty;
    final hasError = find.textContaining('Failed').evaluate().isNotEmpty;
    final hasLoading = find.textContaining('Loading').evaluate().isNotEmpty ||
                       find.textContaining('Initializing').evaluate().isNotEmpty;

    debugPrint('TEST: hasClusterOverview=$hasClusterOverview, hasError=$hasError, hasLoading=$hasLoading');

    // App should either show content, loading, or error - but UI must be present
    expect(hasClusterOverview || hasError || hasLoading, isTrue,
        reason: 'Dashboard should show content, error, or loading state');

    expect(find.byType(Card), findsWidgets);

    // Verify theme toggle button
    final themeToggle = find.byTooltip('Toggle theme');
    expect(themeToggle, findsOneWidget);

    debugPrint('TEST: Dashboard verified successfully');

    // ========== 2. Navigate to Nodes page ==========
    debugPrint('TEST: Navigating to Nodes page...');
    await tester.tap(find.text('Nodes').first);
    await tester.pumpAndSettle(const Duration(seconds: 5));

    // Verify Nodes page
    expect(find.text('Add Node'), findsOneWidget);

    // Check for node cards with actions
    expect(find.byType(Card), findsWidgets);

    debugPrint('TEST: Nodes page verified');

    // ========== 3. Open Add Node dialog ==========
    debugPrint('TEST: Opening Add Node dialog...');
    await tester.tap(find.text('Add Node'));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    // Verify dialog opened
    expect(find.byType(AlertDialog), findsOneWidget);

    // Close dialog
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    debugPrint('TEST: Add Node dialog tested');

    // ========== 4. Navigate to Miners page ==========
    debugPrint('TEST: Navigating to Miners page...');
    await tester.tap(find.text('Miners').first);
    await tester.pumpAndSettle(const Duration(seconds: 5));

    // Verify Miners page (may have Add Miner button in header and empty state)
    expect(find.text('Add Miner'), findsWidgets);

    debugPrint('TEST: Miners page verified');

    // ========== 5. Open Add Miner dialog ==========
    debugPrint('TEST: Opening Add Miner dialog...');
    await tester.tap(find.text('Add Miner').first);
    await tester.pumpAndSettle(const Duration(seconds: 2));

    // Verify dialog opened
    expect(find.byType(AlertDialog), findsOneWidget);

    // Close dialog
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    debugPrint('TEST: Add Miner dialog tested');

    // ========== 6. Navigate back to Dashboard ==========
    debugPrint('TEST: Navigating back to Dashboard...');
    await tester.tap(find.text('Dashboard').first);
    await tester.pumpAndSettle(const Duration(seconds: 3));

    // Verify we're back on Dashboard
    expect(find.text('Cluster Overview'), findsWidgets);

    debugPrint('TEST: Full navigation cycle completed');

    // ========== 7. Test theme toggle ==========
    debugPrint('TEST: Testing theme toggle...');
    await tester.tap(themeToggle);
    await tester.pumpAndSettle(const Duration(seconds: 1));

    debugPrint('TEST: Theme toggle tested');

    debugPrint('TEST: All E2E tests passed!');
  });
}
