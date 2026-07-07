import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/models/insumo.dart';
import '../blocs/inventario/inventario_bloc.dart';
import '../blocs/inventario/inventario_event.dart';
import '../blocs/inventario/inventario_state.dart';
import '../../core/theme/app_theme.dart';

import '../../core/widgets/indexed_stack_resume.dart';

class InventarioProduccionScreen extends StatefulWidget {
  const InventarioProduccionScreen({super.key});

  @override
  State<InventarioProduccionScreen> createState() =>
      _InventarioProduccionScreenState();
}

class _InventarioProduccionScreenState
    extends State<InventarioProduccionScreen> {
  final _fmt = NumberFormat.currency(locale: 'es_MX', symbol: '\$');
  List<Insumo> _items = [];
  String _busqueda = '';

  static const _categorias = [
    'Plásticos', 'Vasos térmicos', 'Tapas y vasos', 'Cubiertos',
    'Servilletas', 'Barquillos y conos', 'Otros'
  ];

  @override
  void initState() {
    super.initState();
    activeTabNotifier.addListener(_onTabChange);
  }

  void _onTabChange() {
    if (activeTabNotifier.value == 1) {
      context.read<InventarioBloc>().add(LoadInventario());
    }
  }

  @override
  void dispose() {
    activeTabNotifier.removeListener(_onTabChange);
    super.dispose();
  }

  List<Insumo> get _filtrados => _busqueda.isEmpty
      ? _items
      : _items.where((p) =>
          p.nombre.toLowerCase().contains(_busqueda.toLowerCase()) ||
          p.categoria.toLowerCase().contains(_busqueda.toLowerCase())).toList();

  double get _valorTotal => _items.fold(0.0, (s, p) => s + (p.stockActual * p.costoUnitario));
  int get _agotadosCount => _items.where((p) => p.stockActual == 0).length;
  int get _stockBajoCount => _items.where((p) => p.stockBajo).length;

  void _ajustarCantidad(Insumo p, double delta) {
    final nueva = (p.stockActual + delta).clamp(0.0, double.infinity);
    final actualizado = Insumo(
      id: p.id,
      nombre: p.nombre,
      unidad: p.unidad,
      stockActual: nueva,
      stockMinimo: p.stockMinimo,
      costoUnitario: p.costoUnitario,
      categoria: p.categoria,
      tipo: p.tipo,
      precioVenta: p.precioVenta,
      userId: p.userId,
      updatedAt: DateTime.now(),
    );
    context.read<InventarioBloc>().add(UpdateInsumoEvent(actualizado));
  }

  Future<PickedImageData?> _pickImage() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );
      if (result == null || result.files.isEmpty) return null;
      final file = result.files.first;

      List<int>? bytes = file.bytes;
      if (bytes == null && file.path != null) {
        bytes = await File(file.path!).readAsBytes();
      }

      if (bytes == null) return null;

      return PickedImageData(
        name: file.name,
        bytes: bytes,
        extension: file.extension ?? 'png',
        localPath: file.path,
      );
    } catch (e) {
      print('Error al seleccionar imagen: $e');
      return null;
    }
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
      body: BlocBuilder<InventarioBloc, InventarioState>(
        builder: (context, state) {
          if (state is InventarioLoading || state is InventarioInitial) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state is InventarioError) {
            return Center(child: Text('Error: ${state.message}'));
          }
          if (state is InventarioLoaded) {
            _items = state.insumos.where((i) => i.tipo == TipoInsumo.materiaPrima).toList();

            return Column(
              children: [
                _buildHeader(),
                _buildSearchBar(),
                Expanded(child: _buildList()),
              ],
            );
          }
          return const SizedBox();
        },
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

  Widget _buildCard(Insumo p) {
    final agotado = p.stockActual == 0;
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
              '${p.categoria} · ${_fmt.format(p.costoUnitario)}/${p.unidad}'
              '${p.stockMinimo > 0 ? ' · Mín: ${p.stockMinimo}' : ''}',
              style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
            ),
            trailing: SizedBox(
              width: 80,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(_fmt.format(p.stockActual * p.costoUnitario),
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
                      '${p.stockActual % 1 == 0 ? p.stockActual.toInt() : p.stockActual} ${p.unidad}',
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
    if (path != null) {
      if (path.startsWith('http')) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Image.network(
            path,
            width: 48,
            height: 48,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.broken_image_rounded, color: Colors.grey, size: 20),
            ),
          ),
        );
      }
      if (!kIsWeb && File(path).existsSync()) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Image.file(File(path), width: 48, height: 48, fit: BoxFit.cover),
        );
      }
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

  void _showAjusteDialog(Insumo p) {
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
            onPressed: () {
              final val = double.tryParse(ctrl.text);
              if (val == null) return;
              final actualizado = Insumo(
                id: p.id,
                nombre: p.nombre,
                unidad: p.unidad,
                stockActual: val,
                stockMinimo: p.stockMinimo,
                costoUnitario: p.costoUnitario,
                categoria: p.categoria,
                tipo: p.tipo,
                precioVenta: p.precioVenta,
                userId: p.userId,
                updatedAt: DateTime.now(),
              );
              context.read<InventarioBloc>().add(UpdateInsumoEvent(actualizado));
              if (mounted) Navigator.pop(context);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  void _showForm({Insumo? producto}) {
    final isEdit = producto != null;
    final nombreCtrl = TextEditingController(text: producto?.nombre ?? '');
    final unidadCtrl = TextEditingController(text: producto?.unidad ?? '');
    final cantidadCtrl = TextEditingController(
        text: producto?.stockActual == 0 ? '' : producto?.stockActual.toString() ?? '');
    final cantMinCtrl = TextEditingController(
        text: producto?.stockMinimo == 0 ? '' : producto?.stockMinimo.toString() ?? '');
    final precioCtrl = TextEditingController(
        text: producto?.costoUnitario == 0 ? '' : producto?.costoUnitario.toString() ?? '');
    String categoria = _categorias.contains(producto?.categoria)
        ? producto!.categoria : _categorias.first;
    String? imagenPath = producto?.imagenPath;
    PickedImageData? selectedImage;
    bool isSaving = false;

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
                GestureDetector(
                  onTap: () async {
                    final picked = await _pickImage();
                    if (picked != null) {
                      setModal(() {
                        selectedImage = picked;
                        imagenPath = picked.name;
                      });
                    }
                  },
                  child: Container(
                    height: 90,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0F1FF),
                      borderRadius: BorderRadius.circular(14),
                      image: selectedImage != null
                          ? DecorationImage(
                              image: MemoryImage(Uint8List.fromList(selectedImage!.bytes)),
                              fit: BoxFit.cover,
                            )
                          : (imagenPath != null
                              ? (imagenPath!.startsWith('http')
                                  ? DecorationImage(image: NetworkImage(imagenPath!), fit: BoxFit.cover)
                                  : (!kIsWeb
                                      ? DecorationImage(image: FileImage(File(imagenPath!)), fit: BoxFit.cover)
                                      : null))
                              : null),
                    ),
                    child: (selectedImage == null && imagenPath == null)
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
                              onTap: () => setModal(() {
                                selectedImage = null;
                                imagenPath = null;
                              }),
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
                    onPressed: isSaving
                        ? null
                        : () async {
                            if (nombreCtrl.text.isEmpty) return;

                            setModal(() {
                              isSaving = true;
                            });

                            String? finalImagenPath = imagenPath;

                            if (selectedImage != null) {
                              final repo = context.read<InventarioBloc>().insumoRepository;
                              final uploadedUrl = await repo.uploadImage(
                                nombreCtrl.text.trim().replaceAll(' ', '_'),
                                selectedImage!.bytes,
                                selectedImage!.extension,
                              );
                              if (uploadedUrl != null) {
                                finalImagenPath = uploadedUrl;
                              }
                            }

                            final p = Insumo(
                              id: producto?.id ?? const Uuid().v4(),
                              nombre: nombreCtrl.text.trim(),
                              unidad: unidadCtrl.text.trim().isEmpty ? 'pzs' : unidadCtrl.text.trim(),
                              stockActual: double.tryParse(cantidadCtrl.text) ?? 0,
                              stockMinimo: double.tryParse(cantMinCtrl.text) ?? 0,
                              costoUnitario: double.tryParse(precioCtrl.text) ?? 0,
                              categoria: categoria,
                              tipo: TipoInsumo.materiaPrima,
                              precioVenta: 0,
                              userId: producto?.userId,
                              updatedAt: DateTime.now(),
                              imagenPath: finalImagenPath,
                            );

                            if (isEdit) {
                              context.read<InventarioBloc>().add(UpdateInsumoEvent(p));
                            } else {
                              context.read<InventarioBloc>().add(AddInsumoEvent(p));
                            }

                            if (mounted) Navigator.pop(context);
                          },
                    child: isSaving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : Text(isEdit ? 'Guardar cambios' : 'Agregar insumo'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _confirmDelete(Insumo p) {
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
            onPressed: () {
              context.read<InventarioBloc>().add(DeleteInsumoEvent(p.id));
              if (mounted) Navigator.pop(context);
            },
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }
}

class PickedImageData {
  final String name;
  final List<int> bytes;
  final String extension;
  final String? localPath;

  PickedImageData({
    required this.name,
    required this.bytes,
    required this.extension,
    this.localPath,
  });
}
