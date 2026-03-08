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
      title: 'Cekici Admin',
      debugShowCheckedModeBanner: false,
      theme: AdminTheme.dark,
      home: const AdminShell(),
    );
  }
}
