import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations_context.dart';
import '../ui/core/design_system.dart';
import 'theme_mode_view_model.dart';

class DarkModeToggle extends StatelessWidget {
  const DarkModeToggle({super.key});

  static const toggleKey = ValueKey('dark_mode_toggle');

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeModeViewModel>(
      builder: (context, themeModeViewModel, _) {
        final isDarkMode = themeModeViewModel.isDarkMode;
        return FreshIconButton(
          key: toggleKey,
          tooltip: isDarkMode
              ? context.l10n.darkModeSwitchToLight
              : context.l10n.darkModeSwitchToDark,
          icon: isDarkMode ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
          onPressed: () => themeModeViewModel.setDarkMode(!isDarkMode),
        );
      },
    );
  }
}
