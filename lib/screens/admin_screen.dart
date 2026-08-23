import 'empleados_admin_screen.dart';
import 'super_tarja_screen.dart';
import 'encargados_admin_screen.dart';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'sectores_admin_screen.dart';

class AdminScreen extends StatelessWidget {
  const AdminScreen({super.key});

  Future<void> _cerrarSesion(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    await prefs.remove('rol');
    if (context.mounted) Navigator.of(context).pushReplacementNamed('/');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Panel de Administración'),
        backgroundColor:
            Colors.deepPurple, // Color distinto para que sepa que es Admin
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: "Cerrar Sesión",
            onPressed: () => _cerrarSesion(context),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          const Text(
            "Bienvenido, Administrador",
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          // BOTÓN 1: SECTORES (Ya conectado)
          _crearBotonAccion(
            context,
            "Gestionar Sectores",
            Icons.business,
            Colors.blue,
            () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SectoresAdminScreen(),
                ),
              );
            },
          ),
          // BOTÓN 2: EMPLEADOS
          _crearBotonAccion(
            context,
            "Gestionar Empleados",
            Icons.people,
            Colors.green,
            () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const EmpleadosAdminScreen(),
                ),
              );
            },
          ),
          // BOTÓN: ENCARGADOS (Usuarios)
          _crearBotonAccion(
            context,
            "Cuentas de Usuarios (Encargados)",
            Icons.manage_accounts,
            Colors.indigo,
            () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const EncargadosAdminScreen(),
                ),
              );
            },
          ),

          // BOTÓN 3: SÚPER TARJA (Pendiente)
          _crearBotonAccion(
            context,
            "Súper Tarja (Todos los sectores)",
            Icons.table_chart,
            Colors.orange,
            () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SuperTarjaScreen(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // --- FUNCIÓN CORREGIDA PARA ACEPTAR LA ACCIÓN PERSONALIZADA ---
  Widget _crearBotonAccion(
    BuildContext context,
    String titulo,
    IconData icono,
    Color color,
    VoidCallback onTapAccion, // <- ¡El nuevo parámetro!
  ) {
    return Card(
      elevation: 3,
      margin: const EdgeInsets.only(bottom: 16),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          vertical: 10,
          horizontal: 16,
        ),
        leading: CircleAvatar(
          backgroundColor: color,
          radius: 25,
          child: Icon(icono, color: Colors.white, size: 28),
        ),
        title: Text(
          titulo,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        trailing: const Icon(Icons.arrow_forward_ios, color: Colors.grey),
        onTap: onTapAccion, // <- Ejecuta la función que le pasamos arriba
      ),
    );
  }
}
