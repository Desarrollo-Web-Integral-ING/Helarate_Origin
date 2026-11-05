import 'package:flutter/material.dart';
import '../../core/di/service_locator.dart';
import '../../core/permissions/permiso.dart';
import '../../core/permissions/permission_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_loader.dart';
import '../../core/widgets/app_toast.dart';
import '../../domain/models/asistencia.dart';
import '../../domain/repositories/turnos_repository.dart';
import '../widgets/permission_gate.dart';

/// Índice de esta pantalla en la navegación principal (main.dart).
const int kPermisosTabIndex = 9;

/// Administración de permisos: qué puede hacer cada rol y cada usuario.
/// Los cambios se guardan en la base de datos (rol_permisos / usuario_permisos)
/// y también los hace cumplir el servidor con RLS.
class PermisosScreen extends StatelessWidget {
  const PermisosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PermissionGate(
      permiso: Permiso.permisosAdministrar,
      child: DefaultTabController(
        length: 2,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Permisos'),
            bottom: const TabBar(
              tabs: [
                Tab(icon: Icon(Icons.admin_panel_settings_rounded), text: 'Por rol'),
                Tab(icon: Icon(Icons.person_rounded), text: 'Por usuario'),
              ],
            ),
          ),
          body: const TabBarView(
            physics: NeverScrollableScrollPhysics(),
            children: [_PorRolTab(), _PorUsuarioTab()],
          ),
        ),
      ),
    );
  }
}

// Agrupa los permisos por su grupo, conservando el orden del enum.
Map<String, List<Permiso>> _porGrupo() {
  final out = <String, List<Permiso>>{};
  for (final p in Permiso.values) {
    out.putIfAbsent(p.grupo, () => []).add(p);
  }
  return out;
}

Widget _encabezadoGrupo(BuildContext context, String grupo) => Padding(
      padding: const EdgeInsets.fromLTRB(4, 18, 4, 6),
      child: Text(
        grupo.toUpperCase(),
        style: TextStyle(
          fontSize: 11.5,
          letterSpacing: 0.8,
          fontWeight: FontWeight.w800,
          color: context.brand,
        ),
      ),
    );

// ======================================================================
// POR ROL
// ======================================================================

class _PorRolTab extends StatefulWidget {
  const _PorRolTab();

  @override
  State<_PorRolTab> createState() => _PorRolTabState();
}

class _PorRolTabState extends State<_PorRolTab> {
  final PermissionService _perms = getIt<PermissionService>();

  String _rol = Permiso.rolesEditables.first;
  Map<Permiso, bool> _excepciones = {};
  bool _cargando = true;
  String? _error;

  String? get _tenantId => _perms.usuario?.tenantId;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final t = _tenantId;
    if (t == null) {
      setState(() {
        _cargando = false;
        _error = 'Tu usuario no pertenece a ninguna empresa.';
      });
      return;
    }
    setState(() => _cargando = true);
    try {
      final ex = await _perms.excepcionesDeRol(t, _rol);
      if (!mounted) return;
      setState(() {
        _excepciones = ex;
        _error = null;
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = _mensaje(e);
        _cargando = false;
      });
    }
  }

  String _mensaje(Object e) {
    final s = e.toString().toLowerCase();
    if (s.contains('rol_permisos') && (s.contains('does not exist') || s.contains('pgrst205') || s.contains('schema cache'))) {
      return 'Faltan las tablas de permisos. Ejecuta migracion_turnos_permisos.sql en la base de datos.';
    }
    return e.toString().replaceAll('Exception: ', '');
  }

  bool _efectivo(Permiso p) =>
      _excepciones[p] ?? Permiso.porDefecto(_rol).contains(p);

  Future<void> _cambiar(Permiso p, bool valor) async {
    final t = _tenantId;
    if (t == null) return;
    final previo = Map<Permiso, bool>.from(_excepciones);
    final defecto = Permiso.porDefecto(_rol).contains(p);
    setState(() {
      if (valor == defecto) {
        _excepciones.remove(p);
      } else {
        _excepciones[p] = valor;
      }
    });
    try {
      if (valor == defecto) {
        await _perms.quitarExcepcionRol(t, _rol, p);
      } else {
        await _perms.guardarExcepcionRol(t, _rol, p, valor);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _excepciones = previo);
      AppToast.showError(context, _mensaje(e), title: 'No se pudo guardar');
    }
  }

  Future<void> _restaurar() async {
    final t = _tenantId;
    if (t == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restaurar permisos'),
        content: Text('El rol ${Permiso.etiquetaRol(_rol)} volverá a sus permisos por defecto.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Restaurar')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _perms.restaurarRol(t, _rol);
      await _cargar();
      if (mounted) AppToast.showSuccess(context, 'Permisos restaurados');
    } catch (e) {
      if (mounted) AppToast.showError(context, _mensaje(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Define qué puede hacer cada rol en tu negocio. El dueño siempre tiene todos los permisos.',
                  style: TextStyle(color: context.textMuted, fontSize: 13, height: 1.4),
                ),
                const SizedBox(height: 14),
                SegmentedButton<String>(
                  showSelectedIcon: false,
                  segments: [
                    for (final r in Permiso.rolesEditables)
                      ButtonSegment(value: r, label: Text(Permiso.etiquetaRol(r))),
                  ],
                  selected: {_rol},
                  onSelectionChanged: (v) {
                    setState(() => _rol = v.first);
                    _cargar();
                  },
                ),
                if (_cargando)
                  const Padding(padding: EdgeInsets.all(40), child: AppLoader(size: 52))
                else if (_error != null)
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        Icon(Icons.cloud_off_rounded, size: 44, color: context.textMuted),
                        const SizedBox(height: 10),
                        Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: context.textMuted)),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: _cargar,
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Reintentar'),
                        ),
                      ],
                    ),
                  )
                else ...[
                  for (final g in _porGrupo().entries) ...[
                    _encabezadoGrupo(context, g.key),
                    for (final p in g.value) _fila(context, p),
                  ],
                  const SizedBox(height: 14),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      onPressed: _excepciones.isEmpty ? null : _restaurar,
                      icon: const Icon(Icons.restore_rounded, size: 18),
                      label: const Text('Restaurar valores por defecto'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _fila(BuildContext context, Permiso p) {
    final personalizado = _excepciones.containsKey(p);
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: personalizado ? context.brand.withValues(alpha: 0.5) : context.borderColor,
        ),
      ),
      child: SwitchListTile(
        value: _efectivo(p),
        onChanged: (v) => _cambiar(p, v),
        title: Row(
          children: [
            Flexible(child: Text(p.etiqueta, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14))),
            if (personalizado) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: context.brand.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('Personalizado',
                    style: TextStyle(fontSize: 10, color: context.brand, fontWeight: FontWeight.w800)),
              ),
            ],
          ],
        ),
        subtitle: Text(p.descripcion, style: const TextStyle(fontSize: 12)),
      ),
    );
  }
}

// ======================================================================
// POR USUARIO
// ======================================================================

class _PorUsuarioTab extends StatefulWidget {
  const _PorUsuarioTab();

  @override
  State<_PorUsuarioTab> createState() => _PorUsuarioTabState();
}

class _PorUsuarioTabState extends State<_PorUsuarioTab> {
  final PermissionService _perms = getIt<PermissionService>();
  final TurnosRepository _repo = getIt<TurnosRepository>();

  List<EmpleadoResumen> _usuarios = [];
  EmpleadoResumen? _sel;
  Map<Permiso, bool> _deRol = {}; // excepciones del rol del usuario seleccionado
  Map<Permiso, bool> _deUsuario = {};
  bool _cargando = true;
  bool _cargandoDetalle = false;
  String? _error;

  String? get _tenantId => _perms.usuario?.tenantId;

  @override
  void initState() {
    super.initState();
    _cargarUsuarios();
  }

  Future<void> _cargarUsuarios() async {
    setState(() => _cargando = true);
    try {
      final u = await _repo.empleados();
      if (!mounted) return;
      setState(() {
        _usuarios = u;
        _error = null;
        _cargando = false;
      });
      if (u.isNotEmpty) _seleccionar(u.first);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _cargando = false;
      });
    }
  }

  Future<void> _seleccionar(EmpleadoResumen u) async {
    final t = _tenantId;
    setState(() {
      _sel = u;
      _cargandoDetalle = true;
    });
    try {
      final deRol = t == null || Permiso.esRolIntocable(u.rol)
          ? <Permiso, bool>{}
          : await _perms.excepcionesDeRol(t, u.rol);
      final deUsuario = Permiso.esRolIntocable(u.rol)
          ? <Permiso, bool>{}
          : await _perms.excepcionesDeUsuario(u.id);
      if (!mounted || _sel?.id != u.id) return;
      setState(() {
        _deRol = deRol;
        _deUsuario = deUsuario;
        _cargandoDetalle = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _cargandoDetalle = false);
      AppToast.showError(context, e.toString().replaceAll('Exception: ', ''));
    }
  }

  /// Valor que tendría el usuario sin excepciones propias (lo heredado del rol).
  bool _heredado(Permiso p) =>
      _deRol[p] ?? Permiso.porDefecto(_sel!.rol).contains(p);

  bool _efectivo(Permiso p) => _deUsuario[p] ?? _heredado(p);

  Future<void> _cambiar(Permiso p, bool valor) async {
    final u = _sel;
    final t = _tenantId;
    if (u == null || t == null) return;
    final previo = Map<Permiso, bool>.from(_deUsuario);
    setState(() {
      if (valor == _heredado(p)) {
        _deUsuario.remove(p);
      } else {
        _deUsuario[p] = valor;
      }
    });
    try {
      if (valor == _heredado(p)) {
        await _perms.quitarExcepcionUsuario(u.id, p);
      } else {
        await _perms.guardarExcepcionUsuario(t, u.id, p, valor);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _deUsuario = previo);
      AppToast.showError(context, e.toString().replaceAll('Exception: ', ''), title: 'No se pudo guardar');
    }
  }

  Future<void> _restaurar() async {
    final u = _sel;
    if (u == null) return;
    try {
      await _perms.restaurarUsuario(u.id);
      await _seleccionar(u);
      if (mounted) AppToast.showSuccess(context, 'Ahora hereda los permisos de su rol');
    } catch (e) {
      if (mounted) AppToast.showError(context, e.toString().replaceAll('Exception: ', ''));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) return const AppLoader(message: 'Cargando usuarios...', icon: Icons.lock_person_rounded);
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: context.textMuted)),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _cargarUsuarios,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }
    if (_usuarios.isEmpty) {
      return Center(child: Text('No hay usuarios en tu empresa', style: TextStyle(color: context.textMuted)));
    }

    final u = _sel;
    final intocable = u != null && Permiso.esRolIntocable(u.rol);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Da o quita permisos a una persona en particular. Lo que no cambies se hereda de su rol.',
                  style: TextStyle(color: context.textMuted, fontSize: 13, height: 1.4),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: u?.id,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Usuario', prefixIcon: Icon(Icons.person_rounded)),
                  items: [
                    for (final e in _usuarios)
                      DropdownMenuItem(value: e.id, child: Text('${e.nombre} · ${Permiso.etiquetaRol(e.rol)}')),
                  ],
                  onChanged: (id) {
                    if (id == null) return;
                    _seleccionar(_usuarios.firstWhere((e) => e.id == id));
                  },
                ),
                if (_cargandoDetalle)
                  const Padding(padding: EdgeInsets.all(40), child: AppLoader(size: 52))
                else if (u != null) ...[
                  if (intocable)
                    Container(
                      margin: const EdgeInsets.only(top: 14),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: context.brand.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.verified_user_rounded, color: context.brand),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text('El dueño siempre tiene todos los permisos y no se pueden quitar.'),
                          ),
                        ],
                      ),
                    ),
                  for (final g in _porGrupo().entries) ...[
                    _encabezadoGrupo(context, g.key),
                    for (final p in g.value) _fila(context, p, intocable),
                  ],
                  const SizedBox(height: 14),
                  if (!intocable)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: OutlinedButton.icon(
                        onPressed: _deUsuario.isEmpty ? null : _restaurar,
                        icon: const Icon(Icons.restore_rounded, size: 18),
                        label: const Text('Volver a heredar del rol'),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _fila(BuildContext context, Permiso p, bool bloqueado) {
    final personalizado = !bloqueado && _deUsuario.containsKey(p);
    final valor = bloqueado ? true : _efectivo(p);
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: personalizado ? context.brand.withValues(alpha: 0.5) : context.borderColor,
        ),
      ),
      child: SwitchListTile(
        value: valor,
        onChanged: bloqueado ? null : (v) => _cambiar(p, v),
        title: Row(
          children: [
            Flexible(child: Text(p.etiqueta, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14))),
            const SizedBox(width: 8),
            if (!bloqueado)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: (personalizado ? context.brand : context.textMuted).withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  personalizado ? 'Personalizado' : 'Del rol',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: personalizado ? context.brand : context.textMuted,
                  ),
                ),
              ),
          ],
        ),
        subtitle: Text(p.descripcion, style: const TextStyle(fontSize: 12)),
      ),
    );
  }
}
