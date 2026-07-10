import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/models/usuario_perfil.dart';
import '../../domain/repositories/auth_repository.dart';

class SupabaseAuthRepository implements AuthRepository {
  final _client = Supabase.instance.client;

  Future<UsuarioPerfil?> _getUserProfile(String userId) async {
    // El correo vive en auth.users (Supabase Auth), no en la tabla 'profiles',
    // así que se toma de la sesión actual y se agrega al perfil combinado.
    final sessionUser = _client.auth.currentUser;
    final email = (sessionUser?.id == userId ? sessionUser?.email : null) ?? '';

    try {
      final response = await _client
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();

      if (response == null) {
        // Si por alguna razón el trigger de base de datos no creó el perfil,
        // lo creamos dinámicamente.
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
      // Retornar un perfil básico por seguridad para evitar crash
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

    try {
      await _client
          .from('profiles')
          .update({'aceptado_aviso_at': DateTime.now().toIso8601String()}).eq(
              'id', response.user!.id);

      await _logAuditoria('LOGIN', 'profiles', response.user!.id,
          'Inicio de sesión de usuario y renovación de aceptación del Aviso de Privacidad.');
    } catch (e) {
      print(
          'Error al actualizar fecha de aceptación de aviso en inicio de sesión: $e');
    }

    return await _getUserProfile(response.user!.id);
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
