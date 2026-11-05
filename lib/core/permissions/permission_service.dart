import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/models/usuario_perfil.dart';
import 'permiso.dart';

/// Permisos efectivos del usuario con sesión iniciada.
///
/// Orden de prioridad (igual que `tiene_permiso` en la base de datos):
///   1. dueño / superadmin: todo
///   2. excepción por usuario  (tabla usuario_permisos)
///   3. excepción por rol      (tabla rol_permisos, por empresa)
///   4. valores por defecto del rol (Permiso.porDefecto)
///
/// La base de datos vuelve a comprobar los permisos sensibles con RLS, así que
/// ocultar una vista aquí es comodidad; el bloqueo real está en el servidor.
class PermissionService extends ChangeNotifier {
  SupabaseClient get _client => Supabase.instance.client;

  UsuarioPerfil? _usuario;
  Set<Permiso> _efectivos = {};
  bool _cargado = false;

  bool get cargado => _cargado;
  UsuarioPerfil? get usuario => _usuario;
  String get rol => _usuario?.rol ?? '';

  bool can(Permiso p) => _efectivos.contains(p);

  bool canAny(Iterable<Permiso> ps) => ps.any(can);

  /// Calcula los permisos de [usuario]. Si la base de datos no responde (o aún
  /// no se ejecutó la migración), se usan los valores por defecto del rol.
  Future<void> load(UsuarioPerfil usuario) async {
    _usuario = usuario;
    final base = Set<Permiso>.from(Permiso.porDefecto(usuario.rol));

    if (!Permiso.esRolIntocable(usuario.rol)) {
      try {
        final propios = await Future.wait([
          if (usuario.tenantId != null)
            _client
                .from('rol_permisos')
                .select('permiso, concedido')
                .eq('tenant_id', usuario.tenantId!)
                .eq('rol', usuario.rol)
          else
            Future.value(<dynamic>[]),
          _client
              .from('usuario_permisos')
              .select('permiso, concedido')
              .eq('user_id', usuario.id),
        ]);
        _aplicar(base, propios[0]);
        _aplicar(base, propios[1]);
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
    _cargado = false;
    notifyListeners();
  }

  // ------------------------------------------------------------------
  // Administración (pantalla de Permisos)
  // ------------------------------------------------------------------

  /// Excepciones guardadas para un rol de la empresa.
  Future<Map<Permiso, bool>> excepcionesDeRol(String tenantId, String rol) async {
    final filas = await _client
        .from('rol_permisos')
        .select('permiso, concedido')
        .eq('tenant_id', tenantId)
        .eq('rol', rol);
    return _mapa(filas as List);
  }

  /// Excepciones guardadas para un usuario.
  Future<Map<Permiso, bool>> excepcionesDeUsuario(String userId) async {
    final filas = await _client
        .from('usuario_permisos')
        .select('permiso, concedido')
        .eq('user_id', userId);
    return _mapa(filas as List);
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
}
