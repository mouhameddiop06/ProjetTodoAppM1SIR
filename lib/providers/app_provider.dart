import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/weather_model.dart';
import '../services/location_service.dart';
import '../services/weather_service.dart';
import '../services/local_storage_service.dart';

class AppProvider extends ChangeNotifier {
  final LocationService _locationService = LocationService();
  final WeatherService _weatherService = WeatherService();
  final LocalStorageService _localStorage = LocalStorageService();

  // État de l'application
  bool _isOnline = false;
  bool _isLoadingLocation = false;
  bool _isLoadingWeather = false;
  String? _errorMessage;

  // Données météo et localisation
  Weather? _currentWeather;
  String? _currentLocation;
  DateTime? _lastLocationUpdate;
  DateTime? _lastWeatherUpdate;

  // État des permissions
  LocationPermissionResult? _locationPermissionStatus;

  // Getters
  bool get isOnline => _isOnline;
  bool get isLoadingLocation => _isLoadingLocation;
  bool get isLoadingWeather => _isLoadingWeather;
  String? get errorMessage => _errorMessage;
  Weather? get currentWeather => _currentWeather;
  String? get currentLocation => _currentLocation;
  DateTime? get lastLocationUpdate => _lastLocationUpdate;
  DateTime? get lastWeatherUpdate => _lastWeatherUpdate;
  LocationPermissionResult? get locationPermissionStatus =>
      _locationPermissionStatus;

  // Getters formatés
  String get weatherDisplay {
    if (_currentWeather != null) {
      return '${_currentWeather!.temperatureDisplay} - ${_currentWeather!.capitalizedDescription}';
    }
    return 'Météo indisponible';
  }

  String get locationDisplay {
    return _currentLocation ?? 'Position inconnue';
  }

  String get connectivityStatus {
    return _isOnline ? 'En ligne' : 'Hors ligne';
  }

  /// Constructeur - Initialiser l'application
  AppProvider() {
    _initializeApp();
  }

  /// Initialiser l'état de l'application
  Future<void> _initializeApp() async {
    try {
      await _localStorage.init();
      await _checkConnectivity();
      await _checkLocationPermissions();

      // Démarrer l'écoute de la connectivité
      _startConnectivityListener();
    } catch (e) {
      print('Erreur initialisation app: $e');
      _setError('Erreur d\'initialisation de l\'application');
    }
  }

  /// Vérifier et mettre à jour la connectivité
  Future<void> _checkConnectivity() async {
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      _isOnline = connectivityResult != ConnectivityResult.none;
      notifyListeners();
    } catch (e) {
      print('Erreur vérification connectivité: $e');
      _isOnline = false;
      notifyListeners();
    }
  }

  /// Écouter les changements de connectivité
  void _startConnectivityListener() {
    Connectivity().onConnectivityChanged.listen((ConnectivityResult result) {
      final wasOnline = _isOnline;
      _isOnline = result != ConnectivityResult.none;

      if (!wasOnline && _isOnline) {
        // Reconnecté - actualiser les données
        _onReconnected();
      }

      notifyListeners();
    });
  }

  /// Actions à effectuer lors de la reconnexion
  void _onReconnected() {
    print('Reconnecté - actualisation des données');
    // Actualiser la météo si nécessaire
    if (_currentWeather == null || !_currentWeather!.isDataFresh) {
      updateWeather();
    }
  }

  /// Vérifier les permissions de localisation
  Future<void> _checkLocationPermissions() async {
    try {
      _locationPermissionStatus = await _locationService.checkPermissions();
      notifyListeners();
    } catch (e) {
      print('Erreur vérification permissions: $e');
      _locationPermissionStatus = LocationPermissionResult.error;
      notifyListeners();
    }
  }

  /// Demander les permissions de localisation
  Future<bool> requestLocationPermissions() async {
    try {
      _locationPermissionStatus = await _locationService.requestPermissions();
      notifyListeners();

      if (_locationPermissionStatus == LocationPermissionResult.granted) {
        await updateLocation();
        return true;
      }

      return false;
    } catch (e) {
      print('Erreur demande permissions: $e');
      _setError('Erreur lors de la demande de permissions');
      return false;
    }
  }

  /// Mettre à jour la position
  Future<void> updateLocation({bool forceRefresh = false}) async {
    if (_isLoadingLocation) return;

    _setLoadingLocation(true);
    _clearError();

    try {
      // Vérifier les permissions d'abord
      if (_locationPermissionStatus != LocationPermissionResult.granted) {
        await _checkLocationPermissions();
        if (_locationPermissionStatus != LocationPermissionResult.granted) {
          _setError('Permission de localisation requise');
          return;
        }
      }

      // Obtenir la position
      final locationResult = await _locationService.getCurrentPosition(
        forceRefresh: forceRefresh,
      );

      if (locationResult.isSuccess) {
        final position = locationResult.position!;

        // Formater la position
        _currentLocation = _locationService.formatPosition(position);
        _lastLocationUpdate = DateTime.now();

        notifyListeners();

        // Mettre à jour la météo avec la nouvelle position
        if (_isOnline) {
          await _updateWeatherForPosition(
            latitude: position.latitude,
            longitude: position.longitude,
          );
        }
      } else {
        _setError(locationResult.error ?? 'Erreur de géolocalisation');
      }
    } catch (e) {
      print('Erreur mise à jour position: $e');
      _setError('Erreur lors de la géolocalisation');
    } finally {
      _setLoadingLocation(false);
    }
  }

  /// Mettre à jour la météo
  Future<void> updateWeather({bool forceRefresh = false}) async {
    if (_isLoadingWeather) return;

    _setLoadingWeather(true);
    _clearError();

    try {
      if (!_isOnline) {
        // Essayer de récupérer depuis le cache
        final cachedWeather = await _weatherService.getCurrentWeather();
        if (cachedWeather.isSuccess) {
          _currentWeather = cachedWeather.weather;
          _lastWeatherUpdate = _currentWeather!.lastUpdated;
          notifyListeners();
        } else {
          _setError('Aucune donnée météo disponible hors ligne');
        }
        return;
      }

      // Vérifier si l'API météo est configurée
      if (!_weatherService.isApiConfigured()) {
        // Utiliser des données de test
        _currentWeather = _weatherService.getTestWeather();
        _lastWeatherUpdate = DateTime.now();
        notifyListeners();
        return;
      }

      // Récupérer la météo actuelle
      final weatherResult = await _weatherService.getCurrentWeather(
        forceRefresh: forceRefresh,
      );

      if (weatherResult.isSuccess) {
        _currentWeather = weatherResult.weather;
        _lastWeatherUpdate = _currentWeather!.lastUpdated;
        notifyListeners();
      } else {
        _setError(weatherResult.error ?? 'Erreur météo');
      }
    } catch (e) {
      print('Erreur mise à jour météo: $e');
      _setError('Erreur lors de la récupération de la météo');
    } finally {
      _setLoadingWeather(false);
    }
  }

  /// Mettre à jour la météo pour une position spécifique
  Future<void> _updateWeatherForPosition({
    required double latitude,
    required double longitude,
  }) async {
    if (!_isOnline) return;

    try {
      final weatherResult = await _weatherService.getWeatherForLocation(
        latitude: latitude,
        longitude: longitude,
      );

      if (weatherResult.isSuccess) {
        _currentWeather = weatherResult.weather;
        _lastWeatherUpdate = _currentWeather!.lastUpdated;
        notifyListeners();
      }
    } catch (e) {
      print('Erreur météo pour position: $e');
    }
  }

  /// Rafraîchir toutes les données
  Future<void> refreshAll() async {
    _clearError();

    await _checkConnectivity();

    // Mettre à jour la position et la météo en parallèle
    await Future.wait([
      updateLocation(forceRefresh: true),
      updateWeather(forceRefresh: true),
    ]);
  }

  /// Ouvrir les paramètres de localisation
  Future<bool> openLocationSettings() async {
    return await _locationService.openLocationSettings();
  }

  /// Ouvrir les paramètres d'application
  Future<bool> openAppSettings() async {
    return await _locationService.openAppSettings();
  }

  /// Obtenir les informations de cache
  Map<String, dynamic> getCacheInfo() {
    return {
      'location_cache': _locationService.getCacheInfo(),
      'weather_cache': _weatherService.getCacheInfo(),
      'last_location_update': _lastLocationUpdate?.toIso8601String(),
      'last_weather_update': _lastWeatherUpdate?.toIso8601String(),
    };
  }

  /// Nettoyer tous les caches
  Future<void> clearAllCaches() async {
    try {
      _locationService.clearCache();
      await _weatherService.clearCache();

      _currentWeather = null;
      _currentLocation = null;
      _lastLocationUpdate = null;
      _lastWeatherUpdate = null;

      notifyListeners();
    } catch (e) {
      print('Erreur nettoyage caches: $e');
    }
  }

  /// Gestion des états de chargement
  void _setLoadingLocation(bool loading) {
    _isLoadingLocation = loading;
    notifyListeners();
  }

  void _setLoadingWeather(bool loading) {
    _isLoadingWeather = loading;
    notifyListeners();
  }

  /// Gestion des erreurs
  void _setError(String error) {
    _errorMessage = error;
    notifyListeners();
  }

  void _clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  void clearError() {
    _clearError();
  }

  /// Obtenir un résumé de l'état de l'application
  Map<String, dynamic> getAppStatus() {
    return {
      'is_online': _isOnline,
      'has_location': _currentLocation != null,
      'has_weather': _currentWeather != null,
      'location_permission': _locationPermissionStatus?.name,
      'is_loading': _isLoadingLocation || _isLoadingWeather,
      'has_error': _errorMessage != null,
      'error_message': _errorMessage,
    };
  }

  @override
  void dispose() {
    // Nettoyer les ressources si nécessaire
    super.dispose();
  }
}
