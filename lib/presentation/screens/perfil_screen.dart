import 'dart:convert';
import 'package:flutter/material.dart';
import '../../core/widgets/app_loader.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;

import '../../core/di/service_locator.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/hero_card.dart';
import '../../core/widgets/business_icon_helper.dart';
import '../../domain/models/usuario_perfil.dart';
import '../../domain/models/tenant_model.dart';
import '../../domain/repositories/auth_repository.dart';
import '../blocs/auth/auth_bloc.dart';
import '../blocs/auth/auth_event.dart';
import '../blocs/auth/auth_state.dart';

import '../../core/widgets/app_toast.dart';

class PerfilScreen extends StatefulWidget {
  const PerfilScreen({super.key});

  @override
  State<PerfilScreen> createState() => _PerfilScreenState();
}

class _PerfilScreenState extends State<PerfilScreen> {
  final AuthRepository _authRepository = getIt<AuthRepository>();
  final TextEditingController _nombreController = TextEditingController();

  // Controladores de negocio
  final TextEditingController _negocioNombreCtrl = TextEditingController();
  final TextEditingController _negocioColorCtrl = TextEditingController();
  final TextEditingController _negocioMonedaCtrl = TextEditingController();
  final TextEditingController _negocioDireccionCtrl = TextEditingController();
  final TextEditingController _negocioTelefonoCtrl = TextEditingController();

  bool _editandoNombre = false;
  bool _guardandoNombre = false;
  bool _guardandoNegocio = false;
  bool _guardandoAvatar = false;
  bool _modoOscuro = false;
  String _selectedBusinessIcon = 'storefront';

  // Opciones de estilos de avatares DiceBear
  final List<Map<String, String>> _avatarStyles = [
    {'id': 'notionists', 'label': 'Notion Minimal'},
    {'id': 'bottts', 'label': 'Robots Tech'},
    {'id': 'lorelei', 'label': 'Arte Anime'},
    {'id': 'adventurer', 'label': 'Ilustrado'},
    {'id': 'avataaars', 'label': 'Clásico Humano'},
    {'id': 'micah', 'label': 'Modern Flat'},
  ];

  @override
  void dispose() {
    _nombreController.dispose();
    _negocioNombreCtrl.dispose();
    _negocioColorCtrl.dispose();
    _negocioMonedaCtrl.dispose();
    _negocioDireccionCtrl.dispose();
    _negocioTelefonoCtrl.dispose();
    super.dispose();
  }

  void _mostrarSnack(String mensaje, {bool esError = false}) {
    if (!mounted) return;
    if (esError) {
      AppToast.showError(context, mensaje);
    } else {
      AppToast.showSuccess(context, mensaje);
    }
  }

  void _iniciarEdicion(UsuarioPerfil perfil) {
    _nombreController.text = perfil.nombre;
    setState(() => _editandoNombre = true);
  }

  void _cancelarEdicion() {
    setState(() => _editandoNombre = false);
  }

  Future<void> _guardarNombre() async {
    final nuevo = _nombreController.text.trim();
    if (nuevo.isEmpty) {
      _mostrarSnack('El nombre no puede estar vacío.', esError: true);
      return;
    }

    setState(() => _guardandoNombre = true);
    try {
      final actualizado = await _authRepository.updateProfile(nuevo);
      if (!mounted) return;
      context.read<AuthBloc>().add(ProfileUpdated(actualizado));
      setState(() => _editandoNombre = false);
      _mostrarSnack('Nombre actualizado correctamente.');
    } catch (e) {
      _mostrarSnack('No se pudo actualizar el nombre: $e', esError: true);
    } finally {
      if (mounted) setState(() => _guardandoNombre = false);
    }
  }

  Future<void> _cambiarAvatarDiceBear(String style, String seed) async {
    setState(() => _guardandoAvatar = true);
    try {
      final actualizado = await _authRepository.updateAvatar(style, seed);
      if (!mounted) return;
      context.read<AuthBloc>().add(ProfileUpdated(actualizado));
      _mostrarSnack('¡Avatar DiceBear actualizado con éxito!');
    } catch (e) {
      _mostrarSnack('Error al cambiar avatar: $e', esError: true);
    } finally {
      if (mounted) setState(() => _guardandoAvatar = false);
    }
  }

  Future<void> _guardarNegocio(TenantModel tenantActual) async {
    final nombre = _negocioNombreCtrl.text.trim();
    if (nombre.isEmpty) {
      _mostrarSnack('El nombre del negocio no puede estar vacío.', esError: true);
      return;
    }

    setState(() => _guardandoNegocio = true);
    try {
      final actualizado = tenantActual.copyWith(
        nombre: nombre,
        colorPrimario: _negocioColorCtrl.text.trim().isNotEmpty
            ? _negocioColorCtrl.text.trim()
            : '#2563EB',
        moneda: _negocioMonedaCtrl.text.trim().isNotEmpty
            ? _negocioMonedaCtrl.text.trim()
            : '\$',
        direccion: _negocioDireccionCtrl.text.trim(),
        telefono: _negocioTelefonoCtrl.text.trim(),
        logoIcon: _selectedBusinessIcon,
        modoOscuro: _modoOscuro,
      );

      final result = await _authRepository.updateTenant(actualizado);
      if (!mounted) return;
      context.read<AuthBloc>().add(TenantUpdated(result));
      _mostrarSnack('¡Personalización del negocio guardada!');
    } catch (e) {
      _mostrarSnack('Error al guardar datos del negocio: $e', esError: true);
    } finally {
      if (mounted) setState(() => _guardandoNegocio = false);
    }
  }

  Future<void> _exportarDatos(UsuarioPerfil perfil) async {
    try {
      final client = Supabase.instance.client;
      final insumos = await client.from('insumos').select().limit(50);
      final ventas = await client.from('ventas').select().limit(50);

      final payload = {
        'tipo': 'EJERCICIO_DERECHO_ACCESO_ARCO',
        'fecha_solicitud': DateTime.now().toIso8601String(),
        'legislacion': 'Ley General de Protección de Datos Personales (LGPDPPSO)',
        'usuario': perfil.toJson(),
        'datos_asociados': {
          'total_insumos_muestra': (insumos as List).length,
          'total_ventas_muestra': (ventas as List).length,
        },
      };

      final jsonString = const JsonEncoder.withIndent('  ').convert(payload);
      await Clipboard.setData(ClipboardData(text: jsonString));
      _mostrarSnack('Datos copiados al portapapeles en formato JSON.');
    } catch (e) {
      _mostrarSnack('No se pudieron exportar los datos: $e', esError: true);
    }
  }

  void _confirmarEliminacion() {
    final confirmController = TextEditingController();
    bool puedeEliminar = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Row(
                children: [
                  Icon(Icons.warning_rounded, color: Colors.redAccent),
                  SizedBox(width: 8),
                  Expanded(child: Text('Confirmar Cancelación')),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '¿Estás seguro de que deseas ejercer tu Derecho de Cancelación (ARCO)?\n\n'
                      'Esta acción eliminará de forma irreversible tu perfil de usuario y todos '
                      'tus registros de la base de datos de manera segura.',
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Escribe ELIMINAR para confirmar:',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: confirmController,
                      autofocus: true,
                      decoration: const InputDecoration(hintText: 'ELIMINAR'),
                      onChanged: (value) {
                        setDialogState(() => puedeEliminar = value.trim() == 'ELIMINAR');
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    disabledBackgroundColor: Colors.red.withValues(alpha: 0.35),
                  ),
                  onPressed: puedeEliminar
                      ? () {
                          Navigator.pop(ctx);
                          context.read<AuthBloc>().add(DeleteAccountRequested());
                        }
                      : null,
                  child: const Text('Eliminar definitivamente'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        if (state is! Authenticated) {
          return const AppSplash();
        }
        final perfil = state.usuario;
        final tenant = state.tenant;

        if (tenant != null && _negocioNombreCtrl.text.isEmpty) {
          _negocioNombreCtrl.text = tenant.nombre;
          _negocioColorCtrl.text = tenant.colorPrimario;
          _negocioMonedaCtrl.text = tenant.moneda;
          _negocioDireccionCtrl.text = tenant.direccion ?? '';
          _negocioTelefonoCtrl.text = tenant.telefono ?? '';
          _modoOscuro = tenant.modoOscuro;
          _selectedBusinessIcon = tenant.logoIcon;
        }

        return Scaffold(
          appBar: AppBar(title: const Text('Mi Perfil y Personalización')),
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 680),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 48),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildHeaderCard(perfil, tenant),
                      const SizedBox(height: 24),
                      _buildDiceBearAvatarSelector(perfil),
                      if (perfil.isOwner && tenant != null) ...[
                        const SizedBox(height: 24),
                        _buildNegocioPersonalizacionCard(tenant),
                      ],
                      const SizedBox(height: 24),
                      _buildArcoCard(perfil),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeaderCard(UsuarioPerfil perfil, TenantModel? tenant) {
    Color brandColor = context.brand;
    if (tenant != null) {
      brandColor = AppTheme.parseHexColor(tenant.colorPrimario);
    }

    return HeroCard(
      child: Column(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [brandColor, brandColor.withValues(alpha: 0.6)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: brandColor.withValues(alpha: 0.35),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
              ),
              ClipOval(
                child: Image.network(
                  perfil.avatarUrl,
                  width: 90,
                  height: 90,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width: 90,
                    height: 90,
                    color: brandColor,
                    child: Center(
                      child: Text(
                        perfil.nombre.isNotEmpty ? perfil.nombre[0].toUpperCase() : 'U',
                        style: const TextStyle(fontSize: 32, color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (!_editandoNombre) ...[
            Text(
              perfil.nombre,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                HeroBadge(
                  label: perfil.rol.toUpperCase(),
                  color: perfil.isOwner ? Colors.purple : Colors.blue,
                  icon: perfil.isOwner ? Icons.workspace_premium_rounded : Icons.badge_rounded,
                ),
                if (tenant != null) ...[
                  const SizedBox(width: 8),
                  HeroBadge(
                    label: tenant.nombre,
                    color: brandColor,
                    icon: BusinessIconHelper.getIcon(tenant.logoIcon),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.email_outlined, size: 16, color: context.textMuted),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    perfil.email.isNotEmpty ? perfil.email : 'Sin correo registrado',
                    style: TextStyle(fontSize: 13, color: context.textMuted),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              icon: const Icon(Icons.edit_rounded, size: 16),
              label: const Text('Editar nombre'),
              onPressed: () => _iniciarEdicion(perfil),
            ),
          ] else ...[
            TextField(
              controller: _nombreController,
              decoration: const InputDecoration(labelText: 'Nombre completo'),
              textAlign: TextAlign.center,
              enabled: !_guardandoNombre,
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _guardandoNombre ? null : _cancelarEdicion,
                    child: const Text('Cancelar'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _guardandoNombre ? null : _guardarNombre,
                    child: _guardandoNombre
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: const AppSpinner(size: 20, color: Colors.white),
                          )
                        : const Text('Guardar'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDiceBearAvatarSelector(UsuarioPerfil perfil) {
    return HeroCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.face_retouching_natural_rounded, color: Colors.blue, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Diseño de Avatar (DiceBear Styles)',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    Text(
                      'Selecciona tu estilo de avatar personal o genera uno aleatorio',
                      style: TextStyle(fontSize: 12, color: context.textMuted),
                    ),
                  ],
                ),
              ),
              if (_guardandoAvatar)
                const SizedBox(width: 18, height: 18, child: const AppSpinner(size: 18)),
            ],
          ),
          const SizedBox(height: 20),
          const Text(
            'Elige un estilo artístico:',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 110,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _avatarStyles.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, idx) {
                final style = _avatarStyles[idx];
                final isSelected = perfil.avatarStyle == style['id'];
                final demoUrl = 'https://images.weserv.nl/?url=api.dicebear.com/7.x/' + style['id']! + '/png?seed=' + Uri.encodeComponent(perfil.nombre) + '&output=png';

                return GestureDetector(
                  onTap: () => _cambiarAvatarDiceBear(style['id']!, perfil.nombre),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 90,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.blue.withValues(alpha: 0.1) : Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected ? Colors.blue : Colors.grey.withValues(alpha: 0.2),
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            demoUrl,
                            width: 52,
                            height: 52,
                            fit: BoxFit.cover,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          style['label']!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            color: isSelected ? Colors.blue : context.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.shuffle_rounded, size: 18),
                  label: const Text('Generar Variante Aleatoria'),
                  onPressed: () {
                    final randomSeed = 'avatar_${DateTime.now().millisecondsSinceEpoch}';
                    _cambiarAvatarDiceBear(perfil.avatarStyle, randomSeed);
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNegocioPersonalizacionCard(TenantModel tenant) {
    final colors = [
      {'label': 'Azul Eléctrico', 'hex': '#2563EB', 'color': const Color(0xFF2563EB)},
      {'label': 'Esmeralda', 'hex': '#10B981', 'color': const Color(0xFF10B981)},
      {'label': 'Púrpura Indigo', 'hex': '#6366F1', 'color': const Color(0xFF6366F1)},
      {'label': 'Ámbar Cálido', 'hex': '#F59E0B', 'color': const Color(0xFFF59E0B)},
      {'label': 'Rosa Coral', 'hex': '#F43F5E', 'color': const Color(0xFFF43F5E)},
      {'label': 'Titanio / Slate', 'hex': '#475569', 'color': const Color(0xFF475569)},
    ];

    return HeroCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.tune_rounded, color: Colors.green, size: 22),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Personalización de tu Negocio',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
              const HeroBadge(label: 'Plan Activo', color: Colors.green),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Personaliza el nombre de tu empresa, moneda, ícono de marca y tema visual.',
            style: TextStyle(fontSize: 12, color: context.textMuted),
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _negocioNombreCtrl,
            decoration: const InputDecoration(labelText: 'Nombre comercial de tu negocio', prefixIcon: Icon(Icons.business_rounded)),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _negocioMonedaCtrl,
                  decoration: const InputDecoration(labelText: 'Símbolo Moneda', prefixIcon: Icon(Icons.attach_money_rounded)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _negocioTelefonoCtrl,
                  decoration: const InputDecoration(labelText: 'Teléfono', prefixIcon: Icon(Icons.phone_rounded)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _negocioDireccionCtrl,
            decoration: const InputDecoration(labelText: 'Dirección física (para tickets)', prefixIcon: Icon(Icons.location_on_outlined)),
          ),
          const SizedBox(height: 20),
          const Text(
            'Ícono representativo de tu negocio:',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: BusinessIconHelper.icons.entries.map((entry) {
              final isSelected = _selectedBusinessIcon == entry.key;
              return GestureDetector(
                onTap: () => setState(() => _selectedBusinessIcon = entry.key),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isSelected ? AppTheme.primary.withValues(alpha: 0.15) : Colors.grey.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected ? context.brand : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    entry.value,
                    color: isSelected ? context.brand : context.textMuted,
                    size: 24,
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      _modoOscuro ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                      color: _modoOscuro ? Colors.amber : Colors.orange,
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Tema Visual del Sistema',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        Text(
                          _modoOscuro ? 'Modo Oscuro activado' : 'Modo Claro activado',
                          style: TextStyle(fontSize: 11, color: context.textMuted),
                        ),
                      ],
                    ),
                  ],
                ),
                Switch(
                  value: _modoOscuro,
                  onChanged: (val) {
                    setState(() => _modoOscuro = val);
                    context.read<AuthBloc>().add(ToggleThemeRequested());
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Color principal del sistema:',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 10,
            children: colors.map((c) {
              final isSelected = _negocioColorCtrl.text.toUpperCase() == (c['hex'] as String).toUpperCase();
              final color = c['color'] as Color;
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _negocioColorCtrl.text = c['hex'] as String;
                  });
                },
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? Colors.white : Colors.transparent,
                      width: 3,
                    ),
                    boxShadow: [
                      BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 6, offset: const Offset(0, 2)),
                    ],
                  ),
                  child: isSelected ? const Icon(Icons.check, color: Colors.white, size: 18) : null,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.save_rounded),
              label: _guardandoNegocio
                  ? const SizedBox(width: 20, height: 20, child: const AppSpinner(size: 20, color: Colors.white))
                  : const Text('Guardar Personalización Completa', style: TextStyle(fontWeight: FontWeight.bold)),
              onPressed: _guardandoNegocio ? null : () => _guardarNegocio(tenant),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildArcoCard(UsuarioPerfil perfil) {
    return HeroCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Derechos ARCO y Seguridad',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          const SizedBox(height: 6),
          Text(
            'Tienes derecho a Acceder, Rectificar, Cancelar u Oponerte al uso de tus datos personales.',
            style: TextStyle(fontSize: 12, color: context.textMuted),
          ),
          const SizedBox(height: 18),
          _arcoTile(
            icon: Icons.download_rounded,
            title: 'Acceso',
            subtitle: 'Descarga tus datos personales en formato JSON.',
            actionLabel: 'Exportar',
            onTap: () => _exportarDatos(perfil),
          ),
          const SizedBox(height: 12),
          _arcoTile(
            icon: Icons.edit_note_rounded,
            title: 'Rectificación',
            subtitle: 'Corrige tu nombre desde la tarjeta de perfil.',
            actionLabel: 'Editar',
            onTap: () => _iniciarEdicion(perfil),
          ),
          const SizedBox(height: 12),
          _arcoTile(
            icon: Icons.delete_forever_rounded,
            title: 'Cancelación / Oposición',
            subtitle: 'Elimina tu cuenta y todos tus datos de forma permanente.',
            actionLabel: 'Eliminar',
            esDestructivo: true,
            onTap: _confirmarEliminacion,
          ),
        ],
      ),
    );
  }

  Widget _arcoTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required String actionLabel,
    required VoidCallback onTap,
    bool esDestructivo = false,
  }) {
    final color = esDestructivo ? Colors.redAccent : context.brand;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: esDestructivo ? Colors.red.withValues(alpha: 0.1) : Colors.blue.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: esDestructivo ? Colors.redAccent : null,
                  ),
                ),
                const SizedBox(height: 2),
                Text(subtitle, style: TextStyle(fontSize: 11, color: context.textMuted)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: color),
            onPressed: onTap,
            child: Text(actionLabel, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
          ),
        ],
      ),
    );
  }
}
