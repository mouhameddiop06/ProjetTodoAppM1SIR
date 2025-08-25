import 'package:flutter/foundation.dart';
import 'dart:io';
import '../models/user_model.dart';
import '../services/api_service.dart';
import '../services/local_storage_service.dart';
import '../utils/database_helper.dart';

class AuthProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService();
  final LocalStorageService _localStorage = LocalStorageService();
  final DatabaseHelper _databaseHelper = DatabaseHelper();

  // État de l'authentification
  User? _currentUser;
  bool _isLoggedIn = false;
  bool _isLoading = false;
  String? _errorMessage;

  // Getters
  User? get currentUser => _currentUser;
  bool get isLoggedIn => _isLoggedIn;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  int? get currentUserId => _currentUser?.id;

  // Constructeur
  AuthProvider() {
    _initializeAuth();
  }

  /// Initialiser l'authentification au démarrage
  Future<void> _initializeAuth() async {
    _setLoading(true);

    try {
      await _localStorage.init();

      // Vérifier si un utilisateur est déjà connecté
      if (_localStorage.isLoggedIn()) {
        await _restoreUserSession();
      }
    } catch (e) {
      print('Erreur initialisation auth: $e');
      _setError('Erreur d\'initialisation');
    } finally {
      _setLoading(false);
    }
  }

  /// Restaurer la session utilisateur depuis le stockage local
  Future<void> _restoreUserSession() async {
    try {
      final userId = _localStorage.getUserId();
      final email = _localStorage.getUserEmail();
      final profileImagePath = _localStorage.getProfileImagePath();

      print('Restauration session - userId: $userId, email: $email, profileImagePath: $profileImagePath');

      if (userId != null && email != null) {
        _currentUser = User(
          id: userId,
          email: email,
          profileImagePath: profileImagePath,
        );
        _isLoggedIn = true;
        _clearError();
        
        print('Session restaurée avec succès: ${_currentUser?.toString()}');
        notifyListeners();
      } else {
        print('Session corrompue - nettoyage');
        // Session corrompue, la nettoyer
        await logout();
      }
    } catch (e) {
      print('Erreur restauration session: $e');
      await logout();
    }
  }

  /// Inscription d'un nouvel utilisateur
  Future<bool> register({
    required String email,
    required String password,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      // Validation des entrées
      if (!_validateEmail(email)) {
        _setError('Email invalide');
        return false;
      }

      if (!_validatePassword(password)) {
        _setError('Mot de passe trop court (minimum 6 caractères)');
        return false;
      }

      // Appel API d'inscription
      final response = await _apiService.register(email, password);

      if (response.isSuccess) {
        // L'inscription a réussi, maintenant se connecter
        return await login(email: email, password: password);
      } else {
        _setError(response.error ?? 'Erreur d\'inscription');
        return false;
      }
    } catch (e) {
      print('Erreur registration: $e');
      _setError('Erreur de connexion réseau');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Connexion utilisateur
  Future<bool> login({
    required String email,
    required String password,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      // Validation des entrées
      if (!_validateEmail(email)) {
        _setError('Email invalide');
        return false;
      }

      if (password.isEmpty) {
        _setError('Mot de passe requis');
        return false;
      }

      // Appel API de connexion
      final response = await _apiService.login(email, password);

      if (response.isSuccess && response.data != null) {
        final user = response.data!;
        print('Login réussi - User de l\'API: ${user.toString()}');

        // Sauvegarder l'utilisateur localement
        await _saveUserSession(user);

        // Mettre à jour l'état
        _currentUser = user;
        _isLoggedIn = true;
        _clearError();

        print('État mis à jour - Current user: ${_currentUser?.toString()}');
        notifyListeners();
        return true;
      } else {
        _setError(response.error ?? 'Email ou mot de passe incorrect');
        return false;
      }
    } catch (e) {
      print('Erreur login: $e');
      _setError('Erreur de connexion réseau');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Déconnexion utilisateur
  Future<void> logout() async {
    _setLoading(true);

    try {
      // Nettoyer les données locales
      await _localStorage.clearUserSession();
      await _databaseHelper.clearAllData();

      // Réinitialiser l'état
      _currentUser = null;
      _isLoggedIn = false;
      _clearError();

      print('Déconnexion réussie');
      notifyListeners();
    } catch (e) {
      print('Erreur logout: $e');
      _setError('Erreur lors de la déconnexion');
    } finally {
      _setLoading(false);
    }
  }

  /// Mettre à jour la photo de profil
  Future<bool> updateProfileImage(String imagePath) async {
    if (!_isLoggedIn || _currentUser == null) {
      _setError('Utilisateur non connecté');
      return false;
    }

    _setLoading(true);
    _clearError();

    try {
      print('Mise à jour photo de profil - Chemin reçu: $imagePath');

      // Vérifier que le fichier existe
      final file = File(imagePath);
      if (!await file.exists()) {
        print('Le fichier image n\'existe pas: $imagePath');
        _setError('Le fichier image n\'existe pas');
        return false;
      }

      print('Fichier image existe, taille: ${await file.length()} bytes');

      // Sauvegarder le chemin dans SharedPreferences
      final success = await _localStorage.saveProfileImagePath(imagePath);

      if (success) {
        // Mettre à jour l'utilisateur actuel
        _currentUser = _currentUser!.copyWith(profileImagePath: imagePath);
        print('Photo de profil mise à jour dans l\'état - Nouveau chemin: ${_currentUser?.profileImagePath}');

        // Sauvegarder en base de données locale
        if (_currentUser!.id != null) {
          await _databaseHelper.updateUser(_currentUser!);
          print('Photo de profil sauvegardée en base de données locale');
        }

        _clearError();
        notifyListeners();
        return true;
      } else {
        _setError('Erreur de sauvegarde de l\'image');
        return false;
      }
    } catch (e) {
      print('Erreur update profile image: $e');
      _setError('Erreur lors de la mise à jour: ${e.toString()}');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Vérifier l'état de connexion
  Future<bool> checkAuthStatus() async {
    try {
      if (!_localStorage.isLoggedIn()) {
        await logout();
        return false;
      }

      // Optionnel: Vérifier avec le serveur si connecté
      // final isConnected = await _apiService.checkConnectivity();

      return _isLoggedIn;
    } catch (e) {
      print('Erreur check auth status: $e');
      return false;
    }
  }

  /// Sauvegarder la session utilisateur
  Future<void> _saveUserSession(User user) async {
    try {
      print('Sauvegarde session utilisateur: ${user.toString()}');

      // Sauvegarder dans SharedPreferences
      await _localStorage.saveUserSession(
        userId: user.id!,
        email: user.email,
        profileImagePath: user.profileImagePath,
      );

      print('Session sauvegardée dans SharedPreferences');

      // Sauvegarder dans la base de données locale
      final existingUser = await _databaseHelper.getUserByEmail(user.email);

      if (existingUser == null) {
        await _databaseHelper.insertUser(user);
        print('Nouvel utilisateur créé en base locale');
      } else {
        await _databaseHelper.updateUser(user.copyWith(id: existingUser.id));
        print('Utilisateur existant mis à jour en base locale');
      }
    } catch (e) {
      print('Erreur sauvegarde session: $e');
      throw Exception('Erreur de sauvegarde de session: ${e.toString()}');
    }
  }

  /// Validation email
  bool _validateEmail(String email) {
    return RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(email);
  }

  /// Validation mot de passe
  bool _validatePassword(String password) {
    return password.length >= 6;
  }

  /// Gestion de l'état de chargement
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  /// Gestion des erreurs
  void _setError(String error) {
    _errorMessage = error;
    notifyListeners();
  }

  /// Effacer les erreurs
  void _clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// Effacer les erreurs manuellement (pour l'UI)
  void clearError() {
    _clearError();
  }

  /// Obtenir les informations de session pour debug
  Map<String, dynamic> getSessionInfo() {
    return {
      'is_logged_in': _isLoggedIn,
      'user_id': _currentUser?.id,
      'user_email': _currentUser?.email,
      'has_profile_image': _currentUser?.profileImagePath != null,
      'profile_image_path': _currentUser?.profileImagePath,
      'is_loading': _isLoading,
      'has_error': _errorMessage != null,
    };
  }

  @override
  void dispose() {
    // Nettoyer les ressources si nécessaire
    super.dispose();
  }
}