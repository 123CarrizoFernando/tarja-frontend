import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'sectores_admin_screen.dart';
import 'empleados_admin_screen.dart';
import 'encargados_admin_screen.dart';
import 'super_tarja_screen.dart';
import 'dashboard_screen.dart';

class AdminScreen extends StatelessWidget {
  const AdminScreen({super.key});

  Future<void> _cerrarSesion(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    if (context.mounted) Navigator.of(context).pushReplacementNamed('/');
  }

  // --- BOTONES MÁS GRANDES Y ESPACIOSOS ---
  Widget _crearBotonAccion(
    BuildContext context,
    String titulo,
    IconData icono,
    Color color,
    VoidCallback onTap,
  ) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16), // Más separación entre botones
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Colors.grey.shade50,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: 12,
          ), // Más altura a la tarjeta
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 4,
            ),
            leading: CircleAvatar(
              backgroundColor: color,
              radius: 28, // Círculo de color más grande
              child: Icon(
                icono,
                color: Colors.white,
                size: 30,
              ), // Ícono más grande
            ),
            title: Text(
              titulo,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 17,
              ), // Letra más grande
            ),
            trailing: const Icon(
              Icons.chevron_right,
              color: Colors.grey,
              size: 28,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Panel de Administración'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
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
            const Text(
              "Bienvenido, Administrador",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: ListView(
                children: [
                  _crearBotonAccion(
                    context,
                    "Gestionar Sectores",
                    Icons.business,
                    Colors.blue,
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
                    Colors.green,
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
                    Colors.indigo,
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
                    Colors.orange,
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const SuperTarjaScreen(),
                      ),
                    ),
                  ),
                  _crearBotonAccion(
                    context,
                    "Dashboard (Estadísticas)",
                    Icons.pie_chart,
                    Colors.teal,
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
