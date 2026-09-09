import 'dart:io';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';

import '../database/db_helper.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Map<String, dynamic>> _empleadosLocales = [];
  final Map<int, Map<String, String?>> _asistenciasHoy = {};
  bool _isSyncing = false;
  String _busqueda = "";

  final TextEditingController _correoController = TextEditingController();
  final String baseUrl = "https://tarja-api.onrender.com";

  @override
  void initState() {
    super.initState();
    _cargarDatosIniciales();
  }

  Future<void> _cargarDatosIniciales() async {
    await _cargarEmpleadosDesdeCelular();
    await _cargarAsistenciasLocales();
  }

  Future<void> _cargarEmpleadosDesdeCelular() async {
    final datos = await DBHelper.obtenerEmpleadosLocales();
    setState(() {
      _empleadosLocales = datos;
    });
  }

  Future<void> _cargarAsistenciasLocales() async {
    final registros = await DBHelper.obtenerAsistenciasHoy();
    setState(() {
      _asistenciasHoy.clear();
      for (var item in registros) {
        _asistenciasHoy[item['empleado_id'] as int] = {
          'llegada': item['hora_llegada'] as String?,
          'salida': item['hora_salida'] as String?,
          // Intentamos leer el estado (por si ya existe en la DB local), si no, por defecto es Presente
          'estado': item.containsKey('estado')
              ? (item['estado'] as String?) ?? 'Presente'
              : 'Presente',
        };
      }
    });
  }

  String _obtenerHoraActual() {
    final ahora = TimeOfDay.now();
    final horas = ahora.hour.toString().padLeft(2, '0');
    final minutos = ahora.minute.toString().padLeft(2, '0');
    return "$horas:$minutos";
  }

  Future<void> _marcarLlegada(int empleadoId) async {
    final horaActual = _obtenerHoraActual();
    await DBHelper.registrarLlegadaLocal(empleadoId, horaActual);
    await _cargarAsistenciasLocales();
  }

  Future<void> _marcarSalida(int empleadoId) async {
    final horaActual = _obtenerHoraActual();
    await DBHelper.registrarSalidaLocal(empleadoId, horaActual);
    await _cargarAsistenciasLocales();
  }

  Future<void> _editarHora(int empleadoId, bool esLlegada) async {
    final TimeOfDay? horaElegida = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      helpText: esLlegada ? "Editar hora de Llegada" : "Editar hora de Salida",
    );

    if (horaElegida != null) {
      final horas = horaElegida.hour.toString().padLeft(2, '0');
      final minutos = horaElegida.minute.toString().padLeft(2, '0');
      final nuevaHora = "$horas:$minutos";

      if (esLlegada) {
        await DBHelper.registrarLlegadaLocal(empleadoId, nuevaHora);
      } else {
        await DBHelper.registrarSalidaLocal(empleadoId, nuevaHora);
      }
      await _cargarAsistenciasLocales();
    }
  }

  // --- NUEVA FUNCIÓN: ENVIAR FALTA O LICENCIA AL SERVIDOR ---
  Future<void> _cambiarEstadoGlobal(int empleadoId, String estado) async {
    setState(() {
      _isSyncing = true;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      if (token == null) throw Exception("Sin sesión");

      // Llamada directa al servidor (¡Requiere Internet!)
      final url = Uri.parse(
        '$baseUrl/asistencias/$empleadoId/estado?estado=$estado',
      );
      final response = await http.put(
        url,
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        // Actualizamos la pantalla instantáneamente
        setState(() {
          if (_asistenciasHoy[empleadoId] == null) {
            _asistenciasHoy[empleadoId] = {};
          }
          _asistenciasHoy[empleadoId]!['estado'] = estado;

          // Si faltó, reseteamos las horas en la memoria visual de la app
          if (estado != "Presente") {
            _asistenciasHoy[empleadoId]!['llegada'] = null;
            _asistenciasHoy[empleadoId]!['salida'] = null;
          }
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Estado actualizado a $estado'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        throw Exception("Error del servidor: ${response.statusCode}");
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error (Verifique su conexión): $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isSyncing = false;
      });
    }
  }

  Future<void> _cerrarSesion() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    if (mounted) Navigator.of(context).pushReplacementNamed('/');
  }

  Future<void> _sincronizarConServidor() async {
    setState(() {
      _isSyncing = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      if (token == null) throw Exception("No hay sesión iniciada");

      final asistenciasPendientes =
          await DBHelper.obtenerAsistenciasNoSincronizadas();

      if (asistenciasPendientes.isNotEmpty) {
        final urlSubida = Uri.parse('$baseUrl/asistencias/sincronizar');
        final responseSubida = await http.post(
          urlSubida,
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: json.encode(asistenciasPendientes),
        );

        if (responseSubida.statusCode == 200) {
          await DBHelper.marcarAsistenciasComoSincronizadas();
        } else {
          throw Exception("Error al subir horarios");
        }
      }

      final urlEmpleados = Uri.parse('$baseUrl/empleados');
      final responseEmpleados = await http.get(
        urlEmpleados,
        headers: {'Authorization': 'Bearer $token'},
      );

      if (responseEmpleados.statusCode == 200) {
        final List<dynamic> empleadosNube = json.decode(responseEmpleados.body);
        await DBHelper.guardarEmpleadosLocales(empleadosNube);
      }

      final urlDescarga = Uri.parse('$baseUrl/asistencias/hoy');
      final responseDescarga = await http.get(
        urlDescarga,
        headers: {'Authorization': 'Bearer $token'},
      );

      if (responseDescarga.statusCode == 200) {
        final List<dynamic> asistenciasNube = json.decode(
          responseDescarga.body,
        );
        for (var asis in asistenciasNube) {
          await DBHelper.guardarAsistenciaDesdeNube(asis);
        }
      }

      await _cargarDatosIniciales();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sincronización completa'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() {
        _isSyncing = false;
      });
    }
  }

  Future<void> _sincronizarPendientesSilent(String token) async {
    try {
      final asistenciasPendientes =
          await DBHelper.obtenerAsistenciasNoSincronizadas();
      if (asistenciasPendientes.isNotEmpty) {
        final urlSubida = Uri.parse('$baseUrl/asistencias/sincronizar');
        final responseSubida = await http.post(
          urlSubida,
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: json.encode(asistenciasPendientes),
        );
        if (responseSubida.statusCode == 200) {
          await DBHelper.marcarAsistenciasComoSincronizadas();
        }
      }
    } catch (e) {
      debugPrint("Error en sincronización silenciosa: $e");
    }
  }

  Future<void> _descargarPDF() async {
    setState(() {
      _isSyncing = true;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      if (token == null) throw Exception("No hay sesión iniciada");

      await _sincronizarPendientesSilent(token);

      final response = await http.get(
        Uri.parse('$baseUrl/reporte/descargar_pdf'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final directorio = await getApplicationDocumentsDirectory();
        final archivo = File('${directorio.path}/Reporte_Tarja.pdf');
        await archivo.writeAsBytes(response.bodyBytes);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('¡PDF descargado! Abriendo...'),
              backgroundColor: Colors.green,
            ),
          );
        }
        await OpenFile.open(archivo.path);
      } else {
        throw Exception("Error del servidor: ${response.statusCode}");
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al descargar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isSyncing = false;
      });
    }
  }

  Future<void> _enviarCorreoAPI(String correo) async {
    setState(() {
      _isSyncing = true;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      if (token == null) throw Exception("No hay sesión iniciada");

      await _sincronizarPendientesSilent(token);

      final response = await http.post(
        Uri.parse('$baseUrl/reporte/enviar_correo_api'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'correo_destino': correo}),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('¡Reporte enviado con éxito a $correo!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        throw Exception("Error del servidor: ${response.statusCode}");
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al enviar correo: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isSyncing = false;
      });
    }
  }

  Future<void> _elegirRangoYDescargar() async {
    final DateTimeRange? rangoElegido = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime(2030),
      helpText: 'Seleccionar Rango de Fechas',
      cancelText: 'Cancelar',
      confirmText: 'Generar PDF',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Colors.blueAccent,
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (rangoElegido != null) {
      await _descargarReporteRango(rangoElegido.start, rangoElegido.end);
    }
  }

  Future<void> _descargarReporteRango(DateTime inicio, DateTime fin) async {
    setState(() {
      _isSyncing = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      if (token == null) throw Exception("No hay sesión iniciada");

      await _sincronizarPendientesSilent(token);

      final strInicio =
          "${inicio.year}-${inicio.month.toString().padLeft(2, '0')}-${inicio.day.toString().padLeft(2, '0')}";
      final strFin =
          "${fin.year}-${fin.month.toString().padLeft(2, '0')}-${fin.day.toString().padLeft(2, '0')}";

      final url = Uri.parse(
        '$baseUrl/reporte/rango_pdf?fecha_inicio=$strInicio&fecha_fin=$strFin',
      );
      final response = await http.get(
        url,
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final directorio = await getApplicationDocumentsDirectory();
        final archivo = File(
          '${directorio.path}/Reporte_Horas_${strInicio}_al_$strFin.pdf',
        );
        await archivo.writeAsBytes(response.bodyBytes);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('¡Reporte generado!'),
              backgroundColor: Colors.green,
            ),
          );
        }
        await OpenFile.open(archivo.path);
      } else {
        throw Exception("Error del servidor (Código ${response.statusCode})");
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al descargar reporte: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSyncing = false;
        });
      }
    }
  }

  void _mostrarOpcionesCierre() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: [
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Center(
                  child: Text(
                    '¿Cómo querés generar el reporte?',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(
                  Icons.picture_as_pdf,
                  color: Colors.redAccent,
                ),
                title: const Text('Descargar y Ver PDF'),
                subtitle: const Text('Guardar el archivo en este celular'),
                onTap: () {
                  Navigator.pop(context);
                  _descargarPDF();
                },
              ),
              ListTile(
                leading: const Icon(Icons.mail, color: Colors.blueAccent),
                title: const Text('Enviar por Correo (Oficina)'),
                subtitle: const Text('Mandar el PDF automáticamente'),
                onTap: () {
                  Navigator.pop(context);
                  _pedirCorreo();
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pedirCorreo() async {
    final prefs = await SharedPreferences.getInstance();
    final ultimoCorreo = prefs.getString('ultimo_correo') ?? '';
    if (_correoController.text.isEmpty) _correoController.text = ultimoCorreo;

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Enviar Reporte'),
          content: TextField(
            controller: _correoController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              hintText: 'ejemplo@correo.com',
              labelText: 'Correo de destino',
              prefixIcon: Icon(Icons.email),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                final correo = _correoController.text.trim();
                if (correo.isNotEmpty) {
                  await prefs.setString('ultimo_correo', correo);
                  if (mounted) Navigator.pop(context);
                  _enviarCorreoAPI(correo);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                foregroundColor: Colors.white,
              ),
              child: const Text('Enviar'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _verHistorialEmpleado(int empleadoId, String nombre) async {
    final DateTimeRange? rango = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime(2030),
      helpText: 'Trazabilidad de $nombre',
      confirmText: 'Ver Total de Horas',
    );

    if (rango == null) return;
    setState(() {
      _isSyncing = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      if (token == null) throw Exception("Sin sesión");

      await _sincronizarPendientesSilent(token);

      final strInicio =
          "${rango.start.year}-${rango.start.month.toString().padLeft(2, '0')}-${rango.start.day.toString().padLeft(2, '0')}";
      final strFin =
          "${rango.end.year}-${rango.end.month.toString().padLeft(2, '0')}-${rango.end.day.toString().padLeft(2, '0')}";

      final url = Uri.parse(
        '$baseUrl/empleados/$empleadoId/historial?fecha_inicio=$strInicio&fecha_fin=$strFin',
      );
      final response = await http.get(
        url,
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _mostrarModalHistorial(data);
      } else {
        throw Exception("Error del servidor: ${response.statusCode}");
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() {
        _isSyncing = false;
      });
    }
  }

  void _mostrarModalHistorial(Map<String, dynamic> data) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final detalle = data['detalle'] as List;
        return SafeArea(
          child: Container(
            height: MediaQuery.of(context).size.height * 0.7,
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Text(
                  "Trazabilidad: ${data['empleado']}",
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    "Total del periodo: ${data['total_horas']} hs",
                    style: const TextStyle(
                      fontSize: 20,
                      color: Colors.blueAccent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Divider(height: 30),
                Expanded(
                  child: detalle.isEmpty
                      ? const Center(
                          child: Text(
                            "No hay asistencias marcadas en estas fechas.",
                          ),
                        )
                      : ListView.builder(
                          itemCount: detalle.length,
                          itemBuilder: (context, index) {
                            final dia = detalle[index];
                            return ListTile(
                              leading: const Icon(
                                Icons.calendar_month,
                                color: Colors.grey,
                              ),
                              title: Text("Fecha: ${dia['fecha']}"),
                              subtitle: Text(
                                "Ingresó: ${dia['llegada'] ?? '-'} | Salió: ${dia['salida'] ?? '-'}",
                              ),
                              trailing: Text(
                                "${dia['horas_trabajadas']} hs",
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Colors.green,
                                ),
                              ),
                            );
                          },
                        ),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text("Cerrar Resumen"),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // FILTRAMOS LOS EMPLEADOS DEL ENCARGADO
    final empleadosFiltrados = _empleadosLocales.where((emp) {
      final query = _busqueda.toLowerCase();
      final nombre = emp['nombre_completo'].toString().toLowerCase();
      final legajo = emp['legajo'].toString().toLowerCase();
      return nombre.contains(query) || legajo.contains(query);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tarja Diaria Municipal'),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.date_range),
            onPressed: _isSyncing ? null : _elegirRangoYDescargar,
          ),
          IconButton(
            icon: _isSyncing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.sync),
            onPressed: _isSyncing ? null : _sincronizarConServidor,
          ),
          IconButton(icon: const Icon(Icons.logout), onPressed: _cerrarSesion),
        ],
      ),
      body: Column(
        children: [
          // BARRA DE BÚSQUEDA DEL ENCARGADO
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              decoration: InputDecoration(
                labelText: 'Buscar por nombre o legajo',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                filled: true,
                fillColor: Colors.grey.shade100,
              ),
              onChanged: (valor) => setState(() => _busqueda = valor),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _isSyncing ? () async {} : _sincronizarConServidor,
              child: _empleadosLocales.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: const [
                        SizedBox(
                          height: 300,
                          child: Center(
                            child: Text(
                              'Deslizá hacia abajo para sincronizar.',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ),
                        ),
                      ],
                    )
                  : empleadosFiltrados.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: const [
                        SizedBox(
                          height: 300,
                          child: Center(
                            child: Text(
                              'No se encontraron empleados en la búsqueda',
                            ),
                          ),
                        ),
                      ],
                    )
                  : ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.only(bottom: 80),
                      itemCount: empleadosFiltrados.length,
                      itemBuilder: (context, index) {
                        final emp = empleadosFiltrados[index];
                        final empleadoId = emp['id'];
                        final horarios = _asistenciasHoy[empleadoId] ?? {};
                        final horaLlegada = horarios['llegada'];
                        final horaSalida = horarios['salida'];
                        final estado = horarios['estado'] ?? 'Presente';
                        final yaLlego = horaLlegada != null;
                        final yaSeFue = horaSalida != null;
                        final esPresente = (estado == 'Presente');

                        return Card(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            emp['nombre_completo'],
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                          Text(
                                            'Legajo: ${emp['legajo']}',
                                            style: const TextStyle(
                                              color: Colors.grey,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Row(
                                      children: [
                                        IconButton(
                                          icon: const Icon(
                                            Icons.history,
                                            color: Colors.blueAccent,
                                          ),
                                          onPressed: _isSyncing
                                              ? null
                                              : () => _verHistorialEmpleado(
                                                  empleadoId,
                                                  emp['nombre_completo'],
                                                ),
                                        ),
                                        PopupMenuButton<String>(
                                          icon: const Icon(
                                            Icons.more_vert,
                                            color: Colors.grey,
                                          ),
                                          onSelected: (valor) =>
                                              _cambiarEstadoGlobal(
                                                empleadoId,
                                                valor,
                                              ),
                                          itemBuilder: (context) => [
                                            const PopupMenuItem(
                                              value: "Presente",
                                              child: Text(
                                                "Marcar como Presente (Normal)",
                                              ),
                                            ),
                                            const PopupMenuItem(
                                              value: "Falta",
                                              child: Text(
                                                "Marcar Falta Injustificada",
                                              ),
                                            ),
                                            const PopupMenuItem(
                                              value: "Licencia",
                                              child: Text(
                                                "Marcar Licencia / Justificado",
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                if (esPresente)
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Column(
                                        children: [
                                          ElevatedButton(
                                            onPressed: yaLlego
                                                ? null
                                                : () => _marcarLlegada(
                                                    empleadoId,
                                                  ),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.green,
                                              foregroundColor: Colors.white,
                                              disabledBackgroundColor:
                                                  Colors.grey.shade300,
                                            ),
                                            child: const Text("Llegada"),
                                          ),
                                          if (yaLlego)
                                            Row(
                                              children: [
                                                Text(
                                                  horaLlegada,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.green,
                                                  ),
                                                ),
                                                IconButton(
                                                  icon: const Icon(
                                                    Icons.edit,
                                                    size: 16,
                                                    color: Colors.grey,
                                                  ),
                                                  onPressed: () => _editarHora(
                                                    empleadoId,
                                                    true,
                                                  ),
                                                  padding: EdgeInsets.zero,
                                                  constraints:
                                                      const BoxConstraints(),
                                                ),
                                              ],
                                            ),
                                        ],
                                      ),
                                      Column(
                                        children: [
                                          ElevatedButton(
                                            onPressed: (yaLlego && !yaSeFue)
                                                ? () =>
                                                      _marcarSalida(empleadoId)
                                                : null,
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.orange,
                                              foregroundColor: Colors.white,
                                              disabledBackgroundColor:
                                                  Colors.grey.shade300,
                                            ),
                                            child: const Text("Salida"),
                                          ),
                                          if (yaSeFue)
                                            Row(
                                              children: [
                                                Text(
                                                  horaSalida,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.orange,
                                                  ),
                                                ),
                                                IconButton(
                                                  icon: const Icon(
                                                    Icons.edit,
                                                    size: 16,
                                                    color: Colors.grey,
                                                  ),
                                                  onPressed: () => _editarHora(
                                                    empleadoId,
                                                    false,
                                                  ),
                                                  padding: EdgeInsets.zero,
                                                  constraints:
                                                      const BoxConstraints(),
                                                ),
                                              ],
                                            ),
                                        ],
                                      ),
                                    ],
                                  )
                                else
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 10,
                                    ),
                                    decoration: BoxDecoration(
                                      color: estado == "Falta"
                                          ? Colors.red.shade100
                                          : Colors.orange.shade100,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          estado == "Falta"
                                              ? Icons.cancel
                                              : Icons.beach_access,
                                          color: estado == "Falta"
                                              ? Colors.red
                                              : Colors.orange.shade800,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          "EMPLEADO CON ${estado.toUpperCase()}",
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: estado == "Falta"
                                                ? Colors.red.shade800
                                                : Colors.orange.shade800,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isSyncing ? null : _mostrarOpcionesCierre,
        backgroundColor: Colors.redAccent,
        foregroundColor: Colors.white,
        icon: _isSyncing
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : const Icon(Icons.picture_as_pdf),
        label: Text(
          _isSyncing ? "PROCESANDO..." : "CERRAR JORNADA",
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
