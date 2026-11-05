import 'package:flutter/material.dart';
import '../../core/di/service_locator.dart';
import '../../core/permissions/permiso.dart';
import '../../core/permissions/permission_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_loader.dart';
import '../../core/widgets/app_toast.dart';
import '../../domain/models/asistencia.dart';
import '../../domain/models/rol_personalizado.dart';
import '../../domain/repositories/turnos_repository.dart';
import '../widgets/permission_gate.dart';

/// Índice de esta pantalla en la navegación principal (main.dart).
const int kPermisosTabIndex = 9;

/// Administración de roles y permisos: qué puede hacer cada rol (incluidos los
/// roles que crea el dueño) y cada usuario. Los cambios se guardan en la base
/// de datos y también los hace cumplir el servidor con RLS.
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
            title: const Text('Roles y permisos'),
            bottom: const TabBar(
              tabs: [
                Tab(icon: Icon(Icons.admin_panel_settings_rounded), text: 'Roles'),
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

String _mensajeError(Object e) {
  final s = e.toString().toLowerCase();
  if (s.contains('roles_custom') &&
      (s.contains('does not exist') || s.contains('pgrst205') || s.contains('schema cache'))) {
    return 'Faltan las tablas de roles. Ejecuta migracion_roles_personalizados.sql en la base de datos.';
  }
  if (s.contains('rol_permisos') &&
      (s.contains('does not exist') || s.contains('pgrst205') || s.contains('schema cache'))) {
    return 'Faltan las tablas de permisos. Ejecuta migracion_turnos_permisos.sql en la base de datos.';
  }
  return e.toString().replaceAll('Exception: ', '');
}

// ======================================================================
// ROLES (base + personalizados)
// ======================================================================

class _PorRolTab extends StatefulWidget {
  const _PorRolTab();

  @override
  State<_PorRolTab> createState() => _PorRolTabState();
}

class _PorRolTabState extends State<_PorRolTab> {
  final PermissionService _perms = getIt<PermissionService>();

  String _rol = 'empleado';
  Map<Permiso, bool> _excepciones = {}; // solo roles base
  Set<Permiso> _permisosLocal = {}; // solo roles personalizados
  int? _personasConRol;
  bool _cargando = true;
  String? _error;

  String? get _tenantId => _perms.usuario?.tenantId;
  RolPersonalizado? get _custom => _perms.rolPersonalizado(_rol);

  @override
  void initState() {
    super.initState();
    _perms.addListener(_onPerms);
    _iniciar();
  }

  @override
  void dispose() {
    _perms.removeListener(_onPerms);
    super.dispose();
  }

  void _onPerms() {
    if (mounted) setState(() {});
  }

  Future<void> _iniciar() async {
    final t = _tenantId;
    if (t == null) {
      setState(() {
        _cargando = false;
        _error = 'Tu usuario no pertenece a ninguna empresa.';
      });
      return;
    }
    try {
      await _perms.cargarRoles(t);
    } catch (e) {
      // Sin la tabla de roles solo se pueden editar los roles base.
      debugPrint('Roles personalizados: $e');
    }
    await _seleccionar(_rol);
  }

  Future<void> _seleccionar(String rol) async {
    final t = _tenantId;
    if (t == null) return;
    setState(() {
      _rol = rol;
      _cargando = true;
      _personasConRol = null;
    });
    try {
      final custom = _perms.rolPersonalizado(rol);
      if (custom != null) {
        _permisosLocal = Set<Permiso>.from(custom.permisos);
        _excepciones = {};
        _perms.usuariosConRol(t, rol).then((n) {
          if (mounted && _rol == rol) setState(() => _personasConRol = n);
        }).catchError((_) {});
      } else {
        _excepciones = await _perms.excepcionesDeRol(t, rol);
      }
      if (!mounted) return;
      setState(() {
        _error = null;
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = _mensajeError(e);
        _cargando = false;
      });
    }
  }

  bool _efectivo(Permiso p) {
    if (_custom != null) return _permisosLocal.contains(p);
    return _excepciones[p] ?? Permiso.porDefecto(_rol).contains(p);
  }

  Future<void> _cambiar(Permiso p, bool valor) async {
    final t = _tenantId;
    if (t == null) return;

    final custom = _custom;
    if (custom != null) {
      final previo = Set<Permiso>.from(_permisosLocal);
      final nuevo = Set<Permiso>.from(_permisosLocal);
      valor ? nuevo.add(p) : nuevo.remove(p);
      setState(() => _permisosLocal = nuevo);
      try {
        await _perms.actualizarRol(custom, permisos: nuevo);
      } catch (e) {
        if (!mounted) return;
        setState(() => _permisosLocal = previo);
        AppToast.showError(context, _mensajeError(e), title: 'No se pudo guardar');
      }
      return;
    }

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
      AppToast.showError(context, _mensajeError(e), title: 'No se pudo guardar');
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
      await _seleccionar(_rol);
      if (mounted) AppToast.showSuccess(context, 'Permisos restaurados');
    } catch (e) {
      if (mounted) AppToast.showError(context, _mensajeError(e));
    }
  }

  // ---- Crear / editar / eliminar roles personalizados ----

  Future<void> _nuevoRol() async {
    final t = _tenantId;
    if (t == null) return;
    final datos = await showDialog<_DatosRol>(
      context: context,
      builder: (_) => const _RolDialog(),
    );
    if (datos == null) return;
    try {
      final base = switch (datos.basadoEn) {
        'empleado' => Permiso.porDefecto('empleado'),
        'admin' => Permiso.porDefecto('admin'),
        _ => <Permiso>{Permiso.dashboardVer},
      };
      final rol = await _perms.crearRol(
        tenantId: t,
        nombre: datos.nombre,
        descripcion: datos.descripcion,
        permisos: base,
      );
      if (!mounted) return;
      AppToast.showSuccess(context, 'Rol "${rol.nombre}" creado. Ajusta sus permisos abajo.');
      await _seleccionar(rol.clave);
    } catch (e) {
      if (mounted) AppToast.showError(context, _mensajeError(e), title: 'No se pudo crear el rol');
    }
  }

  Future<void> _editarRol() async {
    final custom = _custom;
    if (custom == null) return;
    final datos = await showDialog<_DatosRol>(
      context: context,
      builder: (_) => _RolDialog(existente: custom),
    );
    if (datos == null) return;
    try {
      await _perms.actualizarRol(custom, nombre: datos.nombre, descripcion: datos.descripcion ?? '');
      if (mounted) AppToast.showSuccess(context, 'Rol actualizado');
    } catch (e) {
      if (mounted) AppToast.showError(context, _mensajeError(e));
    }
  }

  Future<void> _eliminarRol() async {
    final custom = _custom;
    if (custom == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar rol'),
        content: Text('Se eliminará el rol "${custom.nombre}". Solo es posible si nadie lo tiene asignado.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _perms.eliminarRol(custom);
      if (!mounted) return;
      AppToast.showSuccess(context, 'Rol eliminado');
      await _seleccionar('empleado');
    } catch (e) {
      if (mounted) AppToast.showError(context, _mensajeError(e), title: 'No se pudo eliminar');
    }
  }

  @override
  Widget build(BuildContext context) {
    final custom = _custom;
    final roles = _perms.rolesPersonalizados;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
                  'Define qué puede hacer cada rol. El dueño siempre tiene todos los permisos. '
                  'Crea roles propios (socio, reportes, supervisor...) y asígnalos desde Usuarios.',
                  style: TextStyle(color: context.textMuted, fontSize: 13, height: 1.4),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final r in Permiso.rolesEditables)
                      ChoiceChip(
                        label: Text(Permiso.etiquetaRol(r)),
                        selected: _rol == r,
                        onSelected: (_) => _seleccionar(r),
                      ),
                    for (final r in roles)
                      ChoiceChip(
                        avatar: const Icon(Icons.star_rounded, size: 16),
                        label: Text(r.nombre),
                        selected: _rol == r.clave,
                        onSelected: (_) => _seleccionar(r.clave),
                      ),
                    ActionChip(
                      avatar: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Nuevo rol'),
                      onPressed: _nuevoRol,
                    ),
                  ],
                ),
                if (custom != null) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: context.brand.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: context.brand.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.star_rounded, color: context.brand),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(custom.nombre, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                              Text(
                                [
                                  if (custom.descripcion != null) custom.descripcion!,
                                  if (_personasConRol != null)
                                    '$_personasConRol ${_personasConRol == 1 ? 'persona' : 'personas'}',
                                ].join(' · '),
                                style: TextStyle(fontSize: 12, color: context.textMuted),
                              ),
                            ],
                          ),
                        ),
                        IconButton(tooltip: 'Renombrar', onPressed: _editarRol, icon: const Icon(Icons.edit_rounded, size: 20)),
                        IconButton(
                          tooltip: 'Eliminar rol',
                          onPressed: _eliminarRol,
                          icon: const Icon(Icons.delete_outline_rounded, size: 20, color: Colors.red),
                        ),
                      ],
                    ),
                  ),
                ],
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
                          onPressed: _iniciar,
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
                  if (custom == null) ...[
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
              ],
            ),
      ],
    );
  }

  Widget _fila(BuildContext context, Permiso p) {
    final personalizado = _custom == null && _excepciones.containsKey(p);
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

class _DatosRol {
  final String nombre;
  final String? descripcion;
  final String basadoEn; // 'empleado' | 'admin' | 'vacio'
  const _DatosRol(this.nombre, this.descripcion, this.basadoEn);
}

class _RolDialog extends StatefulWidget {
  final RolPersonalizado? existente;
  const _RolDialog({this.existente});

  @override
  State<_RolDialog> createState() => _RolDialogState();
}

class _RolDialogState extends State<_RolDialog> {
  final _nombreCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  String _base = 'empleado';
  String? _error;

  @override
  void initState() {
    super.initState();
    _nombreCtrl.text = widget.existente?.nombre ?? '';
    _descCtrl.text = widget.existente?.descripcion ?? '';
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  void _aceptar() {
    final nombre = _nombreCtrl.text.trim();
    if (nombre.length < 2) {
      setState(() => _error = 'Escribe un nombre para el rol.');
      return;
    }
    final reservados = {'dueño', 'dueno', 'admin', 'administrador', 'empleado', 'superadmin'};
    if (widget.existente == null && reservados.contains(nombre.toLowerCase())) {
      setState(() => _error = 'Ese nombre ya existe como rol base.');
      return;
    }
    final desc = _descCtrl.text.trim();
    Navigator.pop(context, _DatosRol(nombre, desc.isEmpty ? null : desc, _base));
  }

  @override
  Widget build(BuildContext context) {
    final nuevo = widget.existente == null;
    return AlertDialog(
      title: Text(nuevo ? 'Nuevo rol' : 'Editar rol'),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _nombreCtrl,
                autofocus: true,
                maxLength: 30,
                decoration: const InputDecoration(
                  labelText: 'Nombre del rol',
                  hintText: 'Socio, Reportes, Supervisor...',
                ),
              ),
              TextField(
                controller: _descCtrl,
                maxLength: 80,
                decoration: const InputDecoration(labelText: 'Descripción (opcional)'),
              ),
              if (nuevo) ...[
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: _base,
                  decoration: const InputDecoration(labelText: 'Empezar con los permisos de'),
                  items: const [
                    DropdownMenuItem(value: 'empleado', child: Text('Empleado')),
                    DropdownMenuItem(value: 'admin', child: Text('Administrador')),
                    DropdownMenuItem(value: 'vacio', child: Text('Solo ver el inicio')),
                  ],
                  onChanged: (v) => setState(() => _base = v ?? 'empleado'),
                ),
              ],
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 12.5)),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(onPressed: _aceptar, child: Text(nuevo ? 'Crear rol' : 'Guardar')),
      ],
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
  Map<Permiso, bool> _deRol = {}; // excepciones del rol base del usuario seleccionado
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
      final t = _tenantId;
      if (t != null) {
        try {
          await _perms.cargarRoles(t);
        } catch (_) {}
      }
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
        _error = _mensajeError(e);
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
      final intocable = Permiso.esRolIntocable(u.rol);
      final esCustom = _perms.esRolPersonalizado(u.rol);
      final deRol = t == null || intocable || esCustom
          ? <Permiso, bool>{}
          : await _perms.excepcionesDeRol(t, u.rol);
      final deUsuario = intocable ? <Permiso, bool>{} : await _perms.excepcionesDeUsuario(u.id);
      if (!mounted || _sel?.id != u.id) return;
      setState(() {
        _deRol = deRol;
        _deUsuario = deUsuario;
        _cargandoDetalle = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _cargandoDetalle = false);
      AppToast.showError(context, _mensajeError(e));
    }
  }

  /// Valor que tendría el usuario sin excepciones propias (lo heredado del rol).
  bool _heredado(Permiso p) {
    final rol = _sel!.rol;
    final custom = _perms.rolPersonalizado(rol);
    if (custom != null) return custom.permisos.contains(p);
    return _deRol[p] ?? Permiso.porDefecto(rol).contains(p);
  }

  bool _efectivo(Permiso p) => _deUsuario[p] ?? _heredado(p);

  Future<void> _cambiar(Permiso p, bool valor) async {
    final u = _sel;
    final t = _tenantId;
    if (u == null || t == null) return;
    final previo = Map<Permiso, bool>.from(_deUsuario);
    final heredado = _heredado(p);
    setState(() {
      if (valor == heredado) {
        _deUsuario.remove(p);
      } else {
        _deUsuario[p] = valor;
      }
    });
    try {
      if (valor == heredado) {
        await _perms.quitarExcepcionUsuario(u.id, p);
      } else {
        await _perms.guardarExcepcionUsuario(t, u.id, p, valor);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _deUsuario = previo);
      AppToast.showError(context, _mensajeError(e), title: 'No se pudo guardar');
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
      if (mounted) AppToast.showError(context, _mensajeError(e));
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
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      children: [
        Column(
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
