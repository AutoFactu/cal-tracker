import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 720;
        if (isWide) {
          return Scaffold(
            body: Row(
              children: [
                NavigationRail(
                  selectedIndex: _selectedIndex(context),
                  onDestinationSelected: (index) => _go(context, index),
                  labelType: NavigationRailLabelType.all,
                  destinations: const [
                    NavigationRailDestination(icon: Icon(Icons.edit_note), label: Text('Log')),
                    NavigationRailDestination(icon: Icon(Icons.monitor_heart), label: Text('Today')),
                    NavigationRailDestination(icon: Icon(Icons.history), label: Text('History')),
                    NavigationRailDestination(icon: Icon(Icons.restaurant_menu), label: Text('Usual')),
                    NavigationRailDestination(icon: Icon(Icons.settings), label: Text('Settings')),
                  ],
                ),
                const VerticalDivider(width: 1),
                Expanded(child: child),
              ],
            ),
          );
        }
        return Scaffold(
          body: child,
          bottomNavigationBar: NavigationBar(
            selectedIndex: _selectedIndex(context),
            onDestinationSelected: (index) => _go(context, index),
            destinations: const [
              NavigationDestination(icon: Icon(Icons.edit_note), label: 'Log'),
              NavigationDestination(icon: Icon(Icons.monitor_heart), label: 'Today'),
              NavigationDestination(icon: Icon(Icons.history), label: 'History'),
              NavigationDestination(icon: Icon(Icons.restaurant_menu), label: 'Usual'),
              NavigationDestination(icon: Icon(Icons.settings), label: 'Settings'),
            ],
          ),
        );
      },
    );
  }

  int _selectedIndex(BuildContext context) {
    final path = GoRouterState.of(context).matchedLocation;
    return switch (path) {
      '/dashboard' => 1,
      '/history' => 2,
      '/templates' => 3,
      '/settings' => 4,
      _ => 0,
    };
  }

  void _go(BuildContext context, int index) {
    final route = switch (index) {
      1 => '/dashboard',
      2 => '/history',
      3 => '/templates',
      4 => '/settings',
      _ => '/log',
    };
    context.go(route);
  }
}
