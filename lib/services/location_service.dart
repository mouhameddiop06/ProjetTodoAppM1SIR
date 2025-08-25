import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  Position? _lastKnownPosition;
  DateTime? _lastUpdateTime;

  // Cache de position pour éviter les appels répétés
  static const Duration _cacheTimeout = Duration(minutes: 5);

  /// Vérifier les permissions de géolocalisation
  Future<LocationPermissionResult> checkPermissions() async {
    try {
      // Vérifier permission avec permission_handler
      PermissionStatus permission = await Permission.location.status;

      if (permission.isDenied) {
        // Demander la permission
        permission = await Permission.location.request();
      }

      if (permission.isPermanentlyDenied) {
        return LocationPermissionResult.permanentlyDenied;
      }

      if (permission.isDenied) {
        return LocationPermissionResult.denied;
      }

      // Vérifier que le service de localisation est activé
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return LocationPermissionResult.serviceDisabled;
      }

      return LocationPermissionResult.granted;
    } catch (e) {
      print('Erreur lors de la vérification des permissions: $e');
      return LocationPermissionResult.error;
    }
  }

  /// Demander les permissions de localisation
  Future<LocationPermissionResult> requestPermissions() async {
    try {
      // Vérifier d'abord si le service est activé
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return LocationPermissionResult.serviceDisabled;
      }

      // Demander permission avec geolocator (méthode alternative)
      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.deniedForever) {
        return LocationPermissionResult.permanentlyDenied;
      }

      if (permission == LocationPermission.denied) {
        return LocationPermissionResult.denied;
      }

      return LocationPermissionResult.granted;
    } catch (e) {
      print('Erreur lors de la demande de permissions: $e');
      return LocationPermissionResult.error;
    }
  }

  /// Obtenir la position actuelle
  Future<LocationResult> getCurrentPosition({
    bool forceRefresh = false,
  }) async {
    try {
      // Vérifier le cache si pas de force refresh
      if (!forceRefresh && _isPositionCacheValid()) {
        return LocationResult.success(_lastKnownPosition!);
      }

      // Vérifier les permissions
      final permissionResult = await checkPermissions();
      if (permissionResult != LocationPermissionResult.granted) {
        return LocationResult.error(
            _getPermissionErrorMessage(permissionResult));
      }

      // Obtenir la position avec timeout
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15),
      );

      // Mettre à jour le cache
      _lastKnownPosition = position;
      _lastUpdateTime = DateTime.now();

      return LocationResult.success(position);
    } on TimeoutException {
      return LocationResult.error('Timeout lors de la localisation');
    } on PermissionDeniedException {
      return LocationResult.error('Permission de localisation refusée');
    } on LocationServiceDisabledException {
      return LocationResult.error('Service de localisation désactivé');
    } catch (e) {
      print('Erreur lors de la géolocalisation: $e');
      return LocationResult.error('Erreur de géolocalisation: ${e.toString()}');
    }
  }

  /// Obtenir la dernière position connue
  Future<LocationResult> getLastKnownPosition() async {
    try {
      // Retourner le cache si disponible et valide
      if (_isPositionCacheValid()) {
        return LocationResult.success(_lastKnownPosition!);
      }

      // Essayer d'obtenir la dernière position du système
      Position? lastPosition = await Geolocator.getLastKnownPosition();

      if (lastPosition != null) {
        _lastKnownPosition = lastPosition;
        _lastUpdateTime = DateTime.now();
        return LocationResult.success(lastPosition);
      }

      // Aucune position connue, essayer d'en obtenir une nouvelle
      return getCurrentPosition();
    } catch (e) {
      print('Erreur lors de la récupération de la dernière position: $e');
      return LocationResult.error('Aucune position disponible');
    }
  }

  /// Écouter les changements de position (stream)
  Stream<Position> getPositionStream({
    LocationAccuracy accuracy = LocationAccuracy.high,
    int distanceFilter = 10, // Mètres
  }) {
    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
    );

    return Geolocator.getPositionStream(locationSettings: locationSettings);
  }

  /// Calculer la distance entre deux positions
  double calculateDistance({
    required double startLatitude,
    required double startLongitude,
    required double endLatitude,
    required double endLongitude,
  }) {
    return Geolocator.distanceBetween(
      startLatitude,
      startLongitude,
      endLatitude,
      endLongitude,
    );
  }

  /// Formater une position en adresse lisible (coordonnées uniquement)
  String formatPosition(Position position) {
    return '${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}';
  }

  /// Obtenir les paramètres de localisation recommandés
  LocationSettings getRecommendedSettings() {
    return const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
    );
  }

  /// Vérifier si la position en cache est encore valide
  bool _isPositionCacheValid() {
    if (_lastKnownPosition == null || _lastUpdateTime == null) {
      return false;
    }

    final now = DateTime.now();
    return now.difference(_lastUpdateTime!) < _cacheTimeout;
  }

  /// Obtenir le message d'erreur pour les permissions
  String _getPermissionErrorMessage(LocationPermissionResult result) {
    switch (result) {
      case LocationPermissionResult.denied:
        return 'Permission de localisation refusée';
      case LocationPermissionResult.permanentlyDenied:
        return 'Permission de localisation refusée définitivement. Allez dans les paramètres pour l\'autoriser.';
      case LocationPermissionResult.serviceDisabled:
        return 'Service de localisation désactivé. Activez-le dans les paramètres.';
      case LocationPermissionResult.error:
        return 'Erreur lors de la vérification des permissions';
      case LocationPermissionResult.granted:
        return 'Permission accordée';
    }
  }

  /// Ouvrir les paramètres de localisation
  Future<bool> openLocationSettings() async {
    try {
      return await Geolocator.openLocationSettings();
    } catch (e) {
      print('Erreur lors de l\'ouverture des paramètres: $e');
      return false;
    }
  }

  /// Ouvrir les paramètres d'application
  Future<bool> openAppSettings() async {
    try {
      return await openAppSettings();
    } catch (e) {
      print('Erreur lors de l\'ouverture des paramètres d\'app: $e');
      return false;
    }
  }

  /// Nettoyer le cache de position
  void clearCache() {
    _lastKnownPosition = null;
    _lastUpdateTime = null;
  }

  /// Obtenir des informations sur la dernière position mise en cache
  Map<String, dynamic>? getCacheInfo() {
    if (_lastKnownPosition == null || _lastUpdateTime == null) {
      return null;
    }

    return {
      'position': formatPosition(_lastKnownPosition!),
      'timestamp': _lastUpdateTime!.toIso8601String(),
      'age_minutes': DateTime.now().difference(_lastUpdateTime!).inMinutes,
      'is_valid': _isPositionCacheValid(),
    };
  }
}

/// Énumération pour les résultats de permissions
enum LocationPermissionResult {
  granted,
  denied,
  permanentlyDenied,
  serviceDisabled,
  error,
}

/// Classe pour encapsuler les résultats de localisation
class LocationResult {
  final bool isSuccess;
  final Position? position;
  final String? error;

  LocationResult._({
    required this.isSuccess,
    this.position,
    this.error,
  });

  factory LocationResult.success(Position position) {
    return LocationResult._(
      isSuccess: true,
      position: position,
    );
  }

  factory LocationResult.error(String error) {
    return LocationResult._(
      isSuccess: false,
      error: error,
    );
  }

  @override
  String toString() {
    if (isSuccess) {
      return 'LocationResult.success(${position?.latitude}, ${position?.longitude})';
    } else {
      return 'LocationResult.error($error)';
    }
  }
}
