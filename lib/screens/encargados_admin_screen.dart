import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class EncargadosAdminScreen extends StatefulWidget {
  const EncargadosAdminScreen({super.key});

  @override
  State<EncargadosAdminScreen> createState() => _EncargadosAdminScreenState();
}

class _EncargadosAdminScreenState extends State<EncargadosAdminScreen> {
  List<dynamic> _encargados = [];
  List<dynamic> _sectores = [];
  bool _isLoading = false;
  final String baseUrl = "https://tarja-api.onrender.com";

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      final respEncargados = await http.get(
        Uri.parse('$baseUrl/admin/encargados'),
        headers: {'Authorization': 'Bearer $token'},
      );

      final respSectores = await http.get(
        Uri.parse('$baseUrl/admin/sectores'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (respEncargados.statusCode == 200 && respSectores.statusCode == 200) {
        setState(() {
          _encargados = json.decode(respEncargados.body);
          _sectores = json.decode(respSectores.body);
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

  Future<void> _crearEncargado(
    String usuario,
    String password,
    String rol,
    int? sectorId,
  ) async {
    Navigator.pop(context);
    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      final response = await http.post(
        Uri.parse('$baseUrl/admin/encargados'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          "usuario": usuario,
          "password": password,
          "rol": rol,
          "sector_id": rol == "encargado" ? sectorId : null,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Usuario creado con éxito'),
              backgroundColor: Colors.green,
            ),
          );
        }
        await _cargarDatos();
      } else {
        final error = json.decode(response.body);
        throw Exception(error['detail'] ?? "Error al crear usuario");
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

  void _mostrarDialogoNuevoEncargado() {
    final usuarioController = TextEditingController();
    final passwordController = TextEditingController();
    String rolSeleccionado = "encargado";
    int? sectorSeleccionado;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Crear Cuenta de Usuario'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: usuarioController,
                      decoration: const InputDecoration(
                        labelText: 'Nombre de usuario (Login)',
                      ),
                    ),
                    TextField(
                      controller: passwordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Contraseña',
                      ),
                    ),
                    const SizedBox(height: 15),
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Tipo de Cuenta',
                      ),
                      value: rolSeleccionado,
                      items: const [
                        DropdownMenuItem(
                          value: "encargado",
                          child: Text("Encargado de Sector"),
                        ),
                        DropdownMenuItem(
                          value: "admin",
                          child: Text("ADMINISTRADOR"),
                        ),
                      ],
                      onChanged: (valor) {
                        if (valor != null) {
                          setStateDialog(() => rolSeleccionado = valor);
                        }
                      },
                    ),
                    if (rolSeleccionado == "encargado") ...[
                      const SizedBox(height: 15),
                      DropdownButtonFormField<int>(
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Sector a cargo',
                        ),
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
                          setStateDialog(() => sectorSeleccionado = valor);
                        },
                      ),
                    ],
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
                    final userOk = usuarioController.text.trim().isNotEmpty;
                    final passOk = passwordController.text.trim().isNotEmpty;
                    final sectorOk =
                        rolSeleccionado != "encargado" ||
                        sectorSeleccionado != null;

                    if (userOk && passOk && sectorOk) {
                      _crearEncargado(
                        usuarioController.text.trim(),
                        passwordController.text.trim(),
                        rolSeleccionado,
                        sectorSeleccionado,
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Crear Cuenta'),
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestión de Usuarios'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.deepPurple),
            )
          : RefreshIndicator(
              onRefresh: _cargarDatos,
              color: Colors.deepPurple,
              child: _encargados.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: const [
                        SizedBox(height: 150),
                        Center(child: Text("No hay usuarios registrados")),
                      ],
                    )
                  : ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(8),
                      itemCount: _encargados.length,
                      itemBuilder: (context, index) {
                        final enc = _encargados[index];
                        final esAdmin =
                            enc['rol'] == 'admin' || enc['rol'] == 'rrhh';

                        return Card(
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: esAdmin
                                  ? Colors.redAccent
                                  : Colors.deepPurple,
                              child: Icon(
                                esAdmin
                                    ? Icons.admin_panel_settings
                                    : Icons.badge,
                                color: Colors.white,
                              ),
                            ),
                            title: Text(
                              enc['usuario'],
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(
                              esAdmin
                                  ? "ADMINISTRADOR (Todos los sectores)"
                                  : "Sector: ${enc['sector_nombre']}",
                            ),
                            trailing: Text(
                              esAdmin ? "ADMIN" : "ENCARGADO",
                              style: TextStyle(
                                color: esAdmin ? Colors.red : Colors.grey,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _mostrarDialogoNuevoEncargado,
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add),
        label: const Text("NUEVO USUARIO"),
      ),
    );
  }
}
