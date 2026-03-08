import 'package:flutter/material.dart';

import 'screens/dashboard_screen.dart';
import 'screens/drivers_screen.dart';
import 'screens/bookings_screen.dart';
import 'screens/settings_screen.dart';

enum AdminNav { dashboard, drivers, bookings, settings }

class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  AdminNav _current = AdminNav.dashboard;

  static const _navItems = [
    (AdminNav.dashboard, Icons.dashboard_rounded, 'Dashboard'),
    (AdminNav.drivers, Icons.local_shipping_rounded, 'Drivers'),
    (AdminNav.bookings, Icons.book_online_rounded, 'Bookings'),
    (AdminNav.settings, Icons.settings_rounded, 'Settings'),
  ];

  Widget _body() {
    switch (_current) {
      case AdminNav.dashboard:
        return const DashboardScreen();
      case AdminNav.drivers:
        return const DriversScreen();
      case AdminNav.bookings:
        return const BookingsScreen();
      case AdminNav.settings:
        return const SettingsScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          _Sidebar(
            current: _current,
            items: _navItems,
            onTap: (v) => setState(() => _current = v),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppBar(
                  title: Text(_navItems.firstWhere((e) => e.$1 == _current).$3),
                  automaticallyImplyLeading: false,
                ),
                Expanded(child: _body()),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.current,
    required this.items,
    required this.onTap,
  });

  final AdminNav current;
  final List<(AdminNav, IconData, String)> items;
  final ValueChanged<AdminNav> onTap;

  @override
  Widget build(BuildContext context) {
    const goldAccent = Color(0xFFD4AF37);
    const surfaceVariant = Color(0xFF1E1E1E);

    return Container(
      width: 240,
      decoration: const BoxDecoration(
        color: surfaceVariant,
        border: Border(right: BorderSide(color: Colors.white12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Icon(Icons.local_shipping_rounded, color: goldAccent, size: 28),
                const SizedBox(width: 10),
                Text(
                  'Cekici Admin',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: goldAccent,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          ...items.map((e) {
            final (nav, icon, label) = e;
            final selected = current == nav;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Material(
                color: selected ? goldAccent.withValues(alpha: 0.15) : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                child: InkWell(
                  onTap: () => onTap(nav),
                  borderRadius: BorderRadius.circular(10),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    child: Row(
                      children: [
                        Icon(
                          icon,
                          size: 22,
                          color: selected ? goldAccent : Colors.white70,
                        ),
                        const SizedBox(width: 14),
                        Text(
                          label,
                          style: TextStyle(
                            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                            color: selected ? goldAccent : Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
