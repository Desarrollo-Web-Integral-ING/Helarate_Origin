import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../domain/models/campo_personalizado.dart';
import 'barcode_scanner_screen.dart';
import '../screens/campos_personalizados_screen.dart';

class FormularioCamposDinamicos extends StatelessWidget {
  final List<CampoPersonalizado> campos;
  final Map<String, dynamic> valores;
  final void Function(String key, dynamic value) onValorChanged;

  const FormularioCamposDinamicos({
    super.key,
    required this.campos,
    required this.valores,
    required this.onValorChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (campos.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: context.brand.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: context.brand.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              Icon(Icons.tune_rounded, size: 20, color: context.brand),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Personaliza este formulario: agrega Marca, Talla, Proveedor, Lote, etc.',
                  style: TextStyle(fontSize: 12, color: context.textMuted),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CamposPersonalizadosScreen()),
                ),
                child: const Text('Configurar', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Row(
          children: [
            Icon(Icons.tune_rounded, size: 18, color: AppTheme.brandPrimary),
            const SizedBox(width: 8),
            Text(
              'Campos Personalizados del Negocio',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: context.textMain,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...campos.map((campo) {
          final valorActual = valores[campo.nombre];

          switch (campo.tipoDato) {
            case TipoDatoCampo.texto:
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: TextFormField(
                  initialValue: valorActual?.toString() ?? '',
                  decoration: InputDecoration(
                    labelText: '${campo.nombre}${campo.obligatorio ? " *" : ""}',
                    hintText: 'Ingresa ${campo.nombre}',
                  ),
                  validator: (v) {
                    if (campo.obligatorio && (v == null || v.trim().isEmpty)) {
                      return 'Este campo es obligatorio';
                    }
                    return null;
                  },
                  onChanged: (val) => onValorChanged(campo.nombre, val.trim()),
                ),
              );

            case TipoDatoCampo.numero:
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: TextFormField(
                  initialValue: valorActual?.toString() ?? '',
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: '${campo.nombre}${campo.obligatorio ? " *" : ""}',
                    hintText: '0',
                  ),
                  validator: (v) {
                    if (campo.obligatorio && (v == null || v.trim().isEmpty)) {
                      return 'Este campo es obligatorio';
                    }
                    if (v != null && v.isNotEmpty && double.tryParse(v) == null) {
                      return 'Ingresa un número válido';
                    }
                    return null;
                  },
                  onChanged: (val) => onValorChanged(campo.nombre, double.tryParse(val) ?? val),
                ),
              );

            case TipoDatoCampo.opciones:
              final opciones = campo.opciones;
              String? selected = opciones.contains(valorActual?.toString()) ? valorActual?.toString() : null;

              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: DropdownButtonFormField<String>(
                  value: selected,
                  decoration: InputDecoration(
                    labelText: '${campo.nombre}${campo.obligatorio ? " *" : ""}',
                  ),
                  items: opciones
                      .map((op) => DropdownMenuItem(value: op, child: Text(op)))
                      .toList(),
                  validator: (v) {
                    if (campo.obligatorio && (v == null || v.isEmpty)) {
                      return 'Selecciona una opción';
                    }
                    return null;
                  },
                  onChanged: (val) {
                    if (val != null) onValorChanged(campo.nombre, val);
                  },
                ),
              );

            case TipoDatoCampo.fecha:
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) {
                      final str = "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
                      onValorChanged(campo.nombre, str);
                    }
                  },
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: '${campo.nombre}${campo.obligatorio ? " *" : ""}',
                      suffixIcon: const Icon(Icons.calendar_today_rounded, size: 18),
                    ),
                    child: Text(
                      valorActual?.toString() ?? 'Seleccionar fecha...',
                      style: TextStyle(
                        color: valorActual != null ? context.textMain : context.textMuted,
                      ),
                    ),
                  ),
                ),
              );

            case TipoDatoCampo.codigoBarras:
              final controller = TextEditingController(text: valorActual?.toString() ?? '');
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: controller,
                        decoration: InputDecoration(
                          labelText: '${campo.nombre}${campo.obligatorio ? " *" : ""}',
                          hintText: 'Escanea o escribe el código',
                          prefixIcon: const Icon(Icons.qr_code_scanner_rounded, size: 20),
                        ),
                        validator: (v) {
                          if (campo.obligatorio && (v == null || v.trim().isEmpty)) {
                            return 'Este campo es obligatorio';
                          }
                          return null;
                        },
                        onChanged: (val) => onValorChanged(campo.nombre, val.trim()),
                      ),
                    ),
                    if (!kIsWeb) ...[
                      const SizedBox(width: 8),
                      IconButton.filledTonal(
                        icon: const Icon(Icons.camera_alt_rounded),
                        tooltip: 'Escanear con cámara',
                        onPressed: () async {
                          final code = await Navigator.push<String>(
                            context,
                            MaterialPageRoute(
                              builder: (_) => BarcodeScannerScreen(
                                onScanned: (c) => Navigator.pop(context, c),
                              ),
                            ),
                          );
                          if (code != null && code.isNotEmpty) {
                            controller.text = code;
                            onValorChanged(campo.nombre, code);
                          }
                        },
                      ),
                    ],
                  ],
                ),
              );
          }
        }),
      ],
    );
  }
}

