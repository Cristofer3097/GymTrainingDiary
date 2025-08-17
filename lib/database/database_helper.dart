import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'database_exercise.dart';


class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('gym_diary.db');
    return _database!;
  }


  Future<Database> _initDB(String filePath) async {
    Directory documentsDirectory = await getApplicationDocumentsDirectory();
    final path = join(documentsDirectory.path, filePath);
    return await openDatabase(
      path,
      version: 7,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future<void> closeDB() async {
    if (_database != null && _database!.isOpen) {
      await _database!.close();
      _database = null; // Marcar como nulo para que se reinicialice en el próximo acceso
      print("Database connection closed.");
    }
  }

  Future<void> _createDB(Database db, int version) async {

    // Tabla templates
    await db.execute('''
      CREATE TABLE IF NOT EXISTS templates (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        template_key TEXT
      );
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        original_id INTEGER,
        muscle_group TEXT,
        image TEXT,
        description TEXT,
        is_predefined INTEGER DEFAULT 0,
        is_favorite INTEGER DEFAULT 0
      );
    ''');

    // Tabla template_exercises
    await db.execute('''
  CREATE TABLE IF NOT EXISTS template_exercises (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  template_id INTEGER NOT NULL,
  category_id INTEGER NOT NULL,
  FOREIGN KEY (template_id) REFERENCES templates(id) ON DELETE CASCADE,
  FOREIGN KEY (category_id) REFERENCES categories(id) ON DELETE CASCADE
);
''');

    await db.execute('''
    CREATE TABLE IF NOT EXISTS training_sessions (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      session_title TEXT NOT NULL,
      session_dateTime TEXT NOT NULL 
    );
  ''');

    await db.execute('''
    CREATE TABLE IF NOT EXISTS exercise_name_history (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  old_name TEXT NOT NULL,
  new_name TEXT NOT NULL,
  changed_at TEXT DEFAULT CURRENT_TIMESTAMP
);
  ''');

    await db.execute('''
    CREATE TABLE IF NOT EXISTS exercise_logs (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      session_id INTEGER, 
      exercise_name TEXT NOT NULL,
      exercise_id INTEGER,
      dateTime TEXT NOT NULL, 
      series TEXT,
      reps TEXT,
      weight TEXT,
      weightUnit TEXT,
      notes TEXT,
      FOREIGN KEY (session_id) REFERENCES training_sessions(id) ON DELETE CASCADE
    );
  ''');

    await _synchronizePredefinedData(db);
    print("Base de datos creada y datos predefinidos sincronizados.");
  }
  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    print("Ejecutando _upgradeDB de v$oldVersion a v$newVersion.");

    // Mantenemos la migración de la v1 a la v2
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE categories ADD COLUMN is_favorite INTEGER DEFAULT 0');
      print("Migración a v2: Columna 'is_favorite' añadida.");
    }

    // CAMBIO: Nueva migración para la v3.
    // Esta se ejecutará para cualquier usuario que tenga una versión inferior a 3.
    if (oldVersion < 3) {
      print("Migración a v3: Sincronizando datos predefinidos...");
      await _synchronizePredefinedData(db);
      print("Migración a v3 completada.");
    }
    if (oldVersion < 4) {
      print("Migración a v4: Resincronizando datos para corregir enlaces de plantillas...");
      await _synchronizePredefinedData(db);
      print("Migración a v4 completada.");
    }
  }


  Future<void> _synchronizePredefinedData(Database db) async {
    print("Iniciando sincronización de datos predefinidos...");
    final batch = db.batch();

    // 1. Sincronizar Ejercicios
    for (final exerciseData in predefinedExerciseList) {
      final originalId = exerciseData['id'];
      final existingExercise = await db.query(
          'categories',
          where: 'original_id = ? AND is_predefined = 1',
          whereArgs: [originalId],
          limit: 1
      );

      Map<String, dynamic> dataToInsertOrUpdate = {
        'name': exerciseData['name'],
        'muscle_group': exerciseData['muscle_group'],
        'image': exerciseData['image'] ?? 'assets/exercises/placeholder.png',
        'description': exerciseData['description'] ?? 'No hay descripción.',
        'is_predefined': 1,
        'original_id': originalId,
      };

      if (existingExercise.isNotEmpty) {
        // El ejercicio ya existe, lo actualizamos
        batch.update(
            'categories',
            dataToInsertOrUpdate,
            where: 'id = ?',
            whereArgs: [existingExercise.first['id']]
        );
      } else {
        // El ejercicio es nuevo, lo insertamos
        batch.insert(
            'categories',
            dataToInsertOrUpdate,
            conflictAlgorithm: ConflictAlgorithm.ignore // Por si acaso el nombre ya fue tomado por un ejercicio de usuario
        );
      }
    }

    // 2. Sincronizar Plantillas
    for (final templateData in predefinedTemplatesData) {
      String templateKey = templateData['templateKey'] as String;
      String templateName = templateData['templateName'] as String;

      // Buscamos si la plantilla ya existe por su clave única
      final existingTemplates = await db.query('templates', where: 'template_key = ?', whereArgs: [templateKey]);
      int templateId;

      if (existingTemplates.isNotEmpty) {
        templateId = existingTemplates.first['id'] as int;
        // Si el nombre ha cambiado en el archivo, lo actualizamos en la BD
        if (existingTemplates.first['name'] != templateName) {
          batch.update('templates', {'name': templateName}, where: 'id = ?', whereArgs: [templateId]);
        }
      } else {
        // Insertamos la nueva plantilla y obtenemos su ID para el siguiente paso
        templateId = await db.insert('templates', {'name': templateName, 'template_key': templateKey});
      }

      // Si tenemos un ID válido, sincronizamos sus ejercicios
      if(templateId > 0) {
        // Borramos las asociaciones viejas para asegurar una lista limpia
        batch.delete('template_exercises', where: 'template_id = ?', whereArgs: [templateId]);

        List<int> exerciseSourceIds = templateData['exerciseSourceIds'] as List<int>;

        for (int sourceId in exerciseSourceIds) {
          // Buscamos el ID real del ejercicio en la tabla 'categories' usando su 'original_id'
          final exercises = await db.query(
              'categories',
              columns: ['id'],
              where: 'original_id = ?',
              whereArgs: [sourceId]
          );

          if (exercises.isNotEmpty) {
            int categoryDbId = exercises.first['id'] as int;
            batch.insert('template_exercises', {
              'template_id': templateId,
              'category_id': categoryDbId,
            });
          } else {
            print("Advertencia: Ejercicio con source_id $sourceId no encontrado al sincronizar plantilla '$templateName'.");
          }
        }
      }
    }

    await batch.commit(noResult: true);
    print("Sincronización de datos predefinidos finalizada.");
  }
  Future<void> deleteCategory(int id) async {
    final db = await database;
    await db.delete('categories', where: 'id = ?', whereArgs: [id]);

  }
  Future<List<Map<String, dynamic>>> getExerciseLogs(String exerciseName) async {
    final db = await database;
    return await db.query(
      'exercise_logs',
      where: 'exercise_name = ?',
      whereArgs: [exerciseName],
      orderBy: 'dateTime DESC',
    );
  }
  Future<Map<String, dynamic>?> getLastExerciseLog(String exerciseName) async {
    final db = await database;
    final res = await db.query(
      'exercise_logs',
      where: 'exercise_name = ?',
      whereArgs: [exerciseName],
      orderBy: 'dateTime DESC',
      limit: 1,
    );
    if (res.isNotEmpty) return res.first;
    return null;
  }


  Future<int> insertTrainingSession(String title, String dateTime) async {
    final db = await database;
    return await db.insert('training_sessions', {
      'session_title': title,
      'session_dateTime': dateTime,
    });
  }

  Future<int> updateCategory(int id, Map<String, dynamic> category) async {
    final db = await database;
    return await db.update('categories', category, where: 'id = ?', whereArgs: [id]);
  }


  Future<void> updateExerciseLogsName(String oldName, String newName) async {
    final db = await database;
    await db.update(
      'exercise_logs',
      {'exercise_name': newName},
      where: 'exercise_name = ?',
      whereArgs: [oldName],
    );
    print('Nombres de ejercicio actualizados en logs: de "$oldName" a "$newName"');
  }
  // Métodos de inserción y consulta
  Future<int> insertCategory(Map<String, dynamic> categoryData) async {
    final db = await database;
    // Prepara el mapa asegurando que todos los campos de la tabla 'categories'
    // que no vienen de categoryData se establezcan explícitamente a null o un valor por defecto.
    Map<String, dynamic> completeCategoryData = {
      'name': categoryData['name'],
      'muscle_group': categoryData['muscle_group'],
      'image': categoryData['image'],
      'description': categoryData['description'],
    };
    return await db.insert('categories', completeCategoryData);
  }
  Future<void> insertExerciseLogWithSessionId(Map<String, dynamic> logData, int sessionId) async {
    final db = await database;
    Map<String, dynamic> logToInsert = Map.from(logData);
    logToInsert['session_id'] = sessionId;
    await db.insert('exercise_logs', logToInsert);
  }
  Future<void> deleteTrainingSessionAndLogs(int sessionId) async {
    final db = await database;
    int count = await db.delete('training_sessions', where: 'id = ?', whereArgs: [sessionId]);
    if (count > 0) {
      print("Sesión con ID $sessionId y sus logs asociados eliminados.");
    } else {
      print("No se encontró sesión con ID $sessionId para eliminar.");
    }
  }


  Future<void> deleteTemplate(int templateId) async {
    final db = await database;
    await db.delete('templates', where: 'id = ?', whereArgs: [templateId]);
  }

  Future<List<Map<String, dynamic>>> getCategories() async {
    final db = await database;
    // Devuelve todos los campos, incluyendo is_predefined
    return await db.query('categories', orderBy: 'name ASC');
  }




  Future<int> insertTemplate(String name) async {
    final db = await database;
    return await db.insert(
      'templates',
      {'name': name},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

// Agrega este método para guardar los ejercicios de la plantilla
  Future<void> insertTemplateExercises(int templateId, List<int> categoryIds) async {
    final db = await database;

    // Eliminar ejercicios existentes para esta plantilla (si los hay)
    await db.delete(
      'template_exercises',
      where: 'template_id = ?',
      whereArgs: [templateId],
    );

    // Insertar los nuevos ejercicios
    final batch = db.batch();

    for (final categoryId in categoryIds) {
      batch.insert('template_exercises', {
        'template_id': templateId,
        'category_id': categoryId,
      });
    }

    await batch.commit();
  }
  Future<void> updateExerciseName(String oldName, String newName) async {
    final db = await database;
    await db.transaction((txn) async {
      // 1. Registrar el cambio en el historial
      await txn.insert('exercise_name_history', {
        'old_name': oldName,
        'new_name': newName,
      });

      // 2. Actualizar el nombre en todas las tablas afectadas
      await txn.update(
        'categories',
        {'name': newName},
        where: 'name = ?',
        whereArgs: [oldName],
      );

      await txn.update(
        'exercise_logs',
        {'exercise_name': newName},
        where: 'exercise_name = ?',
        whereArgs: [oldName],
      );

    });
  }

// Obtener todas las plantillas
  Future<List<Map<String, dynamic>>> getAllTemplates() async {
    final db = await database;
    return await db.query('templates', columns: ['id', 'name', 'template_key'], orderBy: 'id DESC'); // Añadir template_key
  }

// Obtener los ejercicios de una plantilla
  Future<List<Map<String, dynamic>>> getTemplateExercises(int templateId) async {
    final db = await database;
    final String sql = '''
    SELECT
      te.id as template_exercise_id,
      te.template_id,
      c.id as category_id,
      c.name,
      c.muscle_group as category,
      c.image,
      c.description,
      c.is_predefined,
      c.original_id
    FROM template_exercises te
    JOIN categories c ON te.category_id = c.id
    WHERE te.template_id = ?
    ORDER BY te.id ASC
  ''';
    return await db.rawQuery(sql, [templateId]);
  }

  Future<List<DateTime>> getDatesWithTrainingSessions() async {
    final db = await database;
    final List<Map<String, dynamic>> result = await db.rawQuery(
        "SELECT DISTINCT SUBSTR(session_dateTime, 1, 10) as training_date FROM training_sessions WHERE training_date IS NOT NULL ORDER BY training_date DESC"
    );
    return result.map((map) => DateTime.parse(map['training_date'] as String)).toList();
  }

  Future<List<Map<String, dynamic>>> getTrainingSessionsForDate(DateTime date) async {
    final db = await database;
    String dateString = DateFormat('yyyy-MM-dd').format(date); // Esto ahora es válido
    return await db.query(
      'training_sessions',
      where: "SUBSTR(session_dateTime, 1, 10) = ?",
      whereArgs: [dateString],
      orderBy: 'session_dateTime ASC',
    );
  }

  Future<List<Map<String, dynamic>>> getExerciseLogsForSession(int sessionId) async {
    final db = await database;
    return await db.query(
      'exercise_logs',
      where: "session_id = ?",
      whereArgs: [sessionId],
      orderBy: 'id ASC', // O el orden que prefieras para los ejercicios dentro de una sesión
    );
  }
  Future<Map<String, dynamic>?> getExerciseDefinitionByName(String name) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'categories', // Este es el nombre de tu tabla de definición de ejercicios
      where: 'name = ?',
      whereArgs: [name],
      limit: 1,
    );
    if (maps.isNotEmpty) {
      return maps.first;
    }
    return null;
  }

  // Actualizar el título y fecha de una sesión
  Future<void> updateTrainingSession(int sessionId, String newTitle, String newDateTime) async {
    final db = await database;
    await db.update(
      'training_sessions',
      {'session_title': newTitle, 'session_dateTime': newDateTime},
      where: 'id = ?',
      whereArgs: [sessionId],
    );
  }

  // Función para borrar todos los logs de una sesión (para luego reinsertarlos)
  Future<void> clearExerciseLogsForSession(int sessionId) async {
    final db = await database;
    await db.delete(
      'exercise_logs',
      where: 'session_id = ?',
      whereArgs: [sessionId],
    );
  }

  Future<List<String>> getAllUserImagePaths() async {
    final db = await database;
    // Selecciona la columna 'image' de los ejercicios que NO son predefinidos
    // y cuyo path de imagen no es nulo ni está vacío.
    final List<Map<String, dynamic>> result = await db.query(
      'categories',
      columns: ['image'],
      where: 'is_predefined = ? AND image IS NOT NULL AND image != ?',
      whereArgs: [0, ''],
    );
    // Convierte el resultado en una lista de strings (rutas)
    return result.map((row) => row['image'] as String).toList();
  }
  Future<List<Map<String, dynamic>>> getFullExerciseLogsForSession(int sessionId) async {
    final db = await database;
    // Este query une los logs con las definiciones de los ejercicios para obtener todo en una sola consulta.
    final String sql = '''
    SELECT
      l.*,
      c.id as exercise_definition_id,
      c.muscle_group,
      c.image,
      c.description,
      c.is_predefined,
      c.original_id  
    FROM exercise_logs l
    LEFT JOIN categories c ON l.exercise_name = c.name
    WHERE l.session_id = ?
  ''';
    return await db.rawQuery(sql, [sessionId]);
  }


}

