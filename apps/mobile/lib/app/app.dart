import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/repositories/auth_repository.dart';
import '../data/repositories/nutrition_repository.dart';
import '../data/services/api_config.dart';
import '../data/services/audio_recorder_service.dart';
import '../data/services/secure_token_storage.dart';
import '../generated/api/cal_tracker_api.dart';
import '../ui/features/auth/view_models/auth_view_model.dart';
import '../ui/features/dashboard/view_models/dashboard_view_model.dart';
import '../ui/features/meal_history/view_models/meal_history_view_model.dart';
import '../ui/features/meal_templates/view_models/meal_templates_view_model.dart';
import '../ui/features/settings/view_models/settings_view_model.dart';
import '../ui/features/voice_log/view_models/voice_log_view_model.dart';
import 'router.dart';
import 'theme.dart';

class CalTrackerBootstrap extends StatelessWidget {
  const CalTrackerBootstrap({
    super.key,
    this.apiConfig = const ApiConfig.fromEnvironment(),
  });

  final ApiConfig apiConfig;

  @override
  Widget build(BuildContext context) {
    const tokenStorage = SecureTokenStorage();
    final apiClient = CalTrackerApiClient(
      config: apiConfig,
      tokenStorage: tokenStorage,
    );
    final authRepository =
        AuthRepository(apiClient: apiClient, tokenStorage: tokenStorage);
    final nutritionRepository = NutritionRepository(apiClient: apiClient);

    return MultiProvider(
      providers: [
        Provider<AuthRepository>.value(value: authRepository),
        Provider<NutritionRepository>.value(value: nutritionRepository),
        ChangeNotifierProvider(
            create: (_) => AuthViewModel(authRepository: authRepository)
              ..restoreSession()),
        ChangeNotifierProvider(
            create: (_) => VoiceLogViewModel(
                  nutritionRepository: nutritionRepository,
                  audioRecorderService: AudioRecorderService(),
                )),
        ChangeNotifierProvider(
            create: (_) =>
                DashboardViewModel(nutritionRepository: nutritionRepository)),
        ChangeNotifierProvider(
            create: (_) =>
                MealHistoryViewModel(nutritionRepository: nutritionRepository)),
        ChangeNotifierProvider(
            create: (_) => MealTemplatesViewModel(
                nutritionRepository: nutritionRepository)),
        ChangeNotifierProvider(
            create: (_) => SettingsViewModel(authRepository: authRepository)),
      ],
      child: Consumer<AuthViewModel>(
        builder: (context, authViewModel, _) {
          return MaterialApp.router(
            title: 'Cal Tracker',
            debugShowCheckedModeBanner: false,
            theme: buildTheme(),
            routerConfig: buildRouter(authViewModel),
          );
        },
      ),
    );
  }
}
