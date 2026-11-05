import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class EmpleadosAdminScreen extends StatefulWidget {
  const EmpleadosAdminScreen({super.key});

  @override
  State<EmpleadosAdminScreen> createState() => _EmpleadosAdminScreenState();
}

class _EmpleadosAdminScreenState extends State<EmpleadosAdminScreen> {
  List<dynamic> _empleados = [];
  List<dynamic> _sectores = [];
  List<dynamic> _secretarias = [];
  List<dynamic> _funciones = [];
  bool _isLoading = false;
  String _busqueda = "";
  final String baseUrl = "https://tarja-api.onrender.com";

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  String _soloNumeros(String val) => val.replaceAll(RegExp(r'[^0-9]'), '');

  Future<void> _cargarDatos() async {
    if (mounted) setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      final headers = {'Authorization': 'Bearer $token'};

      final resultados = await Future.wait([
        http.get(Uri.parse('$baseUrl/admin/empleados'), headers: headers),
        http.get(Uri.parse('$baseUrl/admin/sectores'), headers: headers),
        http.get(Uri.parse('$baseUrl/admin/secretarias'), headers: headers),
        http.get(Uri.parse('$baseUrl/admin/funciones'), headers: headers),
      ]);

      if (resultados[0].statusCode == 200 && mounted) {
        setState(() {
          _empleados = json.decode(resultados[0].body);
          if (resultados[1].statusCode == 200)
            _sectores = json.decode(resultados[1].body);
          if (resultados[2].statusCode == 200)
            _secretarias = json.decode(resultados[2].body);
          if (resultados[3].statusCode == 200)
            _funciones = json.decode(resultados[3].body);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _guardarEmpleado(
    String nombre,
    String dni,
    String legajo,
    int sectorId,
    String secretaria,
    String funcion, {
    int? idEdicion,
  }) async {
    Navigator.pop(context);
    if (mounted) setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      final datosJson = json.encode({
        "nombre_completo": nombre.toUpperCase(),
        "dni": _soloNumeros(dni),
        "legajo": _soloNumeros(legajo),
        "sector_id": sectorId,
        "secretaria": secretaria,
        "funcion": funcion,
      });

      final url = idEdicion == null
          ? '$baseUrl/admin/empleados'
          : '$baseUrl/admin/empleados/$idEdicion';

      final response = idEdicion == null
          ? await http.post(
              Uri.parse(url),
              headers: {
                'Authorization': 'Bearer $token',
                'Content-Type': 'application/json',
              },
              body: datosJson,
            )
          : await http.put(
              Uri.parse(url),
              headers: {
                'Authorization': 'Bearer $token',
                'Content-Type': 'application/json',
              },
              body: datosJson,
            );

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                idEdicion == null
                    ? 'Agente registrado con éxito'
                    : 'Agente actualizado',
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
        await _cargarDatos();
      } else {
        final error = json.decode(response.body);
        throw Exception(error['detail'] ?? "Error al guardar");
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

  void _mostrarDialogoEmpleado({Map<String, dynamic>? empleadoExistente}) {
    final esEdicion = empleadoExistente != null;
    final nombreController = TextEditingController(
      text: esEdicion ? empleadoExistente['nombre_completo'] : '',
    );
    final dniController = TextEditingController(
      text: esEdicion
          ? _soloNumeros((empleadoExistente['dni'] ?? '').toString())
          : '',
    );
    final legajoController = TextEditingController(
      text: esEdicion
          ? _soloNumeros((empleadoExistente['legajo'] ?? '').toString())
          : '',
    );
    int? sectorSeleccionado = esEdicion ? empleadoExistente['sector_id'] : null;

    final listaNombresSec = _secretarias
        .map<String>((s) => s['nombre'].toString())
        .toList();
    if (!listaNombresSec.contains("GOBIERNO")) listaNombresSec.add("GOBIERNO");
    String secretariaSel = esEdicion
        ? (empleadoExistente['secretaria'] ?? 'GOBIERNO').toString()
        : listaNombresSec.first;
    if (!listaNombresSec.contains(secretariaSel))
      listaNombresSec.add(secretariaSel);

    final listaNombresFun = _funciones
        .map<String>((f) => f['nombre'].toString())
        .toList();
    if (!listaNombresFun.contains("ADMINISTRATIVA"))
      listaNombresFun.add("ADMINISTRATIVA");
    String funcionSel = esEdicion
        ? (empleadoExistente['funcion'] ?? 'ADMINISTRATIVA').toString()
        : listaNombresFun.first;
    if (!listaNombresFun.contains(funcionSel)) listaNombresFun.add(funcionSel);

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: Text(esEdicion ? 'Editar Agente' : 'Nuevo Agente'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nombreController,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(
                        labelText: 'Apellido y Nombre',
                      ),
                    ),
                    TextField(
                      controller: dniController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'DNI (Sin puntos)',
                      ),
                    ),
                    TextField(
                      controller: legajoController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'CUIL (Solo números, sin guiones)',
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Secretaría',
                      ),
                      value: secretariaSel,
                      items: listaNombresSec.map((s) {
                        return DropdownMenuItem(
                          value: s,
                          child: Text(s, overflow: TextOverflow.ellipsis),
                        );
                      }).toList(),
                      onChanged: (v) {
                        if (v != null) setStateDialog(() => secretariaSel = v);
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Sector'),
                      value: sectorSeleccionado,
                      items: _sectores.map<DropdownMenuItem<int>>((sector) {
                        return DropdownMenuItem<int>(
                          value: sector['id'],
                          child: Text(
                            sector['nombre'],
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (valor) =>
                          setStateDialog(() => sectorSeleccionado = valor),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Función'),
                      value: funcionSel,
                      items: listaNombresFun.map((f) {
                        return DropdownMenuItem(
                          value: f,
                          child: Text(f, overflow: TextOverflow.ellipsis),
                        );
                      }).toList(),
                      onChanged: (v) {
                        if (v != null) setStateDialog(() => funcionSel = v);
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'Cancelar',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (nombreController.text.isNotEmpty &&
                        dniController.text.isNotEmpty &&
                        legajoController.text.isNotEmpty &&
                        sectorSeleccionado != null) {
                      _guardarEmpleado(
                        nombreController.text.trim(),
                        dniController.text.trim(),
                        legajoController.text.trim(),
                        sectorSeleccionado!,
                        secretariaSel,
                        funcionSel,
                        idEdicion: esEdicion ? empleadoExistente['id'] : null,
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                  child: Text(esEdicion ? 'Actualizar' : 'Guardar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final empleadosFiltrados = _empleados.where((emp) {
      final query = _busqueda.toLowerCase();
      final nombre = (emp['nombre_completo'] ?? '').toString().toLowerCase();
      final legajo = (emp['legajo'] ?? '').toString().toLowerCase();
      final dni = (emp['dni'] ?? '').toString().toLowerCase();
      return nombre.contains(query) ||
          legajo.contains(query) ||
          dni.contains(query);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Padrón de Empleados'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              decoration: InputDecoration(
                labelText: 'Buscar por DNI, Apellido o CUIL',
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
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _cargarDatos,
                    color: Colors.green,
                    child: empleadosFiltrados.isEmpty
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: const [
                              SizedBox(height: 150),
                              Center(
                                child: Text("No se encontraron empleados"),
                              ),
                            ],
                          )
                        : ListView.builder(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.all(8),
                            itemCount: empleadosFiltrados.length,
                            itemBuilder: (context, index) {
                              final emp = empleadosFiltrados[index];
                              final cuilLimpio = _soloNumeros(
                                (emp['legajo'] ?? '').toString(),
                              );
                              return Card(
                                child: ListTile(
                                  leading: const CircleAvatar(
                                    backgroundColor: Colors.green,
                                    child: Icon(
                                      Icons.person,
                                      color: Colors.white,
                                    ),
                                  ),
                                  title: Text(
                                    emp['nombre_completo'],
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  subtitle: Text(
                                    "DNI: ${emp['dni'] ?? 'Falta DNI'} | CUIL: $cuilLimpio\n${emp['secretaria'] ?? 'GOBIERNO'} • ${emp['sector_nombre']} (${emp['funcion'] ?? 'ADMINISTRATIVA'})",
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  isThreeLine: true,
                                  trailing: IconButton(
                                    icon: const Icon(
                                      Icons.edit,
                                      color: Colors.blue,
                                    ),
                                    onPressed: () => _mostrarDialogoEmpleado(
                                      empleadoExistente: emp,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _sectores.isEmpty
            ? () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Debe crear un sector primero')),
              )
            : () => _mostrarDialogoEmpleado(),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }
}
