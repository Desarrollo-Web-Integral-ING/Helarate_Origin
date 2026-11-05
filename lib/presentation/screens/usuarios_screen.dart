import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/di/service_locator.dart';
import '../../core/permissions/permiso.dart';
import '../../core/permissions/permission_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_loader.dart';
import '../../core/widgets/app_toast.dart';
import '../../core/widgets/user_avatar.dart';
import '../blocs/auth/auth_bloc.dart';
import '../blocs/auth/auth_state.dart';
import '../widgets/permission_gate.dart';
import 'permisos_screen.dart';

class UsuariosScreen extends StatefulWidget {
  const UsuariosScreen({super.key});

  @override
  State<UsuariosScreen> createState() => _UsuariosScreenState();
}

class _UsuariosScreenState extends State<UsuariosScreen> {
  final _client = Supabase.instance.client;
  final PermissionService _perms = getIt<PermissionService>();

  List<Map<String, dynamic>> _usuarios = [];
  bool _isLoading = true;
  String? _tenantId;
  String? _miId;
  String _negocio = 'tu negocio';

  @override
  void initState() {
    super.initState();
    final authState = context.read<AuthBloc>().state;
    if (authState is Authenticated) {
      // Las personas nuevas siempre se crean en la empresa de quien las invita.
      _tenantId = authState.usuario.tenantId;
      _miId = authState.usuario.id;
      _negocio = authState.tenant?.nombre ?? 'tu negocio';
    }
    _loadUsuarios();
  }

  Future<void> _loadUsuarios() async {
    if (_tenantId == null) {
      setState(() => _isLoading = false);
      return;
    }
    setState(() => _isLoading = true);
    try {
      try {
        await _perms.cargarRoles(_tenantId!);
      } catch (_) {
        // Sin la tabla de roles personalizados solo hay roles base.
      }
      final data = await _client.from('profiles').select().eq('tenant_id', _tenantId!);
      final invites = await _client.from('invitaciones').select().eq('tenant_id', _tenantId!);

      final combined = <Map<String, dynamic>>[
        for (final d in data) {...d, 'is_invite': false},
        for (final i in invites) {...i, 'is_invite': true, 'rol': i['rol'] ?? 'empleado'},
      ];

      if (!mounted) return;
      setState(() {
        _usuarios = combined;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      AppToast.showError(context, 'Error al cargar usuarios');
    }
  }

  // ------------------------------------------------------------------
  // Roles que se pueden asignar
  // ------------------------------------------------------------------

  /// Claves de rol asignables por quien tiene la sesión abierta:
  ///  - con 'permisos.administrar': administrador, empleado y los roles propios;
  ///  - solo con 'usuarios.administrar': únicamente empleado.
  List<String> get _rolesAsignables {
    if (!_perms.can(Permiso.permisosAdministrar)) return ['empleado'];
    return ['empleado', 'admin', ..._perms.rolesPersonalizados.map((r) => r.clave)];
  }

  String _descripcionRol(String clave) {
    final custom = _perms.rolPersonalizado(clave);
    if (custom != null) {
      final n = custom.permisos.length;
      return custom.descripcion ?? '$n ${n == 1 ? 'permiso' : 'permisos'}';
    }
    switch (clave) {
      case 'admin':
        return 'Casi todo, menos administrar permisos';
      case 'empleado':
        return 'Caja, consulta de inventario y su propio turno';
      default:
        return '';
    }
  }

  // ------------------------------------------------------------------
  // Invitar
  // ------------------------------------------------------------------

  void _showInviteModal() {
    if (!puedeOAvisar(context, Permiso.usuariosAdministrar)) return;
    if (_tenantId == null) {
      AppToast.showError(context, 'Tu usuario no pertenece a ninguna empresa.');
      return;
    }
    final formKey = GlobalKey<FormState>();
    final nombreCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final roles = _rolesAsignables;
    String selectedRol = roles.first;
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => StatefulBuilder(builder: (ctx, setModalState) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom + 20, top: 20, left: 24, right: 24),
          child: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Invitar nuevo usuario', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Row(children: [
                    Icon(Icons.storefront_rounded, size: 16, color: context.textMuted),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text('Se creará en $_negocio',
                          style: TextStyle(fontSize: 12.5, color: context.textMuted)),
                    ),
                  ]),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: nombreCtrl,
                    decoration: const InputDecoration(labelText: 'Nombre completo', prefixIcon: Icon(Icons.person)),
                    validator: (v) => (v ?? '').trim().isEmpty ? 'Requerido' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(labelText: 'Correo electrónico', prefixIcon: Icon(Icons.email)),
                    validator: (v) {
                      final t = (v ?? '').trim();
                      if (t.isEmpty) return 'Requerido';
                      if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(t)) return 'Correo no válido';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: selectedRol,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Rol', prefixIcon: Icon(Icons.badge)),
                    items: [
                      for (final r in roles)
                        DropdownMenuItem(
                          value: r,
                          child: Text('${Permiso.etiquetaRol(r)} · ${_descripcionRol(r)}',
                              overflow: TextOverflow.ellipsis),
                        ),
                    ],
                    onChanged: (v) => setModalState(() => selectedRol = v ?? selectedRol),
                  ),
                  if (!_perms.can(Permiso.permisosAdministrar))
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text('Solo el dueño puede invitar con otros roles.',
                          style: TextStyle(fontSize: 12, color: context.textMuted)),
                    ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: context.brand,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: isSubmitting
                          ? null
                          : () async {
                              if (!formKey.currentState!.validate()) return;
                              final email = emailCtrl.text.trim().toLowerCase();
                              final yaExiste = _usuarios.any(
                                  (u) => (u['email'] ?? '').toString().toLowerCase() == email);
                              if (yaExiste) {
                                AppToast.showWarning(context, 'Ese correo ya tiene una cuenta o una invitación.',
                                    title: 'Correo repetido');
                                return;
                              }
                              setModalState(() => isSubmitting = true);
                              try {
                                await _client.from('invitaciones').insert({
                                  'nombre': nombreCtrl.text.trim(),
                                  'email': email,
                                  'rol': selectedRol,
                                  'tenant_id': _tenantId,
                                });
                                if (!mounted) return;
                                AppToast.showSuccess(context,
                                    'Invitación creada. La persona activa su cuenta con ese correo en "Activar cuenta".');
                                Navigator.pop(context);
                                _loadUsuarios();
                              } catch (e) {
                                if (mounted) {
                                  AppToast.showError(context, _mensajeError(e), title: 'No se pudo invitar');
                                }
                                setModalState(() => isSubmitting = false);
                              }
                            },
                      child: isSubmitting
                          ? const AppSpinner(size: 20, color: Colors.white)
                          : const Text('Enviar invitación', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }

  String _mensajeError(Object e) {
    final s = e.toString().toLowerCase();
    if (s.contains('row-level security') || s.contains('42501')) {
      return 'No tienes permiso para hacer esto.';
    }
    final m = RegExp(r'message: ([^,}]+)').firstMatch(e.toString());
    return (m?.group(1) ?? e.toString()).replaceAll('Exception: ', '');
  }

  // ------------------------------------------------------------------
  // Cambiar rol / cancelar invitación
  // ------------------------------------------------------------------

  bool _puedeCambiarRol(Map<String, dynamic> u) {
    if (!_perms.can(Permiso.permisosAdministrar)) return false;
    final rol = (u['rol'] ?? 'empleado').toString();
    if (Permiso.esRolIntocable(rol)) return false;
    if (u['is_invite'] != true && u['id'] == _miId) return false;
    return true;
  }

  Future<void> _cambiarRol(Map<String, dynamic> u) async {
    final actual = (u['rol'] ?? 'empleado').toString();
    final elegido = await showDialog<String>(
      context: context,
      builder: (ctx) {
        String seleccionado = actual;
        return StatefulBuilder(
          builder: (ctx, setD) => AlertDialog(
            title: Text('Rol de ${u['nombre'] ?? 'usuario'}'),
            content: SizedBox(
              width: 380,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final r in _rolesAsignables)
                      RadioListTile<String>(
                        value: r,
                        groupValue: seleccionado,
                        onChanged: (v) => setD(() => seleccionado = v ?? seleccionado),
                        title: Text(Permiso.etiquetaRol(r), style: const TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: Text(_descripcionRol(r), style: const TextStyle(fontSize: 12)),
                      ),
                    const SizedBox(height: 6),
                    Text(
                      'Para crear o ajustar roles ve a "Roles y permisos".',
                      style: TextStyle(fontSize: 12, color: context.textMuted),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
              FilledButton(
                onPressed: seleccionado == actual ? null : () => Navigator.pop(ctx, seleccionado),
                child: const Text('Guardar'),
              ),
            ],
          ),
        );
      },
    );
    if (elegido == null) return;

    try {
      if (u['is_invite'] == true) {
        await _client.from('invitaciones').update({'rol': elegido}).eq('id', u['id']);
      } else {
        await _perms.cambiarRolUsuario(u['id'] as String, elegido);
      }
      if (!mounted) return;
      AppToast.showSuccess(context, 'Ahora es ${Permiso.etiquetaRol(elegido)}');
      _loadUsuarios();
    } catch (e) {
      if (mounted) AppToast.showError(context, _mensajeError(e), title: 'No se pudo cambiar el rol');
    }
  }

  Future<void> _cancelarInvitacion(Map<String, dynamic> u) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancelar invitación'),
        content: Text('${u['email']} ya no podrá activar su cuenta con esta invitación.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Volver')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cancelar invitación'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _client.from('invitaciones').delete().eq('id', u['id']);
      if (!mounted) return;
      AppToast.showInfo(context, 'Invitación cancelada');
      _loadUsuarios();
    } catch (e) {
      if (mounted) AppToast.showError(context, _mensajeError(e));
    }
  }

  // ------------------------------------------------------------------
  // UI
  // ------------------------------------------------------------------

  Color _colorRol(String rol) {
    if (Permiso.esRolIntocable(rol)) return const Color(0xFF8B5CF6);
    if (_perms.esRolPersonalizado(rol)) return context.brand;
    return context.textMuted;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Usuarios y equipo'),
        actions: [
          IfPermitted(
            permiso: Permiso.permisosAdministrar,
            child: TextButton.icon(
              onPressed: () async {
                await Navigator.push(context, MaterialPageRoute(builder: (_) => const PermisosScreen()));
                _loadUsuarios();
              },
              icon: const Icon(Icons.admin_panel_settings_rounded, size: 18),
              label: const Text('Roles y permisos'),
            ),
          ),
        ],
      ),
      floatingActionButton: IfPermitted(
        permiso: Permiso.usuariosAdministrar,
        child: FloatingActionButton.extended(
          onPressed: _showInviteModal,
          backgroundColor: context.brand,
          icon: const Icon(Icons.person_add),
          label: const Text('Nuevo'),
        ),
      ),
      body: _isLoading
          ? const AppLoader()
          : RefreshIndicator(
              onRefresh: _loadUsuarios,
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
                itemCount: _usuarios.length,
                itemBuilder: (context, index) => _tile(context, _usuarios[index]),
              ),
            ),
    );
  }

  Widget _tile(BuildContext context, Map<String, dynamic> u) {
    final isInvite = u['is_invite'] == true;
    final rol = (u['rol'] ?? 'empleado').toString();
    final color = _colorRol(rol);
    final nombre = (u['nombre'] ?? 'Sin nombre').toString();
    final puedeRol = _puedeCambiarRol(u);
    final puedeCancelar = isInvite && _perms.can(Permiso.usuariosAdministrar);

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        contentPadding: const EdgeInsets.fromLTRB(14, 6, 8, 6),
        leading: isInvite
            ? CircleAvatar(
                backgroundColor: Colors.orange.shade100,
                child: const Icon(Icons.schedule, color: Colors.orange),
              )
            : UserAvatar(
                style: (u['avatar_style'] ?? 'gradiente').toString(),
                seed: (u['avatar_seed'] ?? '').toString(),
                name: nombre,
                size: 40,
                png: u['avatar_png'] as String?,
              ),
        title: Text(nombre, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(
          isInvite ? '${u['email'] ?? ''} · invitación pendiente' : (u['email'] ?? '').toString(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                Permiso.etiquetaRol(rol).toUpperCase(),
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color),
              ),
            ),
            if (puedeRol || puedeCancelar)
              PopupMenuButton<String>(
                tooltip: 'Opciones',
                onSelected: (v) {
                  if (v == 'rol') _cambiarRol(u);
                  if (v == 'cancelar') _cancelarInvitacion(u);
                },
                itemBuilder: (_) => [
                  if (puedeRol)
                    const PopupMenuItem(
                      value: 'rol',
                      child: ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.badge_rounded),
                        title: Text('Cambiar rol'),
                      ),
                    ),
                  if (puedeCancelar)
                    const PopupMenuItem(
                      value: 'cancelar',
                      child: ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.cancel_outlined, color: Colors.red),
                        title: Text('Cancelar invitación'),
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
