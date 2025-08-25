class Todo {
  final int? id;
  final int accountId;
  final String title;
  final DateTime date;
  final bool isDone;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final bool isSynced; // Pour gérer la synchronisation offline

  Todo({
    this.id,
    required this.accountId,
    required this.title,
    required this.date,
    this.isDone = false,
    this.createdAt,
    this.updatedAt,
    this.isSynced = false,
  });

  // Conversion vers JSON pour l'API
  Map<String, dynamic> toJson() {
    return {
      'todo_id': id,
      'account_id': accountId,
      'todo': title,
      'date': _formatDateForApi(date),
      'done': isDone,
    };
  }

  // Création depuis JSON (réponse API)
  factory Todo.fromJson(Map<String, dynamic> json) {
    return Todo(
      id: json['todo_id'],
      accountId: json['account_id'],
      title: json['todo'] ?? '',
      date: _parseDateFromApi(json['date']),
      isDone: json['done'] == true || json['done'] == 1,
      isSynced: true, // Vient de l'API donc synchronisé
    );
  }

  // Conversion vers Map pour SQLite local
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'account_id': accountId,
      'title': title,
      'date': date.millisecondsSinceEpoch,
      'is_done': isDone ? 1 : 0,
      'created_at': createdAt?.millisecondsSinceEpoch,
      'updated_at': updatedAt?.millisecondsSinceEpoch,
      'is_synced': isSynced ? 1 : 0,
    };
  }

  // Création depuis Map (SQLite local)
  factory Todo.fromMap(Map<String, dynamic> map) {
    return Todo(
      id: map['id'],
      accountId: map['account_id'],
      title: map['title'] ?? '',
      date: DateTime.fromMillisecondsSinceEpoch(map['date']),
      isDone: map['is_done'] == 1,
      createdAt: map['created_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['created_at'])
          : null,
      updatedAt: map['updated_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['updated_at'])
          : null,
      isSynced: map['is_synced'] == 1,
    );
  }

  // Méthode copyWith pour modifications
  Todo copyWith({
    int? id,
    int? accountId,
    String? title,
    DateTime? date,
    bool? isDone,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isSynced,
  }) {
    return Todo(
      id: id ?? this.id,
      accountId: accountId ?? this.accountId,
      title: title ?? this.title,
      date: date ?? this.date,
      isDone: isDone ?? this.isDone,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isSynced: isSynced ?? this.isSynced,
    );
  }

  // Méthodes utilitaires pour le formatage des dates
  static String _formatDateForApi(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  static DateTime _parseDateFromApi(String? dateString) {
    if (dateString == null || dateString.isEmpty) {
      return DateTime.now();
    }
    try {
      return DateTime.parse(dateString);
    } catch (e) {
      return DateTime.now();
    }
  }

  // Getters utiles
  bool get isToday {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  bool get isPast {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final todoDate = DateTime(date.year, date.month, date.day);
    return todoDate.isBefore(today);
  }

  bool get isFuture {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final todoDate = DateTime(date.year, date.month, date.day);
    return todoDate.isAfter(today);
  }

  String get formattedDate {
    return _formatDateForApi(date);
  }

  @override
  String toString() {
    return 'Todo{id: $id, title: $title, date: $formattedDate, isDone: $isDone, isSynced: $isSynced}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Todo &&
        other.id == id &&
        other.accountId == accountId &&
        other.title == title &&
        other.date == date &&
        other.isDone == isDone;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        accountId.hashCode ^
        title.hashCode ^
        date.hashCode ^
        isDone.hashCode;
  }
}
