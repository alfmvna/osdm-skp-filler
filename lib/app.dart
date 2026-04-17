import 'package:flutter/material.dart';
import 'features/auth/login_screen.dart';
import 'features/dashboard/dashboard_screen.dart';
import 'features/date_select/date_select_screen.dart';
import 'features/log_entry/log_entry_screen.dart';
import 'features/log_viewer/log_viewer_screen.dart';
import 'features/log_entry/confirmation_screen.dart';
import 'shared/theme/app_theme.dart';

class OSDMApp extends StatelessWidget {
  const OSDMApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OSDM SKP Filler',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      initialRoute: '/',
      routes: {
        '/': (context) => const LoginScreen(),
        '/dashboard': (context) => const DashboardScreen(),
        '/date-select': (context) => const DateSelectScreen(),
        '/log-entry': (context) => const LogEntryScreen(),
        '/log-viewer': (context) => const LogViewerScreen(),
        '/confirmation': (context) => const ConfirmationScreen(),
      },
    );
  }
}
