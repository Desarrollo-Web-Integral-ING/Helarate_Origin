import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../models/producto_venta.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';

import '../widgets/indexed_stack_resume.dart';

class InventarioVentaScreen extends StatefulWidget {
  const InventarioVentaScreen({super.key});

  @override
  State<InventarioVentaScreen> createState() => _InventarioVentaScreenState();
}

class _InventarioVentaScreenState extends State<InventarioVentaScreen> {
  final _storage = StorageService();
  final _fmt = NumberFormat.currency(locale: 'es_MX', symbol: '\$');
  List<ProductoVenta> _items = [];
  String _busqueda = '';
  String _filtroCategoria = 'Todos';

  static const _tipos = ['Litro', 'Cono', 'Cono de galleta', 'Cazuela', 'Vaso', 'Otros'];
  static const _filtros = ['Todos', 'Litro', 'Cono', 'Cono de galleta', 'Cazuela', 'Vaso', 'Otros'];
  static const _tamanos = ['Chico', 'Mediano', 'Grande', 'Extra'];

  @override
  void initState() {
    super.initState();
    _load();
    activeTabNotifier.addListener(_onTabChange);
  }

  void _onTabChange() {
    if (activeTabNotifier.value == 2) _load();
  }

  @override
  void dispose() {
    activeTabNotifier.removeListener(_onTabChange);
    super.dispose();
  }

  Future<void> _load() async {
    final items = await _storage.getProductosVenta();
    setState(() => _items = items);
  }

  List<ProductoVenta> get _filtrados {
    var list = _items;
    if (_filtroCategoria != 'Todos') {
      list = list.where((p) => p.categoria == _filtroCategoria).toList();
    }
    if (_busqueda.isNotEmpty) {
      list = list.where((p) =>
          p.nombre.toLowerCase().contains(_busqueda.toLowerCase()) ||
          p.sabor.toLowerCase().contains(_busqueda.toLowerCase())).toList();
    }
    return list;
  }

  Future<void> _ajustarStock(ProductoVenta p, int delta) async {
    final nuevo = (p.stockActual + delta).clamp(0, 99999);
    final actualizado = ProductoVenta(
      id: p.id, nombre: p.nombre, sabor: p.sabor, tamano: p.tamano,
      precio: p.precio, stockActual: nuevo, stockMinimo: p.stockMinimo,
      categoria: p.categoria, imagenPath: p.imagenPath,
      ultimaActualizacion: DateTime.now(),
    );
    await _storage.updateProductoVenta(actualizado);
    _load();
  }

  Future<String?> _pickImage() async {
    final result = await FilePicker.pickFiles(
      type: FileType.image, allowMultiple: false,
    );
    return result?.files.single.path;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventario de Nieves'),
        actions: [
          IconButton(icon: const Icon(Icons.add_rounded), onPressed: () => _showForm()),
        ],
      ),
      body: Column(
        children: [
          _buildHeader(),
          _buildSearchBar(),
          _buildCategoryFilter(),
          Expanded(child: _buildList()),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final agotados = _items.where((p) => p.stockActual == 0).length;
    final stockBajo = _items.where((p) => p.stockBajo).length;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AppTheme.stockGradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: const Color(0xFF43E97B).withValues(alpha: 0.3),
            blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _hStat('Productos', '${_items.length}'),
          _hStat('Agotados', '$agotados', warn: agotados > 0),
          _hStat('Stock bajo', '$stockBajo', warn: stockBajo > 0),
        ],
      ),
    );
  }

  Widget _hStat(String label, String value, {bool warn = false}) => Column(
    children: [
      Text(value, style: TextStyle(
          color: warn ? const Color(0xFFFFEB3B) : Colors.white,
          fontSize: 22, fontWeight: FontWeight.w700)),
      Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
    ],
  );

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: TextField(
        onChanged: (v) => setState(() => _busqueda = v),
        decoration: const InputDecoration(
          hintText: 'Buscar nieve o sabor...',
          prefixIcon: Icon(Icons.search_rounded, color: AppTheme.textSecondary),
        ),
      ),
    );
  }

  Widget _buildCategoryFilter() {
    return SizedBox(
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _filtros.length,
        itemBuilder: (_, i) {
          final cat = _filtros[i];
          final selected = cat == _filtroCategoria;
          return GestureDetector(
            onTap: () => setState(() => _filtroCategoria = cat),
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                gradient: selected ? AppTheme.stockGradient : null,
                color: selected ? null : Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)],
              ),
              child: Text(cat, style: TextStyle(
                color: selected ? Colors.white : AppTheme.textSecondary,
                fontSize: 13,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              )),
            ),
          );
        },
      ),
    );
  }

  Widget _buildList() {
    if (_filtrados.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🍧', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 12),
            const Text('Sin productos registrados',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 15)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => _showForm(),
              icon: const Icon(Icons.add),
              label: const Text('Agregar nieve'),
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
      itemCount: _filtrados.length,
      itemBuilder: (_, i) => _buildCard(_filtrados[i]),
    );
  }

  Widget _buildCard(ProductoVenta p) {
    final agotado = p.stockActual == 0;
    final Color borderColor = agotado ? const Color(0xFFE53935)
        : p.stockBajo ? const Color(0xFFFFB74D) : Colors.transparent;
    final Color bgColor = agotado ? const Color(0xFFFFF0F0)
        : p.stockBajo ? const Color(0xFFFFFBF0) : Colors.white;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1.5),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        children: [
          ListTile(
            contentPadding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            leading: _avatar(p.imagenPath, agotado, p.stockBajo),
            title: Text(p.nombre, style: const TextStyle(
                fontWeight: FontWeight.w600, fontSize: 14, color: AppTheme.textPrimary)),
            subtitle: Text(
              [p.sabor, p.categoria,
                if (p.categoria == 'Vaso' && p.tamano.isNotEmpty) p.tamano]
                  .where((s) => s.isNotEmpty).join(' · '),
              style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
            ),
            trailing: SizedBox(
              width: 80,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(_fmt.format(p.precio),
                      style: const TextStyle(fontWeight: FontWeight.w700,
                          color: AppTheme.primary, fontSize: 13),
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  _stockChip(p),
                ],
              ),
            ),
            onTap: () => _showForm(producto: p),
            onLongPress: () => _confirmDelete(p),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
            child: Row(
              children: [
                _qBtn(Icons.remove, () => _ajustarStock(p, -1), agotado),
                Expanded(
                  child: Center(
                    child: Text(
                      '${p.stockActual} ${p.categoria == 'Litro' || p.categoria == 'Cazuela' ? 'L' : 'pzs'}',
                      style: TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 15,
                        color: agotado ? const Color(0xFFE53935)
                            : p.stockBajo ? const Color(0xFFE65100) : AppTheme.textPrimary,
                      ),
                    ),
                  ),
                ),
                _qBtn(Icons.add, () => _ajustarStock(p, 1), false),
                const SizedBox(width: 6),
                _qBtn(Icons.edit_outlined, () => _showAjusteDialog(p), false,
                    color: AppTheme.primary),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _avatar(String? path, bool agotado, bool stockBajo) {
    if (path != null && File(path).existsSync()) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Image.file(File(path), width: 48, height: 48, fit: BoxFit.cover),
      );
    }
    return Container(
      width: 48, height: 48,
      decoration: BoxDecoration(
        gradient: agotado
            ? const LinearGradient(colors: [Color(0xFFE53935), Color(0xFFEF9A9A)])
            : stockBajo ? AppTheme.salesGradient : AppTheme.stockGradient,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(agotado ? Icons.warning_rounded : Icons.icecream_rounded,
          color: Colors.white, size: 22),
    );
  }

  Widget _stockChip(ProductoVenta p) {
    final agotado = p.stockActual == 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: agotado ? const Color(0xFFFFEBEE)
            : p.stockBajo ? const Color(0xFFFFF3E0) : const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        agotado ? '🔴 Agotado' : p.stockBajo ? '⚠️ Bajo' : '✓ OK',
        style: TextStyle(
          fontSize: 10, fontWeight: FontWeight.w600,
          color: agotado ? const Color(0xFFC62828)
              : p.stockBajo ? const Color(0xFFE65100) : const Color(0xFF2E7D32),
        ),
      ),
    );
  }

  Widget _qBtn(IconData icon, VoidCallback onTap, bool disabled, {Color? color}) {
    return GestureDetector(
      onTap: disabled ? null : onTap,
      child: Container(
        width: 32, height: 32,
        decoration: BoxDecoration(
          color: disabled ? Colors.grey[200]
              : (color ?? AppTheme.primary).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 18,
            color: disabled ? Colors.grey : (color ?? AppTheme.primary)),
      ),
    );
  }

  void _showAjusteDialog(ProductoVenta p) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Ajustar ${p.nombre}'),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Nueva cantidad'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              final val = int.tryParse(ctrl.text);
              if (val == null) return;
              final actualizado = ProductoVenta(
                id: p.id, nombre: p.nombre, sabor: p.sabor, tamano: p.tamano,
                precio: p.precio, stockActual: val, stockMinimo: p.stockMinimo,
                categoria: p.categoria, imagenPath: p.imagenPath,
                ultimaActualizacion: DateTime.now(),
              );
              await _storage.updateProductoVenta(actualizado);
              if (mounted) Navigator.pop(context);
              _load();
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  void _showForm({ProductoVenta? producto}) {
    final isEdit = producto != null;
    final nombreCtrl = TextEditingController(text: producto?.nombre ?? '');
    final saborCtrl = TextEditingController(text: producto?.sabor ?? '');
    final precioCtrl = TextEditingController(
        text: producto?.precio == 0 ? '' : producto?.precio.toString() ?? '');
    final stockCtrl = TextEditingController(
        text: producto?.stockActual == 0 ? '' : producto?.stockActual.toString() ?? '');
    final stockMinCtrl = TextEditingController(text: producto?.stockMinimo.toString() ?? '1');
    String tamano = _tamanos.contains(producto?.tamano) ? producto!.tamano : _tamanos.first;
    String categoria = _tipos.contains(producto?.categoria) ? producto!.categoria : _tipos.first;
    String? imagenPath = producto?.imagenPath;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setModal) => Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            top: 20, left: 20, right: 20,
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
                Center(child: Container(width: 40, height: 4,
                    decoration: BoxDecoration(color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 16),
                Text(isEdit ? 'Editar producto' : 'Nuevo producto',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary)),
                const SizedBox(height: 16),
                // Imagen
                GestureDetector(
                  onTap: () async {
                    final path = await _pickImage();
                    if (path != null) setModal(() => imagenPath = path);
                  },
                  child: Container(
                    height: 90,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0F1FF),
                      borderRadius: BorderRadius.circular(14),
                      image: imagenPath != null
                          ? DecorationImage(
                              image: FileImage(File(imagenPath!)), fit: BoxFit.cover)
                          : null,
                    ),
                    child: imagenPath == null
                        ? const Center(child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_photo_alternate_outlined,
                                  color: AppTheme.textSecondary, size: 28),
                              SizedBox(height: 4),
                              Text('Agregar imagen (opcional)',
                                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                            ]))
                        : Align(
                            alignment: Alignment.topRight,
                            child: GestureDetector(
                              onTap: () => setModal(() => imagenPath = null),
                              child: Container(
                                margin: const EdgeInsets.all(6),
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                    color: Colors.black54, shape: BoxShape.circle),
                                child: const Icon(Icons.close, color: Colors.white, size: 14),
                              ),
                            )),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(controller: nombreCtrl,
                    decoration: const InputDecoration(labelText: 'Nombre')),
                const SizedBox(height: 10),
                TextField(controller: saborCtrl,
                    decoration: const InputDecoration(labelText: 'Sabor')),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: categoria,
                  decoration: const InputDecoration(labelText: 'Tipo'),
                  items: _tipos.map((t) =>
                      DropdownMenuItem(value: t, child: Text(t))).toList(),
                  onChanged: (v) => setModal(() => categoria = v!),
                ),
                if (categoria == 'Vaso') ...[
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: tamano,
                    decoration: const InputDecoration(labelText: 'Tamaño'),
                    items: _tamanos.map((t) =>
                        DropdownMenuItem(value: t, child: Text(t))).toList(),
                    onChanged: (v) => setModal(() => tamano = v!),
                  ),
                ],
                const SizedBox(height: 10),
                TextField(controller: precioCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Precio de venta (\$)')),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: TextField(controller: stockCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Cantidad actual'))),
                  const SizedBox(width: 10),
                  Expanded(child: TextField(controller: stockMinCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Mínimo'))),
                ]),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (nombreCtrl.text.isEmpty) return;
                      final p = ProductoVenta(
                        id: producto?.id ?? const Uuid().v4(),
                        nombre: nombreCtrl.text.trim(),
                        sabor: saborCtrl.text.trim(),
                        tamano: categoria == 'Vaso' ? tamano : '',
                        precio: double.tryParse(precioCtrl.text) ?? 0,
                        stockActual: int.tryParse(stockCtrl.text) ?? 0,
                        stockMinimo: int.tryParse(stockMinCtrl.text) ?? 1,
                        categoria: categoria,
                        imagenPath: imagenPath,
                        ultimaActualizacion: DateTime.now(),
                      );
                      if (isEdit) {
                        await _storage.updateProductoVenta(p);
                      } else {
                        await _storage.addProductoVenta(p);
                      }
                      if (mounted) Navigator.pop(context);
                      _load();
                    },
                    child: Text(isEdit ? 'Guardar cambios' : 'Agregar'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _confirmDelete(ProductoVenta p) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Eliminar producto'),
        content: Text('¿Eliminar "${p.nombre}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await _storage.deleteProductoVenta(p.id);
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
