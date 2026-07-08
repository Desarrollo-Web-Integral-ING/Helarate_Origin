import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;
import 'package:flutter_bloc/flutter_bloc.dart';

import 'core/di/service_locator.dart';
import 'core/theme/app_theme.dart';
import 'domain/repositories/insumo_repository.dart';
import 'domain/repositories/venta_repository.dart';
import 'domain/repositories/auth_repository.dart';
import 'presentation/blocs/inventario/inventario_bloc.dart';
import 'presentation/blocs/inventario/inventario_event.dart';
import 'presentation/blocs/venta/venta_bloc.dart';
import 'presentation/blocs/venta/venta_event.dart';
import 'presentation/blocs/dashboard/dashboard_bloc.dart';
import 'presentation/blocs/dashboard/dashboard_event.dart';
import 'presentation/blocs/auth/auth_bloc.dart';
import 'presentation/blocs/auth/auth_event.dart';
import 'presentation/blocs/auth/auth_state.dart';
import 'presentation/widgets/perfil_dialog.dart';
import 'presentation/screens/dashboard_screen.dart';
import 'presentation/screens/inventario_produccion_screen.dart';
import 'presentation/screens/inventario_venta_screen.dart';
import 'presentation/screens/ventas_screen.dart';
import 'presentation/screens/estadisticas_screen.dart';
import 'presentation/screens/login_screen.dart';


import 'core/widgets/indexed_stack_resume.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Inicialización de Variables de Entorno y Supabase
  await dotenv.load(fileName: '.env');
  final supabaseUrl = dotenv.env['SUPABASE_URL'] ?? '';
  final supabaseKey = dotenv.env['SUPABASE_ANON_KEY'] ?? '';
  print('--- HELARATE DEBUG: VARIABLES DE ENTORNO ---');
  print('SUPABASE_URL: $supabaseUrl');
  print('SUPABASE_ANON_KEY (longitud): ${supabaseKey.length}');
  
  await Supabase.initialize(
    url: supabaseUrl,
    publishableKey: supabaseKey,
  );
  print('--- HELARATE DEBUG: SUPABASE INICIALIZADO ---');
  
  // Inicialización de Inyector de Dependencias
  setupServiceLocator();

  await initializeDateFormatting('es_MX', null);

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
    return MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>(
          create: (context) => AuthBloc(
            authRepository: getIt<AuthRepository>(),
          )..add(AppStarted()),
        ),
        BlocProvider<InventarioBloc>(
          create: (context) => InventarioBloc(
            insumoRepository: getIt<InsumoRepository>(),
          )..add(LoadInventario()),
        ),
        BlocProvider<VentaBloc>(
          create: (context) => VentaBloc(
            ventaRepository: getIt<VentaRepository>(),
          )..add(LoadVentasEvent()),
        ),
        BlocProvider<DashboardBloc>(
          create: (context) => DashboardBloc(
            insumoRepository: getIt<InsumoRepository>(),
            ventaRepository: getIt<VentaRepository>(),
          )..add(LoadDashboardEvent()),
        ),
      ],
      child: MaterialApp(
        title: 'Mi Nevería',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.theme,
        home: BlocBuilder<AuthBloc, AuthState>(
          builder: (context, state) {
            if (state is Authenticated) {
              return const MainNavigation();
            }
            if (state is Unauthenticated || state is AuthFailure) {
              return const LoginScreen();
            }
            return const Scaffold(
              body: Center(
                child: CircularProgressIndicator(),
              ),
            );
          },
        ),
      ),
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
    final width = MediaQuery.of(context).size.width;
    final isLargeScreen = width >= 800;

    final authState = context.watch<AuthBloc>().state;
    final isEmployee = authState is Authenticated && authState.usuario.isEmployee;

    return Scaffold(
      body: Row(
        children: [
          if (isLargeScreen) _buildWebSidebar(isEmployee),
          Expanded(
            child: IndexedStack(
              index: _currentIndex,
              children: _screens,
            ),
          ),
        ],
      ),
      bottomNavigationBar: isLargeScreen
          ? null
          : Container(
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
                      if (!isEmployee)
                        _navItem(4, Icons.bar_chart_rounded,
                            Icons.bar_chart_outlined, 'Stats'),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildWebSidebar(bool isEmployee) {
    final authState = context.read<AuthBloc>().state;
    return Container(
      width: 250,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(4, 0),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
            child: Row(
              children: [
                ShaderMask(
                  shaderCallback: (bounds) => AppTheme.primaryGradient.createShader(bounds),
                  child: const Icon(
                    Icons.icecream_rounded,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Helarate',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                const Text(
                  ' 🍦',
                  style: TextStyle(fontSize: 18),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _sidebarItem(0, Icons.home_rounded, Icons.home_outlined, 'Inicio'),
                const SizedBox(height: 8),
                _sidebarItem(1, Icons.inventory_2_rounded,
                    Icons.inventory_2_outlined, 'Insumos'),
                const SizedBox(height: 8),
                _sidebarItem(
                    2, Icons.icecream_rounded, Icons.icecream_outlined, 'Nieves'),
                const SizedBox(height: 8),
                _sidebarItem(3, Icons.point_of_sale_rounded,
                    Icons.point_of_sale_outlined, 'Ventas'),
                const SizedBox(height: 8),
                if (!isEmployee) ...[
                  _sidebarItem(4, Icons.bar_chart_rounded,
                      Icons.bar_chart_outlined, 'Stats'),
                  const SizedBox(height: 8),
                ],
                GestureDetector(
                  onTap: () {
                    if (authState is Authenticated) {
                      PerfilDialog.show(context, authState.usuario);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.account_circle_rounded,
                          color: AppTheme.textPrimary,
                          size: 22,
                        ),
                        SizedBox(width: 12),
                        Text(
                          'Mi Perfil / ARCO',
                          style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Divider(height: 32, thickness: 1),
                GestureDetector(
                  onTap: () {
                    context.read<AuthBloc>().add(SignOutRequested());
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.logout_rounded,
                          color: AppTheme.secondary,
                          size: 22,
                        ),
                        SizedBox(width: 12),
                        Text(
                          'Cerrar Sesión',
                          style: TextStyle(
                            color: AppTheme.secondary,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'v1.0.0',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sidebarItem(
      int index, IconData activeIcon, IconData inactiveIcon, String label) {
    final isActive = _currentIndex == index;
    return GestureDetector(
      onTap: () => _onTabTap(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: isActive ? AppTheme.primaryGradient : null,
          color: isActive ? null : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              isActive ? activeIcon : inactiveIcon,
              color: isActive ? Colors.white : AppTheme.textSecondary,
              size: 22,
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                color: isActive ? Colors.white : AppTheme.textPrimary,
                fontSize: 14,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
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
