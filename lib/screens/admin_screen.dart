import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'sectores_admin_screen.dart';
import 'empleados_admin_screen.dart';
import 'encargados_admin_screen.dart';
import 'super_tarja_screen.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  bool _isLoading = true;
  Map<String, dynamic> _dashboardData = {};
  final String baseUrl = "https://tarja-api.onrender.com";

  @override
  void initState() {
    super.initState();
    _cargarDashboard();
  }

  Future<void> _cargarDashboard() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      final response = await http.get(
        Uri.parse('$baseUrl/admin/dashboard'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        if (mounted) {
          setState(() {
            _dashboardData = json.decode(response.body);
            _isLoading = false;
          });
        }
      } else {
        throw Exception("Error al cargar estadísticas");
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _cerrarSesion() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    if (mounted) Navigator.of(context).pushReplacementNamed('/');
  }

  // --- WIDGET PARA DIBUJAR LOS 4 BOTONES DE SIEMPRE ---
  Widget _crearBotonAccion(
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
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text('Tablero de Comando (Admin)'),
        backgroundColor: Colors.blueGrey.shade900,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: "Actualizar Tablero",
            onPressed: () {
              setState(() {
                _isLoading = true;
              });
              _cargarDashboard();
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: "Cerrar Sesión",
            onPressed: _cerrarSesion,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _cargarDashboard,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // --- GRÁFICO 1: PRESENTISMO DE HOY ---
                    const Text(
                      "Resumen de Hoy",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.blueGrey,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      elevation: 3,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 120,
                              height: 120,
                              child: PieChart(
                                PieChartData(
                                  sectionsSpace: 2,
                                  centerSpaceRadius: 30,
                                  sections: _generarSeccionesTorta(
                                    _dashboardData['hoy'],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 20),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _indicadorColor(
                                    Colors.green,
                                    "Presentes",
                                    _dashboardData['hoy']['presentes'],
                                  ),
                                  const SizedBox(height: 4),
                                  _indicadorColor(
                                    Colors.redAccent,
                                    "Faltas",
                                    _dashboardData['hoy']['faltas'],
                                  ),
                                  const SizedBox(height: 4),
                                  _indicadorColor(
                                    Colors.orange,
                                    "Licencias",
                                    _dashboardData['hoy']['licencias'],
                                  ),
                                  const SizedBox(height: 4),
                                  _indicadorColor(
                                    Colors.grey,
                                    "Sin Marcar",
                                    _dashboardData['hoy']['sin_marcar'],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 25),

                    // --- GRÁFICO 2: RANKING TOP 3 FALTAS DEL MES ---
                    const Text(
                      "Top 3 Sectores con Faltas (Este Mes)",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.blueGrey,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      elevation: 3,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: _dashboardData['ranking_mes'].isEmpty
                            ? const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(20.0),
                                  child: Text(
                                    "¡No hay faltas registradas este mes!",
                                    style: TextStyle(
                                      color: Colors.green,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              )
                            : SizedBox(
                                height: 160,
                                child: BarChart(
                                  BarChartData(
                                    alignment: BarChartAlignment.spaceAround,
                                    maxY:
                                        _obtenerMaximo(
                                          _dashboardData['ranking_mes'],
                                        ) +
                                        2, // Margen superior
                                    barTouchData: BarTouchData(enabled: true),
                                    titlesData: FlTitlesData(
                                      show: true,
                                      bottomTitles: AxisTitles(
                                        sideTitles: SideTitles(
                                          showTitles: true,
                                          getTitlesWidget: (double value, TitleMeta meta) {
                                            if (value.toInt() >=
                                                _dashboardData['ranking_mes']
                                                    .length) {
                                              return const SizedBox.shrink();
                                            }
                                            String nombre =
                                                _dashboardData['ranking_mes'][value
                                                    .toInt()]['sector'];
                                            // Acortamos el nombre si es muy largo
                                            if (nombre.length > 10) {
                                              nombre =
                                                  "${nombre.substring(0, 10)}...";
                                            }
                                            return SideTitleWidget(
                                              meta: meta,
                                              child: Text(
                                                nombre,
                                                style: const TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                      leftTitles: const AxisTitles(
                                        sideTitles: SideTitles(
                                          showTitles: false,
                                        ),
                                      ), // Ocultamos los números laterales
                                      topTitles: const AxisTitles(
                                        sideTitles: SideTitles(
                                          showTitles: false,
                                        ),
                                      ),
                                      rightTitles: const AxisTitles(
                                        sideTitles: SideTitles(
                                          showTitles: false,
                                        ),
                                      ),
                                    ),
                                    gridData: const FlGridData(show: false),
                                    borderData: FlBorderData(show: false),
                                    barGroups: _generarBarras(
                                      _dashboardData['ranking_mes'],
                                    ),
                                  ),
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 25),

                    // --- BOTONES DE GESTIÓN (LOS ORIGINALES) ---
                    const Text(
                      "Módulos de Gestión",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.blueGrey,
                      ),
                    ),
                    const SizedBox(height: 10),
                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 2,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: 1.2,
                      children: [
                        _crearBotonAccion(
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
                          "Empleados",
                          Icons.people,
                          Colors.green,
                          () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  const EmpleadosAdminScreen(),
                            ),
                          ),
                        ),
                        _crearBotonAccion(
                          "Encargados",
                          Icons.manage_accounts,
                          Colors.indigo,
                          () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  const EncargadosAdminScreen(),
                            ),
                          ),
                        ),
                        _crearBotonAccion(
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
                      ],
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
    );
  }

  // --- FUNCIONES AUXILIARES PARA DIBUJAR LOS GRÁFICOS ---

  List<PieChartSectionData> _generarSeccionesTorta(Map<String, dynamic> hoy) {
    int pres = hoy['presentes'] ?? 0;
    int faltas = hoy['faltas'] ?? 0;
    int lic = hoy['licencias'] ?? 0;
    int sin = hoy['sin_marcar'] ?? 0;
    int total = hoy['total'] ?? 1; // Para evitar dividir por cero
    if (total == 0) total = 1;

    return [
      if (pres > 0)
        PieChartSectionData(
          color: Colors.green,
          value: pres.toDouble(),
          title: '${((pres / total) * 100).toStringAsFixed(0)}%',
          radius: 40,
          titleStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      if (faltas > 0)
        PieChartSectionData(
          color: Colors.redAccent,
          value: faltas.toDouble(),
          title: '${((faltas / total) * 100).toStringAsFixed(0)}%',
          radius: 40,
          titleStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      if (lic > 0)
        PieChartSectionData(
          color: Colors.orange,
          value: lic.toDouble(),
          title: '${((lic / total) * 100).toStringAsFixed(0)}%',
          radius: 40,
          titleStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      if (sin > 0)
        PieChartSectionData(
          color: Colors.grey.shade400,
          value: sin.toDouble(),
          title: '${((sin / total) * 100).toStringAsFixed(0)}%',
          radius: 40,
          titleStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
    ];
  }

  Widget _indicadorColor(Color color, String texto, int cantidad) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
        const SizedBox(width: 8),
        Text(
          "$texto: ",
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        Text(
          cantidad.toString(),
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  double _obtenerMaximo(List<dynamic> ranking) {
    if (ranking.isEmpty) return 10.0;
    double max = 0;
    for (var r in ranking) {
      if (r['faltas'] > max) max = r['faltas'].toDouble();
    }
    return max;
  }

  List<BarChartGroupData> _generarBarras(List<dynamic> ranking) {
    List<BarChartGroupData> barras = [];
    for (int i = 0; i < ranking.length; i++) {
      barras.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: ranking[i]['faltas'].toDouble(),
              color: Colors.redAccent,
              width: 25,
              borderRadius: BorderRadius.circular(4),
              backDrawRodData: BackgroundBarChartRodData(
                show: true,
                toY: _obtenerMaximo(ranking) + 2,
                color: Colors.red.shade50,
              ),
            ),
          ],
          showingTooltipIndicators: [
            0,
          ], // Muestra el número arriba de la barra siempre
        ),
      );
    }
    return barras;
  }
}
