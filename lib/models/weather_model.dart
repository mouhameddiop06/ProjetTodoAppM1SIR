class Weather {
  final double temperature;
  final String description;
  final String location;
  final DateTime lastUpdated;
  final String? icon;

  Weather({
    required this.temperature,
    required this.description,
    required this.location,
    required this.lastUpdated,
    this.icon,
  });

  // Création depuis JSON (API météo)
  factory Weather.fromJson(Map<String, dynamic> json) {
    // Format pour OpenWeatherMap API
    return Weather(
      temperature: (json['main']['temp'] as num).toDouble(),
      description: json['weather'][0]['description'] ?? '',
      location: json['name'] ?? '',
      lastUpdated: DateTime.now(),
      icon: json['weather'][0]['icon'],
    );
  }

  // Conversion vers JSON
  Map<String, dynamic> toJson() {
    return {
      'temperature': temperature,
      'description': description,
      'location': location,
      'last_updated': lastUpdated.toIso8601String(),
      'icon': icon,
    };
  }

  // Conversion vers Map pour SQLite local
  Map<String, dynamic> toMap() {
    return {
      'temperature': temperature,
      'description': description,
      'location': location,
      'last_updated': lastUpdated.millisecondsSinceEpoch,
      'icon': icon,
    };
  }

  // Création depuis Map (SQLite local)
  factory Weather.fromMap(Map<String, dynamic> map) {
    return Weather(
      temperature: map['temperature']?.toDouble() ?? 0.0,
      description: map['description'] ?? '',
      location: map['location'] ?? '',
      lastUpdated: DateTime.fromMillisecondsSinceEpoch(map['last_updated']),
      icon: map['icon'],
    );
  }

  // Getters utiles
  String get temperatureDisplay {
    return '${temperature.round()}°C';
  }

  String get capitalizedDescription {
    if (description.isEmpty) return '';
    return description[0].toUpperCase() + description.substring(1);
  }

  bool get isDataFresh {
    final now = DateTime.now();
    final difference = now.difference(lastUpdated);
    return difference.inMinutes < 30; // Données fraîches si < 30 minutes
  }

  // Méthode copyWith
  Weather copyWith({
    double? temperature,
    String? description,
    String? location,
    DateTime? lastUpdated,
    String? icon,
  }) {
    return Weather(
      temperature: temperature ?? this.temperature,
      description: description ?? this.description,
      location: location ?? this.location,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      icon: icon ?? this.icon,
    );
  }

  @override
  String toString() {
    return 'Weather{temperature: $temperatureDisplay, description: $description, location: $location}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Weather &&
        other.temperature == temperature &&
        other.description == description &&
        other.location == location;
  }

  @override
  int get hashCode {
    return temperature.hashCode ^ description.hashCode ^ location.hashCode;
  }
}
