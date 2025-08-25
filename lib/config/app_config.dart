class AppConfig {
  // Configuration API - CHANGEZ LOCALHOST PAR VOTRE IP POUR MOBILE
  static const String baseUrl = 'http://192.168.1.12/todo/';

  // Endpoints API validés lors des tests
  static const String registerEndpoint = 'register';
  static const String loginEndpoint = 'login';
  static const String todosEndpoint = 'todos';
  static const String insertTodoEndpoint = 'inserttodo';
  static const String updateTodoEndpoint = 'updatetodo';
  static const String deleteTodoEndpoint = 'deletetodo';

  // URLs complètes
  static String get registerUrl => '$baseUrl$registerEndpoint';
  static String get loginUrl => '$baseUrl$loginEndpoint';
  static String get todosUrl => '$baseUrl$todosEndpoint';
  static String get insertTodoUrl => '$baseUrl$insertTodoEndpoint';
  static String get updateTodoUrl => '$baseUrl$updateTodoEndpoint';
  static String get deleteTodoUrl => '$baseUrl$deleteTodoEndpoint';

  // Configuration base de données locale
  static const String databaseName = 'todo_app.db';
  static const int databaseVersion = 1;

  // Noms des tables locales
  static const String usersTable = 'users';
  static const String todosTable = 'todos';
  static const String weatherTable = 'weather';

  // Clés SharedPreferences
  static const String userIdKey = 'user_id';
  static const String emailKey = 'user_email';
  static const String profileImageKey = 'profile_image_path';
  static const String isLoggedInKey = 'is_logged_in';
  static const String lastSyncKey = 'last_sync_timestamp';

  // Configuration météo (OpenWeatherMap - optionnel)
  static const String weatherApiKey = 'YOUR_WEATHER_API_KEY';
  static const String weatherBaseUrl =
      'https://api.openweathermap.org/data/2.5/weather';

  // Configuration app
  static const Duration syncTimeout = Duration(seconds: 30);
  static const Duration weatherCacheTimeout = Duration(minutes: 30);
  static const int maxOfflineTodos = 1000;

  // Messages d'erreur
  static const String networkErrorMessage = 'Erreur de connexion réseau';
  static const String serverErrorMessage = 'Erreur serveur, veuillez réessayer';
  static const String authErrorMessage = 'Email ou mot de passe incorrect';
  static const String offlineModeMessage = 'Mode hors ligne activé';
}
