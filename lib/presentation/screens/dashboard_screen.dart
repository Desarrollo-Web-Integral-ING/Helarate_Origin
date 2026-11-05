import '../../core/widgets/user_avatar.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../../core/widgets/app_loader.dart';
import 'package:intl/intl.dart';
import '../../domain/models/insumo.dart';
import '../../domain/models/venta_model.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/dashboard/dashboard_bloc.dart';
import '../blocs/dashboard/dashboard_state.dart';
import '../blocs/dashboard/dashboard_event.dart';
import '../blocs/auth/auth_bloc.dart';
import '../blocs/auth/auth_event.dart';
import '../blocs/auth/auth_state.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/money.dart';
import '../widgets/stat_card.dart';
import 'inventario_produccion_screen.dart';
import 'inventario_venta_screen.dart';
import 'ventas_screen.dart';
import 'estadisticas_screen.dart';
import 'perfil_screen.dart';
import 'personalizacion_screen.dart';
import '../../core/widgets/business_icon_helper.dart';
import '../../core/widgets/indexed_stack_resume.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    context.read<DashboardBloc>().add(LoadDashboardEvent());
    activeTabNotifier.addListener(_onTabChange);
  }

  void _onTabChange() {
    if (activeTabNotifier.value == 0) {
      context.read<DashboardBloc>().add(LoadDashboardEvent());
    }
  }

  @override
  void dispose() {
    activeTabNotifier.removeListener(_onTabChange);
    super.dispose();
  }
  NumberFormat get _fmt => Money.of(context);

  List<Insumo> _productosVenta = [];
  List<Insumo> _productosProduccion = [];
  List<VentaModel> _ventas = [];

  double get _ventasHoy {
    final hoy = DateTime.now();
    return _ventas
        .where((v) =>
            v.fecha.year == hoy.year &&
            v.fecha.month == hoy.month &&
            v.fecha.day == hoy.day)
        .fold(0.0, (sum, v) => sum + v.totalIngresos);
  }

  double get _ventasMes {
    final hoy = DateTime.now();
    return _ventas
        .where((v) => v.fecha.year == hoy.year && v.fecha.month == hoy.month)
        .fold(0.0, (sum, v) => sum + v.totalIngresos);
  }

  int get _stockBajoCount => _productosVenta.where((p) => p.stockBajo).length;
  int get _productosAgotados => _productosVenta.where((p) => p.stockActual == 0).length;
  int get _insumosAgotados => _productosProduccion.where((p) => p.stockActual == 0).length;
  int get _insumosBajos => _productosProduccion.where((p) => p.stockBajo).length;

  List<VentaModel> get _ventasRecientes =>
      (_ventas..sort((a, b) => b.fecha.compareTo(a.fecha))).take(5).toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocBuilder<DashboardBloc, DashboardState>(
        builder: (context, state) {
          if (state is DashboardLoading || state is DashboardInitial) {
            return const AppLoader();
          }
          if (state is DashboardError) {
            return Center(child: Text('Error: ${state.message}'));
          }
          if (state is DashboardLoaded) {
            _productosVenta = state.insumos.where((i) => i.tipo == TipoInsumo.productoVenta).toList();
            _productosProduccion = state.insumos.where((i) => i.tipo == TipoInsumo.materiaPrima).toList();
            _ventas = state.ventas;

            return RefreshIndicator(
              onRefresh: () async {
                context.read<DashboardBloc>().add(LoadDashboardEvent());
              },
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
                        if (_stockBajoCount > 0 || _productosAgotados > 0 || _insumosAgotados > 0) ...[
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
            );
          }
          return const SizedBox();
        },
      ),
    );
  }

  Widget _buildAppBar() {
    final authState = context.watch<AuthBloc>().state;
    String nombreNegocio = 'Mi Negocio';
    Color brandColor = context.brand;
    if (authState is Authenticated && authState.tenant != null) {
      nombreNegocio = authState.tenant!.nombre;
      brandColor = AppTheme.parseHexColor(authState.tenant!.colorPrimario);
    }
    final primaryGradient = AppTheme.createCustomGradient(brandColor);

    return SliverAppBar(
      expandedHeight: 140,
      floating: false,
      pinned: true,
      backgroundColor: AppTheme.background,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(gradient: primaryGradient),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                children: [
                  Builder(
                    builder: (context) {
                      final isMobile = MediaQuery.of(context).size.width < 800;
                      final user = authState is Authenticated ? authState.usuario : null;
                      final tenant = authState is Authenticated ? authState.tenant : null;
                      
                      if (isMobile && user != null) {
                        return GestureDetector(
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PerfilScreen())),
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                              boxShadow: [
                                BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 8),
                              ],
                            ),
                            child: UserAvatar(style: user.avatarStyle, seed: user.avatarSeed ?? '', name: user.nombre, size: 44, png: user.avatarPng),
                          ),
                        );
                      }
                      
                      if (tenant?.logoUrl != null && tenant!.logoUrl!.isNotEmpty) {
                        return Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 1.5),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.memory(
                              base64Decode(tenant.logoUrl!.contains(',') ? tenant.logoUrl!.split(',').last : tenant.logoUrl!),
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Icon(
                                BusinessIconHelper.getIcon(tenant.logoIcon),
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                          ),
                        );
                      }
                      
                      return Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          BusinessIconHelper.getIcon(tenant?.logoIcon),
                          color: Colors.white,
                          size: 26,
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        nombreNegocio,
                        style: const TextStyle(
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
                  const Spacer(),
                  // Botón flotante HeroUI para cambio rápido de tema Claro / Oscuro con animación
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 1),
                    ),
                    child: IconButton(
                      icon: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        transitionBuilder: (child, anim) => RotationTransition(
                          turns: anim,
                          child: ScaleTransition(scale: anim, child: child),
                        ),
                        child: Icon(
                          (authState is Authenticated && authState.tenant?.modoOscuro == true)
                              ? Icons.dark_mode_rounded
                              : Icons.light_mode_rounded,
                          key: ValueKey(authState is Authenticated && authState.tenant?.modoOscuro == true),
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      tooltip: (authState is Authenticated && authState.tenant?.modoOscuro == true)
                          ? 'Cambiar a modo Claro'
                          : 'Cambiar a modo Oscuro',
                      onPressed: () {
                        context.read<AuthBloc>().add(ToggleThemeRequested());
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.palette_rounded, color: Colors.white),
                    tooltip: 'Personalizar Marca',
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const PersonalizacionScreen()),
                      );
                    },
                  ),
                  if (MediaQuery.of(context).size.width < 800) ...[
                    IconButton(
                      icon: const Icon(Icons.account_circle_rounded, color: Colors.white),
                      tooltip: 'Mi Perfil / ARCO',
                      onPressed: () {
                        final auth = context.read<AuthBloc>().state;
                        if (auth is Authenticated) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const PerfilScreen()),
                          );
                        }
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.logout_rounded, color: Colors.white),
                      tooltip: 'Cerrar sesión',
                      onPressed: () {
                        context.read<AuthBloc>().add(SignOutRequested());
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatsGrid() {
    final authState = context.read<AuthBloc>().state;
    final isEmployee = authState is Authenticated && authState.usuario.isEmployee;
    final screenWidth = MediaQuery.of(context).size.width;

    // Ajuste responsivo profesional HeroUI:
    // En pantallas anchas (Web/Tablet) usamos 4 columnas proporcionadas, en móvil 2 columnas
    final int crossAxisCount = screenWidth >= 1100 ? 4 : (screenWidth >= 600 ? 2 : 2);
    final double childAspectRatio = screenWidth >= 1100 ? 2.1 : (screenWidth >= 800 ? 1.8 : 1.15);

    if (isEmployee) {
      return GridView.count(
        crossAxisCount: crossAxisCount > 2 ? 2 : crossAxisCount,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
        childAspectRatio: childAspectRatio,
        children: [
          StatCard(
            title: 'Productos en catálogo',
            value: '${_productosVenta.length}',
            subtitle: '$_stockBajoCount con stock bajo',
            icon: Icons.inventory_rounded,
            gradient: AppTheme.stockGradient,
            onTap: () => _goTo(const InventarioVentaScreen()),
          ),
          StatCard(
            title: 'Insumos activos',
            value: '${_productosProduccion.length}',
            subtitle: '$_insumosBajos con stock bajo',
            icon: Icons.inventory_2_rounded,
            gradient: AppTheme.productionGradient,
            onTap: () => _goTo(const InventarioProduccionScreen()),
          ),
        ],
      );
    }

    return GridView.count(
      crossAxisCount: crossAxisCount,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 14,
      mainAxisSpacing: 14,
      childAspectRatio: childAspectRatio,
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
          title: 'Productos en catálogo',
          value: '${_productosVenta.length}',
          subtitle: '$_stockBajoCount con stock bajo',
          icon: Icons.inventory_rounded,
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
    final authState = context.read<AuthBloc>().state;
    final isEmployee = authState is Authenticated && authState.usuario.isEmployee;

    final actions = [
      _QuickAction('Insumos', Icons.inventory_2_rounded, AppTheme.productionGradient,
          () => _goTo(const InventarioProduccionScreen())),
      _QuickAction('Catálogo', Icons.shopping_bag_rounded, AppTheme.stockGradient,
          () => _goTo(const InventarioVentaScreen())),
      _QuickAction('Caja Ventas', Icons.point_of_sale_rounded, AppTheme.salesGradient,
          () => _goTo(const VentasScreen())),
      if (!isEmployee)
        _QuickAction('Reportes', Icons.bar_chart_rounded, AppTheme.primaryGradient,
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
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Theme.of(context).brightness == Brightness.dark ? Color(0xFFCBD5E1) : context.textMain,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertas() {
    return Column(
      children: [
        if (_productosAgotados > 0)
          _alertaBanner(
            Icons.warning_amber_rounded,
            '$_productosAgotados producto(s) agotado(s) en catálogo',
            'Revisar',
            const Color(0xFFE3F2FD),
            const Color(0xFF1565C0),
            () => _goTo(const InventarioVentaScreen()),
          ),
        if (_productosAgotados > 0 && (_insumosAgotados > 0 || _insumosBajos > 0))
          const SizedBox(height: 8),
        if (_insumosAgotados > 0)
          _alertaBanner(
            Icons.inventory_2_rounded,
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
            Icons.warning_amber_rounded,
            '$_insumosBajos insumo(s) por debajo del mínimo',
            'Ver',
            const Color(0xFFFFF3E0),
            const Color(0xFFE65100),
            () => _goTo(const InventarioProduccionScreen()),
          ),
      ],
    );
  }

  Widget _alertaBanner(IconData icon, String msg, String accion, Color bg,
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
          Icon(icon, color: textColor, size: 20),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final cardBorder = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final textSub = isDark ? Color(0xFF94A3B8) : context.textMuted;

    if (_ventasRecientes.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cardBorder, width: 1),
        ),
        child: Center(
          child: Text(
            'Sin ventas registradas aún',
            style: TextStyle(color: textSub, fontSize: 14),
          ),
        ),
      );
    }
    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardBorder, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
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
            Divider(height: 1, indent: 16, endIndent: 16, color: cardBorder),
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
              child: const Icon(Icons.point_of_sale_rounded,
                  color: Colors.white, size: 20),
            ),
            title: Text(
              v.detalles.isNotEmpty
                  ? '${v.detalles.first.insumoNombre ?? 'Venta'}${v.detalles.length > 1 ? ' + ${v.detalles.length - 1}' : ''}'
                  : 'Venta',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: isDark ? Color(0xFFF8FAFC) : context.textMain,
              ),
            ),
            subtitle: Text(
              DateFormat('dd/MM/yy HH:mm').format(v.fecha),
              style: TextStyle(
                  fontSize: 12, color: textSub),
            ),
            trailing: Text(
              _fmt.format(v.totalIngresos),
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: isDark ? Color(0xFF38BDF8) : context.brand,
                fontSize: 14,
              ),
            ),
          );
        },
      ),
    );
  }

  void _goTo(Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen)).then((_) {
      if (mounted) {
        context.read<DashboardBloc>().add(LoadDashboardEvent());
      }
    });
  }
}

class _QuickAction {
  final String label;
  final IconData icon;
  final LinearGradient gradient;
  final VoidCallback onTap;
  _QuickAction(this.label, this.icon, this.gradient, this.onTap);
}
