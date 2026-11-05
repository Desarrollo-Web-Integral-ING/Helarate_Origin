import 'campos_personalizados_screen.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../../core/widgets/app_loader.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/hero_card.dart';
import '../../core/widgets/business_icon_helper.dart';
import '../../core/widgets/app_toast.dart';
import '../../domain/models/tenant_model.dart';
import '../blocs/auth/auth_bloc.dart';
import '../blocs/auth/auth_event.dart';
import '../blocs/auth/auth_state.dart';

class PersonalizacionScreen extends StatefulWidget {
  const PersonalizacionScreen({super.key});

  @override
  State<PersonalizacionScreen> createState() => _PersonalizacionScreenState();
}

class _PersonalizacionScreenState extends State<PersonalizacionScreen> {
  final TextEditingController _nombreCtrl = TextEditingController();
  final TextEditingController _monedaCtrl = TextEditingController();
  final TextEditingController _telefonoCtrl = TextEditingController();
  final TextEditingController _direccionCtrl = TextEditingController();
  final TextEditingController _mensajeCtrl = TextEditingController();

  String _colorPrimario = '#2563EB';
  String _selectedIcon = 'storefront';
  String? _logoBase64;
  bool _guardando = false;
  bool _initialized = false;

  final List<Map<String, dynamic>> _coloresDisponibles = [
    {'label': 'Azul Royal', 'hex': '#2563EB', 'color': const Color(0xFF2563EB)},
    {'label': 'Esmeralda', 'hex': '#10B981', 'color': const Color(0xFF10B981)},
    {'label': 'Índigo Violeta', 'hex': '#6366F1', 'color': const Color(0xFF6366F1)},
    {'label': 'Ámbar Cálido', 'hex': '#F59E0B', 'color': const Color(0xFFF59E0B)},
    {'label': 'Rosa Coral', 'hex': '#F43F5E', 'color': const Color(0xFFF43F5E)},
    {'label': 'Cian Neón', 'hex': '#06B6D4', 'color': const Color(0xFF06B6D4)},
    {'label': 'Púrpura Deep', 'hex': '#9333EA', 'color': const Color(0xFF9333EA)},
    {'label': 'Grafito Slate', 'hex': '#475569', 'color': const Color(0xFF475569)},
  ];

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _monedaCtrl.dispose();
    _telefonoCtrl.dispose();
    _direccionCtrl.dispose();
    _mensajeCtrl.dispose();
    super.dispose();
  }

  void _initFields(TenantModel tenant) {
    if (_initialized) return;
    _nombreCtrl.text = tenant.nombre;
    _monedaCtrl.text = tenant.moneda;
    _telefonoCtrl.text = tenant.telefono ?? '';
    _direccionCtrl.text = tenant.direccion ?? '';
    _mensajeCtrl.text = tenant.mensajeRecibo ?? '¡Gracias por su compra!';
    _colorPrimario = tenant.colorPrimario;
    _selectedIcon = tenant.logoIcon;
    _logoBase64 = tenant.logoUrl;
    _initialized = true;
  }

  Future<void> _seleccionarLogo() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['png', 'jpg', 'jpeg', 'webp'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;

      if (file.bytes == null) {
        AppToast.showError(context, 'No se pudo leer la imagen seleccionada');
        return;
      }

      // Validar peso de imagen (máximo 800 KB para almacenamiento óptimo en BD)
      if (file.bytes!.lengthInBytes > 5 * 1024 * 1024) {
        AppToast.showError(context, 'La imagen supera los 5 MB. Elige una imagen más liviana.');
        return;
      }

      final ext = file.extension?.toLowerCase() ?? 'png';
      final mime = ext == 'jpg' || ext == 'jpeg' ? 'image/jpeg' : (ext == 'webp' ? 'image/webp' : 'image/png');
      final base64String = 'data:$mime;base64,${base64Encode(file.bytes!)}';

      setState(() {
        _logoBase64 = base64String;
      });

      AppToast.showSuccess(context, 'Logo cargado. Presiona Guardar para aplicarlo.');
    } catch (e) {
      AppToast.showError(context, 'Error al cargar imagen: $e');
    }
  }

  void _eliminarLogo() {
    setState(() {
      _logoBase64 = null;
    });
  }

  Future<void> _guardarCambios(TenantModel currentTenant) async {
    final nombre = _nombreCtrl.text.trim();
    if (nombre.isEmpty) {
      AppToast.showError(context, 'El nombre comercial no puede estar vacío');
      return;
    }

    setState(() => _guardando = true);
    try {
      final updated = currentTenant.copyWith(
        nombre: nombre,
        colorPrimario: _colorPrimario,
        moneda: _monedaCtrl.text.trim().isNotEmpty ? _monedaCtrl.text.trim() : '\$',
        telefono: _telefonoCtrl.text.trim(),
        direccion: _direccionCtrl.text.trim(),
        mensajeRecibo: _mensajeCtrl.text.trim(),
        logoIcon: _selectedIcon,
        logoUrl: _logoBase64,
        clearLogoUrl: _logoBase64 == null,
      );

      context.read<AuthBloc>().add(UpdateTenantRequested(updated));
      if (!mounted) return;
      AppToast.showSuccess(context, '¡Logo, colores y datos de marca guardados!');
    } catch (e) {
      if (mounted) AppToast.showError(context, 'No se pudo guardar la personalización: $e');
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        if (state is! Authenticated) {
          return const AppSplash();
        }

        final tenant = state.tenant ??
            TenantModel(
              id: state.usuario.tenantId ?? 'default',
              nombre: 'Mi Negocio',
              colorPrimario: _colorPrimario,
            );

        _initFields(tenant);
        final brandColor = AppTheme.parseHexColor(_colorPrimario);

        return Scaffold(
          appBar: AppBar(
            title: const Text('Identidad de Marca & Empresa'),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 48),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Banner Preview estilo HeroUI
                _buildPreviewCard(brandColor),
                const SizedBox(height: 24),

                // Selector de Logo (Carga de Imagen Real o Ícono Vectorial)
                _buildLogoUploadCard(brandColor),
                const SizedBox(height: 24),

                // Selector de Paleta de Color Primario
                _buildColorPaletteCard(brandColor),
                const SizedBox(height: 24),

                // Datos Comerciales
                _buildCompanyDetailsCard(brandColor),
          const SizedBox(height: 20),
          HeroCard(
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: brandColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(Icons.tune_rounded, color: brandColor, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Campos Personalizados del Inventario',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Crea atributos propios para tus productos (Marca, Talla, Proveedor, etc.)',
                        style: TextStyle(fontSize: 12, color: context.textMuted),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: brandColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                  label: const Text('Gestionar'),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CamposPersonalizadosScreen()),
                  ),
                ),
              ],
            ),
          ),

                const SizedBox(height: 32),

                // Botón Guardar Flotante de Alto Impacto
                Container(
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: AppTheme.createCustomGradient(brandColor),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: brandColor.withValues(alpha: 0.4),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    icon: _guardando
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: const AppSpinner(size: 20, color: Colors.white),
                          )
                        : const Icon(Icons.check_circle_rounded, color: Colors.white),
                    label: Text(
                      _guardando ? 'Guardando Personalización...' : 'Aplicar y Guardar Cambios',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    onPressed: _guardando ? null : () => _guardarCambios(tenant),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPreviewCard(Color brandColor) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            brandColor,
            brandColor.withValues(alpha: 0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: brandColor.withValues(alpha: 0.35),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1.5),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: _logoBase64 != null && _logoBase64!.isNotEmpty
                  ? Image.memory(
                      base64Decode(_logoBase64!.contains(',') ? _logoBase64!.split(',').last : _logoBase64!),
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Icon(
                        BusinessIconHelper.getIcon(_selectedIcon),
                        color: Colors.white,
                        size: 38,
                      ),
                    )
                  : Icon(
                      BusinessIconHelper.getIcon(_selectedIcon),
                      color: Colors.white,
                      size: 38,
                    ),
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'VISTA PREVIA DE TU MARCA',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _nombreCtrl.text.trim().isNotEmpty ? _nombreCtrl.text.trim() : 'Nombre de tu Empresa',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Moneda activa: ${_monedaCtrl.text.trim().isNotEmpty ? _monedaCtrl.text.trim() : "\$"} • Logo: ${_logoBase64 != null ? "Imagen personalizada" : "Ícono vectorial"}',
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogoUploadCard(Color brandColor) {
    final isMobile = MediaQuery.of(context).size.width < 500;
    return HeroCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: brandColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.add_photo_alternate_rounded, color: brandColor, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Logo de tu Negocio / Empresa', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                    Text('Sube el logotipo real de tu negocio (PNG, JPG, WebP) o selecciona un ícono rápido', style: TextStyle(fontSize: 12, color: context.textMuted)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Sección de Carga de Archivo (Base64 directo a BD)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: brandColor.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: brandColor.withValues(alpha: 0.2), width: 1.5),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isSmall = constraints.maxWidth < 500;
                final logoWidget = Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(15),
                    child: _logoBase64 != null && _logoBase64!.isNotEmpty
                        ? Image.memory(
                            base64Decode(_logoBase64!.contains(',') ? _logoBase64!.split(',').last : _logoBase64!),
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Icon(BusinessIconHelper.getIcon(_selectedIcon), color: brandColor, size: 30),
                          )
                        : Icon(BusinessIconHelper.getIcon(_selectedIcon), color: brandColor, size: 30),
                  ),
                );
                final infoWidget = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _logoBase64 != null ? 'Logotipo propio activo' : 'Sin logo cargado (usando ícono)',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _logoBase64 != null
                          ? 'Este logo se mostrará en el sidebar, encabezados y tickets.'
                          : 'Sube el archivo PNG, JPG o WebP de tu empresa.',
                      style: TextStyle(fontSize: 12, color: context.textMuted),
                    ),
                  ],
                );
                final actionsWidget = Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: brandColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.upload_file_rounded, size: 18),
                      label: Text(_logoBase64 != null ? 'Cambiar' : 'Subir Logo'),
                      onPressed: _seleccionarLogo,
                    ),
                    if (_logoBase64 != null) ...[
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.red,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        ),
                        icon: const Icon(Icons.delete_outline_rounded, size: 16),
                        label: const Text('Quitar', style: TextStyle(fontSize: 12)),
                        onPressed: _eliminarLogo,
                      ),
                    ],
                  ],
                );
                if (isSmall) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          logoWidget,
                          const SizedBox(width: 14),
                          Expanded(child: infoWidget),
                        ],
                      ),
                      const SizedBox(height: 14),
                      actionsWidget,
                    ],
                  );
                }
                return Row(
                  children: [
                    logoWidget,
                    const SizedBox(width: 16),
                    Expanded(child: infoWidget),
                    const SizedBox(width: 12),
                    actionsWidget,
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 20),

          const Text(
            'O elige un ícono representativo de giro comercial:',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          const SizedBox(height: 12),

          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: isMobile ? 3 : 6,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.1,
            ),
            itemCount: BusinessIconHelper.icons.length,
            itemBuilder: (context, idx) {
              final entry = BusinessIconHelper.icons.entries.elementAt(idx);
              final isSelected = _selectedIcon == entry.key && _logoBase64 == null;

              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedIcon = entry.key;
                    _logoBase64 = null; // Si elige un ícono rápido, reemplaza el logo
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  decoration: BoxDecoration(
                    color: isSelected ? brandColor.withValues(alpha: 0.15) : Colors.grey.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected ? brandColor : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      entry.value,
                      color: isSelected ? brandColor : context.textMuted,
                      size: 26,
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildColorPaletteCard(Color brandColor) {
    return HeroCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: brandColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.palette_rounded, color: brandColor, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Color de Marca del Sistema', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                    Text('Personaliza los botones, resaltados y barras de navegación', style: TextStyle(fontSize: 12, color: context.textMuted)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: _coloresDisponibles.map((c) {
              final isSelected = _colorPrimario.toUpperCase() == (c['hex'] as String).toUpperCase();
              final color = c['color'] as Color;

              return GestureDetector(
                onTap: () => setState(() => _colorPrimario = c['hex'] as String),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? color.withValues(alpha: 0.15) : Colors.grey.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: isSelected ? color : Colors.transparent, width: 2),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                        child: isSelected ? const Icon(Icons.check, size: 12, color: Colors.white) : null,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        c['label'] as String,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          color: isSelected ? color : null,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildCompanyDetailsCard(Color brandColor) {
    return HeroCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: brandColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.business_rounded, color: brandColor, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Datos de tu Negocio', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                    Text('Información visible para ventas, clientes y tickets', style: TextStyle(fontSize: 12, color: context.textMuted)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _nombreCtrl,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'Nombre Comercial',
              prefixIcon: Icon(Icons.storefront_rounded),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _monedaCtrl,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    labelText: 'Símbolo Moneda (\$ o MXN)',
                    prefixIcon: Icon(Icons.attach_money_rounded),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: TextFormField(
                  controller: _telefonoCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Teléfono de Contacto',
                    prefixIcon: Icon(Icons.phone_rounded),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _direccionCtrl,
            decoration: const InputDecoration(
              labelText: 'Dirección o Sucursal',
              prefixIcon: Icon(Icons.location_on_outlined),
            ),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _mensajeCtrl,
            decoration: const InputDecoration(
              labelText: 'Mensaje de agradecimiento en recibos',
              prefixIcon: Icon(Icons.receipt_long_rounded),
            ),
          ),
        ],
      ),
    );
  }
}

