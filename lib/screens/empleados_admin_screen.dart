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
  bool _isLoading = false;
  String _busqueda = ""; // <-- NUEVO: Variable para el buscador
  final String baseUrl = "https://tarja-api.onrender.com";

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    // ARREGLO: Siempre verificamos si está montado antes de actualizar la pantalla
    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      final respEmpleados = await http.get(
        Uri.parse('$baseUrl/admin/empleados'),
        headers: {'Authorization': 'Bearer $token'},
      );

      final respSectores = await http.get(
        Uri.parse('$baseUrl/admin/sectores'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (respEmpleados.statusCode == 200 && respSectores.statusCode == 200) {
        if (mounted) {
          setState(() {
            _empleados = json.decode(respEmpleados.body);
            _sectores = json.decode(respSectores.body);
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // ¡FUNCIÓN UNIFICADA! Sirve para CREAR o para EDITAR dependiendo si le pasamos el ID
  Future<void> _guardarEmpleado(
    String nombre,
    String dni,
    String legajo,
    int sectorId, {
    int? idEdicion,
  }) async {
    Navigator.pop(context);

    // ARREGLO: Check de mounted
    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      final datosJson = json.encode({
        "nombre_completo": nombre,
        "dni": dni,
        "legajo": legajo,
        "sector_id": sectorId,
      });

      http.Response response;

      if (idEdicion == null) {
        // CREAR NUEVO
        response = await http.post(
          Uri.parse('$baseUrl/admin/empleados'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: datosJson,
        );
      } else {
        // EDITAR EXISTENTE
        response = await http.put(
          Uri.parse('$baseUrl/admin/empleados/$idEdicion'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: datosJson,
        );
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                idEdicion == null
                    ? 'Empleado creado con éxito'
                    : 'Empleado actualizado',
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
        await _cargarDatos();
      } else {
        try {
          final error = json.decode(response.body);
          throw Exception(error['detail'] ?? "Error al guardar");
        } catch (_) {
          throw Exception("Error del servidor (${response.statusCode}).");
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      // ARREGLO: Check de mounted
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // ¡POPUP INTELIGENTE! Si le pasas un empleado, rellena los campos.
  void _mostrarDialogoEmpleado({Map<String, dynamic>? empleadoExistente}) {
    final esEdicion = empleadoExistente != null;
    final nombreController = TextEditingController(
      text: esEdicion ? empleadoExistente['nombre_completo'] : '',
    );
    final dniController = TextEditingController(
      text: esEdicion ? empleadoExistente['dni'].toString() : '',
    );
    final legajoController = TextEditingController(
      text: esEdicion ? empleadoExistente['legajo'].toString() : '',
    );
    int? sectorSeleccionado = esEdicion ? empleadoExistente['sector_id'] : null;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: Text(esEdicion ? 'Editar Empleado' : 'Nuevo Empleado'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nombreController,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Nombre y Apellido',
                      ),
                    ),
                    TextField(
                      controller: dniController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'DNI'),
                    ),
                    TextField(
                      controller: legajoController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Legajo'),
                    ),
                    const SizedBox(height: 15),
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
                      onChanged: (valor) {
                        setStateDialog(() {
                          sectorSeleccionado = valor;
                        });
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
    // NUEVO: Filtramos la lista según lo que el usuario haya escrito en el buscador
    final empleadosFiltrados = _empleados.where((emp) {
      final query = _busqueda.toLowerCase();
      final nombre = emp['nombre_completo'].toString().toLowerCase();
      final legajo = emp['legajo'].toString().toLowerCase();
      return nombre.contains(query) || legajo.contains(query);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestión de Empleados'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // NUEVO: La Barra de Búsqueda
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
              onChanged: (valor) {
                setState(() {
                  _busqueda = valor;
                });
              },
            ),
          ),
          // Lista de Empleados Filtrada
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : empleadosFiltrados.isEmpty
                ? const Center(child: Text("No se encontraron empleados"))
                : ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: empleadosFiltrados.length,
                    itemBuilder: (context, index) {
                      final emp = empleadosFiltrados[index];
                      return Card(
                        child: ListTile(
                          leading: const CircleAvatar(
                            backgroundColor: Colors.green,
                            child: Icon(Icons.person, color: Colors.white),
                          ),
                          title: Text(
                            emp['nombre_completo'],
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            "Legajo: ${emp['legajo']} - Sector: ${emp['sector_nombre']}",
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.edit, color: Colors.blue),
                            onPressed: () =>
                                _mostrarDialogoEmpleado(empleadoExistente: emp),
                          ),
                        ),
                      );
                    },
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
