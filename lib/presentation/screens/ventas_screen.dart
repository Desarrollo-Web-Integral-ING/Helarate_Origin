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
    final detail = v.detalles.isNotEmpty ? v.detalles.first : null;
    final productoNombre = detail?.insumoNombre ?? 'Producto';
    final cantidad = detail?.cantidad.toInt() ?? 0;
    final precioUnitario = detail?.precioVentaUnitario ?? 0.0;

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
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            gradient: AppTheme.salesGradient,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.icecream_rounded, color: Colors.white, size: 22),
        ),
        title: Text(
          productoNombre,
          style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 15,
              color: AppTheme.textPrimary),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$cantidad pzs · ${_fmt.format(precioUnitario)} c/u',
              style: const TextStyle(
                  fontSize: 12, color: AppTheme.textSecondary),
            ),
            Text(
              DateFormat('dd/MM/yyyy HH:mm').format(v.fecha),
              style: const TextStyle(
                  fontSize: 11, color: AppTheme.textSecondary),
            ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _fmt.format(v.totalIngresos),
              style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primary,
                  fontSize: 15),
            ),
            GestureDetector(
              onTap: () => _confirmDelete(v),
              child: const Icon(Icons.delete_outline_rounded,
                  color: Colors.red, size: 18),
            ),
          ],
        ),
      ),
    );
  }

  void _showRegistrarVenta() {
    Insumo? productoSeleccionado;
    final cantidadCtrl = TextEditingController(text: '1');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setModalState) => Container(
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
              const Text(
                'Registrar venta',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<Insumo>(
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
                onChanged: (v) =>
                    setModalState(() => productoSeleccionado = v),
              ),
              const SizedBox(height: 10),
              if (productoSeleccionado != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F1FF),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Precio unitario',
                          style: TextStyle(
                              color: AppTheme.textSecondary, fontSize: 13)),
                      Text(
                        _fmt.format(productoSeleccionado!.precioVenta),
                        style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppTheme.primary,
                            fontSize: 15),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 10),
              TextField(
                controller: cantidadCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Cantidad'),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    if (productoSeleccionado == null) return;
                    final cantidad = double.tryParse(cantidadCtrl.text) ?? 1.0;
                    if (cantidad <= 0) return;
                    if (cantidad > productoSeleccionado!.stockActual) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Stock insuficiente'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }
                    final ventaId = const Uuid().v4();
                    final detailId = const Uuid().v4();
                    final totalIngresos = cantidad * productoSeleccionado!.precioVenta;
                    final totalCostos = cantidad * productoSeleccionado!.costoUnitario;
                    final gananciaNeta = totalIngresos - totalCostos;

                    final venta = VentaModel(
                      id: ventaId,
                      fecha: DateTime.now(),
                      totalIngresos: totalIngresos,
                      totalCostos: totalCostos,
                      gananciaNeta: gananciaNeta,
                      detalles: [
                        DetalleVentaModel(
                          id: detailId,
                          ventaId: ventaId,
                          insumoId: productoSeleccionado!.id,
                          insumoNombre: '${productoSeleccionado!.nombre}${productoSeleccionado!.sabor != null && productoSeleccionado!.sabor!.isNotEmpty ? " - " + productoSeleccionado!.sabor! : ""}',
                          cantidad: cantidad,
                          precioVentaUnitario: productoSeleccionado!.precioVenta,
                          costoUnitario: productoSeleccionado!.costoUnitario,
                        )
                      ],
                    );

                    context.read<VentaBloc>().add(RegistrarVentaEvent(venta));

                    // Decrementar stock localmente y enviar evento de actualización de insumo
                    final nuevoStock = productoSeleccionado!.stockActual - cantidad;
                    final prodActualizado = Insumo(
                      id: productoSeleccionado!.id,
                      nombre: productoSeleccionado!.nombre,
                      sabor: productoSeleccionado!.sabor,
                      tamano: productoSeleccionado!.tamano,
                      precioVenta: productoSeleccionado!.precioVenta,
                      stockActual: nuevoStock,
                      stockMinimo: productoSeleccionado!.stockMinimo,
                      categoria: productoSeleccionado!.categoria,
                      imagenPath: productoSeleccionado!.imagenPath,
                      tipo: productoSeleccionado!.tipo,
                      costoUnitario: productoSeleccionado!.costoUnitario,
                      unidad: productoSeleccionado!.unidad,
                      userId: productoSeleccionado!.userId,
                      updatedAt: DateTime.now(),
                    );
                    context.read<InventarioBloc>().add(UpdateInsumoEvent(prodActualizado));

                    if (mounted) Navigator.pop(context);
                  },
                  child: const Text('Registrar venta'),
                ),
              ),
            ],
          ),
        ),
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
