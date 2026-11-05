import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'sectores_admin_screen.dart';
import 'empleados_admin_screen.dart';
import 'encargados_admin_screen.dart';
import 'super_tarja_screen.dart';
import 'dashboard_screen.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  String _rol = "reportes";
  String _nombreOperador = "Operador";

  @override
  void initState() {
    super.initState();
    _cargarPerfil();
  }

  Future<void> _cargarPerfil() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _rol = prefs.getString('rol') ?? 'reportes';
        _nombreOperador = prefs.getString('nombre_operador') ?? 'Administrador';
      });
    }
  }

  Future<void> _cerrarSesion(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    await prefs.remove('rol');
    await prefs.remove('nombre_operador');
    if (context.mounted) Navigator.of(context).pushReplacementNamed('/');
  }

  String _etiquetaRol() {
    if (_rol == 'admin') return "ADMINISTRADOR TOTAL";
    if (_rol == 'carga' || _rol == 'rrhh') return "CARGA DE PADRÓN Y REPORTES";
    return "SOLO REPORTES (PDF / EXCEL)";
  }

  Widget _crearBotonAccion(
    BuildContext context,
    String titulo,
    String subtitulo,
    IconData icono,
    Color color,
    VoidCallback onTap,
  ) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Colors.grey.shade50,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 2,
            ),
            leading: CircleAvatar(
              backgroundColor: color,
              radius: 26,
              child: Icon(icono, color: Colors.white, size: 28),
            ),
            title: Text(
              titulo,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            subtitle: Text(
              subtitulo,
              style: const TextStyle(fontSize: 12, color: Colors.black54),
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
    final esAdminTotal = (_rol == 'admin');
    final puedeCargar = (_rol == 'admin' || _rol == 'carga' || _rol == 'rrhh');

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Panel de Gestión Municipal'),
        backgroundColor: Colors.green.shade700,
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
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Operador: $_nombreOperador",
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    "Nivel de Permiso: ${_etiquetaRol()}",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade800,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView(
                children: [
                  // 1. VISIBLE PARA TODOS LOS NIVELES (ADMIN, CARGA Y REPORTES)
                  _crearBotonAccion(
                    context,
                    "Súper Tarja y Reportes",
                    "Asistencias en vivo, Fotos, PDF por sector y 2 Excel",
                    Icons.table_view,
                    Colors.orange,
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const SuperTarjaScreen(),
                      ),
                    ),
                  ),
                  _crearBotonAccion(
                    context,
                    "Dashboard (Estadísticas)",
                    "Resumen diario de presentes, faltas y licencias",
                    Icons.pie_chart,
                    Colors.teal,
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const DashboardScreen(),
                      ),
                    ),
                  ),

                  // 2. VISIBLE SOLO PARA ADMIN TOTAL Y OPERADORES DE CARGA
                  if (puedeCargar) ...[
                    _crearBotonAccion(
                      context,
                      "Padrón de Empleados",
                      "Cargar o editar DNI, CUIL, Secretaría, Sector y Función",
                      Icons.people,
                      Colors.green,
                      () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const EmpleadosAdminScreen(),
                        ),
                      ),
                    ),
                    _crearBotonAccion(
                      context,
                      "Gestionar Sectores",
                      "Crear o ver áreas y cuadrillas municipales",
                      Icons.business,
                      Colors.blue,
                      () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const SectoresAdminScreen(),
                        ),
                      ),
                    ),
                    _crearBotonAccion(
                      context,
                      "Secretarías y Funciones",
                      "Agregar manualmente Secretarías y Funciones al catálogo",
                      Icons.account_balance,
                      Colors.cyan.shade700,
                      () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const CatalogosAdminScreen(),
                        ),
                      ),
                    ),
                  ],

                  // 3. VISIBLE EXCLUSIVAMENTE PARA EL ADMINISTRADOR TOTAL
                  if (esAdminTotal) ...[
                    _crearBotonAccion(
                      context,
                      "Cuentas de Usuarios y Roles",
                      "Crear usuarios de Reportes, Carga, Admin o Encargados",
                      Icons.manage_accounts,
                      Colors.indigo,
                      () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const EncargadosAdminScreen(),
                        ),
                      ),
                    ),
                    _crearBotonAccion(
                      context,
                      "Auditoría del Sistema",
                      "Ver registro histórico de quién realizó cada cambio",
                      Icons.policy,
                      Colors.blueGrey.shade800,
                      () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AuditoriaAdminScreen(),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =========================================================================
// PANTALLA PARA AGREGAR SECRETARÍAS Y FUNCIONES MANUALMENTE DESDE LA APP
// =========================================================================
class CatalogosAdminScreen extends StatefulWidget {
  const CatalogosAdminScreen({super.key});

  @override
  State<CatalogosAdminScreen> createState() => _CatalogosAdminScreenState();
}

class _CatalogosAdminScreenState extends State<CatalogosAdminScreen> {
  List<dynamic> _secretarias = [];
  List<dynamic> _funciones = [];
  bool _isLoading = false;
  final String baseUrl = "https://tarja-api.onrender.com";

  @override
  void initState() {
    super.initState();
    _cargarCatalogos();
  }

  Future<void> _cargarCatalogos() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      final headers = {'Authorization': 'Bearer $token'};

      final resSec = await http.get(
        Uri.parse('$baseUrl/admin/secretarias'),
        headers: headers,
      );
      final resFun = await http.get(
        Uri.parse('$baseUrl/admin/funciones'),
        headers: headers,
      );

      if (resSec.statusCode == 200 && resFun.statusCode == 200 && mounted) {
        setState(() {
          _secretarias = json.decode(resSec.body);
          _funciones = json.decode(resFun.body);
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _agregarItem(String endpoint, String nombre) async {
    if (nombre.trim().isEmpty) return;
    Navigator.pop(context);
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      final res = await http.post(
        Uri.parse('$baseUrl/admin/$endpoint'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({"nombre": nombre.trim().toUpperCase()}),
      );
      if (res.statusCode == 200) {
        await _cargarCatalogos();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Agregado correctamente"),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _mostrarDialogoNuevo(String titulo, String endpoint) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(titulo),
        content: TextField(
          controller: ctrl,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(labelText: "Nombre"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancelar"),
          ),
          ElevatedButton(
            onPressed: () => _agregarItem(endpoint, ctrl.text),
            child: const Text("Guardar"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Secretarías y Funciones"),
          backgroundColor: Colors.cyan.shade700,
          foregroundColor: Colors.white,
          bottom: const TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: [
              Tab(icon: Icon(Icons.account_balance), text: "Secretarías"),
              Tab(icon: Icon(Icons.work), text: "Funciones"),
            ],
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: [
                  Scaffold(
                    body: ListView.builder(
                      padding: const EdgeInsets.all(8),
                      itemCount: _secretarias.length,
                      itemBuilder: (_, i) => Card(
                        child: ListTile(
                          leading: const Icon(
                            Icons.account_balance,
                            color: Colors.cyan,
                          ),
                          title: Text(
                            _secretarias[i]['nombre'],
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ),
                    floatingActionButton: FloatingActionButton.extended(
                      onPressed: () => _mostrarDialogoNuevo(
                        "Nueva Secretaría",
                        "secretarias",
                      ),
                      backgroundColor: Colors.cyan.shade700,
                      foregroundColor: Colors.white,
                      icon: const Icon(Icons.add),
                      label: const Text("Nueva Secretaría"),
                    ),
                  ),
                  Scaffold(
                    body: ListView.builder(
                      padding: const EdgeInsets.all(8),
                      itemCount: _funciones.length,
                      itemBuilder: (_, i) => Card(
                        child: ListTile(
                          leading: const Icon(Icons.work, color: Colors.teal),
                          title: Text(
                            _funciones[i]['nombre'],
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ),
                    floatingActionButton: FloatingActionButton.extended(
                      onPressed: () =>
                          _mostrarDialogoNuevo("Nueva Función", "funciones"),
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                      icon: const Icon(Icons.add),
                      label: const Text("Nueva Función"),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

// =========================================================================
// PANTALLA DE AUDITORÍA DEL SISTEMA (EXCLUSIVA ADMIN TOTAL)
// =========================================================================
class AuditoriaAdminScreen extends StatefulWidget {
  const AuditoriaAdminScreen({super.key});

  @override
  State<AuditoriaAdminScreen> createState() => _AuditoriaAdminScreenState();
}

class _AuditoriaAdminScreenState extends State<AuditoriaAdminScreen> {
  List<dynamic> _logs = [];
  bool _isLoading = false;
  final String baseUrl = "https://tarja-api.onrender.com";

  @override
  void initState() {
    super.initState();
    _cargarLogs();
  }

  Future<void> _cargarLogs() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      final res = await http.get(
        Uri.parse('$baseUrl/admin/auditoria'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (res.statusCode == 200 && mounted) {
        setState(() => _logs = json.decode(res.body));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Auditoría de Cambios"),
        backgroundColor: Colors.blueGrey.shade800,
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _cargarLogs),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _logs.isEmpty
          ? const Center(child: Text("Sin registros de auditoría aún."))
          : ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: _logs.length,
              itemBuilder: (_, i) {
                final l = _logs[i];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    title: Text(
                      "${l['accion']} — ${l['nombre_operador']} (${l['usuario']})",
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(
                          l['detalle'] ?? '',
                          style: const TextStyle(fontSize: 12),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "📅 ${l['fecha_hora']}",
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
