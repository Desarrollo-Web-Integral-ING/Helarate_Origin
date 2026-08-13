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

class _VentasScreenState extends State<VentasScreen> {
  final _fmt = NumberFormat.currency(locale: 'es_MX', symbol: '\$');
  List<VentaModel> _ventas = [];
  List<Insumo> _productos = [];
  String _filtroFecha = 'Hoy';

  static const _filtros = ['Hoy', 'Semana', 'Mes', 'Todo'];

  @override
  void initState() {
    super.initState();
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

  double get _totalFiltrado =>
      _ventasFiltradas.fold(0.0, (sum, v) => sum + v.totalIngresos);

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
              appBar: AppBar(
                title: const Text('Ventas'),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.add_rounded),
                    onPressed: _productos.isEmpty ? null : () => _showRegistrarVenta(),
                  ),
                ],
              ),
              body: _buildBody(state),
              floatingActionButton: _productos.isEmpty
                  ? null
                  : FloatingActionButton.extended(
                      onPressed: () => _showRegistrarVenta(),
                      backgroundColor: AppTheme.primary,
                      icon: const Icon(Icons.add, color: Colors.white),
                      label: const Text('Registrar venta',
                          style: TextStyle(
                              color: Colors.white, fontWeight: FontWeight.w600)),
                    ),
            );
          },
        );
      },
    );
  }

  Widget _buildBody(VentaState state) {
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
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AppTheme.salesGradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF6584).withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Total $_filtroFecha',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
              Text(
                _fmt.format(_totalFiltrado),
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w700),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text('Ventas',
                  style: TextStyle(color: Colors.white70, fontSize: 12)),
              Text(
                '${_ventasFiltradas.length}',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w700),
              ),
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
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                  ),
                ],
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
            Text(
              _productos.isEmpty
                  ? 'Primero agrega productos al inventario'
                  : 'Sin ventas en este período',
              style: const TextStyle(
                  color: AppTheme.textSecondary, fontSize: 15),
              textAlign: TextAlign.center,
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
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            gradient: AppTheme.salesGradient,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.icecream_rounded, color: Colors.white, size: 22),
        ),
        title: Text(
          titulo,
          style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 15,
              color: AppTheme.textPrimary),
        ),
        subtitle: Text(
          subtitulo,
          style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _fmt.format(v.totalIngresos),
                  style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primary,
                      fontSize: 15),
                ),
              ],
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => _confirmDelete(v),
              child: const Icon(Icons.delete_outline_rounded,
                  color: Colors.red, size: 20),
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
                    Expanded(
                      child: Text(
                        '• ${d.insumoNombre ?? "Producto"}',
                        style: const TextStyle(
                            fontSize: 13, color: AppTheme.textPrimary),
                      ),
                    ),
                    Text(
                      '${d.cantidad.toInt()} pzs × ${_fmt.format(d.precioVentaUnitario)} = ${_fmt.format(d.total)}',
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  void _showRegistrarVenta() {
    Insumo? productoSeleccionado;
    final cantidadCtrl = TextEditingController(text: '1');
    final List<_CartItem> carrito = [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final totalIngresos = carrito.fold(0.0, (sum, i) => sum + i.subtotal);
          final totalPiezas = carrito.fold(0.0, (sum, i) => sum + i.cantidad).toInt();

          void agregarAlCarrito() {
            if (productoSeleccionado == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Por favor selecciona un producto'),
                  backgroundColor: Colors.orange,
                ),
              );
              return;
            }

            final cantidad = double.tryParse(cantidadCtrl.text) ?? 1.0;
            if (cantidad <= 0) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Ingresa una cantidad mayor a 0'),
                  backgroundColor: Colors.orange,
                ),
              );
              return;
            }

            // Calcular cantidad ya en carrito para este producto
            final yaEnCarrito = carrito
                .where((i) => i.producto.id == productoSeleccionado!.id)
                .fold(0.0, (s, i) => s + i.cantidad);

            if (yaEnCarrito + cantidad > productoSeleccionado!.stockActual) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Stock insuficiente. Cantidad excede el stock disponible'),
                  backgroundColor: Colors.red,
                  duration: Duration(seconds: 3),
                ),
              );
              return;
            }

            final index = carrito.indexWhere((i) => i.producto.id == productoSeleccionado!.id);
            if (index >= 0) {
              carrito[index].cantidad += cantidad;
            } else {
              carrito.add(_CartItem(producto: productoSeleccionado!, cantidad: cantidad));
            }

            cantidadCtrl.text = '1';
            productoSeleccionado = null;
            setModalState(() {});
          }

          return Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(ctx).size.height * 0.85,
            ),
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              top: 20,
              left: 20,
              right: 20,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Registrar venta (Carrito)',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary),
                      ),
                      if (carrito.isNotEmpty)
                        Text(
                          '$totalPiezas piezas en total',
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.primary),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Selector de producto
                  DropdownButtonFormField<Insumo>(
                    value: productoSeleccionado,
                    decoration: const InputDecoration(labelText: 'Producto'),
                    items: _productos
                        .map((p) => DropdownMenuItem(
                              value: p,
                              child: Text(
                                '${p.nombre}${p.sabor != null && p.sabor!.isNotEmpty ? " - " + p.sabor! : ""} (${p.stockActual.toInt()} disp.)',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ))
                        .toList(),
                    onChanged: (v) => setModalState(() => productoSeleccionado = v),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: cantidadCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Cantidad',
                            contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton.icon(
                        onPressed: agregarAlCarrito,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        ),
                        icon: const Icon(Icons.add_shopping_cart_rounded, color: Colors.white, size: 18),
                        label: const Text('Agregar', style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (carrito.isNotEmpty) ...[
                    const Text(
                      'Productos en esta venta:',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9F9FB),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: carrito.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, idx) {
                          final item = carrito[idx];
                          final nombreCompleto = '${item.producto.nombre}${item.producto.sabor != null && item.producto.sabor!.isNotEmpty ? " - " + item.producto.sabor! : ""}';
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        nombreCompleto,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13,
                                            color: AppTheme.textPrimary),
                                      ),
                                      Text(
                                        '${_fmt.format(item.producto.precioVenta)} c/u · Subtotal: ${_fmt.format(item.subtotal)}',
                                        style: const TextStyle(
                                            fontSize: 11,
                                            color: AppTheme.textSecondary),
                                      ),
                                    ],
                                  ),
                                ),
                                Row(
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.remove_circle_outline, size: 20),
                                      color: Colors.grey,
                                      onPressed: () {
                                        setModalState(() {
                                          if (item.cantidad > 1) {
                                            item.cantidad--;
                                          } else {
                                            carrito.removeAt(idx);
                                          }
                                        });
                                      },
                                    ),
                                    Text(
                                      '${item.cantidad.toInt()}',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w700, fontSize: 14),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.add_circle_outline, size: 20),
                                      color: AppTheme.primary,
                                      onPressed: () {
                                        if (item.cantidad + 1 > item.producto.stockActual) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(
                                              content: Text('Stock insuficiente. Cantidad excede el stock disponible'),
                                              backgroundColor: Colors.red,
                                              duration: Duration(seconds: 3),
                                            ),
                                          );
                                          return;
                                        }
                                        setModalState(() {
                                          item.cantidad++;
                                        });
                                      },
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                      onPressed: () {
                                        setModalState(() {
                                          carrito.removeAt(idx);
                                        });
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0F1FF),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Total a Cobrar',
                              style: TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600)),
                          Text(
                            _fmt.format(totalIngresos),
                            style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                color: AppTheme.primary,
                                fontSize: 18),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: carrito.isEmpty
                          ? null
                          : () {
                              // Validar stock para cada producto en el carrito por seguridad
                              for (final item in carrito) {
                                if (item.cantidad > item.producto.stockActual) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Stock insuficiente en ${item.producto.nombre}. Cantidad excede el stock disponible'),
                                      backgroundColor: Colors.red,
                                      duration: const Duration(seconds: 3),
                                    ),
                                  );
                                  return;
                                }
                              }

                              final ventaId = const Uuid().v4();
                              final totalCostos = carrito.fold(0.0, (sum, i) => sum + i.costoTotal);
                              final gananciaNeta = totalIngresos - totalCostos;

                              final detalles = carrito.map((item) {
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

                              // Decrementar stock localmente y enviar evento para cada producto del carrito
                              for (final item in carrito) {
                                final nuevoStock = item.producto.stockActual - item.cantidad;
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
                                  updatedAt: DateTime.now(),
                                );
                                context.read<InventarioBloc>().add(UpdateInsumoEvent(prodActualizado));
                              }

                              if (mounted) Navigator.pop(context);
                            },
                      child: Text(
                        carrito.isEmpty
                            ? 'Selecciona y agrega productos'
                            : 'Confirmar venta (${_fmt.format(totalIngresos)})',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
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
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              context.read<VentaBloc>().add(DeleteVentaEvent(v.id));
              if (mounted) Navigator.pop(context);
            },
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }
}

