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
  int? _sectorFiltro; // null significa "Todos"
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
    setState(() {
      _isLoading = true;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      final respSect = await http.get(
        Uri.parse('$baseUrl/admin/sectores'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (respSect.statusCode == 200) _sectores = json.decode(respSect.body);

      final fechaStr = _formatearFecha(_fechaSeleccionada);
      final respAsis = await http.get(
        Uri.parse('$baseUrl/admin/asistencias/$fechaStr'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (respAsis.statusCode == 200) _asistencias = json.decode(respAsis.body);

      if (mounted) setState(() {});
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted)
        setState(() {
          _isLoading = false;
        });
    }
  }

  Future<void> _exportarExcel(List<dynamic> datos) async {
    try {
      // Formato CSV (Compatible con Excel) con BOM para acentos UTF-8
      String csv = "Legajo;Nombre;Sector;Llegada;Salida;Estado\n";
      for (var a in datos) {
        csv +=
            "${a['legajo'] ?? '-'};${a['nombre']};${a['sector']};${a['hora_llegada'] ?? '-'};${a['hora_salida'] ?? '-'};${a['estado']}\n";
      }
      final bytes = utf8.encode(csv);
      final bom = [0xEF, 0xBB, 0xBF]; // Para Excel

      final dir = await getApplicationDocumentsDirectory();
      final file = File(
        '${dir.path}/Tarja_${_formatearFecha(_fechaSeleccionada)}.csv',
      );
      await file.writeAsBytes([...bom, ...bytes]);

      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Excel generado con éxito'),
            backgroundColor: Colors.green,
          ),
        );
      OpenFile.open(file.path);
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error al exportar: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    // FILTRAMOS LOS DATOS SEGÚN EL SECTOR SELECCIONADO
    final asistenciasFiltradas = _sectorFiltro == null
        ? _asistencias
        : _asistencias.where((a) => a['sector_id'] == _sectorFiltro).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Súper Tarja Global'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.table_view),
            tooltip: "Exportar a Excel",
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
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
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

          // FILTRO DE SECTORES
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: DropdownButtonFormField<int>(
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Filtrar por Sector',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.business),
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
              onChanged: (val) => setState(() {
                _sectorFiltro = val;
              }),
            ),
          ),

          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.orange),
                  )
                : asistenciasFiltradas.isEmpty
                ? const Center(
                    child: Text(
                      "No hay registros.",
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: asistenciasFiltradas.length,
                    itemBuilder: (context, index) {
                      final asis = asistenciasFiltradas[index];
                      final esPresente = (asis['estado'] == 'Presente');
                      return Card(
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: esPresente
                                ? Colors.blue
                                : Colors.red,
                            child: Icon(
                              esPresente ? Icons.check : Icons.warning_amber,
                              color: Colors.white,
                            ),
                          ),
                          title: Text(
                            asis['nombre'],
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Legajo: ${asis['legajo'] ?? '-'} | Sector: ${asis['sector']}",
                                style: const TextStyle(
                                  color: Colors.orange,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (esPresente)
                                Text(
                                  "Llegada: ${asis['hora_llegada'] ?? '--:--'} | Salida: ${asis['hora_salida'] ?? '--:--'}",
                                )
                              else
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
        ],
      ),
    );
  }
}
