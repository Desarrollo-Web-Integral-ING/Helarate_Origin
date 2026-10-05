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
import '../../core/widgets/app_toast.dart';
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
  final _fmt = NumberFormat.currency(locale: 'es_MX', symbol: '\$');
  List<VentaModel> _ventas = [];
  List<Insumo> _productos = [];
  String _filtroFecha = 'Hoy';
  static const _filtros = ['Hoy', 'Semana', 'Mes', 'Todo'];

  final List<_CartItem> _carrito = [];
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    activeTabNotifier.addListener(_onTabChange);
  }

  void _onTabChange() {
    if (activeTabNotifier.value == 3) {
      _dispatchLoadVentas();
    }
  }

  @override
  void dispose() {
    activeTabNotifier.removeListener(_onTabChange);
    _tabController.dispose();
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
              backgroundColor: const Color(0xFFF8F9FA),
              appBar: AppBar(
                title: const Text('Ventas'),
                bottom: TabBar(
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

  // ================== TAB: TIENDA (POS) ==================

  Widget _buildTiendaTab() {
    if (_productos.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined, size: 56, color: Colors.grey[300]),
            const SizedBox(height: 12),
            const Text(
              'No hay productos registrados para venta.\nAgrega productos en el Inventario primero.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          ],
        ),
      );
    }

    final totalIngresos = _carrito.fold(0.0, (sum, i) => sum + i.subtotal);
    final totalPiezas = _carrito.fold(0.0, (sum, i) => sum + i.cantidad).toInt();

    return Column(
      children: [
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.65,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemCount: _productos.length,
            itemBuilder: (context, index) {
              final p = _productos[index];
              final cantidad = _getCantidad(p);
              final nombreCompleto = '${p.nombre}${p.sabor != null && p.sabor!.isNotEmpty ? " - " + p.sabor! : ""}';
              final bool hasImage = p.imagenPath != null && p.imagenPath!.isNotEmpty;

              return Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: cantidad > 0 ? AppTheme.primary.withOpacity(0.2) : Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      spreadRadius: cantidad > 0 ? 1 : 0,
                    ),
                  ],
                  border: Border.all(
                    color: cantidad > 0 ? AppTheme.primary : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      flex: 4,
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                        child: hasImage
                            ? Image.file(
                                File(p.imagenPath!),
                                fit: BoxFit.cover,
                                errorBuilder: (c,e,s) => _buildPlaceholder(),
                              )
                            : _buildPlaceholder(),
                      ),
                    ),
                    Expanded(
                      flex: 5,
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              nombreCompleto,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            const Spacer(),
                            Text(
                              _fmt.format(p.precioVenta),
                              style: const TextStyle(fontWeight: FontWeight.w800, color: AppTheme.primary, fontSize: 16),
                            ),
                            Text(
                              'Disp: ${p.stockActual.toInt()} ${p.unidad}',
                              style: const TextStyle(color: Colors.grey, fontSize: 11),
                            ),
                            const SizedBox(height: 6),
                            if (cantidad == 0)
                              SizedBox(
                                width: double.infinity,
                                height: 32,
                                child: ElevatedButton(
                                  onPressed: p.stockActual > 0 ? () => _updateCantidad(p, 1) : null,
                                  style: ElevatedButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  child: const Text('Agregar', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                ),
                              )
                            else
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  GestureDetector(
                                    onTap: () => _updateCantidad(p, -1),
                                    child: Container(
                                      decoration: BoxDecoration(color: Colors.red.shade100, shape: BoxShape.circle),
                                      padding: const EdgeInsets.all(6),
                                      child: const Icon(Icons.remove, size: 16, color: Colors.red),
                                    ),
                                  ),
                                  Text('$cantidad', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                  GestureDetector(
                                    onTap: p.stockActual > cantidad ? () => _updateCantidad(p, 1) : null,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: p.stockActual > cantidad ? AppTheme.primary.withOpacity(0.1) : Colors.grey.shade200, 
                                        shape: BoxShape.circle
                                      ),
                                      padding: const EdgeInsets.all(6),
                                      child: Icon(Icons.add, size: 16, color: p.stockActual > cantidad ? AppTheme.primary : Colors.grey),
                                    ),
                                  ),
                                ],
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
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -4))],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('$totalPiezas artículos', style: const TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.w600)),
                      Text(_fmt.format(totalIngresos), style: const TextStyle(color: AppTheme.textPrimary, fontSize: 20, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const Spacer(),
                  ElevatedButton.icon(
                    onPressed: () => _showCobrarModal(),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      backgroundColor: AppTheme.primary,
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

  Widget _buildPlaceholder() {
    return Container(
      color: Colors.grey.shade100,
      child: Center(child: Icon(Icons.icecream, size: 40, color: Colors.grey.shade300)),
    );
  }

  void _showCobrarModal() {
    final montoRecibidoCtrl = TextEditingController();
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
            decoration: const BoxDecoration(
              color: Colors.white,
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
                        trailing: Text(_fmt.format(item.subtotal), style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primary)),
                      );
                    },
                  ),
                ),
                
                const Divider(thickness: 2),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total a Cobrar:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                    Text(_fmt.format(totalIngresos), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: AppTheme.primary)),
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
                          prefixIcon: const Icon(Icons.attach_money, color: AppTheme.primary, size: 20),
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
                            color: isError ? Colors.red.shade50 : (isOk ? Colors.green.shade50 : Colors.grey.shade50),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: isError ? Colors.red.shade200 : (isOk ? Colors.green.shade300 : Colors.grey.shade300)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(isError ? 'Falta' : 'Cambio', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isError ? Colors.red.shade700 : AppTheme.textSecondary)),
                              Text(
                                montoRecibido > 0 ? _fmt.format(cambio.abs()) : '\$0.00',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isError ? Colors.red.shade700 : (isOk ? Colors.green.shade700 : AppTheme.textPrimary)),
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
                      const SizedBox(width: 8),
                      _buildMontoRapidoBtn('\$50', 50.0, montoRecibidoCtrl, setModalState),
                      const SizedBox(width: 8),
                      _buildMontoRapidoBtn('\$100', 100.0, montoRecibidoCtrl, setModalState),
                      const SizedBox(width: 8),
                      _buildMontoRapidoBtn('\$200', 200.0, montoRecibidoCtrl, setModalState),
                      const SizedBox(width: 8),
                      _buildMontoRapidoBtn('\$500', 500.0, montoRecibidoCtrl, setModalState),
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
                        backgroundColor: AppTheme.primary,
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

                        context.read<VentaBloc>().add(RegistrarVentaEvent(venta));

                        for (final item in _carrito) {
                          final nuevoStock = item.producto.stockActual - item.cantidad;
                          
                          // No copyWith available so recreate Insumo with updated stock
                          final prodActualizado = Insumo(
                            id: item.producto.id,
                            nombre: item.producto.nombre,
                            sabor: item.producto.sabor,
                            tamano: item.producto.tamano,
                            precioVenta: item.producto.precioVenta,
                            stockActual: nuevoStock,
                            stockMinimo: item.producto.stockMinimo,
                            categoria: item.producto.categoria,
                            imagenPath: item.producto.imagenPath,
                            tipo: item.producto.tipo,
                            costoUnitario: item.producto.costoUnitario,
                            unidad: item.producto.unidad,
                            userId: item.producto.userId,
                            tenantId: item.producto.tenantId,
                            updatedAt: DateTime.now(),
                          );
                          
                          context.read<InventarioBloc>().add(UpdateInsumoEvent(prodActualizado));
                        }

                        if (mounted) {
                          AppToast.showSuccess(context, 'Venta registrada con éxito');
                          setState(() { _carrito.clear(); });
                          Navigator.pop(context);
                        }
                      },
                      child: const Text('Completar Venta', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
      backgroundColor: Colors.white,
      side: BorderSide(color: Colors.grey.shade300),
      onPressed: () => setModalState(() => ctrl.text = monto.toStringAsFixed(2)),
    );
  }

  // ================== TAB: HISTORIAL ==================

  Widget _buildHistorialTab(VentaState state) {
    if (state is VentaLoading || state is VentaInitial) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state is VentaError) {
      return Center(child: Text('Error: ${state.message}'));
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
        boxShadow: [BoxShadow(color: const Color(0xFFFF6584).withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4))],
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
                color: selected ? null : Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4)],
              ),
              child: Text(
                f,
                style: TextStyle(
                  color: selected ? Colors.white : AppTheme.textSecondary,
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
            const Text(
              'Sin ventas en este período',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 15),
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        leading: Container(
          width: 44, height: 44,
          decoration: BoxDecoration(gradient: AppTheme.salesGradient, borderRadius: BorderRadius.circular(14)),
          child: const Icon(Icons.icecream_rounded, color: Colors.white, size: 22),
        ),
        title: Text(titulo, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: AppTheme.textPrimary)),
        subtitle: Text(subtitulo, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_fmt.format(v.totalIngresos), style: const TextStyle(fontWeight: FontWeight.w700, color: AppTheme.primary, fontSize: 15)),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => _confirmDelete(v),
              child: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 20),
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
                    Expanded(child: Text('• ${d.insumoNombre ?? "Producto"}', style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary))),
                    Text('${d.cantidad.toInt()} pzs × ${_fmt.format(d.precioVentaUnitario)} = ${_fmt.format(d.total)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  void _confirmDelete(VentaModel v) {
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
