class ApiConfig {
  const ApiConfig({required this.baseUrl});

  const ApiConfig.fromEnvironment()
      : baseUrl = const String.fromEnvironment(
          'API_BASE_URL',
          defaultValue: 'http://localhost:3000',
        );

  final String baseUrl;
}
