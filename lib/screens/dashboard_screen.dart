import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/producto_produccion.dart';
import '../models/producto_venta.dart';
import '../models/venta.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../widgets/stat_card.dart';
import 'inventario_produccion_screen.dart';
import 'inventario_venta_screen.dart';
import 'ventas_screen.dart';
import 'estadisticas_screen.dart';

import '../widgets/indexed_stack_resume.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _storage = StorageService();
  final _fmt = NumberFormat.currency(locale: 'es_MX', symbol: '\$');

  List<ProductoVenta> _productosVenta = [];
  List<ProductoProduccion> _productosProduccion = [];
  List<Venta> _ventas = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
    activeTabNotifier.addListener(_onTabChange);
  }

  void _onTabChange() {
    if (activeTabNotifier.value == 0) _load();
  }

  @override
  void dispose() {
    activeTabNotifier.removeListener(_onTabChange);
    super.dispose();
  }

  Future<void> _load() async {
    final pv = await _storage.getProductosVenta();
    final pp = await _storage.getProductosProduccion();
    final v = await _storage.getVentas();
    setState(() {
      _productosVenta = pv;
      _productosProduccion = pp;
      _ventas = v;
      _loading = false;
    });
  }

  double get _ventasHoy {
    final hoy = DateTime.now();
    return _ventas
        .where((v) =>
            v.fecha.year == hoy.year &&
            v.fecha.month == hoy.month &&
            v.fecha.day == hoy.day)
        .fold(0.0, (sum, v) => sum + v.total);
  }

  double get _ventasMes {
    final hoy = DateTime.now();
    return _ventas
        .where((v) => v.fecha.year == hoy.year && v.fecha.month == hoy.month)
        .fold(0.0, (sum, v) => sum + v.total);
  }

  int get _stockBajoCount => _productosVenta.where((p) => p.stockBajo).length;
  int get _nievesAgotadas => _productosVenta.where((p) => p.stockActual == 0 && p.categoria == 'Litro').length;
  int get _insumosAgotados => _productosProduccion.where((p) => p.cantidad == 0).length;
  int get _insumosBajos => _productosProduccion.where((p) => p.stockBajo).length;

  List<Venta> get _ventasRecientes =>
      (_ventas..sort((a, b) => b.fecha.compareTo(a.fecha))).take(5).toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: CustomScrollView(
                slivers: [
                  _buildAppBar(),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        const SizedBox(height: 8),
                        _buildStatsGrid(),
                        const SizedBox(height: 28),
                        _buildQuickActions(),
                        const SizedBox(height: 28),
        if (_stockBajoCount > 0 || _nievesAgotadas > 0 || _insumosAgotados > 0) ...[
                          _buildAlertas(),
                          const SizedBox(height: 28),
                        ],
                        SectionHeader(
                          title: 'Ventas recientes',
                          actionLabel: 'Ver todas',
                          onAction: () => _goTo(const VentasScreen()),
                        ),
                        const SizedBox(height: 12),
                        _buildVentasRecientes(),
                      ]),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 140,
      floating: false,
      pinned: true,
      backgroundColor: AppTheme.background,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(gradient: AppTheme.primaryGradient),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Text('🍧', style: TextStyle(fontSize: 24)),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Mi Nevería',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        DateFormat('EEEE, d MMM', 'es_MX').format(DateTime.now()),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatsGrid() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 14,
      mainAxisSpacing: 14,
      childAspectRatio: 1.3,
      children: [
        StatCard(
          title: 'Ventas hoy',
          value: _fmt.format(_ventasHoy),
          icon: Icons.today_rounded,
          gradient: AppTheme.salesGradient,
          onTap: () => _goTo(const VentasScreen()),
        ),
        StatCard(
          title: 'Ventas del mes',
          value: _fmt.format(_ventasMes),
          icon: Icons.calendar_month_rounded,
          gradient: AppTheme.primaryGradient,
          onTap: () => _goTo(const EstadisticasScreen()),
        ),
        StatCard(
          title: 'Productos en venta',
          value: '${_productosVenta.length}',
          subtitle: '$_stockBajoCount con stock bajo',
          icon: Icons.icecream_rounded,
          gradient: AppTheme.stockGradient,
          onTap: () => _goTo(const InventarioVentaScreen()),
        ),
        StatCard(
          title: 'Ventas totales',
          value: '${_ventas.length}',
          subtitle: 'registros',
          icon: Icons.receipt_long_rounded,
          gradient: AppTheme.productionGradient,
          onTap: () => _goTo(const VentasScreen()),
        ),
      ],
    );
  }

  Widget _buildQuickActions() {
    final actions = [
      _QuickAction('Insumos', Icons.inventory_2_rounded, AppTheme.productionGradient,
          () => _goTo(const InventarioProduccionScreen())),
      _QuickAction('Nieves', Icons.icecream_rounded, AppTheme.stockGradient,
          () => _goTo(const InventarioVentaScreen())),
      _QuickAction('Ventas', Icons.point_of_sale_rounded, AppTheme.salesGradient,
          () => _goTo(const VentasScreen())),
      _QuickAction('Stats', Icons.bar_chart_rounded, AppTheme.primaryGradient,
          () => _goTo(const EstadisticasScreen())),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Acceso rápido'),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: actions.map((a) => _buildActionButton(a)).toList(),
        ),
      ],
    );
  }

  Widget _buildActionButton(_QuickAction a) {
    return GestureDetector(
      onTap: a.onTap,
      child: Column(
        children: [
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              gradient: a.gradient,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: a.gradient.colors.first.withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(a.icon, color: Colors.white, size: 26),
          ),
          const SizedBox(height: 8),
          Text(
            a.label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertas() {
    return Column(
      children: [
        if (_nievesAgotadas > 0)
          _alertaBanner(
            '🍧',
            '$_nievesAgotadas sabor(es) de nieve agotado(s)',
            'Revisar',
            const Color(0xFFE3F2FD),
            const Color(0xFF1565C0),
            () => _goTo(const InventarioVentaScreen()),
          ),
        if (_nievesAgotadas > 0 && (_insumosAgotados > 0 || _insumosBajos > 0))
          const SizedBox(height: 8),
        if (_insumosAgotados > 0)
          _alertaBanner(
            '📦',
            '$_insumosAgotados insumo(s) agotado(s) — necesitas reponerlos',
            'Ver',
            const Color(0xFFFFEBEE),
            const Color(0xFFC62828),
            () => _goTo(const InventarioProduccionScreen()),
          ),
        if (_insumosAgotados > 0 && _insumosBajos > 0)
          const SizedBox(height: 8),
        if (_insumosBajos > 0)
          _alertaBanner(
            '⚠️',
            '$_insumosBajos insumo(s) por debajo del mínimo',
            'Ver',
            const Color(0xFFFFF3E0),
            const Color(0xFFE65100),
            () => _goTo(const InventarioProduccionScreen()),
          ),
      ],
    );
  }

  Widget _alertaBanner(String emoji, String msg, String accion, Color bg,
      Color textColor, VoidCallback onTap) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: textColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(msg,
                style: TextStyle(
                    color: textColor, fontSize: 13, fontWeight: FontWeight.w500)),
          ),
          GestureDetector(
            onTap: onTap,
            child: Text(accion,
                style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Widget _buildVentasRecientes() {
    if (_ventasRecientes.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(
          child: Text(
            'Sin ventas registradas aún',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
          ),
        ),
      );
    }
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _ventasRecientes.length,
        separatorBuilder: (_, __) =>
            const Divider(height: 1, indent: 16, endIndent: 16),
        itemBuilder: (_, i) {
          final v = _ventasRecientes[i];
          return ListTile(
            leading: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                gradient: AppTheme.salesGradient,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.icecream_rounded,
                  color: Colors.white, size: 20),
            ),
            title: Text(
              v.productoNombre,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: AppTheme.textPrimary,
              ),
            ),
            subtitle: Text(
              DateFormat('dd/MM/yy HH:mm').format(v.fecha),
              style: const TextStyle(
                  fontSize: 12, color: AppTheme.textSecondary),
            ),
            trailing: Text(
              _fmt.format(v.total),
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: AppTheme.primary,
                fontSize: 14,
              ),
            ),
          );
        },
      ),
    );
  }

  void _goTo(Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen))
        .then((_) => _load());
  }
}

class _QuickAction {
  final String label;
  final IconData icon;
  final LinearGradient gradient;
  final VoidCallback onTap;
  _QuickAction(this.label, this.icon, this.gradient, this.onTap);
}
