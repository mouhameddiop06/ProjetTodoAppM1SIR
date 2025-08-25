import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/todo_model.dart';
import '../utils/database_helper.dart';
import 'api_service.dart';
import 'local_storage_service.dart';

class SyncService {
  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;
  SyncService._internal();

  final ApiService _apiService = ApiService();
  final DatabaseHelper _databaseHelper = DatabaseHelper();
  final LocalStorageService _localStorage = LocalStorageService();

  bool _isSyncing = false;
  DateTime? _lastSyncTime;

  /// Synchroniser toutes les données
  Future<SyncResult> syncAll({
    required int accountId,
    bool forceSync = false,
  }) async {
    if (_isSyncing) {
      return SyncResult.error('Synchronisation déjà en cours');
    }

    _isSyncing = true;

    try {
      // Vérifier la connectivité
      if (!await _hasInternetConnection()) {
        return SyncResult.error('Pas de connexion internet');
      }

      // Vérifier si une sync est nécessaire
      if (!forceSync && !_localStorage.needsSync()) {
        return SyncResult.success(SyncStats(
          uploadedTodos: 0,
          downloadedTodos: 0,
          updatedTodos: 0,
          deletedTodos: 0,
          errors: [],
        ));
      }

      final stats = SyncStats();

      // 1. Upload des tâches locales non synchronisées
      final uploadResult = await _uploadUnsyncedTodos(accountId);
      stats.merge(uploadResult);

      // 2. Download des tâches depuis le serveur
      final downloadResult = await _downloadServerTodos(accountId);
      stats.merge(downloadResult);

      // 3. Marquer la synchronisation comme terminée
      await _localStorage.saveLastSyncTimestamp();
      _lastSyncTime = DateTime.now();

      return SyncResult.success(stats);
    } catch (e) {
      print('Erreur lors de la synchronisation: $e');
      return SyncResult.error('Erreur de synchronisation: ${e.toString()}');
    } finally {
      _isSyncing = false;
    }
  }

  /// Upload des tâches non synchronisées vers le serveur
  Future<SyncStats> _uploadUnsyncedTodos(int accountId) async {
    final stats = SyncStats();

    try {
      // Récupérer toutes les tâches non synchronisées
      final unsyncedTodos = await _databaseHelper.getUnsyncedTodos();

      for (final todo in unsyncedTodos) {
        try {
          if (todo.id == null) {
            // Nouvelle tâche à créer
            final response = await _apiService.createTodo(todo);

            if (response.isSuccess) {
              // Marquer comme synchronisée avec l'ID du serveur
              await _databaseHelper.markTodoAsSynced(
                todo.id!,
                response.data!.id!,
              );
              stats.uploadedTodos++;
            } else {
              stats.errors.add('Création échouée: ${response.error}');
            }
          } else {
            // Tâche existante à mettre à jour
            final response = await _apiService.updateTodo(todo);

            if (response.isSuccess) {
              await _databaseHelper.updateTodo(
                todo.copyWith(isSynced: true),
              );
              stats.updatedTodos++;
            } else {
              stats.errors.add('Mise à jour échouée: ${response.error}');
            }
          }
        } catch (e) {
          stats.errors.add('Erreur todo ${todo.title}: ${e.toString()}');
        }
      }
    } catch (e) {
      stats.errors.add('Erreur upload: ${e.toString()}');
    }

    return stats;
  }

  /// Download des tâches depuis le serveur
  Future<SyncStats> _downloadServerTodos(int accountId) async {
    final stats = SyncStats();

    try {
      // Récupérer toutes les tâches du serveur
      final response = await _apiService.getTodos(accountId);

      if (!response.isSuccess) {
        stats.errors.add('Échec download: ${response.error}');
        return stats;
      }

      final serverTodos = response.data!;
      final localTodos = await _databaseHelper.getTodosByAccountId(accountId);

      // Créer des maps pour comparaison efficace
      final localTodosMap = <int, Todo>{};
      for (final todo in localTodos) {
        if (todo.id != null) {
          localTodosMap[todo.id!] = todo;
        }
      }

      // Traiter chaque tâche du serveur
      for (final serverTodo in serverTodos) {
        if (serverTodo.id == null) continue;

        final localTodo = localTodosMap[serverTodo.id!];

        if (localTodo == null) {
          // Nouvelle tâche du serveur
          await _databaseHelper.insertTodo(
            serverTodo.copyWith(isSynced: true),
          );
          stats.downloadedTodos++;
        } else {
          // Tâche existante - vérifier si mise à jour nécessaire
          if (_shouldUpdateLocalTodo(localTodo, serverTodo)) {
            await _databaseHelper.updateTodo(
              serverTodo.copyWith(isSynced: true),
            );
            stats.updatedTodos++;
          }
        }
      }

      // Optionnel: Détecter les tâches supprimées sur le serveur
      // (non implémenté car l'API ne fournit pas cette info)
    } catch (e) {
      stats.errors.add('Erreur download: ${e.toString()}');
    }

    return stats;
  }

  /// Synchroniser une tâche spécifique
  Future<SyncResult> syncSingleTodo({
    required Todo todo,
    required int accountId,
  }) async {
    try {
      if (!await _hasInternetConnection()) {
        return SyncResult.error('Pas de connexion internet');
      }

      if (todo.isSynced) {
        return SyncResult.success(SyncStats());
      }

      final response = await _apiService.createTodo(todo);

      if (response.isSuccess) {
        await _databaseHelper.markTodoAsSynced(
          todo.id!,
          response.data!.id!,
        );

        return SyncResult.success(SyncStats(uploadedTodos: 1));
      } else {
        return SyncResult.error('Échec sync: ${response.error}');
      }
    } catch (e) {
      return SyncResult.error('Erreur sync: ${e.toString()}');
    }
  }

  /// Synchronisation en arrière-plan (tentative silencieuse)
  Future<void> backgroundSync(int accountId) async {
    try {
      if (_isSyncing) return;

      // Sync silencieuse uniquement si connexion disponible
      if (await _hasInternetConnection()) {
        await syncAll(accountId: accountId);
      }
    } catch (e) {
      print('Erreur sync arrière-plan: $e');
      // Ne pas propager l'erreur pour le sync en arrière-plan
    }
  }

  /// Détecter les conflits entre version locale et serveur
  bool _shouldUpdateLocalTodo(Todo local, Todo server) {
    // Logique de résolution de conflit simple:
    // Le serveur gagne toujours (stratégie "server wins")
    return true;

    // Alternative: Comparer les timestamps de mise à jour
    // if (server.updatedAt != null && local.updatedAt != null) {
    //   return server.updatedAt!.isAfter(local.updatedAt!);
    // }
    // return false;
  }

  /// Vérifier la connectivité internet
  Future<bool> _hasInternetConnection() async {
    try {
      final connectivityResult = await Connectivity().checkConnectivity();

      if (connectivityResult == ConnectivityResult.none) {
        return false;
      }

      // Vérifier la connectivité réelle avec l'API
      return await _apiService.checkConnectivity();
    } catch (e) {
      print('Erreur vérification connectivité: $e');
      return false;
    }
  }

  /// Obtenir le statut de synchronisation
  Future<SyncStatus> getSyncStatus(int accountId) async {
    try {
      final unsyncedTodos = await _databaseHelper.getUnsyncedTodos();
      final hasConnection = await _hasInternetConnection();

      return SyncStatus(
        isOnline: hasConnection,
        isSyncing: _isSyncing,
        unsyncedCount: unsyncedTodos.length,
        lastSyncTime: _localStorage.getLastSyncTimestamp(),
        needsSync: _localStorage.needsSync(),
      );
    } catch (e) {
      print('Erreur statut sync: $e');
      return SyncStatus(
        isOnline: false,
        isSyncing: false,
        unsyncedCount: 0,
        lastSyncTime: null,
        needsSync: true,
      );
    }
  }

  /// Forcer une synchronisation complète
  Future<SyncResult> forceSyncAll(int accountId) async {
    return syncAll(accountId: accountId, forceSync: true);
  }

  /// Synchronisation automatique périodique
  void startPeriodicSync(
    int accountId, {
    Duration interval = const Duration(minutes: 15),
  }) {
    // Note: Dans une vraie app, utilisez un package comme workmanager
    // pour la synchronisation en arrière-plan
    print('Sync périodique configurée pour $interval');
  }

  /// Arrêter la synchronisation périodique
  void stopPeriodicSync() {
    print('Sync périodique arrêtée');
  }

  /// Nettoyer les données de sync
  Future<void> clearSyncData() async {
    _isSyncing = false;
    _lastSyncTime = null;
    await _localStorage.saveLastSyncTimestamp();
  }

  /// Obtenir les statistiques de synchronisation
  Future<Map<String, dynamic>> getSyncStats() async {
    final dbStats = await _databaseHelper.getDatabaseStats();

    return {
      'is_syncing': _isSyncing,
      'last_sync': _lastSyncTime?.toIso8601String(),
      'unsynced_todos': dbStats['unsynced_todos'],
      'total_todos': dbStats['todos'],
      'needs_sync': _localStorage.needsSync(),
    };
  }
}

/// Classe pour les résultats de synchronisation
class SyncResult {
  final bool isSuccess;
  final SyncStats? stats;
  final String? error;

  SyncResult._({
    required this.isSuccess,
    this.stats,
    this.error,
  });

  factory SyncResult.success(SyncStats stats) {
    return SyncResult._(
      isSuccess: true,
      stats: stats,
    );
  }

  factory SyncResult.error(String error) {
    return SyncResult._(
      isSuccess: false,
      error: error,
    );
  }

  @override
  String toString() {
    if (isSuccess) {
      return 'SyncResult.success($stats)';
    } else {
      return 'SyncResult.error($error)';
    }
  }
}

/// Statistiques de synchronisation
class SyncStats {
  int uploadedTodos;
  int downloadedTodos;
  int updatedTodos;
  int deletedTodos;
  List<String> errors;

  SyncStats({
    this.uploadedTodos = 0,
    this.downloadedTodos = 0,
    this.updatedTodos = 0,
    this.deletedTodos = 0,
    List<String>? errors,
  }) : errors = errors ?? [];

  /// Fusionner avec d'autres statistiques
  void merge(SyncStats other) {
    uploadedTodos += other.uploadedTodos;
    downloadedTodos += other.downloadedTodos;
    updatedTodos += other.updatedTodos;
    deletedTodos += other.deletedTodos;
    errors.addAll(other.errors);
  }

  /// Obtenir le nombre total d'opérations
  int get totalOperations =>
      uploadedTodos + downloadedTodos + updatedTodos + deletedTodos;

  /// Vérifier s'il y a des erreurs
  bool get hasErrors => errors.isNotEmpty;

  /// Obtenir un résumé des opérations
  String get summary {
    final operations = <String>[];

    if (uploadedTodos > 0) operations.add('$uploadedTodos créées');
    if (downloadedTodos > 0) operations.add('$downloadedTodos téléchargées');
    if (updatedTodos > 0) operations.add('$updatedTodos mises à jour');
    if (deletedTodos > 0) operations.add('$deletedTodos supprimées');

    if (operations.isEmpty) {
      return 'Aucune modification';
    }

    return operations.join(', ');
  }

  @override
  String toString() {
    return 'SyncStats{upload: $uploadedTodos, download: $downloadedTodos, '
        'update: $updatedTodos, delete: $deletedTodos, errors: ${errors.length}}';
  }
}

/// Statut de synchronisation
class SyncStatus {
  final bool isOnline;
  final bool isSyncing;
  final int unsyncedCount;
  final DateTime? lastSyncTime;
  final bool needsSync;

  SyncStatus({
    required this.isOnline,
    required this.isSyncing,
    required this.unsyncedCount,
    this.lastSyncTime,
    required this.needsSync,
  });

  /// Obtenir un message de statut
  String get statusMessage {
    if (isSyncing) {
      return 'Synchronisation en cours...';
    }

    if (!isOnline) {
      return 'Hors ligne${unsyncedCount > 0 ? ' - $unsyncedCount tâches en attente' : ''}';
    }

    if (unsyncedCount > 0) {
      return '$unsyncedCount tâches à synchroniser';
    }

    if (lastSyncTime != null) {
      final timeDiff = DateTime.now().difference(lastSyncTime!);
      if (timeDiff.inHours < 1) {
        return 'Synchronisé il y a ${timeDiff.inMinutes} min';
      } else if (timeDiff.inDays < 1) {
        return 'Synchronisé il y a ${timeDiff.inHours}h';
      } else {
        return 'Synchronisé il y a ${timeDiff.inDays} jours';
      }
    }

    return 'Jamais synchronisé';
  }

  /// Obtenir une icône de statut
  String get statusIcon {
    if (isSyncing) return '🔄';
    if (!isOnline) return '📱';
    if (unsyncedCount > 0) return '⚠️';
    return '✅';
  }

  @override
  String toString() {
    return 'SyncStatus{online: $isOnline, syncing: $isSyncing, '
        'unsynced: $unsyncedCount, needsSync: $needsSync}';
  }
}
