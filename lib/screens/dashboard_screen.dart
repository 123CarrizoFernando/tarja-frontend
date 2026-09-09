import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text('Estadísticas y Dashboard'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: "Actualizar",
            onPressed: () {
              setState(() {
                _isLoading = true;
              });
              _cargarDashboard();
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.teal))
          // ¡ACÁ ESTÁ EL PULL TO REFRESH! (Deslizar hacia abajo)
          : RefreshIndicator(
              onRefresh: _cargarDashboard,
              color: Colors.teal,
              child: SingleChildScrollView(
                // Esto fuerza a que la pantalla siempre se pueda deslizar, aunque esté vacía
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
                      "Top 3 Sectores con Faltas (Mes)",
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
                                        2,
                                    barTouchData: BarTouchData(enabled: true),
                                    titlesData: FlTitlesData(
                                      show: true,
                                      bottomTitles: AxisTitles(
                                        sideTitles: SideTitles(
                                          showTitles: true,
                                          getTitlesWidget: (double value, TitleMeta meta) {
                                            if (value.toInt() >=
                                                _dashboardData['ranking_mes']
                                                    .length)
                                              return const SizedBox.shrink();
                                            String nombre =
                                                _dashboardData['ranking_mes'][value
                                                    .toInt()]['sector'];
                                            if (nombre.length > 10)
                                              nombre =
                                                  "${nombre.substring(0, 10)}...";

                                            // ¡ACÁ ESTÁ LA CORRECCIÓN DEL ERROR!
                                            return SideTitleWidget(
                                              meta: meta, // Cambiamos axisSide por meta
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
                                      ),
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
                  ],
                ),
              ),
            ),
    );
  }

  // --- FUNCIONES AUXILIARES PARA GRÁFICOS ---
  List<PieChartSectionData> _generarSeccionesTorta(Map<String, dynamic> hoy) {
    int pres = hoy['presentes'] ?? 0;
    int faltas = hoy['faltas'] ?? 0;
    int lic = hoy['licencias'] ?? 0;
    int sin = hoy['sin_marcar'] ?? 0;
    int total = hoy['total'] ?? 1;
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
          showingTooltipIndicators: [0],
        ),
      );
    }
    return barras;
  }
}
