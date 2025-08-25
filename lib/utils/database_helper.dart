import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../config/app_config.dart';
import '../models/user_model.dart';
import '../models/todo_model.dart';
import '../models/weather_model.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

  factory DatabaseHelper() => _instance;

  DatabaseHelper._internal();

  // Getter pour la base de données
  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  // Initialisation de la base de données
  Future<Database> _initDatabase() async {
    final databasePath = await getDatabasesPath();
    final path = join(databasePath, AppConfig.databaseName);

    return await openDatabase(
      path,
      version: AppConfig.databaseVersion,
      onCreate: _createTables,
      onUpgrade: _upgradeDatabase,
    );
  }

  // Création des tables
  Future<void> _createTables(Database db, int version) async {
    // Table des utilisateurs
    await db.execute('''
      CREATE TABLE ${AppConfig.usersTable} (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        email TEXT UNIQUE NOT NULL,
        profile_image_path TEXT,
        created_at INTEGER,
        updated_at INTEGER
      )
    ''');

    // Table des tâches avec synchronisation
    await db.execute('''
      CREATE TABLE ${AppConfig.todosTable} (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        server_id INTEGER,
        account_id INTEGER NOT NULL,
        title TEXT NOT NULL,
        date INTEGER NOT NULL,
        is_done INTEGER DEFAULT 0,
        created_at INTEGER,
        updated_at INTEGER,
        is_synced INTEGER DEFAULT 0,
        FOREIGN KEY (account_id) REFERENCES ${AppConfig.usersTable} (id)
      )
    ''');

    // Table météo pour cache local
    await db.execute('''
      CREATE TABLE ${AppConfig.weatherTable} (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        temperature REAL NOT NULL,
        description TEXT NOT NULL,
        location TEXT NOT NULL,
        icon TEXT,
        last_updated INTEGER NOT NULL
      )
    ''');

    // Index pour optimiser les requêtes
    await db.execute('''
      CREATE INDEX idx_todos_account_id ON ${AppConfig.todosTable} (account_id)
    ''');

    await db.execute('''
      CREATE INDEX idx_todos_date ON ${AppConfig.todosTable} (date)
    ''');

    await db.execute('''
      CREATE INDEX idx_todos_synced ON ${AppConfig.todosTable} (is_synced)
    ''');
  }

  // Mise à jour de la base de données
  Future<void> _upgradeDatabase(
      Database db, int oldVersion, int newVersion) async {
    // Gérer les migrations futures
    if (oldVersion < 2) {
      // Exemple de migration pour une future version
      // await db.execute('ALTER TABLE todos ADD COLUMN priority INTEGER DEFAULT 0');
    }
  }

  // === OPÉRATIONS USERS ===

  // Insérer un utilisateur
  Future<int> insertUser(User user) async {
    final db = await database;
    final userMap = user.toMap();
    userMap['created_at'] = DateTime.now().millisecondsSinceEpoch;
    userMap['updated_at'] = DateTime.now().millisecondsSinceEpoch;

    return await db.insert(AppConfig.usersTable, userMap);
  }

  // Récupérer un utilisateur par email
  Future<User?> getUserByEmail(String email) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      AppConfig.usersTable,
      where: 'email = ?',
      whereArgs: [email],
    );

    if (maps.isNotEmpty) {
      return User.fromMap(maps.first);
    }
    return null;
  }

  // Récupérer un utilisateur par ID
  Future<User?> getUserById(int id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      AppConfig.usersTable,
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      return User.fromMap(maps.first);
    }
    return null;
  }

  // Mettre à jour un utilisateur
  Future<int> updateUser(User user) async {
    final db = await database;
    final userMap = user.toMap();
    userMap['updated_at'] = DateTime.now().millisecondsSinceEpoch;

    return await db.update(
      AppConfig.usersTable,
      userMap,
      where: 'id = ?',
      whereArgs: [user.id],
    );
  }

  // === OPÉRATIONS TODOS ===

  // Insérer une tâche
  Future<int> insertTodo(Todo todo) async {
    final db = await database;
    final todoMap = todo.toMap();
    todoMap['created_at'] = DateTime.now().millisecondsSinceEpoch;
    todoMap['updated_at'] = DateTime.now().millisecondsSinceEpoch;

    return await db.insert(AppConfig.todosTable, todoMap);
  }

  // Récupérer toutes les tâches d'un utilisateur
  Future<List<Todo>> getTodosByAccountId(int accountId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      AppConfig.todosTable,
      where: 'account_id = ?',
      whereArgs: [accountId],
      orderBy: 'date DESC, created_at DESC',
    );

    return List.generate(maps.length, (i) {
      return Todo.fromMap(maps[i]);
    });
  }

  // Récupérer les tâches non synchronisées
  Future<List<Todo>> getUnsyncedTodos() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      AppConfig.todosTable,
      where: 'is_synced = ?',
      whereArgs: [0],
      orderBy: 'created_at ASC',
    );

    return List.generate(maps.length, (i) {
      return Todo.fromMap(maps[i]);
    });
  }

  // Mettre à jour une tâche
  Future<int> updateTodo(Todo todo) async {
    final db = await database;
    final todoMap = todo.toMap();
    todoMap['updated_at'] = DateTime.now().millisecondsSinceEpoch;

    return await db.update(
      AppConfig.todosTable,
      todoMap,
      where: 'id = ?',
      whereArgs: [todo.id],
    );
  }

  // Supprimer une tâche
  Future<int> deleteTodo(int id) async {
    final db = await database;
    return await db.delete(
      AppConfig.todosTable,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Marquer une tâche comme synchronisée
  Future<int> markTodoAsSynced(int localId, int serverId) async {
    final db = await database;
    return await db.update(
      AppConfig.todosTable,
      {
        'server_id': serverId,
        'is_synced': 1,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [localId],
    );
  }

  // === OPÉRATIONS MÉTÉO ===

  // Sauvegarder données météo
  Future<int> insertWeather(Weather weather) async {
    final db = await database;
    // Supprimer ancienne entrée météo (on garde que la dernière)
    await db.delete(AppConfig.weatherTable);

    return await db.insert(AppConfig.weatherTable, weather.toMap());
  }

  // Récupérer dernières données météo
  Future<Weather?> getLatestWeather() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      AppConfig.weatherTable,
      orderBy: 'last_updated DESC',
      limit: 1,
    );

    if (maps.isNotEmpty) {
      return Weather.fromMap(maps.first);
    }
    return null;
  }

  // === OPÉRATIONS GÉNÉRALES ===

  // Nettoyer toutes les données (déconnexion)
  Future<void> clearAllData() async {
    final db = await database;
    await db.delete(AppConfig.usersTable);
    await db.delete(AppConfig.todosTable);
    await db.delete(AppConfig.weatherTable);
  }

  // Fermer la base de données
  Future<void> close() async {
    final db = await database;
    await db.close();
    _database = null;
  }

  // Récupérer statistiques pour debug
  Future<Map<String, int>> getDatabaseStats() async {
    final db = await database;

    final userCount = Sqflite.firstIntValue(await db
            .rawQuery('SELECT COUNT(*) FROM ${AppConfig.usersTable}')) ??
        0;

    final todoCount = Sqflite.firstIntValue(await db
            .rawQuery('SELECT COUNT(*) FROM ${AppConfig.todosTable}')) ??
        0;

    final unsyncedCount = Sqflite.firstIntValue(await db.rawQuery(
            'SELECT COUNT(*) FROM ${AppConfig.todosTable} WHERE is_synced = 0')) ??
        0;

    return {
      'users': userCount,
      'todos': todoCount,
      'unsynced_todos': unsyncedCount,
    };
  }
}
