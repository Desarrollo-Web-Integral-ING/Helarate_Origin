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
import 'core/permissions/permiso.dart';
import 'core/permissions/permission_service.dart';
import 'core/widgets/app_toast.dart';
import 'presentation/screens/hardware_screen.dart';
import 'presentation/screens/turnos_screen.dart';
import 'presentation/screens/permisos_screen.dart';
import 'presentation/widgets/permission_gate.dart';
import 'core/widgets/app_loader.dart';

import 'package:flutter/foundation.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (kIsWeb) {
    try {
      // Lector ZXing incluido en web/zxing (sin depender de CDN externos, que
      // pueden estar bloqueados por la red o por extensiones del navegador).
      MobileScannerPlatform.instance.setBarcodeLibraryScriptUrl('zxing/zxing-library.min.js');
      MobileScannerPlatform.instance.setWebBarcodeReader(WebBarcodeReader.zxingJs);
    } catch (_) {}
  }

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
      child: BlocListener<AuthBloc, AuthState>(
        listenWhen: (prev, next) =>
            (prev is Authenticated) != (next is Authenticated) ||
            (prev is Authenticated &&
                next is Authenticated &&
                (prev.usuario.id != next.usuario.id || prev.usuario.rol != next.usuario.rol)),
        listener: (context, state) {
          final perms = getIt<PermissionService>();
          if (state is Authenticated) {
            perms.load(state.usuario);
          } else {
            perms.clear();
          }
        },
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

/// Destino del menú "Más" en móvil.
class _Destino {
  final int index; // -1 = abrir Equipos de caja
  final IconData icon;
  final String label;
  const _Destino(this.index, this.icon, this.label);
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;
  bool _isSidebarCollapsed = false;
  final PermissionService _perms = getIt<PermissionService>();

  // 0 Inicio, 1 Insumos, 2 Catálogo, 3 Ventas, 4 Stats, 5 Usuarios,
  // 6 Personalizar, 7 Campos personalizados, 8 Turnos, 9 Permisos
  final _keys = List.generate(10, (_) => GlobalKey());

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
      TurnosScreen(key: _keys[8]),
      PermisosScreen(key: _keys[9]),
    ];
  }

  /// Permiso que protege cada vista (Turnos y Permisos se protegen solas).
  Permiso? _permisoDeTab(int i) {
    switch (i) {
      case 0:
        return Permiso.dashboardVer;
      case 1:
        return Permiso.insumosVer;
      case 2:
        return Permiso.catalogoVer;
      case 3:
        return Permiso.ventasVer;
      case 4:
        return Permiso.estadisticasVer;
      case 5:
        return Permiso.usuariosVer;
      case 6:
      case 7:
        return Permiso.personalizacionVer;
      default:
        return null;
    }
  }

  bool _puedeVer(int i) {
    if (i == 8) return _perms.canAny(const [Permiso.turnosPropios, Permiso.turnosAdministrar]);
    if (i == 9) return _perms.can(Permiso.permisosAdministrar);
    final p = _permisoDeTab(i);
    return p != null && _perms.can(p);
  }

  int? get _primeraPermitida {
    for (final i in const [0, 3, 1, 2, 4, 8, 5, 9, 6, 7]) {
      if (_puedeVer(i)) return i;
    }
    return null;
  }

  void _irA(int index) {
    if (_currentIndex == index) return;
    setState(() => _currentIndex = index);
    activeTabNotifier.value = index;
  }

  void _onTabTap(int index) {
    if (!_puedeVer(index)) {
      AppToast.showWarning(context, 'No tienes acceso a esta sección.', title: 'Acceso restringido');
      return;
    }
    _irA(index);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _perms,
      builder: (context, _) {
        if (!_perms.cargado) {
          return const AppSplash(message: 'Cargando permisos...');
        }
        final destino = _primeraPermitida;
        if (destino == null) return const AccessDeniedView();

        // Si el permiso de la vista actual se quitó, pasa a una permitida.
        if (!_puedeVer(_currentIndex)) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && !_puedeVer(_currentIndex)) _irA(destino);
          });
        }
        return _scaffold(context);
      },
    );
  }

  Widget _scaffold(BuildContext context) {
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
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: _itemsMovil(),
                  ),
                ),
              ),
            ),
    );
  }

  /// Opciones de la barra inferior (solo las permitidas) + "Más".
  List<Widget> _itemsMovil() {
    final items = <Widget>[
      if (_puedeVer(0)) _navItem(0, Icons.home_rounded, Icons.home_outlined, 'Inicio'),
      if (_puedeVer(1)) _navItem(1, Icons.inventory_2_rounded, Icons.inventory_2_outlined, 'Insumos'),
      if (_puedeVer(2)) _navItem(2, Icons.shopping_bag_rounded, Icons.shopping_bag_outlined, 'Catálogo'),
      if (_puedeVer(3)) _navItem(3, Icons.point_of_sale_rounded, Icons.point_of_sale_outlined, 'Ventas'),
      if (_puedeVer(4)) _navItem(4, Icons.bar_chart_rounded, Icons.bar_chart_outlined, 'Stats'),
      if (_puedeVer(8)) _navItem(8, Icons.timer_rounded, Icons.timer_outlined, 'Turnos'),
    ];
    if (_destinosMas().isNotEmpty) items.add(_navMas());
    // FittedBox evita desbordes en pantallas angostas.
    return [for (final w in items) Flexible(child: FittedBox(fit: BoxFit.scaleDown, child: w))];
  }

  List<_Destino> _destinosMas() => [
        if (_puedeVer(5)) const _Destino(5, Icons.people_alt_rounded, 'Usuarios'),
        if (_puedeVer(9)) const _Destino(9, Icons.admin_panel_settings_rounded, 'Permisos'),
        if (_puedeVer(6)) const _Destino(6, Icons.palette_rounded, 'Personalizar negocio'),
        if (_puedeVer(7)) const _Destino(7, Icons.tune_rounded, 'Campos personalizados'),
        if (_perms.can(Permiso.equiposConfigurar))
          const _Destino(-1, Icons.print_rounded, 'Equipos de caja'),
      ];

  void _abrirMas() {
    final destinos = _destinosMas();
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final d in destinos)
              ListTile(
                leading: Icon(d.icon),
                title: Text(d.label),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () {
                  Navigator.pop(ctx);
                  if (d.index == -1) {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const HardwareScreen()));
                  } else {
                    _onTabTap(d.index);
                  }
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _navMas() {
    final activo = const [5, 6, 7, 9].contains(_currentIndex);
    return _navBoton(
      activo: activo,
      icono: activo ? Icons.grid_view_rounded : Icons.grid_view_outlined,
      label: 'Más',
      onTap: _abrirMas,
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
            child: RepaintBoundary(
              child: _permisoDeTab(i) == null
                  ? _screens[i] // Turnos y Permisos validan por dentro
                  : PermissionGate(permiso: _permisoDeTab(i)!, child: _screens[i]),
            ),
          ),
      ],
    );
  }

  Widget _navItem(int index, IconData activeIcon, IconData inactiveIcon, String label) {
    return _navBoton(
      activo: _currentIndex == index,
      icono: _currentIndex == index ? activeIcon : inactiveIcon,
      label: label,
      onTap: () => _onTabTap(index),
    );
  }

  Widget _navBoton({
    required bool activo,
    required IconData icono,
    required String label,
    required VoidCallback onTap,
  }) {
    final authState = context.read<AuthBloc>().state;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    Color brandColor = AppTheme.primary;
    if (authState is Authenticated && authState.tenant != null) {
      brandColor = AppTheme.parseHexColor(authState.tenant!.colorPrimario);
    }
    final primaryGradient = AppTheme.createCustomGradient(brandColor);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          gradient: activo ? primaryGradient : null,
          borderRadius: BorderRadius.circular(14),
          border: activo ? Border.all(color: Colors.white.withValues(alpha: 0.15), width: 1) : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icono,
              color: activo
                  ? Colors.white
                  : (isDark ? const Color(0xFF94A3B8) : AppTheme.textSecondary),
              size: 22,
            ),
            if (activo) ...[
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
