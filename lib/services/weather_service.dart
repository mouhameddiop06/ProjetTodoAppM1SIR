import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../models/weather_model.dart';
import '../utils/database_helper.dart';
import 'location_service.dart';

class WeatherService {
  static final WeatherService _instance = WeatherService._internal();
  factory WeatherService() => _instance;
  WeatherService._internal();

  final LocationService _locationService = LocationService();
  final DatabaseHelper _databaseHelper = DatabaseHelper();

  // Cache en mémoire pour éviter les appels répétés
  Weather? _cachedWeather;
  DateTime? _lastFetchTime;

  /// Obtenir la météo pour la position actuelle
  Future<WeatherResult> getCurrentWeather({
    bool forceRefresh = false,
  }) async {
    try {
      // Vérifier le cache en mémoire
      if (!forceRefresh && _isMemoryCacheValid()) {
        return WeatherResult.success(_cachedWeather!);
      }

      // Vérifier le cache de la base de données
      if (!forceRefresh) {
        final cachedWeather = await _getCachedWeatherFromDb();
        if (cachedWeather != null) {
          _cachedWeather = cachedWeather;
          _lastFetchTime = cachedWeather.lastUpdated;
          return WeatherResult.success(cachedWeather);
        }
      }

      // Obtenir la position actuelle
      final locationResult = await _locationService.getCurrentPosition();
      if (!locationResult.isSuccess) {
        return WeatherResult.error(
            'Impossible d\'obtenir la position: ${locationResult.error}');
      }

      final position = locationResult.position!;

      // Faire l'appel à l'API météo
      final weather = await _fetchWeatherFromApi(
        latitude: position.latitude,
        longitude: position.longitude,
      );

      if (weather != null) {
        // Mettre à jour les caches
        _cachedWeather = weather;
        _lastFetchTime = DateTime.now();
        await _saveWeatherToDb(weather);

        return WeatherResult.success(weather);
      } else {
        return WeatherResult.error('Impossible de récupérer les données météo');
      }
    } catch (e) {
      print('Erreur lors de la récupération de la météo: $e');

      // En cas d'erreur, essayer de retourner les données mises en cache
      final cachedWeather = await _getCachedWeatherFromDb();
      if (cachedWeather != null) {
        return WeatherResult.success(cachedWeather);
      }

      return WeatherResult.error('Erreur météo: ${e.toString()}');
    }
  }

  /// Obtenir la météo pour des coordonnées spécifiques
  Future<WeatherResult> getWeatherForLocation({
    required double latitude,
    required double longitude,
    bool useCache = true,
  }) async {
    try {
      // Si on autorise le cache et que la position est proche de la dernière
      if (useCache && _isLocationSimilar(latitude, longitude)) {
        if (_isMemoryCacheValid()) {
          return WeatherResult.success(_cachedWeather!);
        }
      }

      final weather = await _fetchWeatherFromApi(
        latitude: latitude,
        longitude: longitude,
      );

      if (weather != null) {
        _cachedWeather = weather;
        _lastFetchTime = DateTime.now();
        await _saveWeatherToDb(weather);

        return WeatherResult.success(weather);
      } else {
        return WeatherResult.error('Impossible de récupérer les données météo');
      }
    } catch (e) {
      print('Erreur lors de la récupération de la météo: $e');
      return WeatherResult.error('Erreur météo: ${e.toString()}');
    }
  }

  /// Récupérer les données météo depuis l'API
  Future<Weather?> _fetchWeatherFromApi({
    required double latitude,
    required double longitude,
  }) async {
    try {
      // Construire l'URL de l'API OpenWeatherMap
      final uri = Uri.parse(AppConfig.weatherBaseUrl).replace(queryParameters: {
        'lat': latitude.toString(),
        'lon': longitude.toString(),
        'appid': AppConfig.weatherApiKey,
        'units': 'metric', // Pour avoir la température en Celsius
        'lang': 'fr', // Descriptions en français
      });

      print('Appel API météo: $uri');

      final response = await http.get(uri).timeout(
            const Duration(seconds: 10),
          );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        return Weather.fromJson(data);
      } else {
        print('Erreur API météo: ${response.statusCode} - ${response.body}');
        return null;
      }
    } on SocketException {
      print('Pas de connexion internet pour la météo');
      return null;
    } on HttpException {
      print('Erreur HTTP lors de l\'appel météo');
      return null;
    } catch (e) {
      print('Erreur lors de l\'appel API météo: $e');
      return null;
    }
  }

  /// Récupérer la météo depuis le cache de la base de données
  Future<Weather?> _getCachedWeatherFromDb() async {
    try {
      final weather = await _databaseHelper.getLatestWeather();

      if (weather != null && weather.isDataFresh) {
        return weather;
      }

      return null;
    } catch (e) {
      print('Erreur lors de la récupération du cache météo: $e');
      return null;
    }
  }

  /// Sauvegarder la météo dans la base de données
  Future<void> _saveWeatherToDb(Weather weather) async {
    try {
      await _databaseHelper.insertWeather(weather);
    } catch (e) {
      print('Erreur lors de la sauvegarde de la météo: $e');
    }
  }

  /// Vérifier si le cache en mémoire est valide
  bool _isMemoryCacheValid() {
    if (_cachedWeather == null || _lastFetchTime == null) {
      return false;
    }

    final now = DateTime.now();
    return now.difference(_lastFetchTime!) < AppConfig.weatherCacheTimeout;
  }

  /// Vérifier si la position est similaire à la dernière position mise en cache
  bool _isLocationSimilar(double latitude, double longitude) {
    if (_cachedWeather == null) return false;

    // Note: Pour une implémentation complète, il faudrait stocker
    // les coordonnées dans le modèle Weather
    // Pour l'instant, on retourne false pour forcer la vérification
    return false;
  }

  /// Obtenir une description météo simple basée sur la température
  String getWeatherDescription(double temperature) {
    if (temperature >= 30) {
      return 'Très chaud';
    } else if (temperature >= 25) {
      return 'Chaud';
    } else if (temperature >= 20) {
      return 'Agréable';
    } else if (temperature >= 15) {
      return 'Frais';
    } else if (temperature >= 10) {
      return 'Froid';
    } else {
      return 'Très froid';
    }
  }

  /// Obtenir l'icône recommandée basée sur la température
  String getTemperatureIcon(double temperature) {
    if (temperature >= 25) {
      return '☀️';
    } else if (temperature >= 15) {
      return '🌤️';
    } else if (temperature >= 5) {
      return '☁️';
    } else {
      return '❄️';
    }
  }

  /// Obtenir les informations du cache pour debug
  Map<String, dynamic> getCacheInfo() {
    return {
      'has_memory_cache': _cachedWeather != null,
      'memory_cache_age_minutes': _lastFetchTime != null
          ? DateTime.now().difference(_lastFetchTime!).inMinutes
          : null,
      'memory_cache_valid': _isMemoryCacheValid(),
      'last_location': _cachedWeather?.location,
      'last_temperature': _cachedWeather?.temperature,
    };
  }

  /// Nettoyer tous les caches
  Future<void> clearCache() async {
    _cachedWeather = null;
    _lastFetchTime = null;

    try {
      // Optionnel: Nettoyer aussi la base de données
      // await _databaseHelper.clearWeatherCache();
    } catch (e) {
      print('Erreur lors du nettoyage du cache météo: $e');
    }
  }

  /// Vérifier si l'API météo est configurée
  bool isApiConfigured() {
    return AppConfig.weatherApiKey.isNotEmpty &&
        AppConfig.weatherApiKey != 'YOUR_WEATHER_API_KEY';
  }

  /// Obtenir des données météo de test (pour développement)
  Weather getTestWeather() {
    return Weather(
      temperature: 22.5,
      description: 'Ensoleillé',
      location: 'Dakar, SN',
      lastUpdated: DateTime.now(),
      icon: '01d',
    );
  }
}

/// Classe pour encapsuler les résultats météo
class WeatherResult {
  final bool isSuccess;
  final Weather? weather;
  final String? error;

  WeatherResult._({
    required this.isSuccess,
    this.weather,
    this.error,
  });

  factory WeatherResult.success(Weather weather) {
    return WeatherResult._(
      isSuccess: true,
      weather: weather,
    );
  }

  factory WeatherResult.error(String error) {
    return WeatherResult._(
      isSuccess: false,
      error: error,
    );
  }

  @override
  String toString() {
    if (isSuccess) {
      return 'WeatherResult.success(${weather?.temperatureDisplay} at ${weather?.location})';
    } else {
      return 'WeatherResult.error($error)';
    }
  }
}
