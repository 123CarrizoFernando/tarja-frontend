import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'sectores_admin_screen.dart';
import 'empleados_admin_screen.dart';
import 'encargados_admin_screen.dart';
import 'super_tarja_screen.dart';
import 'dashboard_screen.dart'; // <-- Importamos el Dashboard

class AdminScreen extends StatelessWidget {
  const AdminScreen({super.key});

  Future<void> _cerrarSesion(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    if (context.mounted) Navigator.of(context).pushReplacementNamed('/');
  }

  // Widget para crear las tarjetas horizontales tal como las tenías
  Widget _crearBotonAccion(
    BuildContext context,
    String titulo,
    IconData icono,
    Color color,
    VoidCallback onTap,
  ) {
    return Card(
      elevation: 1, // Sombra suave
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Colors.grey.shade50, // Fondo apenitas gris/blanco
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: color,
          radius: 22,
          child: Icon(icono, color: Colors.white, size: 24),
        ),
        title: Text(
          titulo,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
        onTap: onTap,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Panel de Administración'),
        backgroundColor: Colors.deepPurple, // El color violeta original
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout), // Ícono de salida en la esquina
            tooltip: "Cerrar Sesión",
            onPressed: () => _cerrarSesion(context),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // El saludo inicial
            const Text(
              "Bienvenido, Administrador",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 20),

            // La lista de botones
            Expanded(
              child: ListView(
                children: [
                  _crearBotonAccion(
                    context,
                    "Gestionar Sectores",
                    Icons.business,
                    Colors.blue, // Azul como en la foto
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const SectoresAdminScreen(),
                      ),
                    ),
                  ),
                  _crearBotonAccion(
                    context,
                    "Gestionar Empleados",
                    Icons.people,
                    Colors.green, // Verde como en la foto
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const EmpleadosAdminScreen(),
                      ),
                    ),
                  ),
                  _crearBotonAccion(
                    context,
                    "Cuentas de Usuarios\n(Encargados)",
                    Icons.manage_accounts,
                    Colors.indigo, // Azul oscuro como en la foto
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const EncargadosAdminScreen(),
                      ),
                    ),
                  ),
                  _crearBotonAccion(
                    context,
                    "Súper Tarja (Todos los\nsectores)",
                    Icons.table_view,
                    Colors.orange, // Naranja como en la foto
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const SuperTarjaScreen(),
                      ),
                    ),
                  ),

                  // ¡EL NUEVO BOTÓN DEL DASHBOARD AL FINAL!
                  _crearBotonAccion(
                    context,
                    "Dashboard (Estadísticas)",
                    Icons.pie_chart,
                    Colors.teal, // Le ponemos color verde azulado
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const DashboardScreen(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
