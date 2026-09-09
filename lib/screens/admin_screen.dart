import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'sectores_admin_screen.dart';
import 'empleados_admin_screen.dart';
import 'encargados_admin_screen.dart';
import 'super_tarja_screen.dart';
import 'dashboard_screen.dart'; // <-- Importamos la nueva pantalla

class AdminScreen extends StatelessWidget {
  const AdminScreen({super.key});

  Future<void> _cerrarSesion(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    if (context.mounted) Navigator.of(context).pushReplacementNamed('/');
  }

  Widget _crearBotonAccion(
    BuildContext context,
    String titulo,
    IconData icono,
    Color color,
    VoidCallback onTap,
  ) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icono, size: 40, color: color),
              const SizedBox(height: 10),
              Text(
                titulo,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Panel de Administración'),
        backgroundColor: Colors.blueGrey.shade900,
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
        child: GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 16.0,
          mainAxisSpacing: 16.0,
          children: [
            _crearBotonAccion(
              context,
              "Sectores",
              Icons.business,
              Colors.purple,
              () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SectoresAdminScreen(),
                ),
              ),
            ),
            _crearBotonAccion(
              context,
              "Empleados",
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
              "Encargados",
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
              "Súper Tarja",
              Icons.table_view,
              Colors.orange,
              () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SuperTarjaScreen(),
                ),
              ),
            ),
            // EL NUEVO BOTÓN
            _crearBotonAccion(
              context,
              "Estadísticas",
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
    );
  }
}
