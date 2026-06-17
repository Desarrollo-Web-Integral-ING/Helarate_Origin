import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../models/venta.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../widgets/stat_card.dart';

import '../widgets/indexed_stack_resume.dart';

class EstadisticasScreen extends StatefulWidget {
  const EstadisticasScreen({super.key});

  @override
  State<EstadisticasScreen> createState() => _EstadisticasScreenState();
}

class _EstadisticasScreenState extends State<EstadisticasScreen> {
  final _storage = StorageService();
  final _fmt = NumberFormat.currency(locale: 'es_MX', symbol: '\$');
  List<Venta> _ventas = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
    activeTabNotifier.addListener(_onTabChange);
  }

  void _onTabChange() {
    if (activeTabNotifier.value == 4) _load();
  }

  @override
  void dispose() {
    activeTabNotifier.removeListener(_onTabChange);
    super.dispose();
  }

  Future<void> _load() async {
    final v = await _storage.getVentas();
    setState(() {
      _ventas = v;
      _loading = false;
    });
  }

  Map<String, double> get _ventasPorDia {
    final now = DateTime.now();
    final Map<String, double> result = {};
    for (int i = 6; i >= 0; i--) {
      final day = now.subtract(Duration(days: i));
      final key = DateFormat('dd/MM').format(day);
      result[key] = 0;
    }
    for (final v in _ventas) {
      if (v.fecha.isAfter(now.subtract(const Duration(days: 7)))) {
        final key = DateFormat('dd/MM').format(v.fecha);
        result[key] = (result[key] ?? 0) + v.total;
      }
    }
    return result;
  }

  Map<String, int> get _topProductos {
    final Map<String, int> result = {};
    for (final v in _ventas) {
      result[v.productoNombre] = (result[v.productoNombre] ?? 0) + v.cantidad;
    }
    final sorted = result.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return Map.fromEntries(sorted.take(5));
  }

  double get _totalGeneral => _ventas.fold(0.0, (sum, v) => sum + v.total);
  double get _promedioVenta =>
      _ventas.isEmpty ? 0 : _totalGeneral / _ventas.length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Estadísticas')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _ventas.isEmpty
              ? _buildEmpty()
              : SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),
                      _buildResumenCards(),
                      const SizedBox(height: 24),
                      const SectionHeader(title: 'Ventas últimos 7 días'),
                      const SizedBox(height: 16),
                      _buildBarChart(),
                      const SizedBox(height: 24),
                      const SectionHeader(title: 'Top productos más vendidos'),
                      const SizedBox(height: 16),
                      _buildTopProductos(),
                      const SizedBox(height: 24),
                      const SectionHeader(title: 'Distribución de ventas'),
                      const SizedBox(height: 16),
                      _buildPieChart(),
                    ],
                  ),
                ),
    );
  }

  Widget _buildEmpty() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('📊', style: TextStyle(fontSize: 56)),
          SizedBox(height: 16),
          Text('Sin datos aún',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary)),
          SizedBox(height: 8),
          Text('Registra ventas para ver estadísticas',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildResumenCards() {
    final now = DateTime.now();
    final ventasHoy = _ventas
        .where((v) =>
            v.fecha.year == now.year &&
            v.fecha.month == now.month &&
            v.fecha.day == now.day)
        .fold(0.0, (sum, v) => sum + v.total);
    final ventasMes = _ventas
        .where((v) => v.fecha.year == now.year && v.fecha.month == now.month)
        .fold(0.0, (sum, v) => sum + v.total);

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 14,
      mainAxisSpacing: 14,
      childAspectRatio: 1.2,
      children: [
        StatCard(
          title: 'Total general',
          value: _fmt.format(_totalGeneral),
          icon: Icons.attach_money_rounded,
          gradient: AppTheme.primaryGradient,
        ),
        StatCard(
          title: 'Ventas del mes',
          value: _fmt.format(ventasMes),
          icon: Icons.calendar_month_rounded,
          gradient: AppTheme.salesGradient,
        ),
        StatCard(
          title: 'Ventas hoy',
          value: _fmt.format(ventasHoy),
          icon: Icons.today_rounded,
          gradient: AppTheme.stockGradient,
        ),
        StatCard(
          title: 'Promedio por venta',
          value: _fmt.format(_promedioVenta),
          icon: Icons.trending_up_rounded,
          gradient: AppTheme.productionGradient,
        ),
      ],
    );
  }

  Widget _buildBarChart() {
    final data = _ventasPorDia;
    final keys = data.keys.toList();
    final values = data.values.toList();
    final maxVal =
        values.isEmpty ? 1.0 : values.reduce((a, b) => a > b ? a : b);

    return Container(
      height: 200,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: BarChart(
        BarChartData(
          maxY: maxVal == 0 ? 10 : maxVal * 1.2,
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (group, groupIndex, rod, rodIndex) =>
                  BarTooltipItem(
                _fmt.format(rod.toY),
                const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 12),
              ),
            ),
          ),
          titlesData: FlTitlesData(
            leftTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final idx = value.toInt();
                  if (idx < 0 || idx >= keys.length) return const SizedBox();
                  return Text(keys[idx],
                      style: const TextStyle(
                          fontSize: 10, color: AppTheme.textSecondary));
                },
              ),
            ),
          ),
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          barGroups: List.generate(
            keys.length,
            (i) => BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: values[i],
                  gradient: AppTheme.primaryGradient,
                  width: 22,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(8)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopProductos() {
    final top = _topProductos;
    if (top.isEmpty) return const SizedBox();
    final maxVal = top.values.reduce((a, b) => a > b ? a : b);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: top.entries.map((e) {
          final pct = maxVal == 0 ? 0.0 : e.value / maxVal;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(e.key,
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: AppTheme.textPrimary),
                          overflow: TextOverflow.ellipsis),
                    ),
                    Text('${e.value} pzs',
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.primary)),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: pct,
                    minHeight: 8,
                    backgroundColor: const Color(0xFFF0F1FF),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                        AppTheme.primary),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildPieChart() {
    final top = _topProductos;
    if (top.isEmpty) return const SizedBox();
    final total = top.values.fold(0, (a, b) => a + b);
    final colors = [
      AppTheme.primary,
      const Color(0xFFFF6584),
      const Color(0xFF43E97B),
      const Color(0xFF4FACFE),
      const Color(0xFFFFB347),
    ];

    return Container(
      height: 220,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: PieChart(
              PieChartData(
                sectionsSpace: 3,
                centerSpaceRadius: 40,
                sections: top.entries.toList().asMap().entries.map((entry) {
                  final i = entry.key;
                  final e = entry.value;
                  final pct = total == 0 ? 0.0 : e.value / total * 100;
                  return PieChartSectionData(
                    color: colors[i % colors.length],
                    value: e.value.toDouble(),
                    title: '${pct.toStringAsFixed(0)}%',
                    radius: 55,
                    titleStyle: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.white),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: top.entries.toList().asMap().entries.map((entry) {
              final i = entry.key;
              final e = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: colors[i % colors.length],
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    SizedBox(
                      width: 100,
                      child: Text(
                        e.key.split(' - ').first,
                        style: const TextStyle(
                            fontSize: 11, color: AppTheme.textSecondary),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
