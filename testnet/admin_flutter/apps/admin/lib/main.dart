import 'package:flutter/material.dart';
import 'package:admin_design_system/admin_design_system.dart';

import 'src/di/injection.dart';
import 'src/router/app_router.dart';
import 'src/stores/theme_store.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await configureDependencies();

  runApp(const AdminApp());
}

class AdminApp extends StatelessWidget {
  const AdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: themeStore,
      builder: (context, _) {
        return MaterialApp.router(
          title: 'Qaspa Testnet Admin',
          debugShowCheckedModeBanner: false,
          theme: AdminTheme.light,
          darkTheme: AdminTheme.dark,
          themeMode: themeStore.themeMode,
          routerConfig: appRouter,
        );
      },
    );
  }
}
