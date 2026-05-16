import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../models/producto_produccion.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';

class InventarioProduccionScreen extends StatefulWidget {
  const InventarioProduccionScreen({super.key});

  @override
  State<InventarioProduccionScreen> createState() =>
      _InventarioProduccionScreenState();
}

class _InventarioProduccionScreenState
    extends State<InventarioProduccionScreen> {
  final _storage = StorageService();
  final _fmt = NumberFormat.currency(locale: 'es_MX', symbol: '\$');
  List<ProductoProduccion> _items = [];
  String _busqueda = '';

  static const _categorias = [
    'Plásticos', 'Vasos térmicos', 'Tapas y vasos', 'Cubiertos',
    'Servilletas', 'Barquillos y conos', 'Otros'
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final items = await _storage.getProductosProduccion();
    setState(() => _items = items);
  }

  List<ProductoProduccion> get _filtrados => _busqueda.isEmpty
      ? _items
      : _items.where((p) =>
          p.nombre.toLowerCase().contains(_busqueda.toLowerCase()) ||
          p.categoria.toLowerCase().contains(_busqueda.toLowerCase())).toList();

  double get _valorTotal => _items.fold(0.0, (s, p) => s + p.valorTotal);
  int get _agotadosCount => _items.where((p) => p.cantidad == 0).length;
  int get _stockBajoCount => _items.where((p) => p.stockBajo).length;

  Future<void> _ajustarCantidad(ProductoProduccion p, double delta) async {
    final nueva = (p.cantidad + delta).clamp(0.0, double.infinity);
    final actualizado = ProductoProduccion(
      id: p.id, nombre: p.nombre, unidad: p.unidad,
      cantidad: nueva, cantidadMinima: p.cantidadMinima,
      precioUnitario: p.precioUnitario, categoria: p.categoria,
      imagenPath: p.imagenPath, ultimaActualizacion: DateTime.now(),
    );
    await _storage.updateProductoProduccion(actualizado);
    _load();
  }

  Future<String?> _pickImage() async {
    final result = await FilePicker.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );
    return result?.files.single.path;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Insumos de Producción'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            onPressed: () => _showForm(),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildHeader(),
          _buildSearchBar(),
          Expanded(child: _buildList()),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AppTheme.productionGradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4FACFE).withValues(alpha: 0.3),
            blurRadius: 12, offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _hStat('Valor total', _fmt.format(_valorTotal)),
          _hStat('Insumos', '${_items.length}'),
          _hStat('Agotados', '$_agotadosCount', warn: _agotadosCount > 0),
          _hStat('Stock bajo', '$_stockBajoCount', warn: _stockBajoCount > 0),
        ],
      ),
    );
  }

  Widget _hStat(String label, String value, {bool warn = false}) => Column(
    children: [
      Text(value,
          style: TextStyle(
              color: warn ? const Color(0xFFFFEB3B) : Colors.white,
              fontSize: 16, fontWeight: FontWeight.w700)),
      Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10)),
    ],
  );

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: TextField(
        onChanged: (v) => setState(() => _busqueda = v),
        decoration: const InputDecoration(
          hintText: 'Buscar insumo...',
          prefixIcon: Icon(Icons.search_rounded, color: AppTheme.textSecondary),
        ),
      ),
    );
  }

  Widget _buildList() {
    if (_filtrados.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('📦', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 12),
            const Text('Sin insumos registrados',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 15)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => _showForm(),
              icon: const Icon(Icons.add),
              label: const Text('Agregar insumo'),
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
      itemCount: _filtrados.length,
      itemBuilder: (_, i) => _buildCard(_filtrados[i]),
    );
  }

  Widget _buildCard(ProductoProduccion p) {
    final agotado = p.cantidad == 0;
    final Color borderColor = agotado
        ? const Color(0xFFE53935)
        : p.stockBajo ? const Color(0xFFFFB74D) : Colors.transparent;
    final Color bgColor = agotado
        ? const Color(0xFFFFF0F0)
        : p.stockBajo ? const Color(0xFFFFFBF0) : Colors.white;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1.5),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        children: [
          ListTile(
            contentPadding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            leading: _avatar(p.imagenPath, agotado, p.stockBajo,
                fallbackIcon: Icons.inventory_2_rounded,
                fallbackGradient: agotado
                    ? const LinearGradient(colors: [Color(0xFFE53935), Color(0xFFEF9A9A)])
                    : p.stockBajo ? AppTheme.salesGradient : AppTheme.productionGradient),
            title: Text(p.nombre,
                style: const TextStyle(fontWeight: FontWeight.w600,
                    fontSize: 14, color: AppTheme.textPrimary)),
            subtitle: Text(
              '${p.categoria} · ${_fmt.format(p.precioUnitario)}/${p.unidad}'
              '${p.cantidadMinima > 0 ? ' · Mín: ${p.cantidadMinima}' : ''}',
              style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
            ),
            trailing: SizedBox(
              width: 80,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(_fmt.format(p.valorTotal),
                      style: const TextStyle(fontWeight: FontWeight.w700,
                          color: AppTheme.primary, fontSize: 13),
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  _statusChip(agotado, p.stockBajo),
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
                _qBtn(Icons.remove, () => _ajustarCantidad(p, -1), agotado),
                Expanded(
                  child: Center(
                    child: Text(
                      '${p.cantidad % 1 == 0 ? p.cantidad.toInt() : p.cantidad} ${p.unidad}',
                      style: TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 15,
                        color: agotado ? const Color(0xFFE53935)
                            : p.stockBajo ? const Color(0xFFE65100)
                            : AppTheme.textPrimary,
                      ),
                    ),
                  ),
                ),
                _qBtn(Icons.add, () => _ajustarCantidad(p, 1), false),
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

  Widget _avatar(String? path, bool agotado, bool stockBajo,
      {required IconData fallbackIcon, required LinearGradient fallbackGradient}) {
    if (path != null && File(path).existsSync()) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Image.file(File(path), width: 48, height: 48, fit: BoxFit.cover),
      );
    }
    return Container(
      width: 48, height: 48,
      decoration: BoxDecoration(
          gradient: fallbackGradient, borderRadius: BorderRadius.circular(14)),
      child: Icon(agotado ? Icons.warning_rounded : fallbackIcon,
          color: Colors.white, size: 22),
    );
  }

  Widget _statusChip(bool agotado, bool stockBajo) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: agotado ? const Color(0xFFFFEBEE)
          : stockBajo ? const Color(0xFFFFF3E0) : const Color(0xFFE8F5E9),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(
      agotado ? '🔴 Agotado' : stockBajo ? '⚠️ Bajo' : '✓ OK',
      style: TextStyle(
        fontSize: 10, fontWeight: FontWeight.w600,
        color: agotado ? const Color(0xFFC62828)
            : stockBajo ? const Color(0xFFE65100) : const Color(0xFF2E7D32),
      ),
    ),
  );

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

  void _showAjusteDialog(ProductoProduccion p) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Ajustar ${p.nombre}'),
        content: TextField(
          controller: ctrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          autofocus: true,
          decoration: InputDecoration(labelText: 'Nueva cantidad (${p.unidad})'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              final val = double.tryParse(ctrl.text);
              if (val == null) return;
              final actualizado = ProductoProduccion(
                id: p.id, nombre: p.nombre, unidad: p.unidad,
                cantidad: val, cantidadMinima: p.cantidadMinima,
                precioUnitario: p.precioUnitario, categoria: p.categoria,
                imagenPath: p.imagenPath, ultimaActualizacion: DateTime.now(),
              );
              await _storage.updateProductoProduccion(actualizado);
              if (mounted) Navigator.pop(context);
              _load();
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  void _showForm({ProductoProduccion? producto}) {
    final isEdit = producto != null;
    final nombreCtrl = TextEditingController(text: producto?.nombre ?? '');
    final unidadCtrl = TextEditingController(text: producto?.unidad ?? '');
    final cantidadCtrl = TextEditingController(
        text: producto?.cantidad == 0 ? '' : producto?.cantidad.toString() ?? '');
    final cantMinCtrl = TextEditingController(
        text: producto?.cantidadMinima == 0 ? '' : producto?.cantidadMinima.toString() ?? '');
    final precioCtrl = TextEditingController(
        text: producto?.precioUnitario == 0 ? '' : producto?.precioUnitario.toString() ?? '');
    String categoria = _categorias.contains(producto?.categoria)
        ? producto!.categoria : _categorias.first;
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
                Text(isEdit ? 'Editar insumo' : 'Nuevo insumo',
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
                    decoration: const InputDecoration(labelText: 'Nombre del insumo')),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: TextField(controller: cantidadCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Cantidad actual'))),
                  const SizedBox(width: 10),
                  Expanded(child: TextField(controller: unidadCtrl,
                      decoration: const InputDecoration(labelText: 'Unidad (kg, L, pzs)'))),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: TextField(controller: precioCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Precio/unidad (\$)'))),
                  const SizedBox(width: 10),
                  Expanded(child: TextField(controller: cantMinCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Cantidad mínima'))),
                ]),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: categoria,
                  decoration: const InputDecoration(labelText: 'Categoría'),
                  items: _categorias.map((c) =>
                      DropdownMenuItem(value: c, child: Text(c))).toList(),
                  onChanged: (v) => setModal(() => categoria = v!),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (nombreCtrl.text.isEmpty) return;
                      final p = ProductoProduccion(
                        id: producto?.id ?? const Uuid().v4(),
                        nombre: nombreCtrl.text.trim(),
                        unidad: unidadCtrl.text.trim().isEmpty ? 'pzs' : unidadCtrl.text.trim(),
                        cantidad: double.tryParse(cantidadCtrl.text) ?? 0,
                        cantidadMinima: double.tryParse(cantMinCtrl.text) ?? 0,
                        precioUnitario: double.tryParse(precioCtrl.text) ?? 0,
                        categoria: categoria,
                        imagenPath: imagenPath,
                        ultimaActualizacion: DateTime.now(),
                      );
                      if (isEdit) {
                        await _storage.updateProductoProduccion(p);
                      } else {
                        await _storage.addProductoProduccion(p);
                      }
                      if (mounted) Navigator.pop(context);
                      _load();
                    },
                    child: Text(isEdit ? 'Guardar cambios' : 'Agregar insumo'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _confirmDelete(ProductoProduccion p) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Eliminar insumo'),
        content: Text('¿Eliminar "${p.nombre}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await _storage.deleteProductoProduccion(p.id);
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
