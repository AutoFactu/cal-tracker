import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/content_frame.dart';
import '../../auth/view_models/auth_view_model.dart';
import '../view_models/settings_view_model.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthViewModel>();
    final settings = context.watch<SettingsViewModel>();
    final user = auth.user;
    return ContentFrame(
      title: 'Settings',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (user != null) Text(user.email),
          SwitchListTile(
            key: const ValueKey('trusted_mode_toggle'),
            title: const Text('Trusted mode'),
            subtitle: const Text('Allow selected usual meals to log automatically.'),
            value: user?.trustedModeEnabled ?? false,
            onChanged: settings.isLoading
                ? null
                : (value) async {
                    final updated = await settings.setTrustedMode(value);
                    if (updated != null && context.mounted) {
                      context.read<AuthViewModel>().setUser(updated);
                    }
                  },
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: auth.logout,
            icon: const Icon(Icons.logout),
            label: const Text('Log out'),
          ),
        ],
      ),
    );
  }
}
