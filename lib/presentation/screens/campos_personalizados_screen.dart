import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../core/di/service_locator.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_toast.dart';
import '../../core/widgets/hero_card.dart';
import '../../core/widgets/app_loader.dart';
import '../../domain/models/campo_personalizado.dart';
import '../../domain/repositories/campo_personalizado_repository.dart';

class CamposPersonalizadosScreen extends StatefulWidget {
  const CamposPersonalizadosScreen({super.key});

  @override
  State<CamposPersonalizadosScreen> createState() => _CamposPersonalizadosScreenState();
}

class _CamposPersonalizadosScreenState extends State<CamposPersonalizadosScreen> {
  final _repo = getIt<CampoPersonalizadoRepository>();
  List<CampoPersonalizado> _campos = [];
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargarCampos();
  }

  Future<void> _cargarCampos() async {
    setState(() => _cargando = true);
    try {
      final list = await _repo.getCampos();
      if (mounted) setState(() => _campos = list);
    } catch (e) {
      if (mounted) AppToast.showError(context, 'Error al cargar campos: $e');
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  void _abrirModalCrearEditar([CampoPersonalizado? campo]) {
    final nombreCtrl = TextEditingController(text: campo?.nombre ?? '');
    final opcionesCtrl = TextEditingController(text: campo?.opciones.join(', ') ?? '');
    TipoDatoCampo tipo = campo?.tipoDato ?? TipoDatoCampo.texto;
    bool obligatorio = campo?.obligatorio ?? false;
    String aplicaA = campo?.aplicaA ?? 'todos';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            padding: EdgeInsets.fromLTRB(24, 20, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppTheme.brandPrimary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Icons.playlist_add_rounded, color: AppTheme.brandPrimary),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          campo == null ? 'Nuevo Campo Personalizado' : 'Editar Campo',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  TextField(
                    controller: nombreCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nombre del Campo *',
                      hintText: 'Ej. Talla, Marca, Proveedor, Edad sugerida',
                      prefixIcon: Icon(Icons.label_outline_rounded),
                    ),
                  ),
                  const SizedBox(height: 14),

                  DropdownButtonFormField<TipoDatoCampo>(
                    value: tipo,
                    decoration: const InputDecoration(
                      labelText: 'Tipo de Dato',
                      prefixIcon: Icon(Icons.category_outlined),
                    ),
                    items: const [
                      DropdownMenuItem(value: TipoDatoCampo.texto, child: Text('Texto Libre')),
                      DropdownMenuItem(value: TipoDatoCampo.numero, child: Text('Número / Cantidad')),
                      DropdownMenuItem(value: TipoDatoCampo.fecha, child: Text('Fecha')),
                      DropdownMenuItem(value: TipoDatoCampo.opciones, child: Text('Lista Desplegable (Dropdown)')),
                      DropdownMenuItem(value: TipoDatoCampo.codigoBarras, child: Text('Código de Barras / QR (Con Escáner)')),
                    ],
                    onChanged: (val) {
                      if (val != null) setModalState(() => tipo = val);
                    },
                  ),

                  if (tipo == TipoDatoCampo.opciones) ...[
                    const SizedBox(height: 14),
                    TextField(
                      controller: opcionesCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Opciones separadas por coma *',
                        hintText: 'Ej: Chico, Mediano, Grande',
                        prefixIcon: Icon(Icons.list_alt_rounded),
                      ),
                    ),
                  ],

                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    value: aplicaA,
                    decoration: const InputDecoration(
                      labelText: 'Aplica para',
                      prefixIcon: Icon(Icons.inventory_2_outlined),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'todos', child: Text('Ambos (Materia Prima y Venta)')),
                      DropdownMenuItem(value: 'producto_venta', child: Text('Solo Productos de Venta')),
                      DropdownMenuItem(value: 'materia_prima', child: Text('Solo Materia Prima / Insumos')),
                    ],
                    onChanged: (val) {
                      if (val != null) setModalState(() => aplicaA = val);
                    },
                  ),

                  const SizedBox(height: 14),
                  SwitchListTile(
                    title: const Text('Campo obligatorio'),
                    subtitle: const Text('Exige llenarlo al guardar el producto'),
                    value: obligatorio,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (v) => setModalState(() => obligatorio = v),
                  ),

                  const SizedBox(height: 20),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.brandPrimary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () async {
                      final nom = nombreCtrl.text.trim();
                      if (nom.isEmpty) {
                        AppToast.showError(context, 'El nombre es obligatorio');
                        return;
                      }

                      List<String> ops = [];
                      if (tipo == TipoDatoCampo.opciones) {
                        ops = opcionesCtrl.text
                            .split(',')
                            .map((e) => e.trim())
                            .where((e) => e.isNotEmpty)
                            .toList();
                        if (ops.isEmpty) {
                          AppToast.showError(context, 'Ingresa al menos una opción para el desplegable');
                          return;
                        }
                      }

                      final nuevo = CampoPersonalizado(
                        id: campo?.id ?? const Uuid().v4(),
                        tenantId: campo?.tenantId ?? '',
                        nombre: nom,
                        tipoDato: tipo,
                        opciones: ops,
                        obligatorio: obligatorio,
                        aplicaA: aplicaA,
                        orden: campo?.orden ?? _campos.length,
                        createdAt: campo?.createdAt ?? DateTime.now(),
                      );

                      Navigator.pop(ctx);
                      await _repo.saveCampo(nuevo);
                      _cargarCampos();
                      if (mounted) AppToast.showSuccess(context, 'Campo guardado exitosamente');
                    },
                    child: const Text('Guardar Campo', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _eliminarCampo(CampoPersonalizado c) async {
    final conf = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Eliminar Campo?'),
        content: Text('Se eliminará "${c.nombre}". Los valores ya capturados en productos anteriores no se borrarán pero ya no aparecerá en el formulario.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (conf == true) {
      await _repo.deleteCampo(c.id);
      _cargarCampos();
      if (mounted) AppToast.showSuccess(context, 'Campo eliminado');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Campos del Inventario'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.brandPrimary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Crear Campo'),
        onPressed: () => _abrirModalCrearEditar(),
      ),
      body: _cargando
          ? const Center(child: AppSpinner(size: 36))
          : _campos.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.tune_rounded, size: 64, color: Colors.grey.withValues(alpha: 0.4)),
                        const SizedBox(height: 16),
                        const Text(
                          'Personaliza los datos de tu catálogo',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Crea campos a tu medida como "Marca", "Talla", "Proveedor", "Edad", etc. y aparecerán automáticamente en el alta de productos.',
                          style: TextStyle(fontSize: 13, color: context.textMuted),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.brandPrimary, foregroundColor: Colors.white),
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('Crear Primer Campo'),
                          onPressed: () => _abrirModalCrearEditar(),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
                  itemCount: _campos.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, idx) {
                    final c = _campos[idx];
                    return HeroCard(
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppTheme.brandPrimary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(_getIconForTipo(c.tipoDato), color: AppTheme.brandPrimary),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      c.nombre,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                    ),
                                    if (c.obligatorio) ...[
                                      const SizedBox(width: 6),
                                      const Text('*', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Tipo: ${_getLabelForTipo(c.tipoDato)} • Aplica: ${_getLabelAplica(c.aplicaA)}',
                                  style: TextStyle(fontSize: 12, color: context.textMuted),
                                ),
                                if (c.tipoDato == TipoDatoCampo.opciones && c.opciones.isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Wrap(
                                    spacing: 4,
                                    children: c.opciones
                                        .map((op) => Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: Colors.grey.withValues(alpha: 0.15),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(op, style: const TextStyle(fontSize: 10)),
                                            ))
                                        .toList(),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 20),
                            tooltip: 'Editar',
                            onPressed: () => _abrirModalCrearEditar(c),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline_rounded, size: 20, color: Colors.red),
                            tooltip: 'Eliminar',
                            onPressed: () => _eliminarCampo(c),
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }

  IconData _getIconForTipo(TipoDatoCampo t) {
    switch (t) {
      case TipoDatoCampo.texto:
        return Icons.text_fields_rounded;
      case TipoDatoCampo.numero:
        return Icons.numbers_rounded;
      case TipoDatoCampo.fecha:
        return Icons.calendar_today_rounded;
      case TipoDatoCampo.opciones:
        return Icons.arrow_drop_down_circle_outlined;
      case TipoDatoCampo.codigoBarras:
        return Icons.qr_code_scanner_rounded;
    }
  }

  String _getLabelForTipo(TipoDatoCampo t) {
    switch (t) {
      case TipoDatoCampo.texto:
        return 'Texto Libre';
      case TipoDatoCampo.numero:
        return 'Número';
      case TipoDatoCampo.fecha:
        return 'Fecha';
      case TipoDatoCampo.opciones:
        return 'Opciones';
      case TipoDatoCampo.codigoBarras:
        return 'Código de Barras / QR';
    }
  }

  String _getLabelAplica(String a) {
    switch (a) {
      case 'materia_prima':
        return 'Solo Insumos';
      case 'producto_venta':
        return 'Solo Venta';
      default:
        return 'Todos';
    }
  }
}

