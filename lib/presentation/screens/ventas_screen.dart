import '../widgets/barcode_scanner_screen.dart';
import 'dart:io' as io;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/models/insumo.dart';
import '../../domain/models/venta_model.dart';
import '../blocs/venta/venta_bloc.dart';
import '../blocs/venta/venta_event.dart';
import '../blocs/venta/venta_state.dart';
import '../blocs/inventario/inventario_bloc.dart';
import '../blocs/inventario/inventario_event.dart';
import '../blocs/inventario/inventario_state.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/money.dart';
import '../../core/widgets/app_toast.dart';
import '../../core/widgets/app_loader.dart';
import '../widgets/receipt_dialog.dart';
import '../blocs/auth/auth_bloc.dart';
import '../blocs/auth/auth_state.dart';
import '../../core/di/service_locator.dart';
import '../../core/hardware/hardware_service.dart';
import '../../core/hardware/hardware_settings.dart';
import 'hardware_screen.dart';
import '../../core/permissions/permiso.dart';
import '../../core/permissions/permission_service.dart';
import '../widgets/permission_gate.dart';
import '../../core/widgets/indexed_stack_resume.dart';

class _CartItem {
  final Insumo producto;
  double cantidad;

  _CartItem({required this.producto, required this.cantidad});

  double get subtotal => producto.precioVenta * cantidad;
  double get costoTotal => producto.costoUnitario * cantidad;
}

class VentasScreen extends StatefulWidget {
  const VentasScreen({super.key});

  @override
  State<VentasScreen> createState() => _VentasScreenState();
}

class _VentasScreenState extends State<VentasScreen> with SingleTickerProviderStateMixin {
  NumberFormat get _fmt => Money.of(context);
  List<VentaModel> _ventas = [];
  List<Insumo> _productos = [];
  String _filtroFecha = 'Hoy';
  static const _filtros = ['Hoy', 'Semana', 'Mes', 'Todo'];

  final List<_CartItem> _carrito = [];
  late TabController _tabController;
  final _busquedaCtrl = TextEditingController();
  final _busquedaFocus = FocusNode();
  String _busqueda = '';
  bool _pilaAbierta = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    activeTabNotifier.addListener(_onTabChange);
  }

  void _onTabChange() {
    if (activeTabNotifier.value == 3) {
      _dispatchLoadVentas();
      // Los productos se necesitan para vender y para buscar por código.
      context.read<InventarioBloc>().add(LoadInventario());
      _focusScanner();
    }
  }

  @override
  void dispose() {
    activeTabNotifier.removeListener(_onTabChange);
    _tabController.dispose();
    _busquedaCtrl.dispose();
    _busquedaFocus.dispose();
    super.dispose();
  }

  void _dispatchLoadVentas() {
    final now = DateTime.now();
    switch (_filtroFecha) {
      case 'Hoy':
        context.read<VentaBloc>().add(LoadVentasEvent(date: now));
        break;
      case 'Semana':
        context.read<VentaBloc>().add(LoadVentasEvent(
          startDate: now.subtract(const Duration(days: 7)),
          endDate: now,
        ));
        break;
      case 'Mes':
        context.read<VentaBloc>().add(LoadVentasEvent(
          startDate: DateTime(now.year, now.month, 1),
          endDate: DateTime(now.year, now.month + 1, 0, 23, 59, 59),
        ));
        break;
      case 'Todo':
        context.read<VentaBloc>().add(LoadVentasEvent(
          startDate: DateTime(2020, 1, 1),
          endDate: DateTime(2030, 12, 31),
        ));
        break;
    }
  }

  List<VentaModel> get _ventasFiltradas => _ventas;
  double get _totalFiltrado => _ventasFiltradas.fold(0.0, (sum, v) => sum + v.totalIngresos);

  void _updateCantidad(Insumo producto, int delta) {
    setState(() {
      final idx = _carrito.indexWhere((i) => i.producto.id == producto.id);
      if (idx >= 0) {
        final item = _carrito[idx];
        if (item.cantidad + delta > producto.stockActual) {
          AppToast.showWarning(context, 'Stock insuficiente de ${producto.nombre}');
          return;
        }
        if (item.cantidad + delta <= 0) {
          _carrito.removeAt(idx);
        } else {
          item.cantidad += delta;
          // El último producto tocado/escaneado queda al tope de la pila.
          if (delta > 0 && idx != _carrito.length - 1) {
            _carrito.removeAt(idx);
            _carrito.add(item);
          }
        }
      } else if (delta > 0) {
        if (1 > producto.stockActual) {
          AppToast.showWarning(context, 'Stock insuficiente de ${producto.nombre}');
          return;
        }
        _carrito.add(_CartItem(producto: producto, cantidad: 1));
      }
    });
  }

  /// Fija una cantidad exacta (p. ej. 12 piezas escaneadas una sola vez).
  void _setCantidad(Insumo producto, int cantidad) {
    setState(() {
      final idx = _carrito.indexWhere((i) => i.producto.id == producto.id);
      if (idx < 0) return;
      if (cantidad <= 0) {
        _carrito.removeAt(idx);
        return;
      }
      var q = cantidad;
      if (q > producto.stockActual) {
        q = producto.stockActual.toInt();
        AppToast.showWarning(
          context,
          'Solo hay $q disponibles de ${producto.nombre}',
          title: 'Stock insuficiente',
        );
      }
      _carrito[idx].cantidad = q.toDouble();
    });
  }

  Future<void> _pedirCantidad(_CartItem item) async {
    final ctrl = TextEditingController(text: item.cantidad.toInt().toString());
    ctrl.selection = TextSelection(baseOffset: 0, extentOffset: ctrl.text.length);
    final result = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(item.producto.nombre, maxLines: 2, overflow: TextOverflow.ellipsis),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'Cantidad',
            helperText: 'Disponibles: ${item.producto.stockActual.toInt()}',
          ),
          onSubmitted: (v) => Navigator.pop(ctx, int.tryParse(v)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, int.tryParse(ctrl.text)),
            child: const Text('Aplicar'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (result != null) _setCantidad(item.producto, result);
    _busquedaFocus.requestFocus();
  }

  List<Insumo> get _productosFiltrados {
    final q = _busqueda.trim().toLowerCase();
    if (q.isEmpty) return _productos;
    return _productos.where((p) {
      final texto = '${p.nombre} ${p.sabor ?? ''} ${p.categoria} ${p.codigoBarras ?? ''} ${p.sku ?? ''}'.toLowerCase();
      return texto.contains(q);
    }).toList();
  }

  /// Un lector de código de barras/QR (USB o Bluetooth) escribe el código como
  /// un teclado y envía Enter. Si el código coincide con un producto, se agrega
  /// al carrito y el campo queda listo para el siguiente escaneo.
  HardwareSettings get _hw => getIt<HardwareService>().settings;

  /// Deja el cursor en el campo de escaneo (si la terminal lo tiene activado).
  void _focusScanner() {
    // En celular no auto-enfocar para no abrir el teclado sobre los productos
    final isMobile = MediaQuery.of(context).size.width < 700;
    if (!isMobile && _hw.scannerEnabled && _hw.scannerFocusOnOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _busquedaFocus.requestFocus();
      });
    }
  }

  // ---------- Búsqueda por código de barras / QR ----------

  String _normCode(String s) => s.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '');

  /// Compara códigos de forma tolerante: ignora espacios y mayúsculas, y trata
  /// igual un EAN-13 y su UPC-A (cero inicial de diferencia).
  bool _sameCode(String? stored, String scanned) {
    if (stored == null || stored.trim().isEmpty) return false;
    final a = _normCode(stored);
    final b = _normCode(scanned);
    if (a == b) return true;
    final digits = RegExp(r'^\d+$');
    if (digits.hasMatch(a) && digits.hasMatch(b)) {
      return a.replaceFirst(RegExp(r'^0+'), '') == b.replaceFirst(RegExp(r'^0+'), '');
    }
    return false;
  }

  Insumo? _buscarPorCodigo(String code) {
    for (final p in _productos) {
      if (_sameCode(p.codigoBarras, code) || _sameCode(p.sku, code)) return p;
    }
    return null;
  }

  /// Agrega al carrito el producto que corresponde al código. Lo usan el lector
  /// USB/Bluetooth, la cámara y el campo de búsqueda.
  ScanOutcome _agregarPorCodigo(String code) {
    final p = _buscarPorCodigo(code);
    if (p == null) {
      return ScanOutcome(found: false, title: code);
    }
    final antes = _getCantidad(p);
    _updateCantidad(p, 1);
    final ahora = _getCantidad(p);
    final sabor = (p.sabor != null && p.sabor!.isNotEmpty) ? ' - ${p.sabor}' : '';
    final nombre = '${p.nombre}$sabor';
    if (ahora == antes) {
      // _updateCantidad ya avisó que no hay stock suficiente.
      return ScanOutcome(
        found: true,
        title: nombre,
        quantity: ahora,
        subtitle: 'Sin stock suficiente',
      );
    }
    return ScanOutcome(
      found: true,
      title: nombre,
      quantity: ahora,
      subtitle: _fmt.format(p.precioVenta),
    );
  }

  Future<void> _abrirCamaraEscaner() async {
    // Asegura que los productos estén cargados antes de escanear.
    final inv = context.read<InventarioBloc>().state;
    if (inv is! InventarioLoaded) {
      context.read<InventarioBloc>().add(LoadInventario());
    }
    final noEncontrado = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => BarcodeScannerScreen(
          // Cada código leído se agrega a la caja; con el modo continuo la
          // cámara sigue abierta mostrando lo que se va agregando.
          onCode: _agregarPorCodigo,
        ),
      ),
    );
    if (!mounted) return;
    // En modo "un código" el escáner devuelve el código solo si NO existe.
    if (noEncontrado != null && noEncontrado.isNotEmpty && _buscarPorCodigo(noEncontrado) == null) {
      setState(() {
        _busquedaCtrl.text = noEncontrado;
        _busqueda = noEncontrado;
      });
      AppToast.showWarning(context, 'No hay productos con el código "$noEncontrado"',
          title: 'Sin coincidencias');
    }
    _focusScanner();
  }

  void _onScanSubmit(String value) {
    final code = value.trim();
    if (code.isEmpty) return;
    // Con el lector desactivado, o con un código más corto que el mínimo
    // configurado, Enter solo busca (no agrega al carrito).
    if (!_hw.scannerEnabled || !_hw.scannerAutoAdd || code.length < _hw.scannerMinLength) {
      _busquedaFocus.requestFocus();
      return;
    }
    final outcome = _agregarPorCodigo(code);
    if (outcome.found) {
      _busquedaCtrl.clear();
      setState(() => _busqueda = '');
    } else if (_productosFiltrados.isEmpty) {
      AppToast.showWarning(context, 'No hay productos con el código "$code"', title: 'Sin coincidencias');
    }
    _busquedaFocus.requestFocus();
  }

  /// Traduce errores técnicos de la base de datos a mensajes entendibles.
  String _mensajeError(String raw) {
    final r = raw.toLowerCase();
    if (r.contains('pgrst204') || r.contains('schema cache') || r.contains('column')) {
      return 'La base de datos no está actualizada con las columnas de ventas. '
          'Ejecuta migracion_alinear_esquema_app.sql en Supabase y reintenta.';
    }
    if (r.contains('socket') || r.contains('network') || r.contains('timeout') || r.contains('failed host')) {
      return 'Sin conexión con el servidor. Revisa tu internet y reintenta.';
    }
    if (r.contains('row-level security') || r.contains('42501')) {
      return 'Tu usuario no tiene permiso para registrar ventas.';
    }
    return raw.replaceAll('Exception: ', '');
  }

  int _getCantidad(Insumo producto) {
    final idx = _carrito.indexWhere((i) => i.producto.id == producto.id);
    return idx >= 0 ? _carrito[idx].cantidad.toInt() : 0;
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<InventarioBloc, InventarioState>(
      builder: (context, invState) {
        if (invState is InventarioLoaded) {
          _productos = invState.insumos.where((i) => i.tipo == TipoInsumo.productoVenta).toList();
        }
        return BlocBuilder<VentaBloc, VentaState>(
          builder: (context, state) {
            if (state is VentasLoaded) {
              _ventas = state.ventas;
            }
            return Scaffold(
              // backgroundColor eliminado para respetar scaffoldBackgroundColor del tema
              appBar: AppBar(
                title: const Text('Ventas'),
                actions: [_buildHardwareActions()],
                bottom: TabBar(
                  labelColor: Theme.of(context).brightness == Brightness.dark ? Color(0xFF38BDF8) : context.brand,
                  unselectedLabelColor: Theme.of(context).brightness == Brightness.dark ? Color(0xFF94A3B8) : context.textMuted,
                  indicatorColor: Theme.of(context).brightness == Brightness.dark ? Color(0xFF38BDF8) : context.brand,
                  controller: _tabController,
                  tabs: const [
                    Tab(icon: Icon(Icons.storefront), text: 'Tienda'),
                    Tab(icon: Icon(Icons.receipt_long), text: 'Historial'),
                  ],
                ),
              ),
              body: TabBarView(
                controller: _tabController,
                children: [
                  _buildTiendaTab(),
                  _buildHistorialTab(state),
                ],
              ),
            );
          },
        );
      },
    );
  }

  /// Estado de la impresora + apertura manual del cajón + acceso a la configuración.
  Widget _buildHardwareActions() {
    final hw = getIt<HardwareService>();
    return ListenableBuilder(
      listenable: hw,
      builder: (context, _) {
        final color = switch (hw.status) {
          PrinterStatus.ready => Colors.green,
          PrinterStatus.unverified => Colors.blue,
          PrinterStatus.offline => Colors.red,
          PrinterStatus.notConfigured => null,
        };
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (hw.settings.printerConnection == PrinterConnection.network &&
                hw.status == PrinterStatus.ready)
              IconButton(
                tooltip: 'Abrir cajón',
                icon: const Icon(Icons.lock_open_rounded),
                onPressed: () async {
                  final r = await hw.openDrawer();
                  if (!mounted) return;
                  if (r.ok) {
                    AppToast.showSuccess(context, r.message);
                  } else {
                    AppToast.showError(context, r.message, title: 'Cajón');
                  }
                },
              ),
            IconButton(
              tooltip: color == null ? 'Configurar equipos de caja' : hw.statusDetail,
              onPressed: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const HardwareScreen()),
                );
                _focusScanner();
              },
              icon: Stack(
                clipBehavior: Clip.none,
                children: [
                  const Icon(Icons.print_rounded),
                  if (color != null)
                    Positioned(
                      right: -2,
                      top: -2,
                      child: Container(
                        width: 9,
                        height: 9,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(color: context.surfaceColor, width: 1.5),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  // ================== TAB: TIENDA (POS) ==================

  Widget _buildTiendaTab() {
    if (_productos.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined, size: 56, color: Colors.grey[300]),
            const SizedBox(height: 12),
            Text(
              'No hay productos registrados para venta.\nAgrega productos en el Inventario primero.',
              textAlign: TextAlign.center,
              style: TextStyle(color: context.textMuted),
            ),
          ],
        ),
      );
    }

    final totalIngresos = _carrito.fold(0.0, (sum, i) => sum + i.subtotal);
    final totalPiezas = _carrito.fold(0.0, (sum, i) => sum + i.cantidad).toInt();

    final productos = _productosFiltrados;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: TextField(
            controller: _busquedaCtrl,
            focusNode: _busquedaFocus,
            textInputAction: TextInputAction.done,
            onChanged: (v) => setState(() => _busqueda = v),
            onSubmitted: _onScanSubmit,
            decoration: InputDecoration(
              hintText: _hw.scannerEnabled ? 'Buscar o escanear código de barras / QR' : 'Buscar producto',
              prefixIcon: IconButton(icon: const Icon(Icons.qr_code_scanner_rounded), tooltip: 'Escanear con la cámara', onPressed: _abrirCamaraEscaner),
              suffixIcon: _busqueda.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () {
                        _busquedaCtrl.clear();
                        setState(() => _busqueda = '');
                      },
                    ),
            ),
          ),
        ),
        _buildPila(),
        Expanded(
          child: productos.isEmpty
              ? Center(
                  child: Text('Sin resultados para "$_busqueda"',
                      style: TextStyle(color: context.textMuted)),
                )
              : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: productos.length,
            itemBuilder: (context, index) {
              final p = productos[index];
              final cantidad = _getCantidad(p);
              final nombreCompleto = '${p.nombre}${p.sabor != null && p.sabor!.isNotEmpty ? " - " + p.sabor! : ""}';
              final bool hasImage = p.imagenPath != null && p.imagenPath!.isNotEmpty;

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: context.surfaceColor,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: cantidad > 0 ? context.brand.withValues(alpha: 0.2) : Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      spreadRadius: cantidad > 0 ? 1 : 0,
                    ),
                  ],
                  border: Border.all(
                    color: cantidad > 0 ? context.brand : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: Row(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: SizedBox(
                          width: 54,
                          height: 54,
                          child: hasImage
                              ? (p.imagenPath!.startsWith("http")
                                  ? Image.network(
                                      p.imagenPath!,
                                      fit: BoxFit.cover,
                                      errorBuilder: (c, e, s) => _buildPlaceholder(),
                                    )
                                  : kIsWeb
                                      ? _buildPlaceholder()
                                      : Image.file(
                                          io.File(p.imagenPath!),
                                          fit: BoxFit.cover,
                                          errorBuilder: (c, e, s) => _buildPlaceholder(),
                                        ))
                              : _buildPlaceholder(),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    nombreCompleto,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Theme.of(context).brightness == Brightness.dark ? Color(0xFFF8FAFC) : context.textMain),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _fmt.format(p.precioVenta),
                                    style: TextStyle(fontWeight: FontWeight.w800, color: context.brand, fontSize: 16),
                                  ),
                                  Text(
                                    'Disp: ${p.stockActual.toInt()} ${p.unidad}',
                                    style: const TextStyle(color: Colors.grey, fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (cantidad == 0)
                              ElevatedButton(
                                onPressed: p.stockActual > 0 ? () => _updateCantidad(p, 1) : null,
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                child: const Text('Agregar', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              )
                            else
                              Container(
                                decoration: BoxDecoration(
                                  color: context.brand.withValues(alpha: 0.05),
                                  borderRadius: BorderRadius.circular(20)
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    GestureDetector(
                                      onTap: () => _updateCantidad(p, -1),
                                      child: Container(
                                        decoration: BoxDecoration(color: Colors.red.shade100, shape: BoxShape.circle),
                                        padding: const EdgeInsets.all(6),
                                        child: const Icon(Icons.remove, size: 16, color: Colors.red),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 12),
                                      child: Text('$cantidad', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                    ),
                                    GestureDetector(
                                      onTap: p.stockActual > cantidad ? () => _updateCantidad(p, 1) : null,
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: p.stockActual > cantidad ? context.brand.withValues(alpha: 0.2) : Colors.grey.shade200, 
                                          shape: BoxShape.circle
                                        ),
                                        padding: const EdgeInsets.all(6),
                                        child: Icon(Icons.add, size: 16, color: p.stockActual > cantidad ? context.brand : Colors.grey),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        
        // --- BOTTOM CART SUMMARY ---
        if (_carrito.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.surfaceColor,
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -4))],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('$totalPiezas artículos', style: const TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.w600)),
                      Text(_fmt.format(totalIngresos), style: TextStyle(color: context.textMain, fontSize: 20, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const Spacer(),
                  ElevatedButton.icon(
                    onPressed: () => _showCobrarModal(),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      backgroundColor: context.brand,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.shopping_cart_checkout, color: Colors.white),
                    label: const Text('Ir a Pagar', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  )
                ],
              ),
            ),
          )
      ],
    );
  }

  // ---- Pila de caja: lo último escaneado/agregado queda arriba ----

  Widget _buildPila() {
    if (_carrito.isEmpty) return const SizedBox.shrink();
    final items = _carrito.reversed.toList();
    final total = _carrito.fold(0.0, (s, i) => s + i.subtotal);
    final piezas = _carrito.fold(0.0, (s, i) => s + i.cantidad).toInt();
    final maxH = (MediaQuery.of(context).size.height * 0.34).clamp(140.0, 300.0);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.brand.withValues(alpha: 0.45)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: () => setState(() => _pilaAbierta = !_pilaAbierta),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
              child: Row(
                children: [
                  Icon(Icons.layers_rounded, color: context.brand, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'En caja · $piezas pzs · ${_fmt.format(total)}',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() => _carrito.clear());
                      _busquedaFocus.requestFocus();
                    },
                    child: const Text('Vaciar'),
                  ),
                  Icon(_pilaAbierta ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                      color: context.textMuted),
                  const SizedBox(width: 4),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: _pilaAbierta
                ? ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: maxH),
                    child: ListView.builder(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      itemCount: items.length,
                      itemBuilder: (_, i) => _pilaRow(items[i], isLast: i == 0),
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }

  Widget _pilaRow(_CartItem item, {required bool isLast}) {
    final p = item.producto;
    final nombre = '${p.nombre}${p.sabor != null && p.sabor!.isNotEmpty ? " - ${p.sabor}" : ""}';
    final q = item.cantidad.toInt();

    Widget stepButton(IconData icon, VoidCallback? onTap, Color color) => InkResponse(
          onTap: onTap,
          radius: 22,
          child: Container(
            padding: EdgeInsets.all(isLast ? 8 : 6),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.14), shape: BoxShape.circle),
            child: Icon(icon, size: isLast ? 20 : 16, color: onTap == null ? context.textMuted : color),
          ),
        );

    return TweenAnimationBuilder<double>(
      key: ValueKey('pila_${p.id}'),
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      builder: (context, v, child) => Opacity(
        opacity: v,
        child: Transform.translate(offset: Offset(0, (1 - v) * -10), child: child),
      ),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 14, vertical: isLast ? 10 : 6),
        decoration: BoxDecoration(
          color: isLast ? context.brand.withValues(alpha: 0.10) : null,
          border: Border(top: BorderSide(color: context.borderColor)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isLast)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Text('ÚLTIMO AGREGADO',
                          style: TextStyle(
                              fontSize: 9.5,
                              letterSpacing: 0.6,
                              fontWeight: FontWeight.w800,
                              color: context.brand)),
                    ),
                  Text(nombre,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontWeight: isLast ? FontWeight.w700 : FontWeight.w600,
                          fontSize: isLast ? 15 : 13)),
                  Text('${_fmt.format(p.precioVenta)} c/u · ${_fmt.format(item.subtotal)}',
                      style: TextStyle(fontSize: 11.5, color: context.textMuted)),
                ],
              ),
            ),
            stepButton(Icons.remove_rounded, () => _updateCantidad(p, -1), Colors.red),
            // Toca el número para escribir la cantidad exacta.
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => _pedirCantidad(item),
              child: Container(
                constraints: BoxConstraints(minWidth: isLast ? 52 : 40),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                alignment: Alignment.center,
                child: Text('$q',
                    style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: isLast ? 20 : 15,
                        decoration: TextDecoration.underline,
                        decorationStyle: TextDecorationStyle.dotted)),
              ),
            ),
            stepButton(Icons.add_rounded,
                p.stockActual > item.cantidad ? () => _updateCantidad(p, 1) : null, context.brand),
            const SizedBox(width: 4),
            InkResponse(
              onTap: () => _setCantidad(p, 0),
              radius: 18,
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Icon(Icons.delete_outline_rounded, size: 18, color: context.textMuted),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: context.brand.withValues(alpha: 0.08),
      child: Center(child: Icon(Icons.icecream, size: 40, color: context.brand.withValues(alpha: 0.35))),
    );
  }

  void _showCobrarModal() {
    final montoRecibidoCtrl = TextEditingController();
    final screenContext = context;
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final totalIngresos = _carrito.fold(0.0, (sum, i) => sum + i.subtotal);

          return Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(ctx).size.height * 0.90,
            ),
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              top: 20, left: 20, right: 20,
            ),
            decoration: BoxDecoration(
              color: context.surfaceColor,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 16),
                const Text('Confirmar Venta', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: _carrito.length,
                    separatorBuilder: (_,__) => const Divider(height: 1),
                    itemBuilder: (context, idx) {
                      final item = _carrito[idx];
                      final nombre = '${item.producto.nombre}${item.producto.sabor != null && item.producto.sabor!.isNotEmpty ? " - " + item.producto.sabor! : ""}';
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(nombre, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                        subtitle: Text('${item.cantidad.toInt()} x ${_fmt.format(item.producto.precioVenta)}'),
                        trailing: Text(_fmt.format(item.subtotal), style: TextStyle(fontWeight: FontWeight.bold, color: context.brand)),
                      );
                    },
                  ),
                ),
                
                const Divider(thickness: 2),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total a Cobrar:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                    Text(_fmt.format(totalIngresos), style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: context.brand)),
                  ],
                ),
                const SizedBox(height: 16),
                
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: montoRecibidoCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          labelText: 'Efectivo Recibido',
                          prefixIcon: Icon(Icons.attach_money, color: context.brand, size: 20),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onChanged: (_) => setModalState(() {}),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: Builder(builder: (context) {
                        final montoRecibido = double.tryParse(montoRecibidoCtrl.text) ?? 0.0;
                        final cambio = montoRecibido - totalIngresos;
                        final isError = montoRecibido > 0 && cambio < 0;
                        final isOk = montoRecibido > 0 && cambio >= 0;

                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: (isError ? Colors.red : (isOk ? Colors.green : context.textMuted)).withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: (isError ? Colors.red : (isOk ? Colors.green : context.textMuted)).withValues(alpha: 0.35)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(isError ? 'Falta' : 'Cambio', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isError ? Colors.red.shade700 : context.textMuted)),
                              Text(
                                _fmt.format(montoRecibido > 0 ? cambio.abs() : 0),
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isError ? Colors.red.shade700 : (isOk ? Colors.green.shade700 : context.textMain)),
                              ),
                            ],
                          ),
                        );
                      }),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildMontoRapidoBtn('Exacto', totalIngresos, montoRecibidoCtrl, setModalState),
                      for (final m in const [50.0, 100.0, 200.0, 500.0]) ...[
                        const SizedBox(width: 8),
                        _buildMontoRapidoBtn('${Money.symbolOf(ctx)}${m.toInt()}', m, montoRecibidoCtrl, setModalState),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                
                SizedBox(
                  width: double.infinity,
                  child: Builder(builder: (context) {
                    final montoRecibido = double.tryParse(montoRecibidoCtrl.text) ?? 0.0;
                    final bool canSubmit = _carrito.isNotEmpty && (montoRecibido == 0 || montoRecibido >= totalIngresos);

                    return ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        backgroundColor: context.brand,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: (!canSubmit || isSubmitting) ? null : () async {
                        if (isSubmitting) return;
                        setModalState(() => isSubmitting = true);
                        
                        for (final item in _carrito) {
                          if (item.cantidad > item.producto.stockActual) {
                            AppToast.showError(context, 'Stock insuficiente en ${item.producto.nombre}');
                            setModalState(() => isSubmitting = false);
                            return;
                          }
                        }

                        final ventaId = const Uuid().v4();
                        final totalCostos = _carrito.fold(0.0, (sum, i) => sum + i.costoTotal);
                        final gananciaNeta = totalIngresos - totalCostos;

                        final detalles = _carrito.map((item) {
                          return DetalleVentaModel(
                            id: const Uuid().v4(),
                            ventaId: ventaId,
                            insumoId: item.producto.id,
                            insumoNombre: '${item.producto.nombre}${item.producto.sabor != null && item.producto.sabor!.isNotEmpty ? " - " + item.producto.sabor! : ""}',
                            cantidad: item.cantidad,
                            precioVentaUnitario: item.producto.precioVenta,
                            costoUnitario: item.producto.costoUnitario,
                          );
                        }).toList();

                        final venta = VentaModel(
                          id: ventaId,
                          fecha: DateTime.now(),
                          totalIngresos: totalIngresos,
                          totalCostos: totalCostos,
                          gananciaNeta: gananciaNeta,
                          detalles: detalles,
                        );

                        final ventaBloc = context.read<VentaBloc>();
                        final inventarioBloc = context.read<InventarioBloc>();

                        // Esperar el resultado real del guardado: solo si la venta
                        // quedó registrada se descuenta el stock y se muestra el ticket.
                        final resultado = ventaBloc.stream
                            .firstWhere((s) => s is VentaSuccess || s is VentaError)
                            .timeout(const Duration(seconds: 20));
                        ventaBloc.add(RegistrarVentaEvent(venta));

                        VentaState resultadoFinal;
                        try {
                          resultadoFinal = await resultado;
                        } catch (_) {
                          resultadoFinal = VentaError('Tiempo de espera agotado. Revisa tu conexión.');
                        }

                        if (resultadoFinal is VentaError) {
                          setModalState(() => isSubmitting = false);
                          if (mounted) {
                            AppToast.showError(
                              screenContext,
                              _mensajeError(resultadoFinal.message),
                              title: 'No se pudo guardar la venta',
                            );
                          }
                          return;
                        }

                        for (final item in _carrito) {
                          final nuevoStock = item.producto.stockActual - item.cantidad;
                          final prodActualizado = item.producto.copyWith(stockActual: nuevoStock, updatedAt: DateTime.now());
                          inventarioBloc.add(UpdateInsumoEvent(prodActualizado));
                        }
                        if (mounted) {
                          final efectivo = montoRecibido > 0 ? montoRecibido : null;
                          final authState = screenContext.read<AuthBloc>().state;
                          final tenant = authState is Authenticated ? authState.tenant : null;
                          final fmtVenta = Money.of(screenContext);
                          final hw = getIt<HardwareService>();

                          setState(() { _carrito.clear(); });
                          Navigator.pop(context);

                          // Imprime / abre el cajón SOLO si la terminal tiene el
                          // equipo configurado y conectado. No bloquea la venta.
                          hw
                              .onSaleCompleted(
                                venta: venta,
                                fmt: fmtVenta,
                                tenant: tenant,
                                efectivoRecibido: efectivo,
                              )
                              .then((avisos) {
                            if (!mounted) return;
                            for (final a in avisos) {
                              AppToast.showWarning(
                                screenContext,
                                '${a.message} La venta sí quedó guardada.',
                                title: 'Equipo de caja',
                              );
                            }
                          });

                          if (hw.settings.showReceiptOnScreen) {
                            ReceiptDialog.show(screenContext, venta, efectivoRecibido: efectivo);
                          } else {
                            AppToast.showSuccess(screenContext, 'Venta registrada');
                          }
                          _focusScanner();
                        }
                      },
                      child: isSubmitting
                          ? const AppSpinner(size: 22, color: Colors.white)
                          : const Text('Completar Venta', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    );
                  }),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildMontoRapidoBtn(String label, double monto, TextEditingController ctrl, StateSetter setModalState) {
    return ActionChip(
      label: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
      backgroundColor: context.surfaceColor,
      side: BorderSide(color: context.borderColor),
      onPressed: () => setModalState(() => ctrl.text = monto.toStringAsFixed(2)),
    );
  }

  // ================== TAB: HISTORIAL ==================

  Widget _buildHistorialTab(VentaState state) {
    if (!getIt<PermissionService>().can(Permiso.ventasHistorial)) {
      return const AccessDeniedView(permiso: Permiso.ventasHistorial);
    }
    if (state is VentaLoading || state is VentaInitial) {
      return const AppLoader(message: 'Cargando ventas...', icon: Icons.point_of_sale_rounded);
    }
    if (state is VentaError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off_rounded, size: 52, color: context.textMuted),
              const SizedBox(height: 12),
              Text(
                _mensajeError(state.message),
                textAlign: TextAlign.center,
                style: TextStyle(color: context.textMuted),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _dispatchLoadVentas,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }
    return Column(
      children: [
        _buildResumen(),
        _buildFiltros(),
        Expanded(child: _buildLista()),
      ],
    );
  }

  Widget _buildResumen() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AppTheme.salesGradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: const Color(0xFFFF6584).withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Total $_filtroFecha', style: const TextStyle(color: Colors.white70, fontSize: 12)),
              Text(_fmt.format(_totalFiltrado), style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w700)),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text('Ventas', style: TextStyle(color: Colors.white70, fontSize: 12)),
              Text('${_ventasFiltradas.length}', style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w700)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFiltros() {
    return SizedBox(
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _filtros.length,
        itemBuilder: (_, i) {
          final f = _filtros[i];
          final selected = f == _filtroFecha;
          return GestureDetector(
            onTap: () {
              setState(() => _filtroFecha = f);
              _dispatchLoadVentas();
            },
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              decoration: BoxDecoration(
                gradient: selected ? AppTheme.salesGradient : null,
                color: selected ? null : context.surfaceColor,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)],
              ),
              child: Text(
                f,
                style: TextStyle(
                  color: selected ? Colors.white : context.textMuted,
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLista() {
    if (_ventasFiltradas.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.shopping_cart_outlined, size: 56, color: Colors.grey[300]),
            const SizedBox(height: 12),
            Text(
              'Sin ventas en este período',
              style: TextStyle(color: context.textMuted, fontSize: 15),
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      itemCount: _ventasFiltradas.length,
      itemBuilder: (_, i) => _buildVentaCard(_ventasFiltradas[i]),
    );
  }

  Widget _buildVentaCard(VentaModel v) {
    final hasMultiple = v.detalles.length > 1;
    final totalPiezas = v.detalles.fold(0.0, (sum, d) => sum + d.cantidad).toInt();
    
    final titulo = v.detalles.isEmpty
        ? 'Venta'
        : hasMultiple
            ? '${v.detalles.length} productos ($totalPiezas pzs)'
            : (v.detalles.first.insumoNombre ?? 'Producto');

    final subtitulo = v.detalles.isEmpty
        ? DateFormat('dd/MM/yyyy HH:mm').format(v.fecha)
        : hasMultiple
            ? '${v.detalles.map((d) => "${d.insumoNombre ?? 'Producto'} x${d.cantidad.toInt()}").join(', ')}\n${DateFormat('dd/MM/yyyy HH:mm').format(v.fecha)}'
            : '${v.detalles.first.cantidad.toInt()} pzs · ${_fmt.format(v.detalles.first.precioVentaUnitario)} c/u · ${DateFormat('dd/MM/yyyy HH:mm').format(v.fecha)}';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        leading: Container(
          width: 44, height: 44,
          decoration: BoxDecoration(gradient: AppTheme.salesGradient, borderRadius: BorderRadius.circular(14)),
          child: const Icon(Icons.icecream_rounded, color: Colors.white, size: 22),
        ),
        title: Text(titulo, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: context.textMain)),
        subtitle: Text(subtitulo, style: TextStyle(fontSize: 12, color: context.textMuted)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_fmt.format(v.totalIngresos), style: TextStyle(fontWeight: FontWeight.w700, color: context.brand, fontSize: 15)),
            const SizedBox(width: 8),
            IfPermitted(
              permiso: Permiso.ventasEliminar,
              child: GestureDetector(
                onTap: () => _confirmDelete(v),
                child: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 20),
              ),
            ),
          ],
        ),
        children: [
          const Divider(height: 1),
          const SizedBox(height: 8),
          ...v.detalles.map((d) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: Text('• ${d.insumoNombre ?? "Producto"}', style: TextStyle(fontSize: 13, color: context.textMain))),
                    Text('${d.cantidad.toInt()} pzs × ${_fmt.format(d.precioVentaUnitario)} = ${_fmt.format(d.total)}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: context.textMuted)),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  void _confirmDelete(VentaModel v) {
    if (!puedeOAvisar(context, Permiso.ventasEliminar)) return;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Eliminar venta'),
        content: const Text('¿Eliminar este registro de venta?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              context.read<VentaBloc>().add(DeleteVentaEvent(v.id));
              if (mounted) {
                AppToast.showInfo(context, 'Registro de venta eliminado');
                Navigator.pop(context);
              }
            },
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }
}
