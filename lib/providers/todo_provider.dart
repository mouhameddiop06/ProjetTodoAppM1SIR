import 'package:flutter/foundation.dart';
import '../models/todo_model.dart';
import '../services/api_service.dart';
import '../services/sync_service.dart';
import '../utils/database_helper.dart';

class TodoProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService();
  final SyncService _syncService = SyncService();
  final DatabaseHelper _databaseHelper = DatabaseHelper();

  // État des tâches
  List<Todo> _todos = [];
  bool _isLoading = false;
  String? _errorMessage;
  bool _isSyncing = false;
  SyncStatus? _syncStatus;

  // Getters
  List<Todo> get todos => _todos;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isSyncing => _isSyncing;
  SyncStatus? get syncStatus => _syncStatus;

  // Getters filtrés
  List<Todo> get completedTodos => _todos.where((todo) => todo.isDone).toList();
  List<Todo> get pendingTodos => _todos.where((todo) => !todo.isDone).toList();
  List<Todo> get todayTodos => _todos.where((todo) => todo.isToday).toList();
  List<Todo> get unsyncedTodos =>
      _todos.where((todo) => !todo.isSynced).toList();

  // Statistiques
  int get totalTodos => _todos.length;
  int get completedCount => completedTodos.length;
  int get pendingCount => pendingTodos.length;
  int get unsyncedCount => unsyncedTodos.length;

  /// Charger toutes les tâches pour un utilisateur
  Future<void> loadTodos(int accountId) async {
    _setLoading(true);
    _clearError();

    try {
      // Charger d'abord depuis la base locale
      await _loadLocalTodos(accountId);

      // Mettre à jour le statut de sync
      await _updateSyncStatus(accountId);

      // Essayer de synchroniser en arrière-plan
      _backgroundSync(accountId);
    } catch (e) {
      print('Erreur chargement todos: $e');
      _setError('Erreur lors du chargement des tâches');
    } finally {
      _setLoading(false);
    }
  }

  /// Charger les tâches depuis la base locale
  Future<void> _loadLocalTodos(int accountId) async {
    try {
      final localTodos = await _databaseHelper.getTodosByAccountId(accountId);
      _todos = localTodos;
      notifyListeners();
    } catch (e) {
      print('Erreur chargement local: $e');
      throw Exception('Erreur de chargement local');
    }
  }

  /// Créer une nouvelle tâche
  Future<bool> createTodo({
    required int accountId,
    required String title,
    required DateTime date,
  }) async {
    if (title.trim().isEmpty) {
      _setError('Le titre de la tâche ne peut pas être vide');
      return false;
    }

    _clearError();

    try {
      // Créer la tâche localement d'abord
      final newTodo = Todo(
        accountId: accountId,
        title: title.trim(),
        date: date,
        isDone: false,
        createdAt: DateTime.now(),
        isSynced: false, // Pas encore synchronisée
      );

      // Sauvegarder en local
      final localId = await _databaseHelper.insertTodo(newTodo);
      final todoWithId = newTodo.copyWith(id: localId);

      // Ajouter à la liste
      _todos.add(todoWithId);
      notifyListeners();

      // Essayer de synchroniser immédiatement si connecté
      _syncSingleTodo(todoWithId, accountId);

      return true;
    } catch (e) {
      print('Erreur création todo: $e');
      _setError('Erreur lors de la création de la tâche');
      return false;
    }
  }

  /// Mettre à jour une tâche
  Future<bool> updateTodo({
    required Todo todo,
    String? newTitle,
    DateTime? newDate,
    bool? newIsDone,
  }) async {
    _clearError();

    try {
      // Créer la tâche mise à jour
      final updatedTodo = todo.copyWith(
        title: newTitle,
        date: newDate,
        isDone: newIsDone,
        updatedAt: DateTime.now(),
        isSynced: false, // Marquer comme non synchronisée
      );

      // Mettre à jour en local
      await _databaseHelper.updateTodo(updatedTodo);

      // Mettre à jour dans la liste
      final index = _todos.indexWhere((t) => t.id == todo.id);
      if (index != -1) {
        _todos[index] = updatedTodo;
        notifyListeners();
      }

      // Essayer de synchroniser
      _syncSingleTodo(updatedTodo, todo.accountId);

      return true;
    } catch (e) {
      print('Erreur mise à jour todo: $e');
      _setError('Erreur lors de la mise à jour');
      return false;
    }
  }

  /// Marquer une tâche comme terminée/non terminée
  Future<bool> toggleTodoCompletion(Todo todo) async {
    return updateTodo(todo: todo, newIsDone: !todo.isDone);
  }

  /// Supprimer une tâche
  Future<bool> deleteTodo(Todo todo) async {
    _clearError();

    try {
      // Supprimer de l'API d'abord si synchronisée
      if (todo.isSynced && todo.id != null) {
        final response = await _apiService.deleteTodo(todo.id!);
        if (!response.isSuccess) {
          _setError('Erreur de suppression sur le serveur');
          return false;
        }
      }

      // Supprimer localement
      if (todo.id != null) {
        await _databaseHelper.deleteTodo(todo.id!);
      }

      // Retirer de la liste
      _todos.removeWhere((t) => t.id == todo.id);
      notifyListeners();

      return true;
    } catch (e) {
      print('Erreur suppression todo: $e');
      _setError('Erreur lors de la suppression');
      return false;
    }
  }

  /// Synchroniser toutes les tâches
  Future<void> syncAllTodos(int accountId) async {
    if (_isSyncing) return;

    _setSyncing(true);
    _clearError();

    try {
      final result = await _syncService.syncAll(accountId: accountId);

      if (result.isSuccess) {
        // Recharger les tâches après synchronisation
        await _loadLocalTodos(accountId);

        // Afficher un message de succès si des opérations ont été effectuées
        if (result.stats!.totalOperations > 0) {
          _setSuccessMessage(
              'Synchronisation réussie: ${result.stats!.summary}');
        }
      } else {
        _setError(result.error ?? 'Erreur de synchronisation');
      }
    } catch (e) {
      print('Erreur sync: $e');
      _setError('Erreur de synchronisation');
    } finally {
      _setSyncing(false);
      await _updateSyncStatus(accountId);
    }
  }

  /// Synchroniser une tâche spécifique en arrière-plan
  void _syncSingleTodo(Todo todo, int accountId) async {
    try {
      await _syncService.syncSingleTodo(todo: todo, accountId: accountId);
      await _loadLocalTodos(accountId);
      await _updateSyncStatus(accountId);
    } catch (e) {
      print('Erreur sync single todo: $e');
    }
  }

  /// Synchronisation en arrière-plan
  void _backgroundSync(int accountId) async {
    try {
      await _syncService.backgroundSync(accountId);
      await _loadLocalTodos(accountId);
      await _updateSyncStatus(accountId);
    } catch (e) {
      print('Erreur background sync: $e');
    }
  }

  /// Mettre à jour le statut de synchronisation
  Future<void> _updateSyncStatus(int accountId) async {
    try {
      _syncStatus = await _syncService.getSyncStatus(accountId);
      notifyListeners();
    } catch (e) {
      print('Erreur update sync status: $e');
    }
  }

  /// Rechercher des tâches
  List<Todo> searchTodos(String query) {
    if (query.trim().isEmpty) return _todos;

    final lowercaseQuery = query.toLowerCase();
    return _todos.where((todo) {
      return todo.title.toLowerCase().contains(lowercaseQuery);
    }).toList();
  }

  /// Filtrer les tâches par date
  List<Todo> getTodosByDate(DateTime date) {
    return _todos.where((todo) {
      return todo.date.year == date.year &&
          todo.date.month == date.month &&
          todo.date.day == date.day;
    }).toList();
  }

  /// Obtenir les tâches par statut
  List<Todo> getTodosByStatus({required bool completed}) {
    return _todos.where((todo) => todo.isDone == completed).toList();
  }

  /// Obtenir les statistiques des tâches
  Map<String, int> getTodoStats() {
    return {
      'total': totalTodos,
      'completed': completedCount,
      'pending': pendingCount,
      'today': todayTodos.length,
      'unsynced': unsyncedCount,
    };
  }

  /// Nettoyer toutes les tâches
  Future<void> clearAllTodos() async {
    try {
      _todos.clear();
      notifyListeners();
    } catch (e) {
      print('Erreur clear todos: $e');
    }
  }

  /// Gestion de l'état de chargement
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  /// Gestion de l'état de synchronisation
  void _setSyncing(bool syncing) {
    _isSyncing = syncing;
    notifyListeners();
  }

  /// Gestion des erreurs
  void _setError(String error) {
    _errorMessage = error;
    notifyListeners();
  }

  /// Message de succès (temporaire)
  void _setSuccessMessage(String message) {
    _errorMessage = null;
    // Dans une vraie app, vous pourriez avoir un système de notifications
    print('Succès: $message');
    notifyListeners();
  }

  /// Effacer les erreurs
  void _clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// Effacer les erreurs manuellement
  void clearError() {
    _clearError();
  }

  /// Rafraîchir les données
  Future<void> refresh(int accountId) async {
    await loadTodos(accountId);
  }

  /// Forcer la synchronisation
  Future<void> forceSync(int accountId) async {
    if (_isSyncing) return;

    _setSyncing(true);
    try {
      final result = await _syncService.forceSyncAll(accountId);
      if (result.isSuccess) {
        await _loadLocalTodos(accountId);
      } else {
        _setError(result.error ?? 'Erreur de synchronisation forcée');
      }
    } finally {
      _setSyncing(false);
      await _updateSyncStatus(accountId);
    }
  }

  @override
  void dispose() {
    super.dispose();
  }
}
