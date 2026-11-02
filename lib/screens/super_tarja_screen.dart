import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';

class SuperTarjaScreen extends StatefulWidget {
  const SuperTarjaScreen({super.key});
  @override
  State<SuperTarjaScreen> createState() => _SuperTarjaScreenState();
}

class _SuperTarjaScreenState extends State<SuperTarjaScreen> {
  DateTime _fechaSeleccionada = DateTime.now();
  List<dynamic> _asistencias = [];
  List<dynamic> _sectores = [];
  int? _sectorFiltro;
  String _busquedaDni = "";
  bool _isLoading = false;
  final String baseUrl = "https://tarja-api.onrender.com";

  @override
  void initState() {
    super.initState();
    _cargarSectoresYAsistencias();
  }

  String _formatearFecha(DateTime f) =>
      "${f.year}-${f.month.toString().padLeft(2, '0')}-${f.day.toString().padLeft(2, '0')}";
  String _formatearPantalla(DateTime f) =>
      "${f.day.toString().padLeft(2, '0')}/${f.month.toString().padLeft(2, '0')}/${f.year}";

  Future<void> _cargarSectoresYAsistencias() async {
    if (mounted) setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      final respSect = await http.get(
        Uri.parse('$baseUrl/admin/sectores'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (respSect.statusCode == 200) _sectores = json.decode(respSect.body);

      final fechaStr = _formatearFecha(_fechaSeleccionada);
      String urlAsis = '$baseUrl/admin/asistencias/$fechaStr';
      if (_sectorFiltro != null) {
        urlAsis += '?sector_id=$_sectorFiltro';
      }

      final respAsis = await http.get(
        Uri.parse(urlAsis),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (respAsis.statusCode == 200) _asistencias = json.decode(respAsis.body);

      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _mostrarFotoAuditoria(
    String fotoData,
    String nombre,
    String dni,
    String detalle,
  ) {
    try {
      final esUrl = fotoData.startsWith('http');

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(
            nombre,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "DNI: $dni | $detalle",
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: esUrl
                    ? Image.network(
                        fotoData,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Padding(
                          padding: EdgeInsets.all(20),
                          child: Text(
                            "No se pudo cargar la foto desde el servidor",
                          ),
                        ),
                      )
                    : Image.memory(
                        base64Decode(
                          fotoData.contains(',')
                              ? fotoData.split(',').last
                              : fotoData,
                        ),
                        fit: BoxFit.cover,
                      ),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Cerrar"),
            ),
          ],
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No se pudo mostrar la imagen")),
      );
    }
  }

  Future<void> _descargarPDFAdmin() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      final fechaStr = _formatearFecha(_fechaSeleccionada);

      String url = '$baseUrl/admin/reporte_pdf?fecha=$fechaStr';
      if (_sectorFiltro != null) url += '&sector_id=$_sectorFiltro';

      final response = await http.get(
        Uri.parse(url),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final dir = await getApplicationDocumentsDirectory();
        final file = File('${dir.path}/Reporte_Tarja_$fechaStr.pdf');
        await file.writeAsBytes(response.bodyBytes);
        await OpenFile.open(file.path);
      } else {
        throw Exception("No hay asistencias para ese sector/fecha");
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _exportarExcel(List<dynamic> datos) async {
    try {
      // Ordenar primero por sector y luego por nombre
      final listaOrdenada = List<dynamic>.from(datos);
      listaOrdenada.sort(
        (a, b) => (a['sector'] ?? '').toString().compareTo(
          (b['sector'] ?? '').toString(),
        ),
      );

      String csv =
          "MUNICIPALIDAD DE TARTAGAL - REPORTE DE TARJA (${_formatearPantalla(_fechaSeleccionada)})\n\n";
      String? sectorActual;

      for (var a in listaOrdenada) {
        final sec = (a['sector'] ?? 'Sin Sector').toString();
        if (sec != sectorActual) {
          if (sectorActual != null) csv += "\n";
          sectorActual = sec;
          csv += "SECTOR: ${sectorActual.toUpperCase()}\n";
          csv += "Legajo;DNI;Apellido y Nombre;Entrada;Salida Exigida (6hs);Salida Real;Horas Trabajadas;Estado\n";
        }
        csv +=
            "'${a['legajo'] ?? '-'};${a['dni'] ?? '-'};${a['nombre']};${a['hora_llegada'] ?? '-'};${a['salida_estimada'] ?? '-'};${a['hora_salida'] ?? 'Trabajando'};${a['tiempo_trabajado'] ?? '00h 00m'};${a['estado']}\n";
      }

      final bytes = utf8.encode(csv);
      final bom = [0xEF, 0xBB, 0xBF];

      final dir = await getApplicationDocumentsDirectory();
      final file = File(
        '${dir.path}/Planilla_Tarja_${_formatearFecha(_fechaSeleccionada)}.csv',
      );
      await file.writeAsBytes([...bom, ...bytes]);
      OpenFile.open(file.path);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error al exportar: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final asistenciasFiltradas = _asistencias.where((a) {
      final coincideSector =
          _sectorFiltro == null || a['sector_id'] == _sectorFiltro;
      final q = _busquedaDni.toLowerCase();
      final dniStr = (a['dni'] ?? '').toString().toLowerCase();
      final nomStr = (a['nombre'] ?? '').toString().toLowerCase();
      return coincideSector &&
          (q.isEmpty || dniStr.contains(q) || nomStr.contains(q));
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Súper Tarja y Auditoría'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _cargarSectoresYAsistencias,
          ),
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: "Descargar PDF",
            onPressed: asistenciasFiltradas.isEmpty ? null : _descargarPDFAdmin,
          ),
          IconButton(
            icon: const Icon(Icons.table_view),
            tooltip: "Exportar Excel",
            onPressed: asistenciasFiltradas.isEmpty
                ? null
                : () => _exportarExcel(asistenciasFiltradas),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            color: Colors.orange.shade50,
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Fecha: ${_formatearPantalla(_fechaSeleccionada)}",
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final sel = await showDatePicker(
                      context: context,
                      initialDate: _fechaSeleccionada,
                      firstDate: DateTime(2023),
                      lastDate: DateTime.now().add(const Duration(days: 1)),
                    );
                    if (sel != null && sel != _fechaSeleccionada) {
                      _fechaSeleccionada = sel;
                      _cargarSectoresYAsistencias();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text("Cambiar Día"),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
            child: DropdownButtonFormField<int>(
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Filtrar por Sector',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.business),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
              ),
              value: _sectorFiltro,
              items: [
                const DropdownMenuItem<int>(
                  value: null,
                  child: Text("Todos los sectores"),
                ),
                ..._sectores.map(
                  (s) => DropdownMenuItem<int>(
                    value: s['id'],
                    child: Text(s['nombre'], overflow: TextOverflow.ellipsis),
                  ),
                ),
              ],
              onChanged: (val) {
                setState(() => _sectorFiltro = val);
                _cargarSectoresYAsistencias();
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: TextField(
              decoration: const InputDecoration(
                labelText: 'Buscar por DNI o Nombre (Auditoría)',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
              ),
              onChanged: (v) => setState(() => _busquedaDni = v),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.orange),
                  )
                : RefreshIndicator(
                    onRefresh: _cargarSectoresYAsistencias,
                    color: Colors.orange,
                    child: asistenciasFiltradas.isEmpty
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: const [
                              SizedBox(height: 120),
                              Center(
                                child: Text(
                                  "No hay registros para este filtro.",
                                  style: TextStyle(color: Colors.grey),
                                ),
                              ),
                            ],
                          )
                        : ListView.builder(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.all(8),
                            itemCount: asistenciasFiltradas.length,
                            itemBuilder: (context, index) {
                              final asis = asistenciasFiltradas[index];
                              final esPresente = (asis['estado'] == 'Presente');
                              final enCurso = asis['en_curso'] == true;
                              final fotoIn = asis['foto_llegada'];
                              final fotoOut = asis['foto_salida'];

                              return Card(
                                elevation: 2,
                                margin: const EdgeInsets.symmetric(
                                  vertical: 6,
                                  horizontal: 4,
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(12.0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          CircleAvatar(
                                            backgroundColor: !esPresente
                                                ? Colors.red
                                                : (enCurso
                                                      ? Colors.blue
                                                      : Colors.green),
                                            child: Icon(
                                              !esPresente
                                                  ? Icons.warning_amber
                                                  : (enCurso
                                                        ? Icons.timer
                                                        : Icons.check_circle),
                                              color: Colors.white,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  asis['nombre'],
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 16,
                                                  ),
                                                ),
                                                Text(
                                                  "DNI: ${asis['dni'] ?? '-'} | Leg: ${asis['legajo'] ?? '-'} | ${asis['sector']}",
                                                  style: const TextStyle(
                                                    color: Colors.orange,
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      if (esPresente) ...[
                                        Text(
                                          "Entrada: ${asis['hora_llegada'] ?? '--:--'} | Salida real: ${asis['hora_salida'] ?? 'Trabajando...'}",
                                        ),
                                        Text(
                                          "Salida p/ cumplir 6hs: ${asis['salida_estimada'] ?? '--:--'} hs",
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.blueGrey,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 5,
                                          ),
                                          decoration: BoxDecoration(
                                            color: enCurso
                                                ? Colors.blue.shade50
                                                : Colors.green.shade50,
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                            border: Border.all(
                                              color: enCurso
                                                  ? Colors.blue.shade200
                                                  : Colors.green.shade300,
                                            ),
                                          ),
                                          child: Text(
                                            enCurso
                                                ? "⏱️ En curso: ${asis['tiempo_trabajado']} realizados"
                                                : "✅ Jornada finalizada: ${asis['tiempo_trabajado']}",
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: enCurso
                                                  ? Colors.blue.shade900
                                                  : Colors.green.shade900,
                                            ),
                                          ),
                                        ),
                                        if (fotoIn != null ||
                                            fotoOut != null) ...[
                                          const SizedBox(height: 8),
                                          Row(
                                            children: [
                                              if (fotoIn != null)
                                                OutlinedButton.icon(
                                                  onPressed: () =>
                                                      _mostrarFotoAuditoria(
                                                        fotoIn,
                                                        asis['nombre'],
                                                        asis['dni'] ?? '-',
                                                        "Entrada: ${asis['hora_llegada']}",
                                                      ),
                                                  icon: const Icon(
                                                    Icons.camera_alt,
                                                    size: 16,
                                                    color: Colors.green,
                                                  ),
                                                  label: const Text(
                                                    "Foto Entrada",
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ),
                                              const SizedBox(width: 8),
                                              if (fotoOut != null)
                                                OutlinedButton.icon(
                                                  onPressed: () =>
                                                      _mostrarFotoAuditoria(
                                                        fotoOut,
                                                        asis['nombre'],
                                                        asis['dni'] ?? '-',
                                                        "Salida: ${asis['hora_salida']}",
                                                      ),
                                                  icon: const Icon(
                                                    Icons.camera_alt,
                                                    size: 16,
                                                    color: Colors.orange,
                                                  ),
                                                  label: const Text(
                                                    "Foto Salida",
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ],
                                      ] else
                                        Text(
                                          "Estado: ${asis['estado']}",
                                          style: const TextStyle(
                                            color: Colors.redAccent,
                                            fontWeight: FontWeight.bold,
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
    );
  }
}
