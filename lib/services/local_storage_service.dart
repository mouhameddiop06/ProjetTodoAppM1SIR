import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';

class LocalStorageService {
  static final LocalStorageService _instance = LocalStorageService._internal();
  factory LocalStorageService() => _instance;
  LocalStorageService._internal();

  SharedPreferences? _prefs;

  // Initialiser SharedPreferences
  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  // Vérifier l'initialisation
  void _checkInit() {
    if (_prefs == null) {
      throw Exception(
          'LocalStorageService non initialisé. Appelez init() d\'abord.');
    }
  }

  // === GESTION UTILISATEUR ===

  /// Sauvegarder les données de connexion
  Future<bool> saveUserSession({
    required int userId,
    required String email,
    String? profileImagePath,
  }) async {
    _checkInit();

    try {
      await _prefs!.setInt(AppConfig.userIdKey, userId);
      await _prefs!.setString(AppConfig.emailKey, email);
      await _prefs!.setBool(AppConfig.isLoggedInKey, true);

      if (profileImagePath != null) {
        await _prefs!.setString(AppConfig.profileImageKey, profileImagePath);
      }

      return true;
    } catch (e) {
      print('Erreur lors de la sauvegarde de session: $e');
      return false;
    }
  }

  /// Récupérer l'ID de l'utilisateur connecté
  int? getUserId() {
    _checkInit();
    return _prefs!.getInt(AppConfig.userIdKey);
  }

  /// Récupérer l'email de l'utilisateur connecté
  String? getUserEmail() {
    _checkInit();
    return _prefs!.getString(AppConfig.emailKey);
  }

  /// Récupérer le chemin de la photo de profil
  String? getProfileImagePath() {
    _checkInit();
    return _prefs!.getString(AppConfig.profileImageKey);
  }

  /// Vérifier si l'utilisateur est connecté
  bool isLoggedIn() {
    _checkInit();
    return _prefs!.getBool(AppConfig.isLoggedInKey) ?? false;
  }

  /// Sauvegarder le chemin de la photo de profil
  Future<bool> saveProfileImagePath(String path) async {
    _checkInit();
    try {
      await _prefs!.setString(AppConfig.profileImageKey, path);
      return true;
    } catch (e) {
      print('Erreur lors de la sauvegarde de l\'image: $e');
      return false;
    }
  }

  // === GESTION SYNCHRONISATION ===

  /// Sauvegarder le timestamp de dernière synchronisation
  Future<bool> saveLastSyncTimestamp() async {
    _checkInit();
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      await _prefs!.setInt(AppConfig.lastSyncKey, timestamp);
      return true;
    } catch (e) {
      print('Erreur lors de la sauvegarde du timestamp: $e');
      return false;
    }
  }

  /// Récupérer le timestamp de dernière synchronisation
  DateTime? getLastSyncTimestamp() {
    _checkInit();
    final timestamp = _prefs!.getInt(AppConfig.lastSyncKey);
    return timestamp != null
        ? DateTime.fromMillisecondsSinceEpoch(timestamp)
        : null;
  }

  /// Vérifier si une synchronisation est nécessaire
  bool needsSync({Duration threshold = const Duration(minutes: 5)}) {
    final lastSync = getLastSyncTimestamp();
    if (lastSync == null) return true;

    final now = DateTime.now();
    return now.difference(lastSync) > threshold;
  }

  // === PARAMÈTRES APPLICATIFS ===

  /// Sauvegarder un paramètre booléen
  Future<bool> saveBooleanSetting(String key, bool value) async {
    _checkInit();
    try {
      await _prefs!.setBool(key, value);
      return true;
    } catch (e) {
      print('Erreur lors de la sauvegarde du paramètre $key: $e');
      return false;
    }
  }

  /// Récupérer un paramètre booléen
  bool getBooleanSetting(String key, {bool defaultValue = false}) {
    _checkInit();
    return _prefs!.getBool(key) ?? defaultValue;
  }

  /// Sauvegarder un paramètre string
  Future<bool> saveStringSetting(String key, String value) async {
    _checkInit();
    try {
      await _prefs!.setString(key, value);
      return true;
    } catch (e) {
      print('Erreur lors de la sauvegarde du paramètre $key: $e');
      return false;
    }
  }

  /// Récupérer un paramètre string
  String? getStringSetting(String key, {String? defaultValue}) {
    _checkInit();
    return _prefs!.getString(key) ?? defaultValue;
  }

  /// Sauvegarder un paramètre int
  Future<bool> saveIntSetting(String key, int value) async {
    _checkInit();
    try {
      await _prefs!.setInt(key, value);
      return true;
    } catch (e) {
      print('Erreur lors de la sauvegarde du paramètre $key: $e');
      return false;
    }
  }

  /// Récupérer un paramètre int
  int? getIntSetting(String key, {int? defaultValue}) {
    _checkInit();
    return _prefs!.getInt(key) ?? defaultValue;
  }

  // === CACHE ET DONNÉES TEMPORAIRES ===

  /// Sauvegarder des données JSON en cache
  Future<bool> cacheJsonData(String key, String jsonData) async {
    _checkInit();
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      await _prefs!.setString('${key}_data', jsonData);
      await _prefs!.setInt('${key}_timestamp', timestamp);
      return true;
    } catch (e) {
      print('Erreur lors de la mise en cache: $e');
      return false;
    }
  }

  /// Récupérer des données JSON du cache
  String? getCachedJsonData(String key, {Duration? maxAge}) {
    _checkInit();

    if (maxAge != null) {
      final timestamp = _prefs!.getInt('${key}_timestamp');
      if (timestamp != null) {
        final cacheTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
        final now = DateTime.now();
        if (now.difference(cacheTime) > maxAge) {
          // Cache expiré, le supprimer
          clearCachedData(key);
          return null;
        }
      }
    }

    return _prefs!.getString('${key}_data');
  }

  /// Supprimer des données du cache
  Future<bool> clearCachedData(String key) async {
    _checkInit();
    try {
      await _prefs!.remove('${key}_data');
      await _prefs!.remove('${key}_timestamp');
      return true;
    } catch (e) {
      print('Erreur lors de la suppression du cache: $e');
      return false;
    }
  }

  // === DÉCONNEXION ET NETTOYAGE ===

  /// Effacer toutes les données de session
  Future<bool> clearUserSession() async {
    _checkInit();
    try {
      await _prefs!.remove(AppConfig.userIdKey);
      await _prefs!.remove(AppConfig.emailKey);
      await _prefs!.remove(AppConfig.isLoggedInKey);
      await _prefs!.remove(AppConfig.profileImageKey);
      await _prefs!.remove(AppConfig.lastSyncKey);
      return true;
    } catch (e) {
      print('Erreur lors de la suppression de session: $e');
      return false;
    }
  }

  /// Effacer toutes les données de l'application
  Future<bool> clearAllData() async {
    _checkInit();
    try {
      await _prefs!.clear();
      return true;
    } catch (e) {
      print('Erreur lors du nettoyage complet: $e');
      return false;
    }
  }

  // === MÉTHODES UTILITAIRES ===

  /// Récupérer toutes les clés stockées (pour debug)
  Set<String> getAllKeys() {
    _checkInit();
    return _prefs!.getKeys();
  }

  /// Vérifier si une clé existe
  bool hasKey(String key) {
    _checkInit();
    return _prefs!.containsKey(key);
  }

  /// Obtenir la taille approximative des données stockées (en nombre de clés)
  int getStorageSize() {
    _checkInit();
    return _prefs!.getKeys().length;
  }

  /// Obtenir un résumé des données stockées (pour debug)
  Map<String, dynamic> getStorageSummary() {
    _checkInit();
    final keys = _prefs!.getKeys();
    final summary = <String, dynamic>{};

    for (String key in keys) {
      final value = _prefs!.get(key);
      summary[key] = value?.runtimeType.toString() ?? 'null';
    }

    return summary;
  }
}
