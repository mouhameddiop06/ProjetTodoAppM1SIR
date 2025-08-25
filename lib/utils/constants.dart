import 'package:flutter/material.dart';

class AppColors {
  static const Color primary = Color(0xFF2196F3);
  static const Color secondary = Color(0xFF03DAC6);
  static const Color background = Color(0xFFF5F5F5);
  static const Color surface = Colors.white;
  static const Color error = Color(0xFFB00020);
  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFFF9800);
  static const Color textPrimary = Color(0xFF212121);
  static const Color textSecondary = Color(0xFF757575);
}

class AppStyles {
  static const TextStyle titleLarge = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
  );

  static const TextStyle titleMedium = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  static const TextStyle bodyLarge = TextStyle(
    fontSize: 16,
    color: AppColors.textPrimary,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14,
    color: AppColors.textSecondary,
  );

  static const TextStyle caption = TextStyle(
    fontSize: 12,
    color: AppColors.textSecondary,
  );
}

class AppSizes {
  // Padding
  static const double paddingSmall = 8.0;
  static const double paddingMedium = 16.0;
  static const double paddingLarge = 24.0;
  static const double paddingExtraLarge = 32.0;

  // Margins
  static const double marginSmall = 8.0;
  static const double marginMedium = 16.0;
  static const double marginLarge = 24.0;

  // Border radius
  static const double borderRadius = 12.0;
  static const double borderRadiusSmall = 8.0;
  static const double borderRadiusLarge = 16.0;

  // Elevation
  static const double elevationLow = 2.0;
  static const double elevationMedium = 4.0;
  static const double elevationHigh = 8.0;

  // Icon sizes
  static const double iconSmall = 16.0;
  static const double iconMedium = 24.0;
  static const double iconLarge = 32.0;

  // Button heights
  static const double buttonHeight = 48.0;
  static const double buttonHeightSmall = 36.0;

  // App bar
  static const double appBarHeight = 56.0;
}

class AppStrings {
  // App
  static const String appName = 'Todo App';
  static const String appSubtitle = 'Master M1 2024-2025';

  // Navigation
  static const String home = 'Accueil';
  static const String profile = 'Profil';
  static const String settings = 'Paramètres';

  // Auth
  static const String login = 'Connexion';
  static const String register = 'Inscription';
  static const String logout = 'Déconnexion';
  static const String email = 'Email';
  static const String password = 'Mot de passe';
  static const String confirmPassword = 'Confirmer le mot de passe';
  static const String forgotPassword = 'Mot de passe oublié?';
  static const String createAccount = 'Créer un compte';
  static const String alreadyHaveAccount = 'Déjà un compte?';

  // Todos
  static const String todos = 'Tâches';
  static const String addTodo = 'Ajouter une tâche';
  static const String editTodo = 'Modifier la tâche';
  static const String deleteTodo = 'Supprimer la tâche';
  static const String markAsDone = 'Marquer comme terminé';
  static const String markAsUndone = 'Marquer comme non terminé';
  static const String todoTitle = 'Titre de la tâche';
  static const String todoDate = 'Date';
  static const String searchTodos = 'Rechercher des tâches';
  static const String noTodos = 'Aucune tâche pour le moment';
  static const String completedTodos = 'Tâches terminées';
  static const String pendingTodos = 'Tâches en cours';

  // Status
  static const String online = 'En ligne';
  static const String offline = 'Hors ligne';
  static const String syncing = 'Synchronisation...';
  static const String synced = 'Synchronisé';
  static const String syncFailed = 'Échec de synchronisation';

  // Actions
  static const String save = 'Enregistrer';
  static const String cancel = 'Annuler';
  static const String delete = 'Supprimer';
  static const String edit = 'Modifier';
  static const String create = 'Créer';
  static const String update = 'Mettre à jour';
  static const String refresh = 'Actualiser';
  static const String retry = 'Réessayer';
  static const String confirm = 'Confirmer';

  // Messages
  static const String loading = 'Chargement...';
  static const String noInternetConnection = 'Pas de connexion internet';
  static const String somethingWentWrong = 'Une erreur s\'est produite';
  static const String tryAgain = 'Veuillez réessayer';
  static const String success = 'Succès';
  static const String error = 'Erreur';

  // Validation
  static const String fieldRequired = 'Ce champ est requis';
  static const String emailInvalid = 'Email invalide';
  static const String passwordTooShort =
      'Mot de passe trop court (min 6 caractères)';
  static const String passwordsDoNotMatch =
      'Les mots de passe ne correspondent pas';

  // Weather
  static const String weather = 'Météo';
  static const String temperature = 'Température';
  static const String location = 'Position';
  static const String weatherUnavailable = 'Météo indisponible';

  // Permissions
  static const String locationPermissionRequired =
      'Permission de localisation requise';
  static const String locationPermissionDenied =
      'Permission de localisation refusée';
  static const String openSettings = 'Ouvrir les paramètres';
}

class AppDurations {
  static const Duration splashDelay = Duration(seconds: 3);
  static const Duration animationShort = Duration(milliseconds: 200);
  static const Duration animationMedium = Duration(milliseconds: 300);
  static const Duration animationLong = Duration(milliseconds: 500);
  static const Duration snackBarDuration = Duration(seconds: 3);
  static const Duration autoSyncInterval = Duration(minutes: 5);
}
