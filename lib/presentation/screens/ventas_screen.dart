import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../domain/models/producto_venta.dart';
import '../../domain/models/venta.dart';
import '../../data/services/storage_service.dart';
import '../../core/theme/app_theme.dart';

import '../../core/widgets/indexed_stack_resume.dart';

class VentasScreen extends StatefulWidget {
  const VentasScreen({super.key});

  @override
  State<VentasScreen> createState() => _VentasScreenState();
}

class _VentasScreenState extends State<VentasScreen> {
  final _storage = StorageService();
  final _fmt = NumberFormat.currency(locale: 'es_MX', symbol: '\$');
  List<Venta> _ventas = [];
  List<ProductoVenta> _productos = [];
  String _filtroFecha = 'Hoy';

  static const _filtros = ['Hoy', 'Semana', 'Mes', 'Todo'];

  @override
  void initState() {
    super.initState();
    _load();
    activeTabNotifier.addListener(_onTabChange);
  }

  void _onTabChange() {
    if (activeTabNotifier.value == 3) _load();
  }

  @override
  void dispose() {
    activeTabNotifier.removeListener(_onTabChange);
    super.dispose();
  }

  Future<void> _load() async {
    final v = await _storage.getVentas();
    final p = await _storage.getProductosVenta();
    setState(() {
      _ventas = v..sort((a, b) => b.fecha.compareTo(a.fecha));
      _productos = p;
    });
  }

  List<Venta> get _ventasFiltradas {
    final now = DateTime.now();
    return _ventas.where((v) {
      switch (_filtroFecha) {
        case 'Hoy':
          return v.fecha.year == now.year &&
              v.fecha.month == now.month &&
              v.fecha.day == now.day;
        case 'Semana':
          return v.fecha.isAfter(now.subtract(const Duration(days: 7)));
        case 'Mes':
          return v.fecha.year == now.year && v.fecha.month == now.month;
        default:
          return true;
      }
    }).toList();
  }

  double get _totalFiltrado =>
      _ventasFiltradas.fold(0.0, (sum, v) => sum + v.total);

  @override
  Widget build(BuildContext context) {
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
      body: Column(
        children: [
          _buildResumen(),
          _buildFiltros(),
          Expanded(child: _buildLista()),
        ],
      ),
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
            onTap: () => setState(() => _filtroFecha = f),
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
            const Text('🛒', style: TextStyle(fontSize: 48)),
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

  Widget _buildVentaCard(Venta v) {
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
          v.productoNombre,
          style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 15,
              color: AppTheme.textPrimary),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${v.cantidad} pzs · ${_fmt.format(v.precioUnitario)} c/u',
              style: const TextStyle(
                  fontSize: 12, color: AppTheme.textSecondary),
            ),
            Text(
              DateFormat('dd/MM/yyyy HH:mm').format(v.fecha),
              style: const TextStyle(
                  fontSize: 11, color: AppTheme.textSecondary),
            ),
            if (v.nota != null && v.nota!.isNotEmpty)
              Text(v.nota!,
                  style: const TextStyle(
                      fontSize: 11,
                      color: AppTheme.textSecondary,
                      fontStyle: FontStyle.italic)),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _fmt.format(v.total),
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
    ProductoVenta? productoSeleccionado;
    final cantidadCtrl = TextEditingController(text: '1');
    final notaCtrl = TextEditingController();

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
              DropdownButtonFormField<ProductoVenta>(
                decoration: const InputDecoration(labelText: 'Producto'),
                items: _productos
                    .map((p) => DropdownMenuItem(
                          value: p,
                          child: Text(
                            '${p.nombre} - ${p.sabor} (${p.stockActual} disp.)',
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
                        _fmt.format(productoSeleccionado!.precio),
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
              const SizedBox(height: 10),
              TextField(
                controller: notaCtrl,
                decoration: const InputDecoration(
                    labelText: 'Nota (opcional)',
                    hintText: 'Ej: cliente especial, descuento...'),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    if (productoSeleccionado == null) return;
                    final cantidad = int.tryParse(cantidadCtrl.text) ?? 1;
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
                    final venta = Venta(
                      id: const Uuid().v4(),
                      productoId: productoSeleccionado!.id,
                      productoNombre:
                          '${productoSeleccionado!.nombre} - ${productoSeleccionado!.sabor}',
                      cantidad: cantidad,
                      precioUnitario: productoSeleccionado!.precio,
                      fecha: DateTime.now(),
                      nota: notaCtrl.text.trim().isEmpty
                          ? null
                          : notaCtrl.text.trim(),
                    );
                    await _storage.addVenta(venta);
                    productoSeleccionado!.stockActual -= cantidad;
                    await _storage.updateProductoVenta(productoSeleccionado!);
                    if (mounted) Navigator.pop(context);
                    _load();
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

  void _confirmDelete(Venta v) {
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
            onPressed: () async {
              await _storage.deleteVenta(v.id);
              if (mounted) Navigator.pop(context);
              _load();
            },
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }
}
