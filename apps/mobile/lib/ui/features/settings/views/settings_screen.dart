import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/content_frame.dart';
import '../../../core/design_system.dart';
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
      title: 'Menu',
      subtitle: 'Account and preferences',
      actions: const [
        FreshIconButton(icon: Icons.more_horiz_rounded, tooltip: 'More'),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FreshCard(
            radius: FreshRadii.xl,
            color: FreshColors.limeSoft,
            child: Row(
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: const BoxDecoration(
                    color: FreshColors.surface,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.person_rounded,
                    color: FreshColors.limeDeep,
                    size: 30,
                  ),
                ),
                const SizedBox(width: FreshSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user?.displayName ?? 'Cal Tracker',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      if (user != null)
                        Text(
                          user.email,
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(color: FreshColors.inkSoft),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: FreshSpacing.lg),
          FreshCard(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            child: SwitchListTile(
              key: const ValueKey('trusted_mode_toggle'),
              contentPadding: EdgeInsets.zero,
              secondary: const FreshIconChip(
                icon: Icons.verified_rounded,
                color: FreshColors.limeDeep,
              ),
              title: const Text('Trusted mode'),
              subtitle: const Text(
                  'Allow selected usual meals to log automatically.'),
              value: user?.trustedModeEnabled ?? false,
              activeThumbColor: FreshColors.lime,
              onChanged: settings.isLoading
                  ? null
                  : (value) async {
                      final updated = await settings.setTrustedMode(value);
                      if (updated != null && context.mounted) {
                        context.read<AuthViewModel>().setUser(updated);
                      }
                    },
            ),
          ),
          const SizedBox(height: FreshSpacing.md),
          FreshCard(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const FreshIconChip(
                  icon: Icons.water_drop_rounded,
                  color: FreshColors.water,
                ),
                const SizedBox(width: FreshSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Hydration goal',
                          style: Theme.of(context).textTheme.titleMedium),
                      Text(
                        '12 glasses per day',
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(color: FreshColors.inkMuted),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded),
              ],
            ),
          ),
          const SizedBox(height: FreshSpacing.md),
          FreshCard(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const FreshIconChip(
                  icon: Icons.flag_rounded,
                  color: FreshColors.orange,
                ),
                const SizedBox(width: FreshSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Calorie target',
                          style: Theme.of(context).textTheme.titleMedium),
                      Text(
                        '1920 Kcal daily target',
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(color: FreshColors.inkMuted),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded),
              ],
            ),
          ),
          const SizedBox(height: FreshSpacing.xl),
          OutlinedButton.icon(
            onPressed: auth.logout,
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Log out'),
          ),
        ],
      ),
    );
  }
}
