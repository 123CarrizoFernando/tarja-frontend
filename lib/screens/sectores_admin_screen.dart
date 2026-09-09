import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class SectoresAdminScreen extends StatefulWidget {
  const SectoresAdminScreen({super.key});

  @override
  State<SectoresAdminScreen> createState() => _SectoresAdminScreenState();
}

class _SectoresAdminScreenState extends State<SectoresAdminScreen> {
  List<dynamic> _sectores = [];
  bool _isLoading = false;
  final String baseUrl = "https://tarja-api.onrender.com";

  @override
  void initState() {
    super.initState();
    _cargarSectores();
  }

  Future<void> _cargarSectores() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      final response = await http.get(
        Uri.parse('$baseUrl/admin/sectores'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        setState(() {
          _sectores = json.decode(response.body);
        });
      } else {
        throw Exception("Error al cargar sectores");
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _crearSector(String nombre) async {
    Navigator.pop(context); // Cierra el modal
    setState(() {
      _isLoading = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      final response = await http.post(
        Uri.parse('$baseUrl/admin/sectores'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({"nombre": nombre}),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Sector creado con éxito'),
              backgroundColor: Colors.green,
            ),
          );
        }
        await _cargarSectores(); // Recarga la lista
      } else {
        final error = json.decode(response.body);
        throw Exception(error['detail'] ?? "Error al crear sector");
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _mostrarDialogoNuevoSector() {
    final TextEditingController nombreController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Nuevo Sector'),
          content: TextField(
            controller: nombreController,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Nombre del sector',
              hintText: 'Ej: Obras Públicas',
              prefixIcon: Icon(Icons.business),
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
                final nombre = nombreController.text.trim();
                if (nombre.isNotEmpty) {
                  _crearSector(nombre);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                foregroundColor: Colors.white,
              ),
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestión de Sectores'),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
      ),
      body: _isLoading && _sectores.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : _sectores.isEmpty
          ? const Center(
              child: Text(
                "No hay sectores registrados",
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            )
          // ... (acá arriba seguro tenés el body: _isLoading ? const Center(...) )
          : RefreshIndicator(
              onRefresh: _cargarSectores, // Llama a tu función para refrescar
              color: Colors.blueAccent, // Combina con tu botón azul
              child: _sectores.isEmpty
                  // Si no hay sectores, mostramos un cartel pero que se pueda deslizar
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: const [
                        SizedBox(height: 150),
                        Center(child: Text("No hay sectores registrados")),
                      ],
                    )
                  // Si hay sectores, mostramos tu lista normal
                  : ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(), // ¡LA LÍNEA MÁGICA!
                      padding: const EdgeInsets.all(12),
                      itemCount: _sectores.length,
                      itemBuilder: (context, index) {
                        final sector = _sectores[index];
                        return Card(
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.blue.shade100,
                              child: Text(
                                sector['id'].toString(),
                                style: const TextStyle(
                                  color: Colors.blue,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            title: Text(
                              sector['nombre'],
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                            subtitle: Text("ID del Sistema: ${sector['id']}"),
                          ),
                        );
                      },
                    ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _mostrarDialogoNuevoSector,
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text(
          "NUEVO SECTOR",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
