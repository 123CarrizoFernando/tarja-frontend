import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DBHelper {
  static Future<Database> getDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'tarja_offline.db');

    return openDatabase(
      path,
      version: 2,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE empleados (
            id INTEGER PRIMARY KEY,
            dni TEXT,
            nombre_completo TEXT,
            legajo TEXT,
            sector_id INTEGER
          )
        ''');
        await db.execute('''
          CREATE TABLE asistencias (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            empleado_id INTEGER,
            fecha TEXT,
            hora_llegada TEXT,
            hora_salida TEXT,
            sincronizado INTEGER DEFAULT 0
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('DROP TABLE IF EXISTS asistencias');
          await db.execute('''
            CREATE TABLE asistencias (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              empleado_id INTEGER,
              fecha TEXT,
              hora_llegada TEXT,
              hora_salida TEXT,
              sincronizado INTEGER DEFAULT 0
            )
          ''');
        }
      },
    );
  }

  static Future<void> guardarEmpleadosLocales(List<dynamic> empleados) async {
    final db = await getDatabase();
    await db.delete('empleados');
    Batch batch = db.batch();
    for (var emp in empleados) {
      batch.insert('empleados', {
        'id': emp['id'],
        'dni': emp['dni'],
        'nombre_completo': emp['nombre_completo'],
        'legajo': emp['legajo'],
        'sector_id': emp['sector_id'],
      });
    }
    await batch.commit();
  }

  static Future<List<Map<String, dynamic>>> obtenerEmpleadosLocales() async {
    final db = await getDatabase();
    return db.query('empleados', orderBy: 'nombre_completo');
  }

  static Future<void> registrarLlegadaLocal(int empleadoId, String hora) async {
    final db = await getDatabase();
    final fechaHoy = DateTime.now().toIso8601String().split('T')[0]; 

    final existe = await db.query(
      'asistencias',
      where: 'empleado_id = ? AND fecha = ?',
      whereArgs: [empleadoId, fechaHoy],
    );

    if (existe.isEmpty) {
      await db.insert('asistencias', {
        'empleado_id': empleadoId,
        'fecha': fechaHoy,
        'hora_llegada': hora,
        'sincronizado': 0
      });
    } else {
      await db.update(
        'asistencias',
        {'hora_llegada': hora, 'sincronizado': 0},
        where: 'empleado_id = ? AND fecha = ?',
        whereArgs: [empleadoId, fechaHoy],
      );
    }
  }

  static Future<void> registrarSalidaLocal(int empleadoId, String hora) async {
    final db = await getDatabase();
    final fechaHoy = DateTime.now().toIso8601String().split('T')[0]; 

    await db.update(
      'asistencias',
      {'hora_salida': hora, 'sincronizado': 0},
      where: 'empleado_id = ? AND fecha = ?',
      whereArgs: [empleadoId, fechaHoy],
    );
  }

  static Future<List<Map<String, dynamic>>> obtenerAsistenciasHoy() async {
    final db = await getDatabase();
    final fechaHoy = DateTime.now().toIso8601String().split('T')[0];
    return db.query('asistencias', where: 'fecha = ?', whereArgs: [fechaHoy]);
  }

  static Future<List<Map<String, dynamic>>> obtenerAsistenciasNoSincronizadas() async {
    final db = await getDatabase();
    return db.query('asistencias', where: 'sincronizado = 0');
  }

  static Future<void> marcarAsistenciasComoSincronizadas() async {
    final db = await getDatabase();
    await db.update('asistencias', {'sincronizado': 1}, where: 'sincronizado = 0');
  }

  static Future<void> guardarAsistenciaDesdeNube(Map<String, dynamic> asis) async {
    final db = await getDatabase(); 
    
    final List<Map<String, dynamic>> existe = await db.query(
      'asistencias',
      where: 'empleado_id = ? AND fecha = ?',
      whereArgs: [asis['empleado_id'], asis['fecha']],
    );

    if (existe.isEmpty) {
      await db.insert('asistencias', {
        'empleado_id': asis['empleado_id'],
        'fecha': asis['fecha'],
        'hora_llegada': asis['hora_llegada'],
        'hora_salida': asis['hora_salida'],
        'sincronizado': 1 
      });
    } else {
      await db.update('asistencias', {
        'hora_llegada': asis['hora_llegada'],
        'hora_salida': asis['hora_salida'],
        'sincronizado': 1
      }, where: 'empleado_id = ? AND fecha = ?', whereArgs: [asis['empleado_id'], asis['fecha']]);
    }
  }
}