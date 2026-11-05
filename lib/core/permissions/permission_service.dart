import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/models/rol_personalizado.dart';
import '../../domain/models/usuario_perfil.dart';
import 'permiso.dart';

/// Permisos efectivos del usuario con sesión iniciada.
///
/// Orden de prioridad (igual que `tiene_permiso` en la base de datos):
///   1. dueño / superadmin: todo
///   2. excepción por usuario  (tabla usuario_permisos)
///   3. rol personalizado de la empresa (tabla roles_custom)
///   4. excepción por rol base (tabla rol_permisos, por empresa)
///   5. valores por defecto del rol (Permiso.porDefecto)
///
/// La base de datos vuelve a comprobar los permisos sensibles con RLS, así que
/// ocultar una vista aquí es comodidad; el bloqueo real está en el servidor.
class PermissionService extends ChangeNotifier {
  SupabaseClient get _client => Supabase.instance.client;

  UsuarioPerfil? _usuario;
  Set<Permiso> _efectivos = {};
  List<RolPersonalizado> _roles = [];
  bool _cargado = false;

  bool get cargado => _cargado;
  UsuarioPerfil? get usuario => _usuario;
  String get rol => _usuario?.rol ?? '';
  List<RolPersonalizado> get rolesPersonalizados => List.unmodifiable(_roles);

  bool can(Permiso p) => _efectivos.contains(p);

  bool canAny(Iterable<Permiso> ps) => ps.any(can);

  RolPersonalizado? rolPersonalizado(String clave) {
    for (final r in _roles) {
      if (r.clave == clave) return r;
    }
    return null;
  }

  bool esRolPersonalizado(String clave) => rolPersonalizado(clave) != null;

  /// Permisos que tiene un rol sin excepciones individuales (base o personalizado).
  Set<Permiso> permisosDeRol(String clave) =>
      rolPersonalizado(clave)?.permisos ?? Permiso.porDefecto(clave);

  /// Calcula los permisos de [usuario]. Si la base de datos no responde (o aún
  /// no se ejecutó la migración), se usan los valores por defecto del rol.
  Future<void> load(UsuarioPerfil usuario) async {
    _usuario = usuario;

    // Roles personalizados de la empresa (también sirven para mostrar nombres).
    if (usuario.tenantId != null) {
      try {
        await cargarRoles(usuario.tenantId!, notificar: false);
      } catch (e) {
        debugPrint('Roles personalizados no disponibles ($e)');
      }
    }

    final propio = rolPersonalizado(usuario.rol);
    final base = Set<Permiso>.from(propio?.permisos ?? Permiso.porDefecto(usuario.rol));

    if (!Permiso.esRolIntocable(usuario.rol)) {
      try {
        if (propio == null && usuario.tenantId != null) {
          final delRol = await _client
              .from('rol_permisos')
              .select('permiso, concedido')
              .eq('tenant_id', usuario.tenantId!)
              .eq('rol', usuario.rol);
          _aplicar(base, delRol);
        }
        final delUsuario = await _client
            .from('usuario_permisos')
            .select('permiso, concedido')
            .eq('user_id', usuario.id);
        _aplicar(base, delUsuario);
      } catch (e) {
        debugPrint('Permisos: usando valores por defecto ($e)');
      }
    }

    _efectivos = base;
    _cargado = true;
    notifyListeners();
  }

  void _aplicar(Set<Permiso> destino, List filas) {
    for (final f in filas) {
      final p = Permiso.deClave(f['permiso'] as String? ?? '');
      if (p == null) continue;
      if (f['concedido'] == true) {
        destino.add(p);
      } else {
        destino.remove(p);
      }
    }
  }

  Future<void> reload() async {
    final u = _usuario;
    if (u != null) await load(u);
  }

  void clear() {
    _usuario = null;
    _efectivos = {};
    _roles = [];
    Permiso.nombresRoles = {};
    _cargado = false;
    notifyListeners();
  }

  // ------------------------------------------------------------------
  // Excepciones por rol base y por usuario (pantalla de Permisos)
  // ------------------------------------------------------------------

  Future<Map<Permiso, bool>> excepcionesDeRol(String tenantId, String rol) async {
    final filas = await _client
        .from('rol_permisos')
        .select('permiso, concedido')
        .eq('tenant_id', tenantId)
        .eq('rol', rol);
    return _mapa(filas);
  }

  Future<Map<Permiso, bool>> excepcionesDeUsuario(String userId) async {
    final filas = await _client
        .from('usuario_permisos')
        .select('permiso, concedido')
        .eq('user_id', userId);
    return _mapa(filas);
  }

  Map<Permiso, bool> _mapa(List filas) {
    final out = <Permiso, bool>{};
    for (final f in filas) {
      final p = Permiso.deClave(f['permiso'] as String? ?? '');
      if (p != null) out[p] = f['concedido'] == true;
    }
    return out;
  }

  Future<void> guardarExcepcionRol(
      String tenantId, String rol, Permiso p, bool concedido) async {
    await _client.from('rol_permisos').upsert({
      'tenant_id': tenantId,
      'rol': rol,
      'permiso': p.clave,
      'concedido': concedido,
      'updated_at': DateTime.now().toIso8601String(),
    });
    await _recargarSiAfecta(rol: rol);
  }

  Future<void> quitarExcepcionRol(String tenantId, String rol, Permiso p) async {
    await _client
        .from('rol_permisos')
        .delete()
        .eq('tenant_id', tenantId)
        .eq('rol', rol)
        .eq('permiso', p.clave);
    await _recargarSiAfecta(rol: rol);
  }

  Future<void> restaurarRol(String tenantId, String rol) async {
    await _client.from('rol_permisos').delete().eq('tenant_id', tenantId).eq('rol', rol);
    await _recargarSiAfecta(rol: rol);
  }

  Future<void> guardarExcepcionUsuario(
      String tenantId, String userId, Permiso p, bool concedido) async {
    await _client.from('usuario_permisos').upsert({
      'user_id': userId,
      'tenant_id': tenantId,
      'permiso': p.clave,
      'concedido': concedido,
      'updated_at': DateTime.now().toIso8601String(),
    });
    await _recargarSiAfecta(userId: userId);
  }

  Future<void> quitarExcepcionUsuario(String userId, Permiso p) async {
    await _client
        .from('usuario_permisos')
        .delete()
        .eq('user_id', userId)
        .eq('permiso', p.clave);
    await _recargarSiAfecta(userId: userId);
  }

  Future<void> restaurarUsuario(String userId) async {
    await _client.from('usuario_permisos').delete().eq('user_id', userId);
    await _recargarSiAfecta(userId: userId);
  }

  Future<void> _recargarSiAfecta({String? rol, String? userId}) async {
    final u = _usuario;
    if (u == null) return;
    if (userId == u.id || (rol != null && rol == u.rol)) {
      await reload();
    }
  }

  // ------------------------------------------------------------------
  // Roles personalizados
  // ------------------------------------------------------------------

  /// Descarga los roles de la empresa y actualiza el registro de nombres.
  Future<List<RolPersonalizado>> cargarRoles(String tenantId, {bool notificar = true}) async {
    final filas = await _client
        .from('roles_custom')
        .select()
        .eq('tenant_id', tenantId)
        .order('nombre');
    _roles = filas.map<RolPersonalizado>((j) => RolPersonalizado.fromJson(j)).toList();
    Permiso.nombresRoles = {for (final r in _roles) r.clave: r.nombre};
    if (notificar) notifyListeners();
    return _roles;
  }

  String _generarClave(String nombre) {
    const acentos = {
      'á': 'a', 'é': 'e', 'í': 'i', 'ó': 'o', 'ú': 'u', 'ü': 'u', 'ñ': 'n',
    };
    var base = nombre.toLowerCase().split('').map((c) => acentos[c] ?? c).join();
    base = base.replaceAll(RegExp(r'[^a-z0-9]+'), '_').replaceAll(RegExp(r'^_+|_+$'), '');
    if (base.isEmpty) base = 'rol';
    if (base.length > 18) base = base.substring(0, 18);
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final r = Random.secure();
    final sufijo = List.generate(4, (_) => chars[r.nextInt(chars.length)]).join();
    return '${base}_$sufijo';
  }

  Future<RolPersonalizado> crearRol({
    required String tenantId,
    required String nombre,
    String? descripcion,
    required Set<Permiso> permisos,
  }) async {
    final fila = await _client
        .from('roles_custom')
        .insert({
          'tenant_id': tenantId,
          'clave': _generarClave(nombre),
          'nombre': nombre.trim(),
          'descripcion': descripcion?.trim().isEmpty == true ? null : descripcion?.trim(),
          'permisos': RolPersonalizado.clavesDe(permisos),
        })
        .select()
        .single();
    final rol = RolPersonalizado.fromJson(fila);
    _roles = [..._roles, rol]..sort((a, b) => a.nombre.compareTo(b.nombre));
    Permiso.nombresRoles = {for (final r in _roles) r.clave: r.nombre};
    notifyListeners();
    return rol;
  }

  Future<void> actualizarRol(
    RolPersonalizado rol, {
    String? nombre,
    String? descripcion,
    Set<Permiso>? permisos,
  }) async {
    await _client.from('roles_custom').update({
      if (nombre != null) 'nombre': nombre.trim(),
      if (descripcion != null) 'descripcion': descripcion.trim().isEmpty ? null : descripcion.trim(),
      if (permisos != null) 'permisos': RolPersonalizado.clavesDe(permisos),
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', rol.id);
    final nuevo = rol.copyWith(nombre: nombre?.trim(), descripcion: descripcion, permisos: permisos);
    _roles = [for (final r in _roles) r.id == rol.id ? nuevo : r];
    Permiso.nombresRoles = {for (final r in _roles) r.clave: r.nombre};
    notifyListeners();
    await _recargarSiAfecta(rol: rol.clave);
  }

  /// Cuántas personas (con cuenta) tienen ese rol.
  Future<int> usuariosConRol(String tenantId, String clave) async {
    final filas = await _client
        .from('profiles')
        .select('id')
        .eq('tenant_id', tenantId)
        .eq('rol', clave);
    return filas.length;
  }

  /// Elimina un rol. No se puede si todavía hay personas con ese rol.
  Future<void> eliminarRol(RolPersonalizado rol) async {
    final n = await usuariosConRol(rol.tenantId, rol.clave);
    if (n > 0) {
      throw Exception(
          'No se puede eliminar: $n ${n == 1 ? 'persona tiene' : 'personas tienen'} este rol. Cámbiales el rol primero.');
    }
    await _client.from('roles_custom').delete().eq('id', rol.id);
    _roles = _roles.where((r) => r.id != rol.id).toList();
    Permiso.nombresRoles = {for (final r in _roles) r.clave: r.nombre};
    notifyListeners();
  }

  /// Cambia el rol de una persona (la base de datos valida quién puede hacerlo).
  Future<void> cambiarRolUsuario(String userId, String nuevoRol) async {
    await _client.from('profiles').update({'rol': nuevoRol}).eq('id', userId);
    await _recargarSiAfecta(userId: userId);
  }
}
