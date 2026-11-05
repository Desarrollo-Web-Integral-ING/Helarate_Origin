import '../../core/di/service_locator.dart';
import '../../domain/models/campo_personalizado.dart';
import '../../domain/repositories/campo_personalizado_repository.dart';
import '../widgets/formulario_campos_dinamicos.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../core/widgets/app_loader.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/models/insumo.dart';
import '../blocs/inventario/inventario_bloc.dart';
import '../blocs/inventario/inventario_event.dart';
import '../blocs/inventario/inventario_state.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/money.dart';
import '../../core/widgets/app_toast.dart';
import '../../core/widgets/indexed_stack_resume.dart';

class InventarioVentaScreen extends StatefulWidget {
  const InventarioVentaScreen({super.key});

  @override
  State<InventarioVentaScreen> createState() => _InventarioVentaScreenState();
}

class _InventarioVentaScreenState extends State<InventarioVentaScreen> {
  List<CampoPersonalizado> _camposPersonalizados = [];

  Future<void> _cargarCamposPersonalizados() async {
    try {
      final repo = getIt<CampoPersonalizadoRepository>();
      final list = await repo.getCampos();
      if (mounted) {
        setState(() {
          _camposPersonalizados = list.where((c) => c.aplicaA == 'todos' || c.aplicaA == 'producto_venta').toList();
        });
      }
    } catch (_) {}
  }

  NumberFormat get _fmt => Money.of(context);
  List<Insumo> _items = [];
  String _busqueda = '';
  String _filtroCategoria = 'Todos';

  List<String> get _categoriasDisponibles {
    final setCats = _items.map((i) => i.categoria).where((c) => c.isNotEmpty).toSet();
    if (setCats.isEmpty) return ['General'];
    return setCats.toList()..sort();
  }

  List<String> get _filtros {
    return ['Todos', ..._categoriasDisponibles];
  }

  @override
  void initState() {
    super.initState();
    _cargarCamposPersonalizados();
    context.read<InventarioBloc>().add(LoadInventario());
    activeTabNotifier.addListener(_onTabChange);
  }

  void _onTabChange() {
    if (activeTabNotifier.value == 2) {
      context.read<InventarioBloc>().add(LoadInventario());
    }
  }

  @override
  void dispose() {
    activeTabNotifier.removeListener(_onTabChange);
    super.dispose();
  }

  List<Insumo> get _filtrados {
    var list = _items;
    if (_filtroCategoria != 'Todos') {
      list = list.where((p) => p.categoria == _filtroCategoria).toList();
    }
    if (_busqueda.isNotEmpty) {
      list = list.where((p) =>
          p.nombre.toLowerCase().contains(_busqueda.toLowerCase()) ||
          (p.sabor != null && p.sabor!.toLowerCase().contains(_busqueda.toLowerCase()))).toList();
    }
    return list;
  }

  void _ajustarStock(Insumo p, int delta) {
    final nuevo = (p.stockActual + delta).clamp(0.0, 99999.0);
    final actualizado = p.copyWith(stockActual: nuevo, updatedAt: DateTime.now());
    context.read<InventarioBloc>().add(UpdateInsumoEvent(actualizado));
  }

  Future<PickedImageData?> _pickImage() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        withData: true,
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
        title: const Text('Catálogo de Productos'),
        actions: [
          IconButton(icon: const Icon(Icons.add_rounded), onPressed: () => _showForm()),
        ],
      ),
      body: BlocBuilder<InventarioBloc, InventarioState>(
        builder: (context, state) {
          if (state is InventarioLoading || state is InventarioInitial) {
            return const AppLoader();
          }
          if (state is InventarioError) {
            return Center(child: Text('Error: ${state.message}'));
          }
          if (state is InventarioLoaded) {
            _items = state.insumos.where((i) => i.tipo == TipoInsumo.productoVenta).toList();

            return Column(
              children: [
                _buildHeader(),
                _buildSearchBar(),
                _buildCategoryFilter(),
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
        decoration: InputDecoration(
          hintText: 'Buscar producto o detalle...',
          prefixIcon: Icon(Icons.search_rounded, color: context.textMuted),
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
                color: selected ? Colors.white : context.textMuted,
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
            Text('Sin productos registrados',
                style: TextStyle(color: context.textMuted, fontSize: 15)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => _showForm(),
              icon: const Icon(Icons.add),
              label: const Text('Agregar producto'),
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

  Widget _buildCard(Insumo p) {
    final agotado = p.stockActual == 0;
    final Color borderColor = agotado ? const Color(0xFFE53935)
        : p.stockBajo ? const Color(0xFFFFB74D) : Colors.transparent;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Color bgColor = agotado ? (isDark ? const Color(0xFF450A0A) : const Color(0xFFFFF0F0))
        : p.stockBajo ? (isDark ? const Color(0xFF451A03) : const Color(0xFFFFFBF0)) : (isDark ? const Color(0xFF1E293B) : Colors.white);

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
            leading: _avatar(context, p.imagenPath, p.nombre, agotado, p.stockBajo),
            title: Text(p.nombre, style: TextStyle(
                fontWeight: FontWeight.w600, fontSize: 14, color: isDark ? Color(0xFFF8FAFC) : context.textMain)),
            subtitle: Text(
              [
                // sabor
                p.categoria,
                // tamano
              ].join(' · '),
              style: TextStyle(fontSize: 11, color: isDark ? Color(0xFF94A3B8) : context.textMuted),
            ),
            trailing: SizedBox(
              width: 80,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(_fmt.format(p.precioVenta),
                      style: TextStyle(fontWeight: FontWeight.w700,
                          color: context.brand, fontSize: 13),
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
                      '${p.stockActual.toInt()} ${p.categoria == 'Litro' || p.categoria == 'Cazuela' ? 'L' : 'pzs'}',
                      style: TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 15,
                        color: agotado ? const Color(0xFFE53935)
                            : p.stockBajo ? Color(0xFFE65100) : context.textMain,
                      ),
                    ),
                  ),
                ),
                _qBtn(Icons.add, () => _ajustarStock(p, 1), false),
                const SizedBox(width: 6),
                _qBtn(Icons.edit_outlined, () => _showAjusteDialog(p), false,
                    color: context.brand),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showFullImage(BuildContext context, String? path, String title) {
    if (path == null) return;
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment.topRight,
              child: IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white, size: 30),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.7,
                maxWidth: MediaQuery.of(context).size.width * 0.9,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: InteractiveViewer(
                  panEnabled: true,
                  boundaryMargin: const EdgeInsets.all(20),
                  minScale: 0.5,
                  maxScale: 4.0,
                  child: path.startsWith('http')
                      ? Image.network(path, fit: BoxFit.contain)
                      : Image.file(File(path), fit: BoxFit.contain),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _avatar(BuildContext context, String? path, String nombre, bool agotado, bool stockBajo) {
    Widget avatarWidget;
    if (path != null) {
      if (path.startsWith('http')) {
        avatarWidget = ClipRRect(
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
      } else if (!kIsWeb && File(path).existsSync()) {
        avatarWidget = ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Image.file(File(path), width: 48, height: 48, fit: BoxFit.cover),
        );
      } else {
        avatarWidget = Container(
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
    } else {
      avatarWidget = Container(
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

    if (path != null) {
      return GestureDetector(
        onTap: () => _showFullImage(context, path, nombre),
        child: avatarWidget,
      );
    }
    return avatarWidget;
  }

  Widget _stockChip(Insumo p) {
    final agotado = p.stockActual == 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: agotado ? Colors.red.withValues(alpha: 0.14)
            : p.stockBajo ? Colors.orange.withValues(alpha: 0.16) : Colors.green.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            agotado ? Icons.cancel_rounded
                : p.stockBajo ? Icons.warning_amber_rounded : Icons.check_circle_rounded,
            color: agotado ? const Color(0xFFC62828)
                : p.stockBajo ? const Color(0xFFE65100) : const Color(0xFF2E7D32),
            size: 13,
          ),
          const SizedBox(width: 4),
          Text(
            agotado ? 'Agotado' : p.stockBajo ? 'Bajo' : 'OK',
            style: TextStyle(
              fontSize: 10, fontWeight: FontWeight.w700,
              color: agotado ? const Color(0xFFC62828)
                  : p.stockBajo ? const Color(0xFFE65100) : const Color(0xFF2E7D32),
            ),
          ),
        ],
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
              : (color ?? context.brand).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 18,
            color: disabled ? Colors.grey : (color ?? context.brand)),
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
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Nueva cantidad'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () {
              final val = double.tryParse(ctrl.text);
              if (val == null) return;
              final actualizado = p.copyWith(stockActual: val, updatedAt: DateTime.now());
              context.read<InventarioBloc>().add(UpdateInsumoEvent(actualizado));
              if (mounted) Navigator.pop(context);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  void _showForm({Insumo? producto}) async {
    await _cargarCamposPersonalizados();
    final isEdit = producto != null;
    final nombreCtrl = TextEditingController(text: producto?.nombre ?? '');
    final saborCtrl = TextEditingController(text: producto?.sabor ?? '');
    final codigoCtrl = TextEditingController(text: producto?.codigoBarras ?? '');
    final skuCtrl = TextEditingController(text: producto?.sku ?? '');
    final precioCtrl = TextEditingController(
        text: producto?.precioVenta == 0 ? '' : producto?.precioVenta.toString() ?? '');
    final stockCtrl = TextEditingController(
        text: producto?.stockActual == 0 ? '' : producto?.stockActual.toString() ?? '');
    final stockMinCtrl = TextEditingController(text: producto?.stockMinimo.toString() ?? '1');
    final categoriaCtrl = TextEditingController(text: producto?.categoria ?? 'General');
    String? imagenPath = producto?.imagenPath;
    PickedImageData? selectedImage;
    bool isSaving = false;
    final formKey = GlobalKey<FormState>();
    final Map<String, dynamic> atributosMap = Map<String, dynamic>.from(producto?.atributos ?? {});

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
          decoration: BoxDecoration(
            color: context.surfaceColor,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(child: Container(width: 40, height: 4,
                      decoration: BoxDecoration(color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(2)))),
                  const SizedBox(height: 16),
                  Text(isEdit ? 'Editar producto' : 'Nuevo producto',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700,
                          color: context.textMain)),
                  const SizedBox(height: 16),
                  // Imagen
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
                        color: context.brand.withValues(alpha: 0.10),
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
                          ? Center(child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add_photo_alternate_outlined,
                                    color: context.textMuted, size: 28),
                                SizedBox(height: 4),
                                Text('Agregar imagen (opcional)',
                                    style: TextStyle(color: context.textMuted, fontSize: 12)),
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
                  TextFormField(
                    controller: nombreCtrl,
                    decoration: const InputDecoration(labelText: 'Nombre'),
                    maxLength: 50,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Por favor ingresa el nombre del producto';
                      }
                      if (value.trim().length > 50) {
                        return 'El nombre no puede superar los 50 caracteres';
                      }
                      return null;
                    },
                  ),

                  FormularioCamposDinamicos(
                    campos: _camposPersonalizados,
                    valores: atributosMap,
                    onValorChanged: (k, v) => atributosMap[k] = v,
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: isSaving
                          ? null
                          : () async {
                              if (!formKey.currentState!.validate()) return;

                              final bloc = context.read<InventarioBloc>();
                              setModal(() {
                                isSaving = true;
                              });

                              String? finalImagenPath = imagenPath;

                              if (selectedImage != null) {
                                final uploadedUrl = await bloc.insumoRepository.uploadImage(
                                  nombreCtrl.text.trim().replaceAll(' ', '_'),
                                  selectedImage!.bytes,
                                  selectedImage!.extension,
                                );
                                if (uploadedUrl != null) {
                                  finalImagenPath = uploadedUrl;
                                }
                              }

                              final p = producto != null 
                                  ? producto.copyWith(
                                      nombre: nombreCtrl.text.trim(),
                                      sabor: null,
                                      tamano: null,
                                      precioVenta: double.tryParse(precioCtrl.text) ?? 0.0,
                                      costoUnitario: producto.costoUnitario,
                                      codigoBarras: codigoCtrl.text.trim().isEmpty ? null : codigoCtrl.text.trim(),
                                      sku: skuCtrl.text.trim().isEmpty ? null : skuCtrl.text.trim(),
                                      stockActual: double.tryParse(stockCtrl.text) ?? 0,
                                      stockMinimo: double.tryParse(stockMinCtrl.text) ?? 1.0,
                                      unidad: 'pzs',
                                      categoria: categoriaCtrl.text.trim().isNotEmpty ? categoriaCtrl.text.trim() : 'General',
                                      tipo: TipoInsumo.productoVenta,
                                      updatedAt: DateTime.now(),
                                      imagenPath: finalImagenPath,
                                      atributos: atributosMap,
                                    )
                                  : Insumo(
                                      codigoBarras: codigoCtrl.text.trim().isEmpty ? null : codigoCtrl.text.trim(),
                                      sku: skuCtrl.text.trim().isEmpty ? null : skuCtrl.text.trim(),
                                      id: const Uuid().v4(),
                                      nombre: nombreCtrl.text.trim(),
                                      sabor: null,
                                      tamano: null,
                                      precioVenta: double.tryParse(precioCtrl.text) ?? 0.0,
                                      costoUnitario: 0,
                                      stockActual: double.tryParse(stockCtrl.text) ?? 0,
                                      stockMinimo: double.tryParse(stockMinCtrl.text) ?? 1.0,
                                      unidad: 'pzs',
                                      categoria: categoriaCtrl.text.trim().isNotEmpty ? categoriaCtrl.text.trim() : 'General',
                                      tipo: TipoInsumo.productoVenta,
                                      updatedAt: DateTime.now(),
                                      imagenPath: finalImagenPath,
                                      atributos: atributosMap,
                                    );

                              if (isEdit) {
                                bloc.add(UpdateInsumoEvent(p));
                              } else {
                                bloc.add(AddInsumoEvent(p));
                              }

                              if (mounted) {
                                AppToast.showSuccess(
                                  context,
                                  isEdit ? 'Producto actualizado con éxito' : 'Producto agregado con éxito',
                                );
                                Navigator.pop(context);
                              }
                            },
                      child: isSaving
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: AppSpinner(size: 20, color: Colors.white),
                            )
                          : Text(isEdit ? 'Guardar cambios' : 'Agregar'),
                    ),
                  ),
                ],
              ),
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
        title: const Text('Eliminar producto'),
        content: Text('¿Eliminar "${p.nombre}" del inventario?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              context.read<InventarioBloc>().add(DeleteInsumoEvent(p.id));
              if (mounted) {
                AppToast.showInfo(context, 'Producto "${p.nombre}" eliminado');
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
