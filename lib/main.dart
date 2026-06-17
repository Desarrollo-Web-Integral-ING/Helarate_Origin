import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'theme/app_theme.dart';
import 'screens/dashboard_screen.dart';
import 'screens/inventario_produccion_screen.dart';
import 'screens/inventario_venta_screen.dart';
import 'screens/ventas_screen.dart';
import 'screens/estadisticas_screen.dart';
import 'services/storage_service.dart';

import 'widgets/indexed_stack_resume.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es_MX', null);
  await StorageService().inicializarDatosDefecto();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );
  runApp(const NeveroApp());
}

class NeveroApp extends StatelessWidget {
  const NeveroApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mi Nevería',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      home: const MainNavigation(),
    );
  }
}

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;

  final _keys = [
    GlobalKey(),
    GlobalKey(),
    GlobalKey(),
    GlobalKey(),
    GlobalKey(),
  ];

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      DashboardScreen(key: _keys[0]),
      InventarioProduccionScreen(key: _keys[1]),
      InventarioVentaScreen(key: _keys[2]),
      VentasScreen(key: _keys[3]),
      EstadisticasScreen(key: _keys[4]),
    ];
  }

  void _onTabTap(int index) {
    if (_currentIndex == index) return;
    setState(() => _currentIndex = index);
    activeTabNotifier.value = index;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _navItem(0, Icons.home_rounded, Icons.home_outlined, 'Inicio'),
                _navItem(1, Icons.inventory_2_rounded,
                    Icons.inventory_2_outlined, 'Insumos'),
                _navItem(
                    2, Icons.icecream_rounded, Icons.icecream_outlined, 'Nieves'),
                _navItem(3, Icons.point_of_sale_rounded,
                    Icons.point_of_sale_outlined, 'Ventas'),
                _navItem(4, Icons.bar_chart_rounded,
                    Icons.bar_chart_outlined, 'Stats'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _navItem(
      int index, IconData activeIcon, IconData inactiveIcon, String label) {
    final isActive = _currentIndex == index;
    return GestureDetector(
      onTap: () => _onTabTap(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          gradient: isActive ? AppTheme.primaryGradient : null,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(
              isActive ? activeIcon : inactiveIcon,
              color: isActive ? Colors.white : AppTheme.textSecondary,
              size: 22,
            ),
            if (isActive) ...[
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
