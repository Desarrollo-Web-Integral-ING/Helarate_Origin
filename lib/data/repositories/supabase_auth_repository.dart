import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/models/usuario_perfil.dart';
import '../../domain/models/tenant_model.dart';
import '../../domain/repositories/auth_repository.dart';

class SupabaseAuthRepository implements AuthRepository {
  final _client = Supabase.instance.client;

  Future<UsuarioPerfil?> _getUserProfile(String userId) async {
    final sessionUser = _client.auth.currentUser;
    final email = (sessionUser?.id == userId ? sessionUser?.email : null) ?? '';

    try {
      final response = await _client
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();

      if (response == null) {
        final defaultProfile = {
          'id': userId,
          'nombre': sessionUser?.userMetadata?['nombre'] ?? 'Usuario Nuevo',
          'rol': 'empleado',
        };
        await _client.from('profiles').insert(defaultProfile);

        return UsuarioPerfil(
          id: userId,
          nombre: defaultProfile['nombre'] as String,
          rol: defaultProfile['rol'] as String,
          email: email,
          createdAt: DateTime.now(),
        );
      }

      return UsuarioPerfil.fromJson({...response, 'email': email});
    } catch (e) {
      print('Error al obtener perfil: $e');
      return UsuarioPerfil(
        id: userId,
        nombre: 'Usuario',
        rol: 'empleado',
        email: email,
        createdAt: DateTime.now(),
      );
    }
  }

  @override
  Future<UsuarioPerfil?> getCurrentUser() async {
    final sessionUser = _client.auth.currentUser;
    if (sessionUser == null) return null;
    return await _getUserProfile(sessionUser.id);
  }

  @override
  Stream<UsuarioPerfil?> get onAuthStateChanges {
    return _client.auth.onAuthStateChange.asyncMap((data) async {
      final sessionUser = data.session?.user;
      if (sessionUser == null) return null;
      return await _getUserProfile(sessionUser.id);
    });
  }

  @override
  Future<UsuarioPerfil?> signInWithEmail(String email, String password) async {
    final response = await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
    if (response.user == null) return null;

    // La aceptación del aviso se guarda una sola vez (ver acceptPrivacyNotice);
    // iniciar sesión ya no la sobrescribe.
    await _logAuditoria('LOGIN', 'profiles', response.user!.id,
        'Inicio de sesión de usuario.');

    return await _getUserProfile(response.user!.id);
  }

  @override
  Future<UsuarioPerfil> acceptPrivacyNotice(String version) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('No hay una sesión activa.');
    final now = DateTime.now();

    try {
      await _client.from('profiles').update({
        'aceptado_aviso_at': now.toIso8601String(),
        'aviso_version': version,
      }).eq('id', user.id);
    } catch (_) {
      // Bases de datos sin la columna aviso_version: guardar solo la fecha.
      await _client
          .from('profiles')
          .update({'aceptado_aviso_at': now.toIso8601String()}).eq('id', user.id);
    }

    await _logAuditoria('PRIVACY_ACCEPT', 'profiles', user.id,
        'Aceptación del Aviso de Privacidad (versión $version).');

    final perfil = await _getUserProfile(user.id);
    return (perfil ?? UsuarioPerfil(id: user.id, nombre: 'Usuario', rol: 'empleado', createdAt: now))
        .copyWith(aceptadoAvisoAt: perfil?.aceptadoAvisoAt ?? now);
  }

  @override
  Future<UsuarioPerfil?> signUpWithEmail(
    String email,
    String password,
    String nombre,
    String rol,
  ) async {
    final response = await _client.auth.signUp(
      email: email,
      password: password,
      data: {
        'nombre': nombre,
        'rol': rol,
      },
    );
    if (response.user == null) return null;

    try {
      await _client
          .from('profiles')
          .update({'aceptado_aviso_at': DateTime.now().toIso8601String()}).eq(
              'id', response.user!.id);

      await _logAuditoria('REGISTER', 'profiles', response.user!.id,
          'Registro de nuevo usuario con nombre: "$nombre" y rol: "$rol". Aceptación inicial del Aviso de Privacidad.');
    } catch (e) {
      print('Error al registrar fecha de aceptación de aviso en registro: $e');
    }

    return await _getUserProfile(response.user!.id);
  }

  @override
  Future<UsuarioPerfil?> signUpNewBusiness(String email, String password, String nombre, String empresa) async {
    final res = await _client.auth.signUp(email: email, password: password);
    final user = res.user;
    if (user == null) throw Exception('No se pudo crear el usuario');
    
    // Create tenant con valores predeterminados de personalización
    final tenantRes = await _client.from('tenants').insert({
      'nombre': empresa,
      'tipo_negocio': 'General',
      'color_primario': '#2563EB',
      'activo': true,
    }).select().single();
    final tenantId = tenantRes['id'];

    // Create profile
    final profile = {
      'id': user.id,
      'nombre': nombre,
      'rol': 'dueño',
      'tenant_id': tenantId
    };
    await _client.from('profiles').insert(profile);
    
    return UsuarioPerfil(
      id: user.id,
      nombre: nombre,
      rol: 'dueño',
      email: email,
      tenantId: tenantId as String?,
      createdAt: DateTime.now(),
    );
  }

  @override
  Future<TenantModel?> getTenant(String tenantId) async {
    try {
      final res = await _client
          .from('tenants')
          .select()
          .eq('id', tenantId)
          .maybeSingle();
      if (res == null) return null;
      return TenantModel.fromJson(res);
    } catch (e) {
      print('Error al obtener datos del tenant: $e');
      return null;
    }
  }

  @override
  Future<TenantModel> updateTenant(TenantModel tenant) async {
    final updateData = tenant.toJson()..remove('id');
    await _client
        .from('tenants')
        .update(updateData)
        .eq('id', tenant.id);
    return tenant;
  }

  @override
  Future<void> signOut() async {
    final user = _client.auth.currentUser;
    if (user != null) {
      await _logAuditoria('LOGOUT', 'profiles', user.id,
          'Cierre de sesión de usuario de forma segura.');
    }
    await _client.auth.signOut();
  }

  @override
  Future<void> deleteAccount() async {
    final user = _client.auth.currentUser;
    if (user == null) return;
    try {
      await _logAuditoria('ARCO_DELETE', 'profiles', user.id,
          'Ejercicio de Derecho ARCO: Cancelación de cuenta y solicitud de purgado de datos personales en cascada.');
      await _client.from('profiles').delete().eq('id', user.id);
    } catch (e) {
      print('Error al borrar perfil: $e');
    }
    await signOut();
  }

  @override
  Future<UsuarioPerfil> updateAvatar(String style, String seed) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw Exception('No hay una sesión activa.');
    }

    try {
      await _client.from('profiles').update({
        'avatar_style': style,
        'avatar_seed': seed,
      }).eq('id', user.id);
    } catch (e) {
      print('Aviso: columnas de avatar en DB no configuradas aún, se actualizará localmente: $e');
    }

    final actualizado = await _getUserProfile(user.id);
    if (actualizado == null) {
      throw Exception('No se pudo confirmar la actualización del avatar.');
    }
    return actualizado.copyWith(avatarStyle: style, avatarSeed: seed);
  }

  @override
  Future<UsuarioPerfil> updateProfile(String nombre) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw Exception('No hay una sesión activa.');
    }

    final nombreLimpio = nombre.trim();
    if (nombreLimpio.isEmpty) {
      throw Exception('El nombre no puede estar vacío.');
    }

    await _client
        .from('profiles')
        .update({'nombre': nombreLimpio}).eq('id', user.id);

    await _logAuditoria(
      'ARCO_RECTIFICATION',
      'profiles',
      user.id,
      'Ejercicio de Derecho ARCO: Rectificación del nombre del perfil de usuario.',
    );

    final actualizado = await _getUserProfile(user.id);
    if (actualizado == null) {
      throw Exception('No se pudo confirmar la actualización del perfil.');
    }
    return actualizado;
  }

  Future<void> _logAuditoria(String action, String tableName, String recordId,
      String descripcion) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return;
      await _client.from('audit_logs').insert({
        'user_id': userId,
        'action': action,
        'table_name': tableName,
        'record_id': recordId,
        'descripcion': descripcion,
      });
    } catch (e) {
      print('Error al guardar log de auditoría en base de datos: $e');
    }
  }
}
