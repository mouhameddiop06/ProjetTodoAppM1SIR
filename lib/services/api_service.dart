import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../models/user_model.dart';
import '../models/todo_model.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  // Headers par défaut pour les requêtes
  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  // === AUTHENTIFICATION ===

  /// Inscription d'un nouvel utilisateur
  Future<ApiResponse<User>> register(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse(AppConfig.registerUrl),
        headers: _headers,
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      ).timeout(AppConfig.syncTimeout);

      print('Register Response Status: ${response.statusCode}');
      print('Register Response Body: ${response.body}');

      final responseData = jsonDecode(response.body);

      if (response.statusCode == 200) {
        if (responseData['data'] == 'Inscription Reussie') {
          // Créer un objet User basique (l'API ne retourne pas l'ID pour l'inscription)
          final user = User(email: email);
          return ApiResponse.success(user);
        } else {
          return ApiResponse.error(responseData['error'] ?? 'Erreur d\'inscription');
        }
      } else {
        return ApiResponse.error(responseData['error'] ?? AppConfig.serverErrorMessage);
      }
    } on SocketException {
      return ApiResponse.error(AppConfig.networkErrorMessage);
    } on HttpException {
      return ApiResponse.error(AppConfig.serverErrorMessage);
    } catch (e) {
      print('Register Exception: $e');
      return ApiResponse.error('Erreur inattendue: ${e.toString()}');
    }
  }

  /// Connexion utilisateur
  Future<ApiResponse<User>> login(String email, String password) async {
    try {
      print('Login Request URL: ${AppConfig.loginUrl}');
      print('Login Request Body: ${jsonEncode({'email': email, 'password': password})}');

      final response = await http.post(
        Uri.parse(AppConfig.loginUrl),
        headers: _headers,
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      ).timeout(AppConfig.syncTimeout);

      print('Login Response Status: ${response.statusCode}');
      print('Login Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        print('Login Response Data: $responseData');

        // Vérifier si la réponse contient des données valides
        if (responseData is Map<String, dynamic>) {
          // Case 1: Réponse avec 'data' contenant account_id et email
          if (responseData.containsKey('data') && responseData['data'] is Map) {
            final userData = responseData['data'] as Map<String, dynamic>;
            print('User Data from API: $userData');

            final accountId = _parseAccountId(userData['account_id']);
            final userEmail = userData['email']?.toString() ?? email;

            if (accountId != null) {
              final user = User(
                id: accountId,
                email: userEmail,
              );
              print('User created successfully: $user');
              return ApiResponse.success(user);
            } else {
              print('Account ID is null or invalid');
              return ApiResponse.error('ID utilisateur invalide');
            }
          }
          
          // Case 2: Réponse directe avec account_id et email
          else if (responseData.containsKey('account_id')) {
            print('Direct account_id response: ${responseData['account_id']}');

            final accountId = _parseAccountId(responseData['account_id']);
            final userEmail = responseData['email']?.toString() ?? email;

            if (accountId != null) {
              final user = User(
                id: accountId,
                email: userEmail,
              );
              print('User created successfully from direct response: $user');
              return ApiResponse.success(user);
            } else {
              print('Account ID is null or invalid in direct response');
              return ApiResponse.error('ID utilisateur invalide');
            }
          }

          // Case 3: Vérifier s'il y a une erreur
          else if (responseData.containsKey('error')) {
            final errorMessage = responseData['error']?.toString() ?? AppConfig.authErrorMessage;
            print('API Error: $errorMessage');
            return ApiResponse.error(errorMessage);
          }

          // Case 4: Réponse inattendue mais pas d'erreur explicite
          else {
            print('Unexpected response structure: $responseData');
            return ApiResponse.error('Format de réponse inattendu');
          }
        } else {
          print('Response is not a Map: $responseData');
          return ApiResponse.error('Format de réponse invalide');
        }
      } else {
        print('HTTP Error: ${response.statusCode}');
        try {
          final errorData = jsonDecode(response.body);
          return ApiResponse.error(errorData['error'] ?? AppConfig.authErrorMessage);
        } catch (e) {
          return ApiResponse.error('Erreur HTTP: ${response.statusCode}');
        }
      }
    } on SocketException catch (e) {
      print('SocketException: $e');
      return ApiResponse.error(AppConfig.networkErrorMessage);
    } on HttpException catch (e) {
      print('HttpException: $e');
      return ApiResponse.error(AppConfig.serverErrorMessage);
    } catch (e) {
      print('Login Exception: $e');
      return ApiResponse.error('Erreur de connexion: ${e.toString()}');
    }
  }

  /// Helper method pour parser l'account_id de différents formats
  int? _parseAccountId(dynamic accountId) {
    if (accountId == null) return null;
    
    if (accountId is int) {
      return accountId;
    }
    
    if (accountId is String) {
      try {
        return int.parse(accountId);
      } catch (e) {
        print('Error parsing account_id string: $accountId');
        return null;
      }
    }
    
    print('Unexpected account_id type: ${accountId.runtimeType}');
    return null;
  }

  // === GESTION DES TÂCHES ===

  /// Récupérer toutes les tâches d'un utilisateur
  Future<ApiResponse<List<Todo>>> getTodos(int accountId) async {
    try {
      print('GetTodos Request URL: ${AppConfig.todosUrl}');
      print('GetTodos Request Body: ${jsonEncode({'account_id': accountId.toString()})}');

      final response = await http.post(
        Uri.parse(AppConfig.todosUrl),
        headers: _headers,
        body: jsonEncode({
          'account_id': accountId.toString(),
        }),
      ).timeout(AppConfig.syncTimeout);

      print('GetTodos Response Status: ${response.statusCode}');
      print('GetTodos Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        
        if (responseData is List) {
          final todos = responseData
              .map((todoJson) => Todo.fromJson(todoJson))
              .toList();
          return ApiResponse.success(todos);
        } else if (responseData is Map && responseData.containsKey('data')) {
          final List<dynamic> todosData = responseData['data'] ?? [];
          final todos = todosData
              .map((todoJson) => Todo.fromJson(todoJson))
              .toList();
          return ApiResponse.success(todos);
        } else if (responseData is Map && responseData.containsKey('error')) {
          return ApiResponse.error(responseData['error'] ?? 'Aucune tâche trouvée');
        } else {
          return ApiResponse.success([]); // Aucune tâche
        }
      } else {
        try {
          final responseData = jsonDecode(response.body);
          return ApiResponse.error(responseData['error'] ?? AppConfig.serverErrorMessage);
        } catch (e) {
          return ApiResponse.error('Erreur serveur: ${response.statusCode}');
        }
      }
    } on SocketException {
      return ApiResponse.error(AppConfig.networkErrorMessage);
    } catch (e) {
      print('GetTodos Exception: $e');
      return ApiResponse.error('Erreur lors de la récupération: ${e.toString()}');
    }
  }

  /// Créer une nouvelle tâche
  Future<ApiResponse<Todo>> createTodo(Todo todo) async {
    try {
      print('CreateTodo Request URL: ${AppConfig.insertTodoUrl}');
      print('CreateTodo Request Body: ${jsonEncode(todo.toJson())}');

      final response = await http.post(
        Uri.parse(AppConfig.insertTodoUrl),
        headers: _headers,
        body: jsonEncode(todo.toJson()),
      ).timeout(AppConfig.syncTimeout);

      print('CreateTodo Response Status: ${response.statusCode}');
      print('CreateTodo Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        
        if (responseData['data'] != null && 
            responseData['data'].toString().contains('Successfully inserted')) {
          // L'API ne retourne pas l'ID de la tâche créée, donc on marque comme synchronisée
          final createdTodo = todo.copyWith(isSynced: true);
          return ApiResponse.success(createdTodo);
        } else {
          return ApiResponse.error(responseData['error'] ?? 'Erreur lors de la création');
        }
      } else {
        try {
          final responseData = jsonDecode(response.body);
          return ApiResponse.error(responseData['error'] ?? AppConfig.serverErrorMessage);
        } catch (e) {
          return ApiResponse.error('Erreur serveur: ${response.statusCode}');
        }
      }
    } on SocketException {
      return ApiResponse.error(AppConfig.networkErrorMessage);
    } catch (e) {
      print('CreateTodo Exception: $e');
      return ApiResponse.error('Erreur lors de la création: ${e.toString()}');
    }
  }

  /// Mettre à jour une tâche
  Future<ApiResponse<Todo>> updateTodo(Todo todo) async {
    try {
      print('UpdateTodo Request URL: ${AppConfig.updateTodoUrl}');
      print('UpdateTodo Request Body: ${jsonEncode(todo.toJson())}');

      final response = await http.post(
        Uri.parse(AppConfig.updateTodoUrl),
        headers: _headers,
        body: jsonEncode(todo.toJson()),
      ).timeout(AppConfig.syncTimeout);

      print('UpdateTodo Response Status: ${response.statusCode}');
      print('UpdateTodo Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        
        if (responseData['data'] != null && 
            responseData['data'].toString().contains('Mise a jour reussie')) {
          final updatedTodo = todo.copyWith(isSynced: true);
          return ApiResponse.success(updatedTodo);
        } else {
          return ApiResponse.error(responseData['error'] ?? 'Erreur lors de la mise à jour');
        }
      } else {
        try {
          final responseData = jsonDecode(response.body);
          return ApiResponse.error(responseData['error'] ?? AppConfig.serverErrorMessage);
        } catch (e) {
          return ApiResponse.error('Erreur serveur: ${response.statusCode}');
        }
      }
    } on SocketException {
      return ApiResponse.error(AppConfig.networkErrorMessage);
    } catch (e) {
      print('UpdateTodo Exception: $e');
      return ApiResponse.error('Erreur lors de la mise à jour: ${e.toString()}');
    }
  }

  /// Supprimer une tâche
  Future<ApiResponse<bool>> deleteTodo(int todoId) async {
    try {
      print('DeleteTodo Request URL: ${AppConfig.deleteTodoUrl}');
      print('DeleteTodo Request Body: ${jsonEncode({'todo_id': todoId.toString()})}');

      final response = await http.post(
        Uri.parse(AppConfig.deleteTodoUrl),
        headers: _headers,
        body: jsonEncode({
          'todo_id': todoId.toString(),
        }),
      ).timeout(AppConfig.syncTimeout);

      print('DeleteTodo Response Status: ${response.statusCode}');
      print('DeleteTodo Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        
        if (responseData['data'] != null && 
            responseData['data'].toString().contains('Suppression reussies')) {
          return ApiResponse.success(true);
        } else {
          return ApiResponse.error(responseData['error'] ?? 'Erreur lors de la suppression');
        }
      } else {
        try {
          final responseData = jsonDecode(response.body);
          return ApiResponse.error(responseData['error'] ?? AppConfig.serverErrorMessage);
        } catch (e) {
          return ApiResponse.error('Erreur serveur: ${response.statusCode}');
        }
      }
    } on SocketException {
      return ApiResponse.error(AppConfig.networkErrorMessage);
    } catch (e) {
      print('DeleteTodo Exception: $e');
      return ApiResponse.error('Erreur lors de la suppression: ${e.toString()}');
    }
  }

  // === MÉTHODES UTILITAIRES ===

  /// Vérifier la connectivité avec l'API
  Future<bool> checkConnectivity() async {
    try {
      final response = await http.get(
        Uri.parse(AppConfig.baseUrl),
      ).timeout(const Duration(seconds: 5));
      
      return response.statusCode == 200;
    } catch (e) {
      print('Connectivity check failed: $e');
      return false;
    }
  }
}

/// Classe pour encapsuler les réponses de l'API
class ApiResponse<T> {
  final bool isSuccess;
  final T? data;
  final String? error;

  ApiResponse._({
    required this.isSuccess,
    this.data,
    this.error,
  });

  factory ApiResponse.success(T data) {
    return ApiResponse._(
      isSuccess: true,
      data: data,
    );
  }

  factory ApiResponse.error(String error) {
    return ApiResponse._(
      isSuccess: false,
      error: error,
    );
  }

  @override
  String toString() {
    if (isSuccess) {
      return 'ApiResponse.success($data)';
    } else {
      return 'ApiResponse.error($error)';
    }
  }
}