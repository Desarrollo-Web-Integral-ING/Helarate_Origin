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
import 'presentation/blocs/venta/venta_bloc.dart';
import 'presentation/blocs/dashboard/dashboard_bloc.dart';
import 'presentation/blocs/auth/auth_bloc.dart';
import 'presentation/blocs/auth/auth_event.dart';
import 'presentation/blocs/auth/auth_state.dart';
import 'presentation/screens/superadmin_screen.dart';
import 'presentation/screens/usuarios_screen.dart';
import 'presentation/screens/dashboard_screen.dart';
import 'presentation/screens/inventario_produccion_screen.dart';
import 'presentation/screens/inventario_venta_screen.dart';
import 'presentation/screens/ventas_screen.dart';
import 'presentation/screens/estadisticas_screen.dart';
import 'presentation/screens/login_screen.dart';
import 'presentation/screens/personalizacion_screen.dart';
import 'presentation/screens/campos_personalizados_screen.dart';
import 'presentation/widgets/web_sidebar.dart';
import 'presentation/widgets/privacy_gate.dart';

import 'core/widgets/indexed_stack_resume.dart';
import 'core/utils/money.dart';
import 'core/hardware/hardware_service.dart';
import 'core/widgets/app_loader.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Detección automática de entorno: DEV (Local/Docker) vs PROD (Nube)
  try {
    await dotenv.load(fileName: '.env');
  } catch (e) {
    debugPrint('Nota: .env no cargado: ');
  }

  final supabaseUrl = dotenv.env['SUPABASE_URL'] ?? '';
  final supabaseKey = dotenv.env['SUPABASE_ANON_KEY'] ?? '';
  debugPrint('🔌 [SUPABASE CONECTANDO A]: $supabaseUrl');

  await Supabase.initialize(
    url: supabaseUrl,
    publishableKey: supabaseKey,
  );

  // Inicialización de Inyector de Dependencias
  setupServiceLocator();
  // Equipos de esta terminal (impresora, cajón, lector). No bloquea el arranque si falla.
  try {
    await getIt<HardwareService>().load();
  } catch (e) {
    debugPrint('Hardware: $e');
  }

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
          ),
        ),
        BlocProvider<VentaBloc>(
          create: (context) => VentaBloc(
            ventaRepository: getIt<VentaRepository>(),
          ),
        ),
        BlocProvider<DashboardBloc>(
          create: (context) => DashboardBloc(
            insumoRepository: getIt<InsumoRepository>(),
            ventaRepository: getIt<VentaRepository>(),
          ),
        ),
      ],
      // Solo reconstruye el MaterialApp cuando cambia algo que afecta al tema,
      // al título, a la moneda o a la pantalla raíz. Evita trabas innecesarias.
      child: BlocBuilder<AuthBloc, AuthState>(
        buildWhen: (prev, next) => _appKey(prev) != _appKey(next),
        builder: (context, state) {
          String appTitle = 'Punto de Venta';
          Color brandColor = AppTheme.primary;
          bool isDark = state.isDarkMode;
          String moneda = '\$';

          if (state is Authenticated && state.tenant != null) {
            appTitle = state.tenant!.nombre;
            brandColor = AppTheme.parseHexColor(state.tenant!.colorPrimario);
            isDark = state.isDarkMode;
            moneda = state.tenant!.moneda;
          }

          final Widget home;
          if (state is Authenticated) {
            home = state.usuario.rol == 'superadmin'
                ? const PrivacyGate(key: ValueKey('superadmin'), child: SuperAdminScreen())
                : const PrivacyGate(key: ValueKey('main'), child: MainNavigation());
          } else if (state is AuthInitial) {
            home = const AppSplash(key: ValueKey('splash'));
          } else {
            home = const LoginScreen(key: ValueKey('login'));
          }

          return MaterialApp(
            title: appTitle,
            debugShowCheckedModeBanner: false,
            themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
            // Los ThemeData se memorizan en AppTheme: alternar claro/oscuro no
            // vuelve a construirlos.
            theme: AppTheme.getTheme(brandColor, false),
            darkTheme: AppTheme.getTheme(brandColor, true),
            themeAnimationDuration: const Duration(milliseconds: 280),
            themeAnimationCurve: Curves.easeInOut,
            builder: (context, child) =>
                MoneyScope(simbolo: moneda, child: child ?? const SizedBox()),
            home: AnimatedSwitcher(
              duration: const Duration(milliseconds: 350),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              transitionBuilder: (child, anim) => FadeTransition(
                opacity: anim,
                child: ScaleTransition(
                  scale: Tween(begin: 0.98, end: 1.0).animate(anim),
                  child: child,
                ),
              ),
              child: home,
            ),
          );
        },
      ),
    );
  }

  /// Clave que resume lo que realmente cambia la apariencia raíz de la app.
  static Object _appKey(AuthState s) {
    if (s is Authenticated) {
      final t = s.tenant;
      return (
        'auth',
        s.usuario.rol,
        t?.nombre,
        t?.colorPrimario,
        s.isDarkMode,
        t?.moneda,
      );
    }
    if (s is AuthInitial) return ('initial', s.isDarkMode);
    return ('unauth', s.isDarkMode);
  }
}
class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;
  bool _isSidebarCollapsed = false;

  final _keys = [
    GlobalKey(),
    GlobalKey(),
    GlobalKey(),
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
      UsuariosScreen(key: _keys[5]),
      PersonalizacionScreen(key: _keys[6]),
      CamposPersonalizadosScreen(key: _keys[7]),
    ];
  }

  void _onTabTap(int index) {
    if (_currentIndex == index) return;
    setState(() => _currentIndex = index);
    activeTabNotifier.value = index;
  }

  @override
  Widget build(BuildContext context) {
    final isWeb = MediaQuery.of(context).size.width >= 800;
    final authState = context.watch<AuthBloc>().state;
    final isEmployee =
        authState is Authenticated && authState.usuario.isEmployee;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final navBgColor = isDark ? const Color(0xFF0F172A) : Colors.white;
    final borderColor = isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06);

    return Scaffold(
      body: isWeb
          ? Row(
              children: [
                WebSidebar(
                  isCollapsed: _isSidebarCollapsed,
                  isEmployee: isEmployee,
                  currentIndex: _currentIndex,
                  onTabSelected: _onTabTap,
                  onToggleCollapse: () =>
                      setState(() => _isSidebarCollapsed = !_isSidebarCollapsed),
                ),
                Expanded(child: _buildTabs()),
              ],
            )
          : _buildTabs(),
      bottomNavigationBar: isWeb
          ? null
          : Container(
              decoration: BoxDecoration(
                color: navBgColor,
                border: Border(top: BorderSide(color: borderColor, width: 1)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.06),
                    blurRadius: 20,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SafeArea(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _navItem(
                          0, Icons.home_rounded, Icons.home_outlined, 'Inicio'),
                      _navItem(1, Icons.inventory_2_rounded,
                          Icons.inventory_2_outlined, 'Insumos'),
                      _navItem(2, Icons.shopping_bag_rounded,
                          Icons.shopping_bag_outlined, 'Catálogo'),
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

  /// Mantiene el estado de cada pestaña y anima la entrada de la activa.
  Widget _buildTabs() {
    return IndexedStack(
      index: _currentIndex,
      children: [
        for (var i = 0; i < _screens.length; i++)
          _TabFade(
            active: i == _currentIndex,
            child: RepaintBoundary(child: _screens[i]),
          ),
      ],
    );
  }

  Widget _navItem(
      int index, IconData activeIcon, IconData inactiveIcon, String label) {
    final isActive = _currentIndex == index;
    final authState = context.read<AuthBloc>().state;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    Color brandColor = AppTheme.primary;
    if (authState is Authenticated && authState.tenant != null) {
      brandColor = AppTheme.parseHexColor(authState.tenant!.colorPrimario);
    }
    final primaryGradient = AppTheme.createCustomGradient(brandColor);

    return GestureDetector(
      onTap: () => _onTabTap(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          gradient: isActive ? primaryGradient : null,
          borderRadius: BorderRadius.circular(14),
          border: isActive
              ? Border.all(color: Colors.white.withValues(alpha: 0.15), width: 1)
              : null,
        ),
        child: Row(
          children: [
            Icon(
              isActive ? activeIcon : inactiveIcon,
              color: isActive
                  ? Colors.white
                  : (isDark ? const Color(0xFF94A3B8) : AppTheme.textSecondary),
              size: 22,
            ),
            if (isActive) ...[
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Fundido + leve desplazamiento cada vez que una pestaña pasa a ser la activa.
class _TabFade extends StatefulWidget {
  final bool active;
  final Widget child;
  const _TabFade({required this.active, required this.child});

  @override
  State<_TabFade> createState() => _TabFadeState();
}

class _TabFadeState extends State<_TabFade>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 280),
    value: widget.active ? 1 : 0,
  );
  late final Animation<double> _fade =
      CurvedAnimation(parent: _c, curve: Curves.easeOut);
  late final Animation<Offset> _slide = Tween(
    begin: const Offset(0, 0.02),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _c, curve: Curves.easeOutCubic));

  @override
  void didUpdateWidget(_TabFade old) {
    super.didUpdateWidget(old);
    if (widget.active && !old.active) {
      _c.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}
