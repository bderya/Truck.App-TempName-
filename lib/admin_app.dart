import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'features/admin_dashboard/admin_shell.dart';
import 'features/admin_dashboard/theme/admin_theme.dart';

/// Flutter Web Admin Dashboard entry.
/// Run with: flutter run -d chrome (or flutter run -d web-server)
class AdminApp extends StatelessWidget {
  const AdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'app_title'.tr(),
      debugShowCheckedModeBanner: false,
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,
      theme: AdminTheme.dark,
      home: const AdminShell(),
    );
  }
}
