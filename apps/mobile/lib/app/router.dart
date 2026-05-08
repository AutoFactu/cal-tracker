import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../ui/features/auth/view_models/auth_view_model.dart';
import '../ui/features/auth/views/auth_screen.dart';
import '../ui/features/dashboard/views/dashboard_screen.dart';
import '../ui/features/meal_history/views/meal_history_screen.dart';
import '../ui/features/meal_templates/views/meal_templates_screen.dart';
import '../ui/features/settings/views/settings_screen.dart';
import '../ui/features/voice_log/views/voice_log_screen.dart';
import '../ui/core/app_shell.dart';

GoRouter buildRouter(AuthViewModel authViewModel) {
  return GoRouter(
    initialLocation: '/log',
    refreshListenable: authViewModel,
    redirect: (context, state) {
      final isAuthRoute = state.matchedLocation == '/auth';
      if (!authViewModel.hasSession && !isAuthRoute) {
        return '/auth';
      }
      if (authViewModel.hasSession && isAuthRoute) {
        return '/log';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/auth',
        builder: (context, state) => const AuthScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(path: '/log', builder: (context, state) => const VoiceLogScreen()),
          GoRoute(path: '/dashboard', builder: (context, state) => const DashboardScreen()),
          GoRoute(path: '/history', builder: (context, state) => const MealHistoryScreen()),
          GoRoute(path: '/templates', builder: (context, state) => const MealTemplatesScreen()),
          GoRoute(path: '/settings', builder: (context, state) => const SettingsScreen()),
        ],
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(child: Text(state.error?.message ?? 'Route not found')),
    ),
  );
}
